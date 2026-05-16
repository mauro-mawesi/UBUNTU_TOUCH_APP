import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import "../js/Time.js" as Time

Item {
    id: root
    property var appTheme
    property var i18nApp
    property var conversations: []      // [{id, title, lastMessage, updatedAt, messageCount, topicId}, ...]
    property var topics: []             // [{id, colorPresetIndex, ...}, ...]
    property int currentId: -1
    property string filterText: ""
    property bool wideMode: true        // false → row actions are always visible (touch UX)

    function _topicColorFor(topicId) {
        if (!topicId || topicId <= 0) return "transparent";
        for (var i = 0; i < topics.length; i++) {
            if (topics[i].id === topicId) {
                var presets = appTheme.presets || [];
                var idx = topics[i].colorPresetIndex || 0;
                if (idx >= 0 && idx < presets.length) return presets[idx].primary;
                return appTheme.primary;
            }
        }
        return "transparent";
    }
    signal newChatRequested()
    signal conversationSelected(int id)
    signal renameRequested(int id, string currentTitle)
    signal deleteRequested(int id, string currentTitle)

    readonly property var filteredConversations: {
        if (!filterText || filterText.length === 0) return conversations;
        var q = filterText.toLowerCase();
        var out = [];
        for (var i = 0; i < conversations.length; i++) {
            var c = conversations[i];
            var inTitle = c.title && c.title.toLowerCase().indexOf(q) >= 0;
            var inLast = c.lastMessage && c.lastMessage.toLowerCase().indexOf(q) >= 0;
            if (inTitle || inLast) out.push(c);
        }
        return out;
    }

    // Each row gets a `_bucket` for the ListView section header.
    readonly property var groupedConversations: {
        var src = filteredConversations;
        var lang = (i18nApp && i18nApp.language) ? i18nApp.language : "en";
        var out = [];
        for (var i = 0; i < src.length; i++) {
            var c = src[i];
            var copy = {};
            for (var k in c) copy[k] = c[k];
            copy._bucket = Time.dateBucket(c.updatedAt, lang);
            out.push(copy);
        }
        return out;
    }

    Rectangle {
        anchors.fill: parent
        color: appTheme.surface
    }

    Rectangle {
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        width: 1
        color: appTheme.border
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: units.gu(6)
            color: "transparent"

            BrandMark {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: units.gu(1.5)
                }
                appTheme: root.appTheme
                size: units.gu(3.5)
            }
        }

        // New chat button — primary filled action.
        Rectangle {
            id: newBtn
            Layout.fillWidth: true
            Layout.preferredHeight: units.gu(5)
            Layout.leftMargin: units.gu(1)
            Layout.rightMargin: units.gu(1)
            Layout.topMargin: units.gu(0.2)
            Layout.bottomMargin: units.gu(0.5)
            radius: appTheme.radiusMd
            color: newBtnMouse.pressed
                   ? appTheme.secondary
                   : (newBtnMouse.containsMouse ? Qt.lighter(appTheme.primary, 1.08)
                                                : appTheme.primary)
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: units.gu(1.2)
                anchors.rightMargin: units.gu(1.2)
                spacing: units.gu(0.8)

                Icon {
                    Layout.preferredWidth: units.gu(1.8)
                    Layout.preferredHeight: units.gu(1.8)
                    name: "add"
                    color: appTheme.textOnPrimary
                }
                Label {
                    Layout.fillWidth: true
                    text: i18nApp.tr("New chat")
                    color: appTheme.textOnPrimary
                    textSize: Label.Small
                    font.bold: true
                }
            }
            PressEffect {
                id: newBtnMouse
                onClicked: root.newChatRequested()
            }
        }

        // Search field
        Rectangle {
            id: searchBox
            Layout.fillWidth: true
            Layout.preferredHeight: units.gu(4.2)
            Layout.leftMargin: units.gu(1)
            Layout.rightMargin: units.gu(1)
            Layout.topMargin: units.gu(0.4)
            Layout.bottomMargin: units.gu(0.4)
            radius: units.gu(0.8)
            color: appTheme.surfaceAlt
            border.color: searchInput.activeFocus ? appTheme.borderFocus : appTheme.border
            border.width: 1
            visible: root.conversations.length > 0
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Icon {
                id: searchIcon
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: units.gu(1)
                }
                width: units.gu(1.8); height: width
                name: "find"
                color: appTheme.textMuted
            }

            TextInput {
                id: searchInput
                anchors {
                    left: searchIcon.right
                    right: clearBtn.visible ? clearBtn.left : parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: units.gu(0.8)
                    rightMargin: units.gu(0.6)
                }
                clip: true
                color: appTheme.text
                selectionColor: appTheme.primary
                selectedTextColor: "white"
                font.pixelSize: FontUtils.sizeToPixels("small")
                onTextChanged: root.filterText = text

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.i18nApp ? root.i18nApp.tr("Search conversations") : "Search conversations"
                    color: appTheme.textMuted
                    textSize: Label.Small
                    visible: searchInput.text.length === 0 && !searchInput.activeFocus
                }
            }

            Rectangle {
                id: clearBtn
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: units.gu(0.6)
                }
                width: units.gu(2.4); height: units.gu(2.4)
                radius: width / 2
                color: clearMouse.containsMouse ? appTheme.surfaceHover : "transparent"
                visible: searchInput.text.length > 0
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(1.4); height: width
                    name: "close"
                    color: appTheme.textMuted
                }
                PressEffect {
                    id: clearMouse
                    onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                }
            }
        }

        // Conversations list
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.groupedConversations
            spacing: units.gu(0.2)
            topMargin: units.gu(0.5)
            bottomMargin: units.gu(1)
            leftMargin: units.gu(0.8)
            rightMargin: units.gu(0.8)

            section.property: "_bucket"
            section.delegate: Item {
                width: ListView.view.width
                height: units.gu(3.2)
                Label {
                    anchors {
                        left: parent.left
                        bottom: parent.bottom
                        leftMargin: units.gu(1.2)
                        bottomMargin: units.gu(0.4)
                    }
                    text: section
                    color: appTheme.textMuted
                    textSize: Label.XSmall
                    font.bold: true
                }
            }

            delegate: Rectangle {
                id: row
                width: ListView.view.width - units.gu(1.6)
                height: itemCol.implicitHeight + units.gu(1.6)
                radius: appTheme.radiusMd
                readonly property bool isActive: modelData.id === root.currentId
                color: isActive ? appTheme.bgAccent
                                : (itemMouse.containsMouse ? appTheme.surfaceHover : "transparent")
                border.color: isActive ? appTheme.borderFocus : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }

                // Vertical topic color bar (left edge).
                Rectangle {
                    id: topicBar
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        leftMargin: units.gu(0.5)
                        topMargin: units.gu(0.6)
                        bottomMargin: units.gu(0.6)
                    }
                    width: units.gu(0.45)
                    radius: width / 2
                    color: root._topicColorFor(modelData.topicId)
                    visible: modelData.topicId > 0
                }

                ColumnLayout {
                    id: itemCol
                    anchors {
                        left: parent.left; right: actionsRow.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: units.gu(1.4)
                        rightMargin: units.gu(0.4)
                    }
                    spacing: units.gu(0.2)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(0.6)

                        Label {
                            Layout.fillWidth: true
                            text: modelData.title.length > 0
                                  ? modelData.title
                                  : i18nApp.tr("Untitled")
                            color: appTheme.text
                            textSize: Label.Small
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Label {
                            text: Time.relativeShort(modelData.updatedAt,
                                                     i18nApp ? i18nApp.language : "en")
                            color: appTheme.textMuted
                            textSize: Label.XSmall
                            visible: text.length > 0
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        // Hide the preview when it would just repeat the title.
                        // `deriveTitle` seeds the row from the first message,
                        // so brand-new conversations would otherwise show the
                        // same text on both lines (e.g. "Hola / Hola").
                        readonly property string _previewRaw: modelData.lastMessage
                                ? modelData.lastMessage.substring(0, 80).replace(/\n/g, " ").trim()
                                : ""
                        readonly property string _titleNorm: (modelData.title || "").trim()
                        text: _previewRaw
                        color: appTheme.textMuted
                        textSize: Label.XSmall
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: text.length > 0
                                 && _previewRaw.toLowerCase() !== _titleNorm.toLowerCase()
                    }
                }

                Row {
                    id: actionsRow
                    anchors {
                        right: parent.right; verticalCenter: parent.verticalCenter
                        rightMargin: units.gu(0.4)
                    }
                    spacing: units.gu(0.2)
                    visible: !root.wideMode
                             || itemMouse.containsMouse
                             || renameMouse.containsMouse
                             || deleteMouse.containsMouse

                    Rectangle {
                        width: units.gu(3); height: units.gu(3)
                        radius: width / 2
                        color: renameMouse.containsMouse ? appTheme.surfaceHover : "transparent"
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(1.6); height: width
                            name: "edit"
                            color: appTheme.textSecondary
                        }
                        PressEffect {
                            id: renameMouse
                            onClicked: root.renameRequested(modelData.id, modelData.title)
                        }
                    }
                    Rectangle {
                        width: units.gu(3); height: units.gu(3)
                        radius: width / 2
                        color: deleteMouse.containsMouse ? appTheme.danger : "transparent"
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(1.6); height: width
                            name: "delete"
                            color: deleteMouse.containsMouse ? "white" : appTheme.textSecondary
                        }
                        PressEffect {
                            id: deleteMouse
                            onClicked: root.deleteRequested(modelData.id, modelData.title)
                        }
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    anchors.rightMargin: actionsRow.visible ? actionsRow.width + units.gu(0.4) : 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.conversationSelected(modelData.id)
                }
            }

            // Empty state
            Label {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: {
                    if (!root.i18nApp) return "";
                    if (root.conversations.length === 0) return root.i18nApp.tr("No conversations yet");
                    return root.i18nApp.tr("No matches");
                }
                color: appTheme.textMuted
                textSize: Label.Small
            }
        }
    }
}
