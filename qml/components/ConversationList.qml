import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

Item {
    id: root
    property var appTheme
    property var i18nApp
    property var conversations: []      // [{id, title, lastMessage, updatedAt, messageCount}, ...]
    property int currentId: -1
    property string filterText: ""
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
            Layout.preferredHeight: units.gu(7)
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: units.gu(1.5)
                anchors.rightMargin: units.gu(1.5)
                spacing: units.gu(1)

                Rectangle {
                    Layout.preferredWidth: units.gu(3.5)
                    Layout.preferredHeight: units.gu(3.5)
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: appTheme.primary }
                        GradientStop { position: 1; color: appTheme.secondary }
                    }
                    Label {
                        anchors.centerIn: parent
                        text: "✦"
                        color: "white"
                        font.pixelSize: units.gu(2)
                    }
                }

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: i18nApp.tr("RAG Assistant")
                    color: appTheme.text
                    textSize: Label.Medium
                    font.bold: true
                    elide: Text.ElideRight
                }
            }
        }

        // New chat button
        Rectangle {
            id: newBtn
            Layout.fillWidth: true
            Layout.preferredHeight: units.gu(5)
            Layout.leftMargin: units.gu(1)
            Layout.rightMargin: units.gu(1)
            Layout.bottomMargin: units.gu(0.5)
            radius: units.gu(1)
            color: newBtnMouse.containsMouse ? appTheme.surfaceHover : "transparent"
            border.color: appTheme.border
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: units.gu(1.2)
                anchors.rightMargin: units.gu(1.2)
                spacing: units.gu(0.8)

                Icon {
                    Layout.preferredWidth: units.gu(1.8)
                    Layout.preferredHeight: units.gu(1.8)
                    name: "add"
                    color: appTheme.text
                }
                Label {
                    Layout.fillWidth: true
                    text: i18nApp.tr("New chat")
                    color: appTheme.text
                    textSize: Label.Small
                    font.bold: true
                }
            }
            MouseArea {
                id: newBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
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
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
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
            model: root.filteredConversations
            spacing: units.gu(0.2)
            topMargin: units.gu(0.5)
            bottomMargin: units.gu(1)
            leftMargin: units.gu(0.8)
            rightMargin: units.gu(0.8)

            delegate: Rectangle {
                width: ListView.view.width - units.gu(1.6)
                height: itemCol.implicitHeight + units.gu(1.6)
                radius: units.gu(1)
                readonly property bool isActive: modelData.id === root.currentId
                color: isActive ? appTheme.bgAccent
                                : (itemMouse.containsMouse ? appTheme.surfaceHover : "transparent")
                border.color: isActive ? appTheme.borderFocus : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }

                ColumnLayout {
                    id: itemCol
                    anchors {
                        left: parent.left; right: actionsRow.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: units.gu(1)
                        rightMargin: units.gu(0.4)
                    }
                    spacing: units.gu(0.2)

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
                        Layout.fillWidth: true
                        text: modelData.lastMessage
                              ? modelData.lastMessage.substring(0, 80).replace(/\n/g, " ")
                              : ""
                        color: appTheme.textMuted
                        textSize: Label.XSmall
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: text.length > 0
                    }
                }

                Row {
                    id: actionsRow
                    anchors {
                        right: parent.right; verticalCenter: parent.verticalCenter
                        rightMargin: units.gu(0.4)
                    }
                    spacing: units.gu(0.2)
                    visible: itemMouse.containsMouse || renameMouse.containsMouse || deleteMouse.containsMouse

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
                        MouseArea {
                            id: renameMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
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
                        MouseArea {
                            id: deleteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
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
