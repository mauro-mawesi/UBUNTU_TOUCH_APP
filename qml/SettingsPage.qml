import QtQuick 2.7
import QtGraphicalEffects 1.0
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3
import "components"
import "js/Store.js" as Store
import "js/BrainMetrics.js" as Metrics

Page {
    id: page
    property var appSettings
    property var i18nApp
    property var appTheme
    property var themeTransition: null
    property var accentSweep: null
    // When true, theme/accent changes apply directly instead of running the
    // capture+circle-reveal animation. Avoids freezing a snapshot of an
    // in-flight chat bubble (visual jank + brief privacy concern) and
    // smooths out the experience when the user fidgets with settings while
    // a response streams.
    property bool chatBusy: false

    // Emitted whenever topics are created/edited/deleted so ChatPage refreshes.
    signal topicsModified()

    property var topics: []
    property bool revealApiKey: false
    property bool revealGeminiKey: false
    property bool revealWhisperKey: false
    property bool revealTtsKey: false

    function refreshTopics() {
        topics = Store.listTopics();
    }

    Component.onCompleted: {
        // Defensive: Component.onCompleted ordering between sibling Items is
        // not guaranteed, so we re-init here too. Store.init is idempotent.
        Store.init(appSettings.collectionId, i18nApp.tr("General"));
        refreshTopics();
    }

    function topicColor(topic) {
        if (!topic) return appTheme.textMuted;
        var presets = appTheme.presets || [];
        var idx = topic.colorPresetIndex || 0;
        if (idx >= 0 && idx < presets.length) return presets[idx].primary;
        return appTheme.primary;
    }

    function openTopicEditor(topic) {
        PopupUtils.open(topicEditor, page, { editing: topic || null });
    }

    function openTopicDelete(topic) {
        PopupUtils.open(topicDeleteDialog, page, { topicRef: topic });
    }

    // Spawn the colour picker anchored on the Custom chip. We park the
    // target preset index on the popover so its `chosen` handler knows
    // which slot to activate after the user commits.
    function openColorPicker(presetIdx, caller) {
        var seed = appSettings.customAccentColor && appSettings.customAccentColor.length > 0
                   ? appSettings.customAccentColor
                   : appTheme.presets[presetIdx].primary;
        PopupUtils.open(colorPickerDialog, caller || page, {
            appTheme: page.appTheme,
            i18nApp: page.i18nApp,
            initialHex: seed,
            targetIndex: presetIdx
        });
    }

    Component {
        id: colorPickerDialog
        ColorPickerPopover {
            id: cp
            property int targetIndex: -1
            onChosen: {
                // Apply the change directly — don't wait for the sweep's
                // midpoint signal. AppTheme's 520ms color Behavior on
                // _primaryAnim morphs every shade smoothly underneath the
                // beam, so the visual still reads as a coordinated swap
                // even when the mutation lands immediately.
                appSettings.customAccentColor = hex;
                if (appSettings.themePresetIndex !== targetIndex) {
                    appSettings.themePresetIndex = targetIndex;
                }
                if (page.accentSweep && !page.chatBusy) {
                    // No deferred mutation needed; the sweep is purely a
                    // visual flourish on top of the morph.
                    page.accentSweep.pendingIndex = -1;
                    page.accentSweep.run(hex, appTheme.deriveSecondary(hex));
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: -1
        gradient: Gradient {
            GradientStop { position: 0.0; color: appTheme.bgGradientStart }
            GradientStop { position: 0.5; color: appTheme.bgGradientMid }
            GradientStop { position: 1.0; color: appTheme.bgGradientEnd }
        }
    }

    header: PageHeader {
        StyleHints {
            backgroundColor: "transparent"
            foregroundColor: appTheme.text
            dividerColor: appTheme.border
        }
        contents: Item {
            anchors.fill: parent
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: appTheme.space2
                BrandMark {
                    anchors.verticalCenter: parent.verticalCenter
                    appTheme: page.appTheme
                    size: units.gu(2.8)
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: i18nApp.tr("Settings")
                    color: appTheme.text
                    textSize: Label.Large
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
        }
    }

    Flickable {
        anchors {
            top: page.header.bottom
            left: parent.left; right: parent.right; bottom: parent.bottom
        }
        contentHeight: rootCol.implicitHeight + units.gu(4)
        clip: true

        ColumnLayout {
            id: rootCol
            anchors {
                left: parent.left; right: parent.right
                top: parent.top
                topMargin: units.gu(2)
                leftMargin: units.gu(1.5)
                rightMargin: units.gu(1.5)
            }
            spacing: units.gu(1.5)

            // ---------- Appearance ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Appearance"
                icon: "preferences-desktop-theme-symbolic"
                collapsible: true

                FieldLabel {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.5)
                    appTheme: page.appTheme
                    i18nApp: page.i18nApp
                    textKey: "Theme"
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.6)

                    Repeater {
                        model: [
                            { code: "dark",  labelKey: "Dark" },
                            { code: "light", labelKey: "Light" }
                        ]
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: units.gu(4.5)
                            radius: units.gu(0.8)
                            color: appSettings.themeMode === modelData.code
                                   ? appTheme.primary
                                   : (themeMouse.containsMouse ? appTheme.surfaceHover : appTheme.surfaceAlt)
                            border.color: appSettings.themeMode === modelData.code
                                          ? appTheme.secondary : appTheme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            TransLabel {
                                anchors.centerIn: parent
                                i18nApp: page.i18nApp
                                key: modelData.labelKey
                                color: appSettings.themeMode === modelData.code
                                       ? appTheme.textOnPrimary : appTheme.text
                                fontPixelSize: FontUtils.sizeToPixels("small")
                                bold: appSettings.themeMode === modelData.code
                            }
                            MouseArea {
                                id: themeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (appSettings.themeMode === modelData.code) return;
                                    if (page.themeTransition && !page.chatBusy) {
                                        var p = mapToItem(null, mouse.x, mouse.y);
                                        page.themeTransition.run(p.x, p.y, modelData.code);
                                    } else {
                                        appSettings.themeMode = modelData.code;
                                    }
                                }
                            }
                        }
                    }
                }

                FieldLabel {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.8)
                    appTheme: page.appTheme
                    i18nApp: page.i18nApp
                    textKey: "Accent color"
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: units.gu(0.8)

                    Repeater {
                        id: presetRepeater
                        model: appTheme.presets
                        Rectangle {
                            id: chipRect
                            // The Custom slot is identified by position — it's
                            // always the last entry in `presets`. Reading
                            // `modelData.isCustom` was unreliable in the
                            // Repeater context (the rainbow LinearGradient
                            // ended up painted on every chip; see the audit
                            // screenshot 5.png).
                            readonly property bool isCustomSlot:
                                index === appTheme.presets.length - 1

                            width: units.gu(5.5)
                            height: units.gu(5.5)
                            radius: width / 2
                            clip: true
                            // Built-in presets render as a primary→secondary
                            // duo. The Custom slot has placeholder values
                            // here that are covered by the rainbow overlay.
                            // (Don't set `color`: it overrides `gradient`
                            // and leaves the chip empty.)
                            gradient: Gradient {
                                GradientStop { position: 0; color: modelData.primary }
                                GradientStop { position: 1; color: modelData.secondary }
                            }
                            border.color: appSettings.themePresetIndex === index
                                          ? appTheme.text : "transparent"
                            border.width: 3

                            // Rainbow fill for the Custom chip — diagonal
                            // LinearGradient through the full HSV ring,
                            // clipped by the parent's circular radius.
                            LinearGradient {
                                anchors.fill: parent
                                visible: chipRect.isCustomSlot
                                start: Qt.point(0, 0)
                                end:   Qt.point(parent.width, parent.height)
                                gradient: Gradient {
                                    GradientStop { position: 0.00; color: "#ef4444" }
                                    GradientStop { position: 0.17; color: "#f59e0b" }
                                    GradientStop { position: 0.33; color: "#84cc16" }
                                    GradientStop { position: 0.50; color: "#06b6d4" }
                                    GradientStop { position: 0.67; color: "#6366f1" }
                                    GradientStop { position: 0.83; color: "#a855f7" }
                                    GradientStop { position: 1.00; color: "#ec4899" }
                                }
                            }

                            // '+' badge centred on the Custom chip. Replaced
                            // by the 'ok' tick when Custom is the active slot.
                            Rectangle {
                                visible: chipRect.isCustomSlot
                                         && appSettings.themePresetIndex !== index
                                anchors.centerIn: parent
                                width: units.gu(2.6); height: width
                                radius: width / 2
                                color: appTheme.surface
                                border.color: appTheme.text
                                border.width: 1
                                Icon {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.65; height: width
                                    name: "add"
                                    color: appTheme.text
                                }
                            }

                            Icon {
                                visible: appSettings.themePresetIndex === index
                                anchors.centerIn: parent
                                width: units.gu(2.5); height: width
                                name: "ok"
                                color: "white"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                // Custom: always open the picker on tap so
                                // re-tapping the active Custom chip lets the
                                // user adjust their colour. Other presets:
                                // sweep+apply unless chat is busy.
                                onClicked: {
                                    if (chipRect.isCustomSlot) {
                                        page.openColorPicker(index, chipRect);
                                        return;
                                    }
                                    if (appSettings.themePresetIndex === index) return;
                                    if (page.accentSweep && !page.chatBusy) {
                                        page.accentSweep.pendingIndex = index;
                                        page.accentSweep.run(modelData.primary,
                                                             modelData.secondary);
                                    } else {
                                        appSettings.themePresetIndex = index;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------- Interface (language) ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Interface"
                icon: "preferences-desktop-locale-symbolic"
                collapsible: true

                FieldLabel {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.5)
                    appTheme: page.appTheme
                    i18nApp: page.i18nApp
                    textKey: "Language"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.6)

                    Repeater {
                        model: [
                            { code: "en", labelKey: "English" },
                            { code: "es", labelKey: "Spanish" },
                            { code: "nl", labelKey: "Dutch" }
                        ]
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: units.gu(4.5)
                            radius: units.gu(0.8)
                            color: appSettings.language === modelData.code
                                   ? appTheme.primary
                                   : (langMouse.containsMouse ? appTheme.surfaceHover : appTheme.surfaceAlt)
                            border.color: appSettings.language === modelData.code
                                          ? appTheme.secondary : appTheme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            TransLabel {
                                anchors.centerIn: parent
                                i18nApp: page.i18nApp
                                key: modelData.labelKey
                                color: appSettings.language === modelData.code
                                       ? appTheme.textOnPrimary : appTheme.text
                                fontPixelSize: FontUtils.sizeToPixels("small")
                                bold: appSettings.language === modelData.code
                            }
                            MouseArea {
                                id: langMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: appSettings.language = modelData.code
                            }
                        }
                    }
                }
            }

            // ---------- Language model ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Language model"
                icon: "system-run"
                collapsible: true

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "OpenRouter API Key" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.4)

                    StyledField {
                        Layout.fillWidth: true
                        appTheme: page.appTheme
                        echoMode: page.revealApiKey ? TextInput.Normal : TextInput.Password
                        placeholderText: "sk-or-..."
                        text: appSettings.apiKey
                        onTextChanged: appSettings.apiKey = text
                    }
                    Rectangle {
                        Layout.preferredWidth: units.gu(4.5)
                        Layout.preferredHeight: units.gu(4.5)
                        Layout.alignment: Qt.AlignVCenter
                        radius: appTheme.radiusMd
                        color: revealMouse.containsMouse ? appTheme.surfaceHover : appTheme.surfaceAlt
                        border.color: appTheme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(1.8); height: width
                            name: page.revealApiKey ? "view-off" : "view-on"
                            color: appTheme.textSecondary
                        }
                        MouseArea {
                            id: revealMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.revealApiKey = !page.revealApiKey
                        }
                    }
                }

                // The key lives plaintext in Qt.labs.settings (.conf in
                // ~/.config/ragassistant.ragassistant/). Surface this to the
                // user so they can decide rotation cadence / scope-limit it.
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.2)
                    text: i18nApp.tr("Key is saved unencrypted on this device.")
                    color: appTheme.textMuted
                    textSize: Label.XSmall
                    wrapMode: Text.Wrap
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Model" }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    placeholderText: "google/gemini-2.5-pro"
                    text: appSettings.model
                    onTextChanged: appSettings.model = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Base URL" }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.openrouterUrl
                    // Only accept blanks or strings that start with http(s) —
                    // prevents an accidental "evil.com" paste from sending the
                    // API key to an arbitrary host on the next request.
                    onTextChanged: if (text.length === 0 || /^https?:\/\//i.test(text)) appSettings.openrouterUrl = text;
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.8)
                    spacing: units.gu(0.8)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            text: i18nApp.tr("Enable tools (function calling)")
                            color: appTheme.text
                            textSize: Label.Small
                        }
                        Label {
                            Layout.fillWidth: true
                            text: i18nApp.tr("Lets the model call built-in tools like calculator or current time. Requires a tool-capable model.")
                            color: appTheme.textMuted
                            textSize: Label.XSmall
                            wrapMode: Text.Wrap
                        }
                    }
                    Switch {
                        Layout.alignment: Qt.AlignTop
                        checked: appSettings.toolsEnabled
                        onCheckedChanged: appSettings.toolsEnabled = checked
                    }
                }
            }

            // ---------- Chroma ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Vector store (Chroma)"
                icon: "drive-harddisk-symbolic"
                collapsible: true
                collapsed: true

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Base URL" }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.chromaUrl
                    onTextChanged: if (text.length === 0 || /^https?:\/\//i.test(text)) appSettings.chromaUrl = text;
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Tenant" }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.tenant
                    onTextChanged: appSettings.tenant = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Database" }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.database
                    onTextChanged: appSettings.database = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Collection ID" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.4)

                    StyledField {
                        Layout.fillWidth: true
                        appTheme: page.appTheme
                        text: appSettings.collectionId
                        onTextChanged: appSettings.collectionId = text
                    }
                    Rectangle {
                        Layout.preferredWidth: units.gu(4.5)
                        Layout.preferredHeight: units.gu(4.5)
                        Layout.alignment: Qt.AlignVCenter
                        radius: appTheme.radiusMd
                        color: pickMouse.containsMouse ? appTheme.surfaceHover : appTheme.surfaceAlt
                        border.color: appTheme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(1.8); height: width
                            name: "view-list-symbolic"
                            color: appTheme.textSecondary
                        }
                        MouseArea {
                            id: pickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PopupUtils.open(collectionPicker, page)
                        }
                    }
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Top K results" }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: String(appSettings.topK)
                    inputMethodHints: Qt.ImhDigitsOnly
                    onTextChanged: {
                        var n = parseInt(text);
                        if (!isNaN(n) && n > 0) appSettings.topK = n;
                    }
                }
            }

            // ---------- Embeddings ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Embeddings"
                icon: "view-list-symbolic"
                collapsible: true
                collapsed: true

                FieldLabel {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.5)
                    appTheme: page.appTheme
                    i18nApp: page.i18nApp
                    textKey: "Embedding provider"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.6)

                    Repeater {
                        model: [
                            { code: "ollama", labelKey: "Ollama" },
                            { code: "gemini", labelKey: "Gemini" }
                        ]
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: units.gu(4.5)
                            radius: units.gu(0.8)
                            color: appSettings.embedderProvider === modelData.code
                                   ? appTheme.primary
                                   : (provMouse.containsMouse ? appTheme.surfaceHover : appTheme.surfaceAlt)
                            border.color: appSettings.embedderProvider === modelData.code
                                          ? appTheme.secondary : appTheme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Label {
                                anchors.centerIn: parent
                                text: modelData.labelKey
                                color: appSettings.embedderProvider === modelData.code
                                       ? appTheme.textOnPrimary : appTheme.text
                                textSize: Label.Small
                                font.bold: appSettings.embedderProvider === modelData.code
                            }
                            MouseArea {
                                id: provMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: appSettings.embedderProvider = modelData.code
                            }
                        }
                    }
                }

                // ----- Ollama provider fields -----
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.6)
                    visible: appSettings.embedderProvider !== "gemini"

                    FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Base URL" }
                    StyledField {
                        Layout.fillWidth: true
                        appTheme: page.appTheme
                        text: appSettings.ollamaUrl
                        onTextChanged: if (text.length === 0 || /^https?:\/\//i.test(text)) appSettings.ollamaUrl = text;
                    }

                    FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Embedding model" }
                    StyledField {
                        Layout.fillWidth: true
                        appTheme: page.appTheme
                        text: appSettings.embedModel
                        onTextChanged: appSettings.embedModel = text
                    }
                }

                // ----- Gemini provider fields -----
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.6)
                    visible: appSettings.embedderProvider === "gemini"

                    FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Gemini API Key" }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(0.4)

                        StyledField {
                            Layout.fillWidth: true
                            appTheme: page.appTheme
                            echoMode: page.revealGeminiKey ? TextInput.Normal : TextInput.Password
                            placeholderText: "AIza..."
                            text: appSettings.geminiApiKey
                            onTextChanged: appSettings.geminiApiKey = text
                        }
                        Rectangle {
                            Layout.preferredWidth: units.gu(4.5)
                            Layout.preferredHeight: units.gu(4.5)
                            Layout.alignment: Qt.AlignVCenter
                            radius: appTheme.radiusMd
                            color: revealGeminiMouse.containsMouse ? appTheme.surfaceHover : appTheme.surfaceAlt
                            border.color: appTheme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Icon {
                                anchors.centerIn: parent
                                width: units.gu(1.8); height: width
                                name: page.revealGeminiKey ? "view-off" : "view-on"
                                color: appTheme.textSecondary
                            }
                            MouseArea {
                                id: revealGeminiMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.revealGeminiKey = !page.revealGeminiKey
                            }
                        }
                    }

                    // Same disclosure as the OpenRouter key: stored plaintext
                    // in Qt.labs.settings .conf.
                    Label {
                        Layout.fillWidth: true
                        Layout.topMargin: units.gu(0.2)
                        text: i18nApp.tr("Key is saved unencrypted on this device.")
                        color: appTheme.textMuted
                        textSize: Label.XSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.topMargin: units.gu(0.2)
                        visible: appSettings.geminiApiKey.length === 0
                        text: i18nApp.tr("API key required for Gemini provider")
                        color: appTheme.danger ? appTheme.danger : "#ef4444"
                        textSize: Label.XSmall
                        wrapMode: Text.Wrap
                    }

                    FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Gemini embedding model" }
                    StyledField {
                        Layout.fillWidth: true
                        appTheme: page.appTheme
                        placeholderText: "gemini-embedding-2"
                        text: appSettings.geminiEmbedModel
                        onTextChanged: appSettings.geminiEmbedModel = text
                    }

                    FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Gemini base URL" }
                    StyledField {
                        Layout.fillWidth: true
                        appTheme: page.appTheme
                        text: appSettings.geminiEmbedUrl
                        onTextChanged: if (text.length === 0 || /^https?:\/\//i.test(text)) appSettings.geminiEmbedUrl = text;
                    }
                }
            }

            // ---------- Topics ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Topics"
                icon: "tag"
                collapsible: true

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.5)
                    spacing: units.gu(0.4)

                    Repeater {
                        model: page.topics
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: units.gu(5)
                            radius: units.gu(0.8)
                            color: topicMouse.containsMouse ? appTheme.surfaceHover : appTheme.surfaceAlt
                            border.color: appTheme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: units.gu(1)
                                    rightMargin: units.gu(0.4)
                                }
                                spacing: units.gu(0.8)

                                Rectangle {
                                    Layout.preferredWidth: units.gu(1.4)
                                    Layout.preferredHeight: units.gu(1.4)
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: width / 2
                                    color: page.topicColor(modelData)
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 0

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.name || i18nApp.tr("Untitled")
                                        color: appTheme.text
                                        textSize: Label.Small
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.collectionId || ""
                                        color: appTheme.textMuted
                                        textSize: Label.XSmall
                                        elide: Text.ElideMiddle
                                        visible: text.length > 0
                                    }
                                }

                                // Edit
                                Rectangle {
                                    Layout.preferredWidth: units.gu(3); Layout.preferredHeight: units.gu(3)
                                    radius: width / 2
                                    color: editMouse.containsMouse ? appTheme.surfaceHover : "transparent"
                                    Icon {
                                        anchors.centerIn: parent
                                        width: units.gu(1.6); height: width
                                        name: "edit"
                                        color: appTheme.textSecondary
                                    }
                                    MouseArea {
                                        id: editMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.openTopicEditor(modelData)
                                    }
                                }
                                // Delete
                                Rectangle {
                                    Layout.preferredWidth: units.gu(3); Layout.preferredHeight: units.gu(3)
                                    radius: width / 2
                                    color: delMouse.containsMouse ? appTheme.danger : "transparent"
                                    Icon {
                                        anchors.centerIn: parent
                                        width: units.gu(1.6); height: width
                                        name: "delete"
                                        color: delMouse.containsMouse ? "white" : appTheme.textSecondary
                                    }
                                    MouseArea {
                                        id: delMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.openTopicDelete(modelData)
                                    }
                                }
                            }

                            MouseArea {
                                id: topicMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                propagateComposedEvents: true
                                onClicked: mouse.accepted = false
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: i18nApp.tr("No topics yet")
                        color: appTheme.textMuted
                        textSize: Label.Small
                        horizontalAlignment: Text.AlignHCenter
                        visible: page.topics.length === 0
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: units.gu(4.5)
                        Layout.topMargin: units.gu(0.6)
                        radius: units.gu(0.8)
                        color: addTopicMouse.pressed ? appTheme.secondary
                              : (addTopicMouse.containsMouse ? appTheme.surfaceHover : appTheme.primary)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: units.gu(0.6)
                            Icon {
                                Layout.preferredWidth: units.gu(1.8); Layout.preferredHeight: units.gu(1.8)
                                name: "add"
                                color: appTheme.textOnPrimary
                            }
                            Label {
                                text: i18nApp.tr("Add topic")
                                color: appTheme.textOnPrimary
                                textSize: Label.Small
                                font.bold: true
                            }
                        }
                        MouseArea {
                            id: addTopicMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.openTopicEditor(null)
                        }
                    }
                }
            }

            // ---------- Voice (STT) ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Voice (STT)"
                icon: "audio-input-microphone-symbolic"
                collapsible: true
                collapsed: true

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Base URL" }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.whisperUrl
                    onTextChanged: if (text.length === 0 || /^https?:\/\//i.test(text)) appSettings.whisperUrl = text;
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Model" }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    placeholderText: "Systran/faster-whisper-small"
                    text: appSettings.whisperModel
                    onTextChanged: appSettings.whisperModel = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "API Key (optional)" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.4)

                    StyledField {
                        Layout.fillWidth: true
                        appTheme: page.appTheme
                        echoMode: page.revealWhisperKey ? TextInput.Normal : TextInput.Password
                        text: appSettings.whisperApiKey
                        onTextChanged: appSettings.whisperApiKey = text
                    }
                    Rectangle {
                        Layout.preferredWidth: units.gu(4.5)
                        Layout.preferredHeight: units.gu(4.5)
                        Layout.alignment: Qt.AlignVCenter
                        radius: appTheme.radiusMd
                        color: whisperRevealMouse.containsMouse ? appTheme.surfaceHover : appTheme.surfaceAlt
                        border.color: appTheme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(1.8); height: width
                            name: page.revealWhisperKey ? "view-off" : "view-on"
                            color: appTheme.textSecondary
                        }
                        MouseArea {
                            id: whisperRevealMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.revealWhisperKey = !page.revealWhisperKey
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.2)
                    text: i18nApp.tr("Key is saved unencrypted on this device.")
                    color: appTheme.textMuted
                    textSize: Label.XSmall
                    wrapMode: Text.Wrap
                    visible: appSettings.whisperApiKey.length > 0
                }
            }

            // ---------- Voice (TTS) ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Voice (TTS)"
                icon: "audio-input-microphone-symbolic"
                collapsible: true
                collapsed: true

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Base URL" }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.ttsUrl
                    onTextChanged: if (text.length === 0 || /^https?:\/\//i.test(text)) appSettings.ttsUrl = text;
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Voice (empty = auto by language)" }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    placeholderText: "af_bella"
                    text: appSettings.ttsVoice
                    onTextChanged: appSettings.ttsVoice = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "API Key (optional)" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.4)

                    StyledField {
                        Layout.fillWidth: true
                        appTheme: page.appTheme
                        echoMode: page.revealTtsKey ? TextInput.Normal : TextInput.Password
                        text: appSettings.ttsApiKey
                        onTextChanged: appSettings.ttsApiKey = text
                    }
                    Rectangle {
                        Layout.preferredWidth: units.gu(4.5)
                        Layout.preferredHeight: units.gu(4.5)
                        Layout.alignment: Qt.AlignVCenter
                        radius: appTheme.radiusMd
                        color: ttsRevealMouse.containsMouse ? appTheme.surfaceHover : appTheme.surfaceAlt
                        border.color: appTheme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(1.8); height: width
                            name: page.revealTtsKey ? "view-off" : "view-on"
                            color: appTheme.textSecondary
                        }
                        MouseArea {
                            id: ttsRevealMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.revealTtsKey = !page.revealTtsKey
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.2)
                    text: i18nApp.tr("Key is saved unencrypted on this device.")
                    color: appTheme.textMuted
                    textSize: Label.XSmall
                    wrapMode: Text.Wrap
                    visible: appSettings.ttsApiKey.length > 0
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.8)
                    spacing: units.gu(0.8)

                    Label {
                        Layout.fillWidth: true
                        text: i18nApp.tr("Auto-speak assistant replies")
                        color: appTheme.text
                        textSize: Label.Small
                    }
                    Switch {
                        checked: appSettings.ttsAutoSpeak
                        onCheckedChanged: appSettings.ttsAutoSpeak = checked
                    }
                }
            }

            // ---------- Connectivity test ----------
            Card {
                id: connectivityCard
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Connectivity"
                icon: "network-wireless"
                collapsible: true

                // Per-service state: "" | "checking" | "ok" | "fail"
                property string chromaState: ""
                property string chromaDetail: ""
                property string ollamaState: ""
                property string ollamaDetail: ""
                property string openrouterState: ""
                property string openrouterDetail: ""

                function _statusColor(s) {
                    if (s === "ok") return appTheme.success;
                    if (s === "fail") return appTheme.danger;
                    if (s === "checking") return appTheme.textSecondary;
                    return appTheme.textMuted;
                }
                function _statusIcon(s) {
                    if (s === "ok") return "ok";
                    if (s === "fail") return "close";
                    return "reload";
                }
                function _statusLabel(s) {
                    if (s === "ok") return i18nApp.tr("OK");
                    if (s === "fail") return i18nApp.tr("Failed");
                    if (s === "checking") return i18nApp.tr("Testing…");
                    return "—";
                }

                function _ping(method, url, authHeader, onDone) {
                    var xhr = new XMLHttpRequest();
                    var t0 = Date.now();
                    try { xhr.open(method, url); }
                    catch (e) { onDone(false, "bad URL"); return; }
                    if (authHeader) xhr.setRequestHeader("Authorization", authHeader);

                    // Bounded watchdog: if the service doesn't answer in 5s we
                    // surface "timeout" instead of leaving the row spinning.
                    // Settled-flag prevents double-settle on race with abort.
                    var settled = false;
                    var watchdog = Qt.createQmlObject(
                        'import QtQuick 2.7; Timer { interval: 5000; repeat: false }',
                        connectivityCard);
                    function settle(ok, detail) {
                        if (settled) return;
                        settled = true;
                        if (watchdog) { watchdog.stop(); watchdog.destroy(); watchdog = null; }
                        onDone(ok, detail);
                    }
                    watchdog.triggered.connect(function() {
                        try { xhr.abort(); } catch (e) {}
                        settle(false, "timeout");
                    });
                    watchdog.start();

                    xhr.onreadystatechange = function() {
                        if (xhr.readyState !== XMLHttpRequest.DONE) return;
                        var dt = Date.now() - t0;
                        if (xhr.status === 0) { settle(false, "unreachable"); return; }
                        if (xhr.status >= 200 && xhr.status < 300) { settle(true, dt + "ms"); return; }
                        settle(false, "HTTP " + xhr.status);
                    };
                    try { xhr.send(); } catch (e) { settle(false, "send error"); }
                }

                function testAll() {
                    chromaState = "checking"; chromaDetail = "";
                    ollamaState = "checking"; ollamaDetail = "";
                    openrouterState = "checking"; openrouterDetail = "";

                    var chromaPing = (appSettings.chromaUrl || "").replace(/\/+$/, "") + "/api/v2/heartbeat";
                    _ping("GET", chromaPing, null, function(ok, detail) {
                        chromaState = ok ? "ok" : "fail";
                        chromaDetail = detail;
                    });

                    var ollamaPing = (appSettings.ollamaUrl || "").replace(/\/+$/, "") + "/api/tags";
                    _ping("GET", ollamaPing, null, function(ok, detail) {
                        ollamaState = ok ? "ok" : "fail";
                        ollamaDetail = detail;
                    });

                    if (!appSettings.apiKey || appSettings.apiKey.length === 0) {
                        openrouterState = "fail";
                        openrouterDetail = i18nApp.tr("No API key");
                    } else {
                        var orPing = (appSettings.openrouterUrl || "").replace(/\/+$/, "") + "/auth/key";
                        _ping("GET", orPing, "Bearer " + appSettings.apiKey, function(ok, detail) {
                            openrouterState = ok ? "ok" : "fail";
                            openrouterDetail = detail;
                        });
                    }
                }

                // Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: units.gu(4.5)
                    Layout.topMargin: units.gu(0.4)
                    radius: units.gu(0.8)
                    color: testMouse.pressed ? appTheme.secondary
                          : (testMouse.containsMouse ? appTheme.surfaceHover : appTheme.primary)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Label {
                        anchors.centerIn: parent
                        text: i18nApp.tr("Test connection")
                        color: appTheme.textOnPrimary
                        textSize: Label.Small
                        font.bold: true
                    }

                    MouseArea {
                        id: testMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: connectivityCard.testAll()
                    }
                }

                // Status rows
                Repeater {
                    model: [
                        { label: i18nApp.tr("Vector store (Chroma)"),
                          state: connectivityCard.chromaState,
                          detail: connectivityCard.chromaDetail },
                        { label: i18nApp.tr("Embeddings (Ollama)"),
                          state: connectivityCard.ollamaState,
                          detail: connectivityCard.ollamaDetail },
                        { label: i18nApp.tr("Language model"),
                          state: connectivityCard.openrouterState,
                          detail: connectivityCard.openrouterDetail }
                    ]

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: index === 0 ? units.gu(0.6) : 0
                        spacing: units.gu(0.8)

                        Icon {
                            Layout.preferredWidth: units.gu(1.8)
                            Layout.preferredHeight: units.gu(1.8)
                            name: connectivityCard._statusIcon(modelData.state)
                            color: connectivityCard._statusColor(modelData.state)
                            opacity: modelData.state.length === 0 ? 0.4 : 1.0
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: appTheme.text
                            textSize: Label.Small
                        }
                        Label {
                            text: connectivityCard._statusLabel(modelData.state)
                                  + (modelData.detail.length > 0 ? " · " + modelData.detail : "")
                            color: connectivityCard._statusColor(modelData.state)
                            textSize: Label.XSmall
                        }
                    }
                }
            }
        }
    }

    // ---- topic editor dialog ----
    Component {
        id: topicEditor
        Dialog {
            id: dlg
            property var editing: null   // null = create
            property int colorIdx: editing ? (editing.colorPresetIndex || 0) : 0

            title: editing ? i18nApp.tr("Edit topic") : i18nApp.tr("New topic")

            Column {
                width: parent ? parent.width : units.gu(38)
                spacing: units.gu(0.4)

                FieldLabel { width: parent.width; appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Name" }
                StyledField {
                    id: nameField
                    width: parent.width
                    appTheme: page.appTheme
                    text: dlg.editing ? dlg.editing.name : ""
                }

                Item { width: 1; height: units.gu(0.4) }

                FieldLabel { width: parent.width; appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Collection ID" }
                StyledField {
                    id: collectionField
                    width: parent.width
                    appTheme: page.appTheme
                    text: dlg.editing ? dlg.editing.collectionId : ""
                }

                Item { width: 1; height: units.gu(0.4) }

                FieldLabel { width: parent.width; appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "Color" }
                Flow {
                    width: parent.width
                    spacing: units.gu(0.6)

                    Repeater {
                        model: appTheme.presets
                        Rectangle {
                            width: units.gu(3.6); height: units.gu(3.6)
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0; color: modelData.primary }
                                GradientStop { position: 1; color: modelData.secondary }
                            }
                            border.color: dlg.colorIdx === index ? appTheme.text : "transparent"
                            border.width: 3
                            Icon {
                                visible: dlg.colorIdx === index
                                anchors.centerIn: parent
                                width: units.gu(1.6); height: width
                                name: "ok"
                                color: "white"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dlg.colorIdx = index
                            }
                        }
                    }
                }

                Item { width: 1; height: units.gu(0.4) }

                FieldLabel { width: parent.width; appTheme: page.appTheme; i18nApp: page.i18nApp; textKey: "System prompt addon (optional)" }
                Rectangle {
                    width: parent.width
                    height: units.gu(9)
                    radius: units.gu(0.8)
                    color: appTheme.surfaceAlt
                    border.color: addonInput.activeFocus ? appTheme.borderFocus : appTheme.border
                    border.width: 1

                    TextArea {
                        id: addonInput
                        anchors.fill: parent
                        anchors.margins: units.gu(0.6)
                        wrapMode: TextEdit.Wrap
                        color: appTheme.text
                        text: dlg.editing ? dlg.editing.systemPromptAddon : ""
                    }
                }

                Item { width: 1; height: units.gu(0.6) }

                Row {
                    spacing: units.gu(1)
                    Button {
                        text: i18nApp.tr("Cancel")
                        onClicked: PopupUtils.close(dlg)
                    }
                    Button {
                        text: i18nApp.tr("Save")
                        color: appTheme.primary
                        onClicked: {
                            var fields = {
                                name: nameField.text.trim(),
                                collectionId: collectionField.text.trim(),
                                colorPresetIndex: dlg.colorIdx,
                                icon: dlg.editing ? (dlg.editing.icon || "") : "",
                                systemPromptAddon: addonInput.text
                            };
                            if (fields.name.length === 0) return;
                            if (dlg.editing) Store.updateTopic(dlg.editing.id, fields);
                            else Store.createTopic(fields);
                            page.refreshTopics();
                            page.topicsModified();
                            PopupUtils.close(dlg);
                        }
                    }
                }
            }
        }
    }

    // ---- Chroma collection picker dialog ----
    Component {
        id: collectionPicker
        Dialog {
            id: dlg
            property var collections: []
            property string state_: "loading"   // "loading" | "ok" | "fail"
            property string errorDetail: ""

            title: i18nApp.tr("Pick a collection")
            text: state_ === "fail" ? (i18nApp.tr("Failed to load") + ": " + errorDetail) : ""

            Component.onCompleted: {
                Metrics.listChromaCollections(
                    appSettings.chromaUrl, appSettings.tenant, appSettings.database,
                    function(items) { dlg.collections = items; dlg.state_ = "ok"; },
                    function(err)   { dlg.errorDetail = err; dlg.state_ = "fail"; }
                );
            }

            Item {
                width: parent ? parent.width : units.gu(38)
                height: Math.min(units.gu(40), Math.max(units.gu(6), listCol.implicitHeight))

                Label {
                    anchors.centerIn: parent
                    visible: dlg.state_ === "loading"
                    text: i18nApp.tr("Loading…")
                    color: appTheme.textMuted
                    textSize: Label.Small
                }

                Label {
                    anchors.centerIn: parent
                    visible: dlg.state_ === "ok" && dlg.collections.length === 0
                    text: i18nApp.tr("No collections found")
                    color: appTheme.textMuted
                    textSize: Label.Small
                }

                Flickable {
                    anchors.fill: parent
                    visible: dlg.state_ === "ok" && dlg.collections.length > 0
                    contentHeight: listCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: listCol
                        width: parent.width
                        spacing: units.gu(0.4)

                        Repeater {
                            model: dlg.collections
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: units.gu(7)
                                radius: units.gu(0.8)
                                color: appSettings.collectionId === modelData.id
                                       ? appTheme.primary
                                       : (rowMouse.containsMouse ? appTheme.surfaceHover : appTheme.surfaceAlt)
                                border.color: appSettings.collectionId === modelData.id
                                              ? appTheme.secondary : appTheme.border
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors {
                                        left: parent.left; right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: units.gu(1); rightMargin: units.gu(1)
                                    }
                                    spacing: units.gu(0.1)

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.name || "(unnamed)"
                                        color: appSettings.collectionId === modelData.id
                                               ? appTheme.textOnPrimary : appTheme.text
                                        textSize: Label.Small
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: {
                                            var dim = modelData.dimension !== "" ? (modelData.dimension + "d · ") : "";
                                            var emb = (modelData.metadata && modelData.metadata["embedder_id"]) || "";
                                            return dim + (emb.length > 0 ? emb + " · " : "") + modelData.id;
                                        }
                                        color: appSettings.collectionId === modelData.id
                                               ? appTheme.textOnPrimary : appTheme.textMuted
                                        textSize: Label.XSmall
                                        elide: Text.ElideMiddle
                                    }
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        appSettings.collectionId = modelData.id;
                                        PopupUtils.close(dlg);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Row {
                spacing: units.gu(1)
                Button {
                    text: i18nApp.tr("Cancel")
                    onClicked: PopupUtils.close(dlg)
                }
            }
        }
    }

    // ---- topic delete dialog ----
    Component {
        id: topicDeleteDialog
        Dialog {
            id: dlg
            property var topicRef: null
            title: i18nApp.tr("Delete topic")
            text: i18nApp.tr("Delete topic \"%1\"? Conversations using it will become Auto.")
                  .replace("%1", topicRef ? topicRef.name : "")

            Row {
                spacing: units.gu(1)
                Button {
                    text: i18nApp.tr("Cancel")
                    onClicked: PopupUtils.close(dlg)
                }
                Button {
                    text: i18nApp.tr("Delete")
                    color: appTheme.danger
                    onClicked: {
                        if (dlg.topicRef) Store.deleteTopic(dlg.topicRef.id);
                        page.refreshTopics();
                        page.topicsModified();
                        PopupUtils.close(dlg);
                    }
                }
            }
        }
    }
}
