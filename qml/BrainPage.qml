import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import "components"
import "js/BrainMetrics.js" as Metrics

Page {
    id: page
    property var appSettings
    property var i18nApp
    property var appTheme

    // ---- Chroma state ----
    property string chromaState: ""           // "" | "loading" | "ok" | "fail"
    property string chromaError: ""
    property var chromaCollections: []        // array of { id, name, dimension, count, countState }

    // ---- Local SQLite state ----
    property var localStats: ({})

    // ---- Health state ----
    // Each: "" | "checking" | "ok" | "fail"
    property var healthRows: []   // array of { key, label, url, authHeader, state, detail }

    // ---- Ollama state ----
    property string ollamaState: ""
    property string ollamaError: ""
    property var ollamaModels: []

    function refreshAll() {
        refreshChroma();
        refreshLocal();
        refreshHealth();
        refreshOllama();
    }

    function refreshLocal() {
        localStats = Metrics.localDbStats();
    }

    function refreshChroma() {
        chromaState = "loading";
        chromaError = "";
        chromaCollections = [];
        Metrics.listChromaCollections(
            appSettings.chromaUrl, appSettings.tenant, appSettings.database,
            function(items) {
                // Seed entries with placeholder counts, then fan out per-collection.
                var seeded = [];
                for (var i = 0; i < items.length; i++) {
                    seeded.push({
                        id: items[i].id,
                        name: items[i].name,
                        dimension: items[i].dimension,
                        count: -1,
                        countState: "loading"
                    });
                }
                chromaCollections = seeded;
                chromaState = "ok";
                for (var j = 0; j < items.length; j++) {
                    (function(idx, colId) {
                        Metrics.countChromaCollection(
                            appSettings.chromaUrl, appSettings.tenant, appSettings.database, colId,
                            function(n) { _setCollectionCount(idx, n, "ok"); },
                            function(_e) { _setCollectionCount(idx, -1, "fail"); });
                    })(j, items[j].id);
                }
            },
            function(err) { chromaState = "fail"; chromaError = err; });
    }

    function _setCollectionCount(idx, n, st) {
        // QML arrays of dicts: rebuild the row to trigger model update.
        var copy = chromaCollections.slice();
        if (idx < 0 || idx >= copy.length) return;
        copy[idx] = {
            id: copy[idx].id,
            name: copy[idx].name,
            dimension: copy[idx].dimension,
            count: n,
            countState: st
        };
        chromaCollections = copy;
    }

    function refreshOllama() {
        ollamaState = "loading";
        ollamaError = "";
        ollamaModels = [];
        Metrics.listOllamaModels(appSettings.ollamaUrl,
            function(items) { ollamaModels = items; ollamaState = "ok"; },
            function(err)   { ollamaState = "fail"; ollamaError = err; });
    }

    function refreshHealth() {
        var apiKey = appSettings.apiKey || "";
        var rows = [
            { key: "chroma",
              label: i18nApp.tr("Vector store (Chroma)"),
              method: "GET",
              url: (appSettings.chromaUrl || "").replace(/\/+$/, "") + "/api/v2/heartbeat",
              auth: null,
              state: "checking", detail: "" },
            { key: "ollama",
              label: i18nApp.tr("Embeddings (Ollama)"),
              method: "GET",
              url: (appSettings.ollamaUrl || "").replace(/\/+$/, "") + "/api/tags",
              auth: null,
              state: "checking", detail: "" },
            { key: "openrouter",
              label: i18nApp.tr("Language model"),
              method: "GET",
              url: (appSettings.openrouterUrl || "").replace(/\/+$/, "") + "/auth/key",
              auth: apiKey.length > 0 ? "Bearer " + apiKey : null,
              state: apiKey.length > 0 ? "checking" : "fail",
              detail: apiKey.length > 0 ? "" : i18nApp.tr("No API key") },
            { key: "whisper",
              label: i18nApp.tr("Speech to text (Whisper)"),
              method: "GET",
              url: (appSettings.whisperUrl || "").replace(/\/+$/, "") + "/v1/models",
              auth: null,
              state: "checking", detail: "" },
            { key: "tts",
              label: i18nApp.tr("Text to speech (Kokoro)"),
              method: "GET",
              url: (appSettings.ttsUrl || "").replace(/\/+$/, "") + "/v1/audio/voices",
              auth: null,
              state: "checking", detail: "" }
        ];
        healthRows = rows;
        for (var i = 0; i < rows.length; i++) {
            if (rows[i].state !== "checking") continue;
            (function(idx, r) {
                Metrics.pingService(r.method, r.url, r.auth, function(ok, detail) {
                    _setHealth(idx, ok ? "ok" : "fail", detail);
                });
            })(i, rows[i]);
        }
    }

    function _setHealth(idx, st, detail) {
        var copy = healthRows.slice();
        if (idx < 0 || idx >= copy.length) return;
        copy[idx] = {
            key: copy[idx].key, label: copy[idx].label,
            method: copy[idx].method, url: copy[idx].url, auth: copy[idx].auth,
            state: st, detail: detail
        };
        healthRows = copy;
    }

    function _statusColor(s) {
        if (s === "ok") return appTheme.success;
        if (s === "fail") return appTheme.danger;
        if (s === "checking" || s === "loading") return appTheme.textSecondary;
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
        if (s === "checking" || s === "loading") return i18nApp.tr("Loading…");
        return "—";
    }

    // Refresh whenever the page becomes visible (push onto PageStack).
    onVisibleChanged: { if (visible) refreshAll(); }

    // ---- background ----
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
        title: i18nApp.tr("Brain metrics")
        StyleHints {
            backgroundColor: "transparent"
            foregroundColor: appTheme.text
            dividerColor: appTheme.border
        }
        trailingActionBar.actions: [
            Action {
                iconName: "reload"
                text: i18nApp.tr("Refresh")
                onTriggered: refreshAll()
            }
        ]
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: page.header.height
        contentWidth: width
        contentHeight: col.implicitHeight + units.gu(4)
        clip: true

        ColumnLayout {
            id: col
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: units.gu(2); rightMargin: units.gu(2); topMargin: units.gu(2)
            }
            spacing: units.gu(1.5)

            // ---------- Chroma collections ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Knowledge collections"
                icon: "view-list-symbolic"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.8)
                    Icon {
                        Layout.preferredWidth: units.gu(1.8)
                        Layout.preferredHeight: units.gu(1.8)
                        name: page._statusIcon(page.chromaState)
                        color: page._statusColor(page.chromaState)
                        opacity: page.chromaState.length === 0 ? 0.4 : 1.0
                    }
                    Label {
                        Layout.fillWidth: true
                        text: page.chromaState === "fail"
                              ? (i18nApp.tr("Failed") + " · " + page.chromaError)
                              : (page.chromaState === "loading"
                                 ? i18nApp.tr("Loading…")
                                 : i18nApp.tr("%1 collections").replace("%1", page.chromaCollections.length))
                        color: page._statusColor(page.chromaState)
                        textSize: Label.XSmall
                    }
                }

                Repeater {
                    model: page.chromaCollections
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: units.gu(0.6)
                        spacing: units.gu(0.2)

                        Label {
                            Layout.fillWidth: true
                            text: modelData.name || modelData.id
                            color: appTheme.text
                            textSize: Label.Small
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: {
                                var parts = [];
                                if (modelData.countState === "ok") {
                                    parts.push(i18nApp.tr("%1 docs").replace("%1", modelData.count));
                                } else if (modelData.countState === "loading") {
                                    parts.push(i18nApp.tr("Loading…"));
                                } else {
                                    parts.push(i18nApp.tr("count unavailable"));
                                }
                                if (modelData.dimension !== "" && modelData.dimension !== null) {
                                    parts.push(i18nApp.tr("dim %1").replace("%1", modelData.dimension));
                                }
                                return parts.join(" · ");
                            }
                            color: appTheme.textSecondary
                            textSize: Label.XSmall
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.id
                            color: appTheme.textMuted
                            textSize: Label.XSmall
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }

            // ---------- Local SQLite ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "App database"
                icon: "save"

                Repeater {
                    model: [
                        { label: i18nApp.tr("Conversations"),
                          value: String(page.localStats.conversations || 0) },
                        { label: i18nApp.tr("Messages"),
                          value: String(page.localStats.messages || 0) },
                        { label: i18nApp.tr("Topics"),
                          value: String(page.localStats.topics || 0) },
                        { label: i18nApp.tr("User messages"),
                          value: String((page.localStats.byRole && page.localStats.byRole.user) || 0) },
                        { label: i18nApp.tr("Assistant messages"),
                          value: String((page.localStats.byRole && page.localStats.byRole.assistant) || 0) },
                        { label: i18nApp.tr("First message"),
                          value: Metrics.humanDate(page.localStats.oldestMs || 0) },
                        { label: i18nApp.tr("Last message"),
                          value: Metrics.humanDate(page.localStats.newestMs || 0) }
                    ]
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: index === 0 ? units.gu(0.4) : 0
                        spacing: units.gu(0.8)
                        Label {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: appTheme.textSecondary
                            textSize: Label.Small
                        }
                        Label {
                            text: modelData.value
                            color: appTheme.text
                            textSize: Label.Small
                            font.bold: true
                        }
                    }
                }
            }

            // ---------- Service health ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Services"
                icon: "network-wireless"

                Repeater {
                    model: page.healthRows
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: index === 0 ? units.gu(0.4) : 0
                        spacing: units.gu(0.8)
                        Icon {
                            Layout.preferredWidth: units.gu(1.8)
                            Layout.preferredHeight: units.gu(1.8)
                            name: page._statusIcon(modelData.state)
                            color: page._statusColor(modelData.state)
                            opacity: modelData.state.length === 0 ? 0.4 : 1.0
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: appTheme.text
                            textSize: Label.Small
                        }
                        Label {
                            text: page._statusLabel(modelData.state)
                                  + (modelData.detail && modelData.detail.length > 0
                                     ? " · " + modelData.detail : "")
                            color: page._statusColor(modelData.state)
                            textSize: Label.XSmall
                        }
                    }
                }
            }

            // ---------- Ollama models ----------
            Card {
                Layout.fillWidth: true
                appTheme: page.appTheme
                i18nApp: page.i18nApp
                sectionTitleKey: "Ollama models"
                icon: "stock_chart"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.8)
                    Icon {
                        Layout.preferredWidth: units.gu(1.8)
                        Layout.preferredHeight: units.gu(1.8)
                        name: page._statusIcon(page.ollamaState)
                        color: page._statusColor(page.ollamaState)
                        opacity: page.ollamaState.length === 0 ? 0.4 : 1.0
                    }
                    Label {
                        Layout.fillWidth: true
                        text: page.ollamaState === "fail"
                              ? (i18nApp.tr("Failed") + " · " + page.ollamaError)
                              : (page.ollamaState === "loading"
                                 ? i18nApp.tr("Loading…")
                                 : i18nApp.tr("%1 models").replace("%1", page.ollamaModels.length))
                        color: page._statusColor(page.ollamaState)
                        textSize: Label.XSmall
                    }
                }

                Repeater {
                    model: page.ollamaModels
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: units.gu(0.4)
                        spacing: units.gu(0.8)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: appTheme.text
                                textSize: Label.Small
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: modelData.family.length > 0 || modelData.parameterSize.length > 0
                                text: [modelData.family, modelData.parameterSize].filter(function(s) {
                                    return s && s.length > 0;
                                }).join(" · ")
                                color: appTheme.textSecondary
                                textSize: Label.XSmall
                                elide: Text.ElideRight
                            }
                        }
                        Label {
                            text: Metrics.humanBytes(modelData.sizeBytes)
                            color: appTheme.textMuted
                            textSize: Label.XSmall
                        }
                    }
                }
            }
        }
    }
}
