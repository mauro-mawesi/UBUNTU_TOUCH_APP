import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "../js/Markdown.js" as Markdown
import "../js/Time.js" as Time

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
    property real timestamp: 0           // epoch ms (0 = unknown / hide)
    // Named `modelLabel` (not `model`) because a `model` property here would
    // shadow ListView's delegate-context `model`, breaking every `model.role`
    // / `model.content` binding in ChatPage's delegate.
    property string modelLabel: ""
    signal speakRequested()
    signal regenerateRequested()

    // Tool-call rendering (role === "tool")
    property string toolName: ""
    property string toolArgs: ""
    property string toolResult: ""
    property string toolError: ""
    property bool toolExpanded: false

    readonly property bool isUser: role === "user"
    readonly property bool isSystem: role === "system"
    readonly property bool isTool: role === "tool"
    readonly property bool isAssistant: role === "assistant"

    // F7: which chip is currently expanded (-1 = none)
    property int expandedSourceIdx: -1

    width: parent ? parent.width : 0
    height: isTool ? (toolCard.height + units.gu(1.0)) : (bg.height + units.gu(1.2))

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

    // Measures unwrapped text width so the bubble can shrink to short replies.
    TextMetrics {
        id: textMetrics
        font.pixelSize: FontUtils.sizeToPixels("medium")
        text: bubble.text
    }
    readonly property real _bubbleW: Math.min(
        parent ? (parent.width - units.gu(3)) : units.gu(40),
        units.gu(55),
        Math.max(units.gu(14), textMetrics.width + units.gu(5)))

    Rectangle {
        id: bg
        visible: !bubble.isTool
        anchors {
            top: parent.top
            topMargin: units.gu(0.4)
            left: bubble.isUser ? undefined : parent.left
            right: bubble.isUser ? parent.right : undefined
            leftMargin: bubble.isUser ? 0 : units.gu(1.5)
            rightMargin: bubble.isUser ? units.gu(1.5) : 0
        }
        width: bubble._bubbleW
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
            AccentFlicker { appTheme: bubble.appTheme }
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
                Accessible.role: Accessible.Button
                Accessible.name: bubble.speaking
                                 ? (i18nApp ? i18nApp.tr("Stop speaking") : "Stop speaking")
                                 : (i18nApp ? i18nApp.tr("Speak message") : "Speak message")
            }

            // Regenerate button (assistant only).
            Rectangle {
                id: regenBtn
                visible: bubble.isAssistant && bubble.text.length > 0 && !bubble.streaming
                width: units.gu(2.6); height: units.gu(2.6)
                radius: width / 2
                color: regenMouse.pressed
                       ? appTheme.surfaceHover
                       : (regenMouse.containsMouse ? appTheme.surfaceAlt : "transparent")
                opacity: regenMouse.containsMouse ? 1.0 : 0.55
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(1.6); height: width
                    name: "view-refresh"
                    color: appTheme.textSecondary
                }
                MouseArea {
                    id: regenMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bubble.regenerateRequested()
                }
                Accessible.role: Accessible.Button
                Accessible.name: i18nApp ? i18nApp.tr("Regenerate response") : "Regenerate response"
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
                Accessible.role: Accessible.Button
                Accessible.name: i18nApp ? i18nApp.tr("Copy text") : "Copy text"
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

                Item {
                    Layout.preferredWidth: units.gu(2)
                    Layout.preferredHeight: units.gu(2)
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: !bubble.isAssistant
                        color: bubble.isUser ? Qt.rgba(1, 1, 1, 0.25)
                                             : (bubble.isSystem ? appTheme.warning : appTheme.primary)
                        Icon {
                            anchors.centerIn: parent
                            width: parent.width * 0.7; height: width
                            name: bubble.isUser ? "account"
                                                : (bubble.isSystem ? "dialog-warning-symbolic"
                                                                   : "")
                            color: "white"
                        }
                    }
                    BrandMark {
                        anchors.fill: parent
                        visible: bubble.isAssistant
                        appTheme: bubble.appTheme
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignVCenter
                    text: bubble.isUser ? i18nApp.tr("You")
                                        : (bubble.isSystem ? i18nApp.tr("System") : i18nApp.tr("Assistant"))
                    textSize: Label.XSmall
                    color: bubble.isUser ? Qt.rgba(1, 1, 1, 0.85) : appTheme.textSecondary
                    font.bold: true
                }

                // Model + relative time meta line.
                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: bubbleActions.width + units.gu(0.8)
                    text: {
                        var parts = [];
                        if (bubble.isAssistant && bubble.modelLabel.length > 0) parts.push(bubble.modelLabel);
                        if (bubble.timestamp > 0) {
                            parts.push(Time.relativeShort(bubble.timestamp,
                                                          i18nApp ? i18nApp.language : "en"));
                        }
                        return parts.length > 0 ? "· " + parts.join(" · ") : "";
                    }
                    textSize: Label.XSmall
                    color: bubble.isUser ? Qt.rgba(1, 1, 1, 0.65) : appTheme.textMuted
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            Label {
                id: textLabel
                width: parent.width
                // Appends a "▎" caret while streaming so the user sees the
                // bubble is still being generated. Goes through markdown for
                // assistant so it lands at the end of the rendered text.
                text: {
                    var t = bubble.text;
                    if (bubble.streaming && t.length > 0) t = t + " ▎";
                    return bubble.isUser || bubble.isSystem
                           ? t
                           : Markdown.render(t, {
                                codeBg: appTheme.codeBg,
                                linkColor: appTheme.linkColor,
                                border: appTheme.border
                            });
                }
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
                    dotColor: appTheme.primary
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
                        height: tagLabel.height + units.gu(1.0)
                        width: tagLabel.width + units.gu(1.8)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        // Staggered entry animation — each chip fades + slides
                        // in with a small index-based delay so retrieval feels alive.
                        opacity: 0
                        transform: Translate { id: chipTr; y: units.gu(0.6) }
                        Component.onCompleted: chipEntry.start()
                        ParallelAnimation {
                            id: chipEntry
                            PauseAnimation { duration: Math.min(index, 8) * 60 }
                            NumberAnimation {
                                target: chip; property: "opacity"
                                to: 1; duration: 200; easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: chipTr; property: "y"
                                to: 0; duration: 220; easing.type: Easing.OutCubic
                            }
                        }

                        Label {
                            id: tagLabel
                            anchors.centerIn: parent
                            text: {
                                var m = modelData.metadata || {};
                                var name = m.file_name || m.storage_ref || m.source_id || "doc";
                                if (name.length > 32) name = "…" + name.substring(name.length - 31);
                                var rel = "";
                                if (modelData.distance !== undefined && modelData.distance !== null) {
                                    var r = Math.max(0, Math.min(1, 1 - Number(modelData.distance)));
                                    rel = " · " + Math.round(r * 100) + "%";
                                }
                                return (index + 1) + ". " + name + rel;
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
                id: snippetPanel
                width: parent.width
                readonly property bool _open: bubble.expandedSourceIdx >= 0
                                              && bubble.sources
                                              && bubble.expandedSourceIdx < bubble.sources.length
                color: appTheme.surfaceAlt
                border.color: appTheme.border
                border.width: 1
                radius: units.gu(0.8)
                clip: true
                height: _open ? (snippetCol.implicitHeight + units.gu(1.2)) : 0
                opacity: _open ? 1 : 0
                visible: height > 0
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

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
                                var r = Math.max(0, Math.min(1, 1 - Number(s.distance)));
                                return Math.round(r * 100) + "%";
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

    // ---- tool-call card (collapsible) ----
    Rectangle {
        id: toolCard
        visible: bubble.isTool
        anchors {
            top: parent.top
            topMargin: units.gu(0.4)
            left: parent.left
            leftMargin: units.gu(1.5)
            rightMargin: units.gu(1.5)
        }
        width: bubble._bubbleW
        height: toolCol.implicitHeight + units.gu(1.2)
        radius: units.gu(1.2)
        color: appTheme.surfaceAlt
        border.color: bubble.toolError.length > 0 ? appTheme.danger : appTheme.border
        border.width: 1

        Column {
            id: toolCol
            anchors {
                left: parent.left; right: parent.right
                top: parent.top
                topMargin: units.gu(0.6)
                leftMargin: units.gu(1)
                rightMargin: units.gu(1)
            }
            spacing: units.gu(0.4)

            // Header row: icon + name + status + expand toggle
            RowLayout {
                width: parent.width
                spacing: units.gu(0.6)

                Icon {
                    Layout.preferredWidth: units.gu(1.8)
                    Layout.preferredHeight: units.gu(1.8)
                    Layout.alignment: Qt.AlignVCenter
                    name: bubble.toolError.length > 0 ? "dialog-warning-symbolic" : "preferences-system-symbolic"
                    color: bubble.toolError.length > 0 ? appTheme.danger : appTheme.primary
                }
                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: bubble.toolName
                    color: appTheme.text
                    textSize: Label.Small
                    font.bold: true
                    elide: Text.ElideRight
                }
                Label {
                    Layout.alignment: Qt.AlignVCenter
                    text: bubble.toolError.length > 0
                          ? (i18nApp ? i18nApp.tr("error") : "error")
                          : (i18nApp ? i18nApp.tr("ok") : "ok")
                    color: bubble.toolError.length > 0 ? appTheme.danger : appTheme.textSecondary
                    textSize: Label.XSmall
                }
                Icon {
                    Layout.preferredWidth: units.gu(1.6)
                    Layout.preferredHeight: units.gu(1.6)
                    Layout.alignment: Qt.AlignVCenter
                    name: bubble.toolExpanded ? "up" : "down"
                    color: appTheme.textSecondary
                }
            }

            // Expanded body: args + result/error. Animated height for smooth toggle.
            Item {
                id: toolBodyWrap
                width: parent.width
                height: bubble.toolExpanded ? bodyCol.implicitHeight : 0
                clip: true
                opacity: bubble.toolExpanded ? 1 : 0
                visible: height > 0
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Column {
                    id: bodyCol
                    width: parent.width
                    spacing: units.gu(0.4)

                Label {
                    width: parent.width
                    text: i18nApp ? i18nApp.tr("Arguments") : "Arguments"
                    color: appTheme.textMuted
                    textSize: Label.XSmall
                    font.bold: true
                }
                Rectangle {
                    width: parent.width
                    height: argsLabel.implicitHeight + units.gu(0.8)
                    radius: units.gu(0.4)
                    color: appTheme.codeBg
                    Label {
                        id: argsLabel
                        anchors {
                            left: parent.left; right: parent.right
                            top: parent.top
                            margins: units.gu(0.4)
                        }
                        text: bubble.toolArgs.length > 0 ? bubble.toolArgs : "{}"
                        color: appTheme.text
                        textSize: Label.XSmall
                        wrapMode: Text.Wrap
                        font.family: "Monospace"
                    }
                }

                Label {
                    width: parent.width
                    text: bubble.toolError.length > 0
                          ? (i18nApp ? i18nApp.tr("Error") : "Error")
                          : (i18nApp ? i18nApp.tr("Result") : "Result")
                    color: appTheme.textMuted
                    textSize: Label.XSmall
                    font.bold: true
                }
                Rectangle {
                    width: parent.width
                    height: resultLabel.implicitHeight + units.gu(0.8)
                    radius: units.gu(0.4)
                    color: appTheme.codeBg
                    Label {
                        id: resultLabel
                        anchors {
                            left: parent.left; right: parent.right
                            top: parent.top
                            margins: units.gu(0.4)
                        }
                        text: bubble.toolError.length > 0 ? bubble.toolError : bubble.toolResult
                        color: bubble.toolError.length > 0 ? appTheme.danger : appTheme.text
                        textSize: Label.XSmall
                        wrapMode: Text.Wrap
                        font.family: "Monospace"
                    }
                }
                }   // bodyCol
            }       // toolBodyWrap
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: bubble.toolExpanded = !bubble.toolExpanded
        }
    }
}
