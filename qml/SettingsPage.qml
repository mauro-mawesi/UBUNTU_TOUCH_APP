import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import "components"

Page {
    id: page
    property var appSettings
    property var i18nApp
    property var appTheme

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
                                onClicked: appSettings.themeMode = modelData.code
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

                FieldLabel { Layout.fillWidth: true; Layout.topMargin: units.gu(0.5); appTheme: page.appTheme; text: i18nApp.tr("OpenRouter API Key") }
                StyledField {
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    echoMode: TextInput.Password
                    placeholderText: "sk-or-..."
                    text: appSettings.apiKey
                    onTextChanged: appSettings.apiKey = text
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
            }

            // ---------- Chroma ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                sectionTitle: i18nApp.tr("Vector store (Chroma)")

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

            // ---------- Voice (TTS) ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                sectionTitle: i18nApp.tr("Voice (TTS)")

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
}
