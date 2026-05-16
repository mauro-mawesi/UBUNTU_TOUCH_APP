import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3
import "components"
import "js/Store.js" as Store

Page {
    id: page
    property var appSettings
    property var i18nApp
    property var appTheme
    property var themeTransition: null

    // Emitted whenever topics are created/edited/deleted so ChatPage refreshes.
    signal topicsModified()

    property var topics: []
    property bool revealApiKey: false

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
        title: i18nApp.tr("Settings")
        StyleHints {
            backgroundColor: "transparent"
            foregroundColor: appTheme.text
            dividerColor: appTheme.border
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
                sectionTitle: i18nApp.tr("Appearance")
                icon: "preferences-desktop-theme-symbolic"
                collapsible: true

                FieldLabel {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.5)
                    appTheme: page.appTheme
                    text: i18nApp.tr("Theme")
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.6)

                    Repeater {
                        model: [
                            { code: "dark",  label: i18nApp.tr("Dark") },
                            { code: "light", label: i18nApp.tr("Light") }
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

                            Label {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: appSettings.themeMode === modelData.code
                                       ? appTheme.textOnPrimary : appTheme.text
                                textSize: Label.Small
                                font.bold: appSettings.themeMode === modelData.code
                            }
                            MouseArea {
                                id: themeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (appSettings.themeMode === modelData.code) return;
                                    if (page.themeTransition) {
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
                    text: i18nApp.tr("Accent color")
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: units.gu(0.8)

                    Repeater {
                        model: appTheme.presets
                        Rectangle {
                            width: units.gu(5.5)
                            height: units.gu(5.5)
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0; color: modelData.primary }
                                GradientStop { position: 1; color: modelData.secondary }
                            }
                            border.color: appSettings.themePresetIndex === index
                                          ? appTheme.text : "transparent"
                            border.width: 3

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
                                onClicked: appSettings.themePresetIndex = index
                            }
                        }
                    }
                }
            }

            // ---------- Interface (language) ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                sectionTitle: i18nApp.tr("Interface")
                icon: "preferences-desktop-locale-symbolic"
                collapsible: true

                FieldLabel {
                    Layout.fillWidth: true
                    Layout.topMargin: units.gu(0.5)
                    appTheme: page.appTheme
                    text: i18nApp.tr("Language")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.6)

                    Repeater {
                        model: [
                            { code: "en", label: i18nApp.tr("English") },
                            { code: "es", label: i18nApp.tr("Spanish") },
                            { code: "nl", label: i18nApp.tr("Dutch") }
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

                            Label {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: appSettings.language === modelData.code
                                       ? appTheme.textOnPrimary : appTheme.text
                                textSize: Label.Small
                                font.bold: appSettings.language === modelData.code
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
                sectionTitle: i18nApp.tr("Language model")
                icon: "system-run"
                collapsible: true

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("OpenRouter API Key") }
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

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("Model") }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    placeholderText: "google/gemini-2.5-pro"
                    text: appSettings.model
                    onTextChanged: appSettings.model = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("Base URL") }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.openrouterUrl
                    onTextChanged: appSettings.openrouterUrl = text
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
                sectionTitle: i18nApp.tr("Vector store (Chroma)")
                icon: "drive-harddisk-symbolic"
                collapsible: true
                collapsed: true

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("Base URL") }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.chromaUrl
                    onTextChanged: appSettings.chromaUrl = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("Tenant") }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.tenant
                    onTextChanged: appSettings.tenant = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("Database") }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.database
                    onTextChanged: appSettings.database = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("Collection ID") }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.collectionId
                    onTextChanged: appSettings.collectionId = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("Top K results") }
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
                sectionTitle: i18nApp.tr("Embeddings (Ollama)")
                icon: "view-list-symbolic"
                collapsible: true
                collapsed: true

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("Base URL") }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.ollamaUrl
                    onTextChanged: appSettings.ollamaUrl = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("Embedding model") }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.embedModel
                    onTextChanged: appSettings.embedModel = text
                }
            }

            // ---------- Topics ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                sectionTitle: i18nApp.tr("Topics")
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

            // ---------- Voice (TTS) ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                sectionTitle: i18nApp.tr("Voice (TTS)")
                icon: "audio-input-microphone-symbolic"
                collapsible: true
                collapsed: true

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("Base URL") }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    text: appSettings.ttsUrl
                    onTextChanged: appSettings.ttsUrl = text
                }

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("Voice (empty = auto by language)") }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    placeholderText: "af_bella"
                    text: appSettings.ttsVoice
                    onTextChanged: appSettings.ttsVoice = text
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
                sectionTitle: i18nApp.tr("Connectivity")
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
                    xhr.onreadystatechange = function() {
                        if (xhr.readyState !== XMLHttpRequest.DONE) return;
                        var dt = Date.now() - t0;
                        if (xhr.status === 0) { onDone(false, "unreachable"); return; }
                        if (xhr.status >= 200 && xhr.status < 300) { onDone(true, dt + "ms"); return; }
                        onDone(false, "HTTP " + xhr.status);
                    };
                    try { xhr.send(); } catch (e) { onDone(false, "send error"); }
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

                FieldLabel { width: parent.width; appTheme: page.appTheme; text: i18nApp.tr("Name") }
                StyledField {
                    id: nameField
                    width: parent.width
                    appTheme: page.appTheme
                    text: dlg.editing ? dlg.editing.name : ""
                }

                Item { width: 1; height: units.gu(0.4) }

                FieldLabel { width: parent.width; appTheme: page.appTheme; text: i18nApp.tr("Collection ID") }
                StyledField {
                    id: collectionField
                    width: parent.width
                    appTheme: page.appTheme
                    text: dlg.editing ? dlg.editing.collectionId : ""
                }

                Item { width: 1; height: units.gu(0.4) }

                FieldLabel { width: parent.width; appTheme: page.appTheme; text: i18nApp.tr("Color") }
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

                FieldLabel { width: parent.width; appTheme: page.appTheme; text: i18nApp.tr("System prompt addon (optional)") }
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
