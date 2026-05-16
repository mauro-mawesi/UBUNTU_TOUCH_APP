import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "../js/Markdown.js" as Markdown

Item {
    id: bubble
    property string role: "user"
    property string text: ""
    property var sources: []
    property bool streaming: false
    // "retrieving" | "thinking" | "" — drives F5 placeholder while text is empty
    property string phase: ""
    property var i18nApp
    property var appTheme
    property bool speaking: false
    signal speakRequested()

    readonly property bool isUser: role === "user"
    readonly property bool isSystem: role === "system"

    // F7: which chip is currently expanded (-1 = none)
    property int expandedSourceIdx: -1

    width: parent ? parent.width : 0
    height: bg.height + units.gu(1.2)

    // F1: hidden helper to push text into the system clipboard
    TextEdit {
        id: clipboardHelper
        visible: false
        function copyText(t) {
            text = t;
            selectAll();
            copy();
            deselect();
        }
    }

    Rectangle {
        id: bg
        anchors {
            top: parent.top
            topMargin: units.gu(0.4)
            left: bubble.isUser ? undefined : parent.left
            right: bubble.isUser ? parent.right : undefined
            leftMargin: bubble.isUser ? 0 : units.gu(1.5)
            rightMargin: bubble.isUser ? units.gu(1.5) : 0
        }
        width: Math.min(parent.width - units.gu(3), units.gu(55))
        height: contentCol.implicitHeight + units.gu(2.2)
        radius: units.gu(1.8)
        color: bubble.isSystem ? appTheme.bubbleSystemBg
                               : (bubble.isUser ? "transparent" : appTheme.bubbleAssistantBg)
        border.color: bubble.isUser ? "transparent"
                                    : (bubble.isSystem ? appTheme.bubbleSystemBorder : appTheme.bubbleAssistantBorder)
        border.width: 1

        // gradient overlay for user bubbles
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: bubble.isUser
            gradient: Gradient {
                GradientStop { position: 0.0; color: appTheme.primary }
                GradientStop { position: 1.0; color: appTheme.secondary }
            }
        }

        // F1 + speaker: action buttons grouped at the top-right of the bubble.
        Row {
            id: bubbleActions
            anchors {
                top: parent.top
                right: parent.right
                topMargin: units.gu(0.6)
                rightMargin: units.gu(0.6)
            }
            spacing: units.gu(0.2)
            z: 2

            // Speaker button (only on assistant bubbles with content)
            Rectangle {
                id: speakBtn
                visible: !bubble.isUser && !bubble.isSystem && bubble.text.length > 0 && !bubble.streaming
                width: units.gu(2.6); height: units.gu(2.6)
                radius: width / 2
                color: bubble.speaking
                       ? appTheme.primary
                       : (speakerMouse.pressed
                          ? appTheme.surfaceHover
                          : (speakerMouse.containsMouse ? appTheme.surfaceAlt : "transparent"))
                opacity: bubble.speaking || speakerMouse.containsMouse ? 1.0 : 0.55
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(1.6); height: width
                    name: bubble.speaking ? "media-playback-stop" : "audio-speakers-symbolic"
                    color: bubble.speaking ? "white" : appTheme.textSecondary
                }

                MouseArea {
                    id: speakerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bubble.speakRequested()
                }
            }

            // Copy button
            Rectangle {
                id: copyBtn
                visible: bubble.text.length > 0 && !bubble.streaming
                width: units.gu(2.6); height: units.gu(2.6)
                radius: width / 2
                color: copyMouse.pressed
                       ? (bubble.isUser ? Qt.rgba(1, 1, 1, 0.32) : appTheme.surfaceHover)
                       : (copyMouse.containsMouse
                          ? (bubble.isUser ? Qt.rgba(1, 1, 1, 0.22) : appTheme.surfaceAlt)
                          : "transparent")
                opacity: copyMouse.containsMouse ? 1.0 : 0.55
                Behavior on opacity { NumberAnimation { duration: 120 } }

                property bool justCopied: false

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(1.6); height: width
                    name: copyBtn.justCopied ? "ok" : "edit-copy"
                    color: bubble.isUser ? "white" : appTheme.textSecondary
                }

                Timer {
                    id: copiedTimer
                    interval: 900
                    onTriggered: copyBtn.justCopied = false
                }

                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        clipboardHelper.copyText(bubble.text);
                        copyBtn.justCopied = true;
                        copiedTimer.restart();
                    }
                }
            }
        }

        Column {
            id: contentCol
            anchors {
                left: parent.left; right: parent.right
                top: parent.top
                leftMargin: units.gu(1.6)
                rightMargin: units.gu(1.6)
                topMargin: units.gu(1.1)
            }
            spacing: units.gu(0.7)
            z: 1

            RowLayout {
                width: parent.width
                spacing: units.gu(0.6)

                Rectangle {
                    Layout.preferredWidth: units.gu(2)
                    Layout.preferredHeight: units.gu(2)
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    color: bubble.isUser ? Qt.rgba(1, 1, 1, 0.25)
                                         : (bubble.isSystem ? appTheme.warning : appTheme.primary)
                    Label {
                        anchors.centerIn: parent
                        text: bubble.isUser ? "U" : (bubble.isSystem ? "!" : "A")
                        color: appTheme.textOnPrimary
                        textSize: Label.XSmall
                        font.bold: true
                    }
                }
                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: bubbleActions.width + units.gu(0.8)
                    text: bubble.isUser ? i18nApp.tr("You")
                                        : (bubble.isSystem ? i18nApp.tr("System") : i18nApp.tr("Assistant"))
                    textSize: Label.XSmall
                    color: bubble.isUser ? Qt.rgba(1, 1, 1, 0.85) : appTheme.textSecondary
                    font.bold: true
                    elide: Text.ElideRight
                }
            }

            Label {
                id: textLabel
                width: parent.width
                text: bubble.isUser || bubble.isSystem
                      ? bubble.text
                      : Markdown.render(bubble.text, {
                            codeBg: appTheme.codeBg,
                            linkColor: appTheme.linkColor,
                            border: appTheme.border
                        })
                color: bubble.isUser ? appTheme.bubbleUserText
                                     : (bubble.isSystem ? appTheme.bubbleSystemText : appTheme.bubbleAssistantText)
                wrapMode: Text.Wrap
                textFormat: bubble.isUser || bubble.isSystem
                            ? Text.PlainText : Text.RichText
                textSize: Label.Medium
                lineHeight: 1.25
                visible: bubble.text.length > 0
                onLinkActivated: Qt.openUrlExternally(link)
                linkColor: appTheme.linkColor
            }

            // F5: while streaming and the model hasn't produced any text yet,
            // show the current phase next to the typing dots.
            Row {
                visible: bubble.streaming && bubble.text.length === 0
                spacing: units.gu(0.8)

                TypingIndicator {
                    dotColor: appTheme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    visible: bubble.phase === "retrieving"
                             || bubble.phase === "thinking"
                             || bubble.phase === "classifying"
                    text: bubble.phase === "retrieving"
                          ? i18nApp.tr("Searching context…")
                          : (bubble.phase === "classifying"
                             ? i18nApp.tr("Classifying topic…")
                             : i18nApp.tr("Thinking…"))
                    color: appTheme.textSecondary
                    textSize: Label.XSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // F7: source chips — clicking one toggles the snippet panel below.
            Flow {
                width: parent.width
                spacing: units.gu(0.5)
                visible: bubble.sources && bubble.sources.length > 0

                Repeater {
                    model: bubble.sources
                    Rectangle {
                        id: chip
                        readonly property bool isExpanded: bubble.expandedSourceIdx === index
                        radius: units.gu(0.8)
                        color: isExpanded
                               ? appTheme.surfaceHover
                               : (chipMouse.containsMouse ? appTheme.surfaceAlt : appTheme.chipBg)
                        border.color: isExpanded ? appTheme.borderFocus : appTheme.chipBorder
                        border.width: 1
                        height: tagLabel.height + units.gu(0.6)
                        width: tagLabel.width + units.gu(1.4)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Label {
                            id: tagLabel
                            anchors.centerIn: parent
                            text: {
                                var m = modelData.metadata || {};
                                var name = m.file_name || m.storage_ref || m.source_id || "doc";
                                if (name.length > 36) name = "…" + name.substring(name.length - 35);
                                return (index + 1) + ". " + name;
                            }
                            textSize: Label.XSmall
                            color: appTheme.chipText
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                bubble.expandedSourceIdx =
                                    (bubble.expandedSourceIdx === index) ? -1 : index;
                            }
                        }
                    }
                }
            }

            // F7: expanded snippet panel for the currently selected chip.
            Rectangle {
                width: parent.width
                visible: bubble.expandedSourceIdx >= 0
                         && bubble.sources
                         && bubble.expandedSourceIdx < bubble.sources.length
                color: appTheme.surfaceAlt
                border.color: appTheme.border
                border.width: 1
                radius: units.gu(0.8)
                height: visible ? (snippetCol.implicitHeight + units.gu(1.2)) : 0

                Column {
                    id: snippetCol
                    anchors {
                        left: parent.left; right: parent.right
                        top: parent.top
                        leftMargin: units.gu(1)
                        rightMargin: units.gu(1)
                        topMargin: units.gu(0.6)
                    }
                    spacing: units.gu(0.3)

                    Row {
                        spacing: units.gu(0.6)
                        Label {
                            text: {
                                if (!bubble.sources || bubble.expandedSourceIdx < 0) return "";
                                var s = bubble.sources[bubble.expandedSourceIdx] || {};
                                var m = s.metadata || {};
                                return m.file_name || m.storage_ref || m.source_id || "doc";
                            }
                            color: appTheme.text
                            textSize: Label.XSmall
                            font.bold: true
                            elide: Text.ElideMiddle
                            width: Math.min(implicitWidth, snippetCol.width - units.gu(8))
                        }
                        Label {
                            text: {
                                if (!bubble.sources || bubble.expandedSourceIdx < 0) return "";
                                var s = bubble.sources[bubble.expandedSourceIdx] || {};
                                if (s.distance === undefined || s.distance === null) return "";
                                return "d=" + Number(s.distance).toFixed(3);
                            }
                            color: appTheme.textMuted
                            textSize: Label.XSmall
                        }
                    }

                    Label {
                        width: snippetCol.width
                        text: {
                            if (!bubble.sources || bubble.expandedSourceIdx < 0) return "";
                            var s = bubble.sources[bubble.expandedSourceIdx] || {};
                            var doc = (s.document || "").replace(/\s+/g, " ").trim();
                            if (doc.length === 0) return i18nApp ? i18nApp.tr("(no snippet)") : "(no snippet)";
                            if (doc.length > 600) doc = doc.substring(0, 600) + "…";
                            return doc;
                        }
                        color: appTheme.textSecondary
                        textSize: Label.XSmall
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
