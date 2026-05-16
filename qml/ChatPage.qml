import QtQuick 2.7
import QtMultimedia 5.6
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3
import Ragassistant.Audio 1.0
import "components"
import "js/RagOrchestrator.js" as Rag
import "js/Store.js" as Store
import "js/tools/registry.js" as Tools

Page {
    id: page
    property var appSettings
    property var pageStack
    property var settingsPage
    property var brainPage
    property var i18nApp
    property var appTheme

    // ---- chat state ----
    property var history: []        // OpenRouter history for current session
    property bool busy: false
    property var activeXhr: null
    property int currentConvId: -1
    property int streamingMsgId: -1 // db id of message being streamed

    // ---- sidebar ----
    property var conversations: []
    readonly property bool wideMode: width >= units.gu(80)
    property bool sidebarOpen: false

    // ---- topics ----
    property var topics: []
    property int currentTopicId: -1   // -1 = Auto

    readonly property var currentTopic: {
        if (currentTopicId <= 0) return null;
        for (var i = 0; i < topics.length; i++) {
            if (topics[i].id === currentTopicId) return topics[i];
        }
        return null;
    }

    function refreshTopics() {
        topics = Store.listTopics();
        // If the selected topic was deleted, fall back to Auto.
        if (currentTopicId > 0 && !currentTopic) currentTopicId = -1;
    }

    function selectTopic(id) {
        currentTopicId = (id && id > 0) ? id : -1;
        if (currentConvId > 0) {
            var coll = "";
            if (currentTopic) coll = currentTopic.collectionId || "";
            Store.setConversationTopic(currentConvId, currentTopicId, coll);
            refreshConversations();
        }
    }

    function topicColor(topic) {
        if (!topic) return appTheme.textMuted;
        var presets = appTheme.presets || [];
        var idx = topic.colorPresetIndex || 0;
        if (idx >= 0 && idx < presets.length) return presets[idx].primary;
        return appTheme.primary;
    }

    function refreshConversations() {
        conversations = Store.listConversations();
    }

    function selectConversation(id) {
        currentConvId = id;
        messagesModel.clear();
        history = [];
        var msgs = Store.getMessages(id);
        for (var i = 0; i < msgs.length; i++) {
            var m = msgs[i];
            messagesModel.append({
                role: m.role,
                content: m.content,
                sources: m.sources,
                streaming: false,
                phase: "",
                timestamp: m.createdAt || 0,
                modelName: ""
            });
            if (m.role === "user" || m.role === "assistant") {
                history.push({ role: m.role, content: m.content });
            }
        }
        // Restore the conversation's topic selection.
        for (var k = 0; k < conversations.length; k++) {
            if (conversations[k].id === id) {
                currentTopicId = conversations[k].topicId > 0 ? conversations[k].topicId : -1;
                break;
            }
        }
        if (!wideMode) sidebarOpen = false;
        // F9: switching conversations should always land at the tail.
        listView.stickToBottom = true;
        Qt.callLater(function() { listView.positionViewAtEnd(); });
    }

    function newConversation() {
        currentConvId = -1;
        messagesModel.clear();
        history = [];
        // New chats inherit whatever topic is selected at that moment.
        if (!wideMode) sidebarOpen = false;
    }

    function ensureConvExists(seedText) {
        if (currentConvId > 0) return currentConvId;
        var coll = currentTopic ? (currentTopic.collectionId || "") : (appSettings.collectionId || "");
        var id = Store.createConversation(Store.deriveTitle(seedText), coll,
                                          currentTopicId > 0 ? currentTopicId : null);
        currentConvId = id;
        return id;
    }

    Component.onCompleted: {
        Store.init(appSettings.collectionId, i18nApp.tr("General"));
        refreshTopics();
        refreshConversations();
        if (conversations.length > 0) {
            selectConversation(conversations[0].id);
        }
    }

    Connections {
        target: settingsPage
        ignoreUnknownSignals: true
        onTopicsModified: refreshTopics()
    }

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
        title: i18nApp.tr("RAG Assistant")
        StyleHints {
            backgroundColor: "transparent"
            foregroundColor: appTheme.text
            dividerColor: appTheme.border
        }
        leadingActionBar.actions: [
            Action {
                iconName: "navigation-menu"
                text: i18nApp.tr("Conversations")
                onTriggered: sidebarOpen = !sidebarOpen
            }
        ]
        trailingActionBar.actions: [
            Action {
                iconName: "edit-clear"
                text: i18nApp.tr("New chat")
                enabled: messagesModel.count > 0 && !page.busy
                onTriggered: newConversation()
            },
            Action {
                iconName: "info"
                text: i18nApp.tr("Brain metrics")
                onTriggered: pageStack.push(brainPage)
            },
            Action {
                iconName: "settings"
                text: i18nApp.tr("Settings")
                onTriggered: pageStack.push(settingsPage, { appSettings: appSettings })
            }
        ]
    }

    ListModel { id: messagesModel }

    // Idle watchdog for the active LLM/RAG round. Restarted on every sign of
    // progress (sources, delta, tool calls, new round); stopped on done/error.
    // If it fires we abort activeXhr — the OpenRouterClient.abort wrapper
    // turns that into a clean onDone with whatever partial we have so far.
    Timer {
        id: queryWatchdog
        interval: 30000
        repeat: false
        onTriggered: {
            console.log("[chat] queryWatchdog fired — no activity for "
                        + (interval / 1000) + "s, aborting");
            if (activeXhr) { try { activeXhr.abort(); } catch(e) {} }
        }
    }

    // ---- speech to text ----
    AudioRecorder {
        id: recorder
        onRecordingFinished: {
            console.log("[mic] recording finished, file=" + filePath);
            whisper.transcribe(appSettings.whisperUrl, filePath,
                               i18nApp.language, appSettings.whisperModel);
        }
        onErrorOccurred: {
            console.log("[mic] recorder error: " + message);
            appendMessage("system", "🎙 " + message, [], false);
        }
    }

    WhisperClient {
        id: whisper
        onTranscribed: {
            console.log("[mic] transcribed: " + text.substring(0, 80));
            if (text && text.trim().length > 0) {
                input.text = (input.text.length > 0 ? input.text + " " : "") + text.trim();
            }
        }
        onErrorOccurred: {
            console.log("[mic] whisper error: " + message);
            appendMessage("system", "🎙 " + message, [], false);
        }
    }

    // ---- text to speech ----
    property int speakingIndex: -1     // model index currently being spoken (or -1)

    function voiceForLanguage(lang) {
        if (appSettings.ttsVoice && appSettings.ttsVoice.length > 0) return appSettings.ttsVoice;
        if (lang === "es") return "ef_dora";
        // Kokoro has no Dutch voice (per CLAUDE.md infrastructure notes) —
        // fall back to English af_bella. Don't "fix" this without first
        // confirming the Kokoro deployment has a nl voice available.
        if (lang === "nl") return "af_bella";
        return "af_bella";
    }

    function speakMessage(idx) {
        if (idx < 0 || idx >= messagesModel.count) return;
        var msg = messagesModel.get(idx);
        if (!msg || !msg.content || msg.content.length === 0) return;
        if (ttsPlayer.playbackState === MediaPlayer.PlayingState) {
            ttsPlayer.stop();
            tts.cancel();
            if (speakingIndex === idx) { speakingIndex = -1; return; }
        }
        speakingIndex = idx;
        tts.synthesize(appSettings.ttsUrl, msg.content,
                       voiceForLanguage(i18nApp.language), "mp3");
    }

    function stopSpeaking() {
        ttsPlayer.stop();
        tts.cancel();
        speakingIndex = -1;
    }

    TtsClient {
        id: tts
        onAudioReady: {
            console.log("[tts] audio ready: " + filePath);
            // Each TTS synthesis produces a unique tts_<epoch>.mp3, so MediaPlayer
            // sees a fresh source and reloads cleanly. A plain stop() is enough;
            // the previous empty-string round-trip was paranoia from when files
            // shared a name.
            ttsPlayer.stop();
            ttsPlayer.source = "file://" + filePath;
            ttsPlayer.play();
        }
        onErrorOccurred: {
            console.log("[tts] error: " + message);
            speakingIndex = -1;
        }
    }

    MediaPlayer {
        id: ttsPlayer
        autoLoad: true
        onStopped: {
            if (status === MediaPlayer.EndOfMedia || status === MediaPlayer.NoMedia) {
                speakingIndex = -1;
            }
        }
        onError: {
            console.log("[tts] player error: " + errorString);
            speakingIndex = -1;
        }
    }

    function appendMessage(role, content, sources, streaming, phase) {
        // Defensive: ignore empty user messages. sendQuery already trims, but
        // this guarantees the model never gets a phantom "user" row that
        // MessageBubble would otherwise hide (leaving a gap with no content).
        if (role === "user" && (!content || content.trim().length === 0)) return;
        messagesModel.append({
            role: role,
            content: content || "",
            sources: sources || [],
            streaming: streaming === true,
            phase: phase || "",
            toolName: "",
            toolArgs: "",
            toolResult: "",
            toolError: "",
            timestamp: Date.now(),
            modelName: role === "assistant" ? (appSettings.model || "") : ""
        });
        // F9: user-sent messages re-anchor at the tail; otherwise respect
        // wherever the user is reading.
        if (role === "user") listView.stickToBottom = true;
        Qt.callLater(function() {
            if (listView.stickToBottom) listView.positionViewAtEnd();
        });
    }

    function appendToolMessage(call, result) {
        var argsStr = "";
        try { argsStr = JSON.stringify(call.arguments || {}, null, 2); }
        catch (e) { argsStr = String(call.arguments || ""); }
        var resStr = "";
        var errStr = "";
        if (result && result.error) {
            errStr = String(result.error);
        } else {
            try { resStr = JSON.stringify(result, null, 2); }
            catch (e) { resStr = String(result); }
        }
        messagesModel.append({
            role: "tool",
            content: "",
            sources: [],
            streaming: false,
            phase: "",
            toolName: call.name || "",
            toolArgs: argsStr,
            toolResult: resStr,
            toolError: errStr,
            timestamp: Date.now(),
            modelName: ""
        });
        Qt.callLater(function() {
            if (listView.stickToBottom) listView.positionViewAtEnd();
        });
    }

    // streamingIdx points to the currently-streaming assistant bubble in
    // messagesModel. Updated whenever a new round's placeholder is appended,
    // and used so tool bubbles slotted in mid-turn don't break content updates.
    property int streamingIdx: -1

    // Throttle scroll-to-end so high-rate streaming (50+ tokens/s) doesn't
    // overwhelm the layout — at most one scroll request per ~16ms (60fps).
    property real _lastScrollAt: 0

    function updateLast(content, streaming) {
        var idx = streamingIdx >= 0 ? streamingIdx : (messagesModel.count - 1);
        if (idx < 0 || idx >= messagesModel.count) return;
        messagesModel.setProperty(idx, "content", content);
        if (streaming !== undefined) messagesModel.setProperty(idx, "streaming", streaming);
        if (!listView.stickToBottom) return;
        var now = Date.now();
        if (now - _lastScrollAt < 16) return;
        _lastScrollAt = now;
        Qt.callLater(function() {
            if (listView.stickToBottom) listView.positionViewAtEnd();
        });
    }

    function updateLastSources(items) {
        var idx = streamingIdx >= 0 ? streamingIdx : (messagesModel.count - 1);
        if (idx < 0 || idx >= messagesModel.count) return;
        messagesModel.setProperty(idx, "sources", items);
    }

    function setLastPhase(p) {
        var idx = streamingIdx >= 0 ? streamingIdx : (messagesModel.count - 1);
        if (idx < 0 || idx >= messagesModel.count) return;
        messagesModel.setProperty(idx, "phase", p || "");
    }

    // Surface persistence failures via the top-of-chat ErrorBanner instead
    // of yellow system bubbles. The previous approach (one bubble per failed
    // call) produced 3 stacked bubbles for a single user message and leaked
    // the raw SQLite path / SQL text into the conversation. The banner
    // dedupes by `label`, humanizes the headline, and tucks the raw error
    // behind a "Details" toggle. Still console.log for debugging.
    function _humanizePersistError(detail) {
        var d = (detail || "").toLowerCase();
        if (d.indexOf("readonly database") >= 0
            || d.indexOf("read-only database") >= 0) {
            return i18nApp.tr("Couldn't save the conversation locally (storage is read-only).");
        }
        if (d.indexOf("can't create path") >= 0
            || d.indexOf("cannot create") >= 0) {
            return i18nApp.tr("Local storage isn't available right now.");
        }
        if (d.indexOf("not null constraint") >= 0) {
            return i18nApp.tr("A field expected by the database was empty.");
        }
        if (d.indexOf("disk i/o error") >= 0
            || d.indexOf("database is locked") >= 0) {
            return i18nApp.tr("Local storage is busy. Retry in a moment.");
        }
        return i18nApp.tr("Couldn't save part of the conversation.");
    }

    function _persistError(label, e) {
        var detail = (e && e.message) ? e.message : String(e);
        console.log("[chat] persist failed at " + label + ": " + detail);
        if (errorBanner) {
            errorBanner.pushError(label, _humanizePersistError(detail), detail);
        }
    }

    function _runAsk(q, topic) {
        var convId = -1;
        try { convId = ensureConvExists(q); }
        catch (e) { _persistError("ensureConvExists", e); }

        try { Store.addMessage(convId, "user", q, []); }
        catch (e) { _persistError("addMessage(user)", e); }

        appendMessage("user", q, [], false);

        streamingMsgId = -1;
        try { streamingMsgId = Store.addMessage(convId, "assistant", "", []); }
        catch (e) { _persistError("addMessage(assistant)", e); }

        appendMessage("assistant", "", [], true, "retrieving");
        streamingIdx = messagesModel.count - 1;

        input.text = "";

        // Per-round text (reset on each new assistant round). Carries over via
        // closure so onDone can fall back to it if `full` is empty.
        var roundText = "";
        // The final-answer text for persistence/TTS — accumulated across rounds.
        var finalText = "";
        var assistantSources = [];

        var collectionId = topic ? (topic.collectionId || appSettings.collectionId)
                                 : appSettings.collectionId;
        var topicAddon = topic ? (topic.systemPromptAddon || "") : "";

        var settingsWithLang = {
            apiKey: appSettings.apiKey, model: appSettings.model, openrouterUrl: appSettings.openrouterUrl,
            chromaUrl: appSettings.chromaUrl, tenant: appSettings.tenant, database: appSettings.database,
            collectionId: collectionId, topK: appSettings.topK,
            ollamaUrl: appSettings.ollamaUrl, embedModel: appSettings.embedModel,
            language: i18nApp.language,
            topicAddon: topicAddon,
            appTitle: "ragassistant"
        };
        if (appSettings.toolsEnabled) {
            settingsWithLang.tools = Tools.getAll();
            settingsWithLang.toolRegistry = Tools;
        }

        console.log("[chat] _runAsk convId=" + convId + " q=" + q.substring(0,40)
                    + " topic=" + (topic ? topic.name + "(" + topic.id + ")" : "none")
                    + " collection=" + collectionId
                    + " tools=" + (settingsWithLang.tools ? settingsWithLang.tools.length : 0));

        queryWatchdog.restart();   // start the idle-timeout watchdog for this round
        activeXhr = Rag.ask(settingsWithLang, history.slice(), q, {
            onSources: function(items) {
                queryWatchdog.restart();
                assistantSources = items;
                updateLastSources(items);
                setLastPhase("thinking");
            },
            onDelta: function(t) {
                queryWatchdog.restart();
                if (roundText.length === 0) setLastPhase("");
                roundText += t;
                updateLast(roundText, true);
            },
            onPreTools: function(text, calls) {
                queryWatchdog.restart();
                // Finalize the current assistant placeholder before the tool
                // bubbles appear. If the model emitted no text in this round
                // (only tool_calls), drop the empty placeholder for cleanliness.
                if (streamingIdx >= 0 && streamingIdx < messagesModel.count) {
                    var current = messagesModel.get(streamingIdx);
                    if (!current.content || current.content.length === 0) {
                        messagesModel.remove(streamingIdx);
                    } else {
                        messagesModel.setProperty(streamingIdx, "streaming", false);
                    }
                }
                streamingIdx = -1;
            },
            onToolDone: function(call, result) {
                queryWatchdog.restart();
                appendToolMessage(call, result);
            },
            onRoundStart: function(depth) {
                queryWatchdog.restart();
                // New assistant round after tool execution: fresh placeholder.
                appendMessage("assistant", "", [], true, "thinking");
                streamingIdx = messagesModel.count - 1;
                roundText = "";
            },
            onDone: function(full) {
                queryWatchdog.stop();
                var text = (full && full.length > 0) ? full : roundText;
                finalText = text;
                updateLast(finalText, false);
                history.push({ role: "user", content: q });
                history.push({ role: "assistant", content: finalText });
                if (streamingMsgId > 0) {
                    Store.updateMessage(streamingMsgId, finalText, assistantSources);
                    streamingMsgId = -1;
                }
                streamingIdx = -1;
                refreshConversations();
                busy = false;
                activeXhr = null;
                if (appSettings.ttsAutoSpeak && finalText.length > 0) {
                    // Speak the final assistant bubble (last non-tool message).
                    for (var i = messagesModel.count - 1; i >= 0; i--) {
                        if (messagesModel.get(i).role === "assistant") {
                            speakMessage(i);
                            break;
                        }
                    }
                }
            },
            onError: function(err) {
                queryWatchdog.stop();
                console.log("[chat] onError: " + err);
                var idx = streamingIdx >= 0 ? streamingIdx : (messagesModel.count - 1);
                var prefix = roundText.length > 0 ? roundText + "\n\n" : "";
                var errText = prefix + err;
                if (idx >= 0 && idx < messagesModel.count) {
                    messagesModel.setProperty(idx, "content", errText);
                    messagesModel.setProperty(idx, "streaming", false);
                }
                if (streamingMsgId > 0) {
                    Store.updateMessage(streamingMsgId, errText, assistantSources);
                    streamingMsgId = -1;
                }
                streamingIdx = -1;
                busy = false;
                activeXhr = null;
            }
        });
    }

    function regenerateLast() {
        if (busy) return;
        var lastUserIdx = -1;
        for (var i = messagesModel.count - 1; i >= 0; i--) {
            if (messagesModel.get(i).role === "user") { lastUserIdx = i; break; }
        }
        if (lastUserIdx < 0) return;
        var q = messagesModel.get(lastUserIdx).content;
        // Drop the last user msg + everything after — sendQuery will re-add.
        while (messagesModel.count > lastUserIdx) {
            messagesModel.remove(messagesModel.count - 1);
        }
        // Trim matching tail of `history` so we don't double up the prompt.
        while (history.length > 0
               && history[history.length - 1].role === "assistant") history.pop();
        if (history.length > 0
            && history[history.length - 1].role === "user"
            && history[history.length - 1].content === q) {
            history.pop();
        }
        sendQuery(q);
    }

    function sendQuery(text) {
        var q = (text || "").trim();
        if (q.length === 0 || busy) return;
        if (!appSettings.apiKey || appSettings.apiKey.length === 0) {
            appendMessage("system", i18nApp.tr("Set your OpenRouter API Key in Settings."), [], false);
            return;
        }

        busy = true;

        // Auto mode: classify first, then pin the conversation to the chosen
        // topic and run the standard retrieve+answer flow.
        if (currentTopicId <= 0 && topics.length > 1) {
            // Briefly show the classifier phase on a placeholder bubble.
            appendMessage("assistant", "", [], true, "classifying");
            Rag.classifyTopic({
                openrouterUrl: appSettings.openrouterUrl,
                apiKey: appSettings.apiKey,
                model: appSettings.model,
                appTitle: "ragassistant"
            }, topics, q, function(pickedId) {
                // Drop the classifier placeholder bubble before _runAsk adds its own.
                if (messagesModel.count > 0) {
                    var lastIdx = messagesModel.count - 1;
                    var last = messagesModel.get(lastIdx);
                    if (last && last.phase === "classifying") messagesModel.remove(lastIdx);
                }
                var chosen = null;
                if (pickedId > 0) {
                    for (var i = 0; i < topics.length; i++) {
                        if (topics[i].id === pickedId) { chosen = topics[i]; break; }
                    }
                }
                if (chosen) {
                    currentTopicId = chosen.id;
                    // Pin to the conversation (creates it if needed first).
                    if (currentConvId <= 0) {
                        // Defer pinning until the conversation row exists.
                    }
                }
                _runAsk(q, chosen);
                if (chosen && currentConvId > 0) {
                    Store.setConversationTopic(currentConvId, chosen.id,
                                               chosen.collectionId || "");
                }
            });
            return;
        }

        _runAsk(q, currentTopic);
    }

    // ---- topic subheader ----
    Rectangle {
        id: topicSubheader
        anchors {
            top: page.header.bottom
            left: parent.left; right: parent.right
        }
        height: topics.length > 1 ? units.gu(4.2) : 0
        visible: topics.length > 1
        color: "transparent"
        z: 1
        clip: true
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: appTheme.border
            opacity: 0.5
        }

        Item {
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: units.gu(1.5)
                rightMargin: units.gu(1.5)
            }
            height: parent.height

            // Topic chip (clickable, opens picker)
            Rectangle {
                id: topicChip
                anchors.verticalCenter: parent.verticalCenter
                height: units.gu(3.2)
                width: chipRow.implicitWidth + units.gu(1.6)
                radius: height / 2
                color: chipMouseArea.containsMouse ? appTheme.surfaceHover : appTheme.surfaceAlt
                border.color: chipMouseArea.containsMouse ? appTheme.borderFocus : appTheme.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: chipRow
                    anchors {
                        left: parent.left; verticalCenter: parent.verticalCenter
                        leftMargin: units.gu(0.8)
                    }
                    spacing: units.gu(0.6)

                    // Indicator — solid disc when topic pinned, reload icon when Auto.
                    Item {
                        Layout.preferredWidth: units.gu(1.6)
                        Layout.preferredHeight: units.gu(1.6)
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: currentTopic ? topicColor(currentTopic) : appTheme.surfaceHover
                            border.color: appTheme.borderStrong
                            border.width: currentTopic ? 0 : 1
                        }
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(1.1); height: width
                            name: "reload"
                            color: appTheme.textSecondary
                            visible: !currentTopic
                        }
                    }
                    Label {
                        Layout.alignment: Qt.AlignVCenter
                        text: currentTopic ? currentTopic.name : i18nApp.tr("Auto")
                        color: appTheme.text
                        textSize: Label.Small
                        font.bold: true
                    }
                    Icon {
                        Layout.preferredWidth: units.gu(1.4)
                        Layout.preferredHeight: units.gu(1.4)
                        Layout.alignment: Qt.AlignVCenter
                        name: "down"
                        color: appTheme.textSecondary
                    }
                }

                PressEffect {
                    id: chipMouseArea
                    onClicked: PopupUtils.open(topicPicker, topicChip)
                }
            }
        }
    }

    // ---- responsive layout ----
    RowLayout {
        anchors {
            top: topicSubheader.bottom
            left: parent.left; right: parent.right; bottom: parent.bottom
        }
        spacing: 0

        // Sidebar (pinned in wide mode, hidden+overlay in narrow)
        ConversationList {
            id: sidebar
            Layout.preferredWidth: units.gu(28)
            Layout.fillHeight: true
            visible: wideMode && sidebarOpen
            appTheme: page.appTheme
            i18nApp: page.i18nApp
            conversations: page.conversations
            topics: page.topics
            currentId: page.currentConvId
            wideMode: page.wideMode
            onNewChatRequested: newConversation()
            onConversationSelected: selectConversation(id)
            onRenameRequested: openRenameDialog(id, currentTitle)
            onDeleteRequested: openDeleteDialog(id, currentTitle)
        }

        // Chat area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                ErrorBanner {
                    id: errorBanner
                    Layout.fillWidth: true
                    appTheme: page.appTheme
                    i18nApp: page.i18nApp
                    severity: "danger"
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Item {
                        anchors.fill: parent
                        anchors.margins: units.gu(3)
                        visible: messagesModel.count === 0

                        ColumnLayout {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(parent.width, page.wideMode ? units.gu(64) : units.gu(50))
                            spacing: units.gu(1.5)

                            BrandMark {
                                Layout.alignment: Qt.AlignHCenter
                                appTheme: page.appTheme
                                size: units.gu(8)
                            }

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                text: i18nApp.tr("What would you like to know today?")
                                textSize: Label.Large
                                color: appTheme.text
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                text: i18nApp.tr("Ask anything about your documents")
                                textSize: Label.Small
                                color: appTheme.textSecondary
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }

                            Item { Layout.preferredHeight: units.gu(1.5) }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: page.wideMode ? 2 : 1
                                columnSpacing: units.gu(1.0)
                                rowSpacing: units.gu(1.0)

                                SuggestionCard {
                                    Layout.fillWidth: true
                                    appTheme: page.appTheme
                                    title: i18nApp.tr("Summarize the working hours policy")
                                    subtitle: i18nApp.tr("From the internal regulations")
                                    onClicked: sendQuery(title)
                                }
                                SuggestionCard {
                                    Layout.fillWidth: true
                                    appTheme: page.appTheme
                                    title: i18nApp.tr("What are the security and JWT requirements?")
                                    subtitle: i18nApp.tr("From operations and security docs")
                                    onClicked: sendQuery(title)
                                }
                                SuggestionCard {
                                    Layout.fillWidth: true
                                    Layout.columnSpan: page.wideMode ? 2 : 1
                                    appTheme: page.appTheme
                                    title: i18nApp.tr("List the vacation rules")
                                    subtitle: i18nApp.tr("From HR documents")
                                    onClicked: sendQuery(title)
                                }
                            }
                        }
                    }

                    ListView {
                        id: listView
                        anchors.fill: parent
                        anchors.leftMargin: units.gu(0.5)
                        anchors.rightMargin: units.gu(0.5)
                        clip: true
                        visible: messagesModel.count > 0
                        model: messagesModel
                        spacing: units.gu(0.2)
                        bottomMargin: units.gu(1)
                        topMargin: units.gu(1)

                        // F9: only follow new content when the user is already at the bottom.
                        // Toggled by hand-scroll (onMovementEnded) and by the jump-to-bottom button.
                        property bool stickToBottom: true

                        function _atBottom() {
                            if (contentHeight <= height) return true;
                            return (contentY + height) >= (contentHeight - units.gu(4));
                        }

                        onMovementEnded: stickToBottom = _atBottom()
                        onCountChanged: if (stickToBottom) positionViewAtEnd()

                        // Only animates items newly appended to the model, not pre-existing
                        // ones reloaded from history or recycled by the ListView pool.
                        // y is left to ListView (animating it caused inserts to fly from
                        // the top of the list to their real position, looking like duplicates).
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"; from: 0; to: 1
                                duration: 200; easing.type: Easing.OutCubic
                            }
                        }

                        delegate: MessageBubble {
                            width: listView.width
                            role: model.role
                            text: model.content
                            sources: model.sources
                            streaming: model.streaming
                            phase: model.phase || ""
                            toolName: model.toolName || ""
                            toolArgs: model.toolArgs || ""
                            toolResult: model.toolResult || ""
                            toolError: model.toolError || ""
                            timestamp: model.timestamp || 0
                            modelLabel: model.modelName || ""
                            i18nApp: page.i18nApp
                            appTheme: page.appTheme
                            speaking: page.speakingIndex === index
                            onSpeakRequested: page.speakMessage(index)
                            onRegenerateRequested: page.regenerateLast()
                        }
                    }

                    // F9: floating "jump to bottom" pill, shown while the user
                    // has scrolled away from the tail.
                    Rectangle {
                        id: jumpBtn
                        visible: messagesModel.count > 0 && !listView.stickToBottom
                        anchors {
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                            bottomMargin: units.gu(1.5)
                        }
                        width: units.gu(4); height: units.gu(4)
                        radius: width / 2
                        color: jumpMouse.pressed ? appTheme.secondary
                              : (jumpMouse.containsMouse ? appTheme.surfaceHover : appTheme.primary)
                        border.color: appTheme.borderFocus
                        border.width: 1
                        opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        z: 2

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2); height: width
                            name: "go-down"
                            color: "white"
                        }

                        PressEffect {
                            id: jumpMouse
                            onClicked: {
                                listView.stickToBottom = true;
                                listView.positionViewAtEnd();
                            }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: i18nApp ? i18nApp.tr("Jump to latest") : "Jump to latest"
                    }
                }

                // Input area
                Rectangle {
                    id: inputArea
                    Layout.fillWidth: true
                    Layout.preferredHeight: inputRow.implicitHeight + units.gu(1.4)
                    Layout.leftMargin: units.gu(1.5)
                    Layout.rightMargin: units.gu(1.5)
                    Layout.bottomMargin: units.gu(1.5)
                    Layout.topMargin: units.gu(0.5)
                    radius: units.gu(2)
                    color: appTheme.surface
                    border.color: input.activeFocus ? appTheme.borderFocus : appTheme.border
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: inputRow
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: units.gu(1.5)
                            rightMargin: units.gu(0.8)
                        }
                        spacing: units.gu(0.8)

                        TextArea {
                            id: input
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredHeight: Math.min(units.gu(14), Math.max(units.gu(4.5), contentHeight + units.gu(2)))
                            placeholderText: recorder.recording
                                             ? i18nApp.tr("Listening…")
                                             : (whisper.busy
                                                ? i18nApp.tr("Transcribing…")
                                                : i18nApp.tr("Ask about your documents…"))
                            wrapMode: TextEdit.Wrap
                            color: appTheme.text
                            autoSize: true
                            maximumLineCount: 6
                            enabled: !recorder.recording && !whisper.busy
                            Keys.onReturnPressed: {
                                if (event.modifiers & Qt.ShiftModifier) { event.accepted = false; }
                                else { event.accepted = true; sendQuery(input.text); }
                            }
                        }

                        // Attach button (placeholder — disabled until backend supports uploads)
                        Rectangle {
                            id: attachBtn
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: units.gu(4.5)
                            Layout.preferredHeight: units.gu(4.5)
                            radius: width / 2
                            color: "transparent"
                            border.color: appTheme.border
                            border.width: 1
                            opacity: 0.45
                            visible: !page.busy

                            Icon {
                                anchors.centerIn: parent
                                width: units.gu(1.8); height: width
                                name: "attachment"
                                color: appTheme.textSecondary
                            }
                            // Disabled — no PressEffect attached. Tooltip-equivalent
                            // is shown via the icon name + placeholder until uploads ship.
                            Accessible.role: Accessible.Button
                            Accessible.name: i18nApp ? i18nApp.tr("Attach a file") : "Attach a file"
                            Accessible.description: i18nApp ? i18nApp.tr("Coming soon") : "Coming soon"
                        }

                        // Mic button
                        Rectangle {
                            id: micBtn
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: units.gu(4.5)
                            Layout.preferredHeight: units.gu(4.5)
                            radius: width / 2
                            color: recorder.recording
                                   ? appTheme.danger
                                   : (whisper.busy ? appTheme.surfaceHover
                                     : (micMouse.containsMouse ? appTheme.surfaceHover : "transparent"))
                            border.color: recorder.recording ? appTheme.danger : appTheme.border
                            border.width: 1
                            visible: !page.busy
                            Behavior on color { ColorAnimation { duration: 120 } }

                            // Pulsing ring while recording
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                radius: width / 2
                                color: "transparent"
                                border.color: appTheme.danger
                                border.width: 2
                                visible: recorder.recording
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: recorder.recording
                                    NumberAnimation { to: 0.0; duration: 800; easing.type: Easing.OutQuad }
                                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InQuad }
                                }
                                SequentialAnimation on scale {
                                    loops: Animation.Infinite
                                    running: recorder.recording
                                    NumberAnimation { to: 1.6; duration: 800; easing.type: Easing.OutQuad }
                                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InQuad }
                                }
                            }

                            Icon {
                                anchors.centerIn: parent
                                width: units.gu(2); height: width
                                name: recorder.recording ? "stop"
                                                         : (whisper.busy ? "view-refresh" : "audio-input-microphone")
                                color: recorder.recording ? "white"
                                                          : (whisper.busy ? appTheme.textSecondary : appTheme.text)

                                RotationAnimation on rotation {
                                    loops: Animation.Infinite
                                    from: 0; to: 360
                                    duration: 900
                                    running: whisper.busy
                                }
                            }

                            PressEffect {
                                id: micMouse
                                enabled: !whisper.busy
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (recorder.recording) recorder.stop();
                                    else recorder.start();
                                }
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: recorder.recording
                                             ? (i18nApp ? i18nApp.tr("Stop recording") : "Stop recording")
                                             : (i18nApp ? i18nApp.tr("Voice input") : "Voice input")
                        }

                        // Send / stop button
                        Rectangle {
                            id: sendBtn
                            Accessible.role: Accessible.Button
                            Accessible.name: page.busy
                                             ? (i18nApp ? i18nApp.tr("Stop") : "Stop")
                                             : (i18nApp ? i18nApp.tr("Send") : "Send")
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: units.gu(4.5)
                            Layout.preferredHeight: units.gu(4.5)
                            radius: width / 2
                            readonly property bool idle: input.text.trim().length === 0 && !page.busy
                            color: page.busy ? appTheme.danger
                                             : (idle ? appTheme.surfaceHover
                                               : (sendMouse.containsMouse ? appTheme.secondary : appTheme.primary))
                            border.color: appTheme.border
                            border.width: sendBtn.idle ? 1 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }

                            // Pulsing stop ring while a request is in flight.
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                radius: width / 2
                                color: "transparent"
                                border.color: appTheme.danger
                                border.width: 2
                                visible: page.busy
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: page.busy
                                    NumberAnimation { to: 0.0; duration: 800; easing.type: Easing.OutQuad }
                                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InQuad }
                                }
                                SequentialAnimation on scale {
                                    loops: Animation.Infinite
                                    running: page.busy
                                    NumberAnimation { to: 1.6; duration: 800; easing.type: Easing.OutQuad }
                                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InQuad }
                                }
                            }

                            Icon {
                                anchors.centerIn: parent
                                width: units.gu(2.2); height: width
                                name: page.busy ? "media-playback-stop" : "send"
                                color: sendBtn.idle ? appTheme.textSecondary : "white"
                            }

                            PressEffect {
                                id: sendMouse
                                enabled: input.text.trim().length > 0 || page.busy
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (page.busy) {
                                        if (activeXhr) { try { activeXhr.abort(); } catch(e) {} }
                                        busy = false;
                                        if (messagesModel.count > 0) {
                                            var idx = messagesModel.count - 1;
                                            messagesModel.setProperty(idx, "streaming", false);
                                        }
                                    } else {
                                        sendQuery(input.text);
                                    }
                                }
                            }
                        }
                    }
                }

                // Keyboard hint — fades in only while composing on wide screens.
                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: units.gu(2.5)
                    Layout.rightMargin: units.gu(2.5)
                    Layout.bottomMargin: units.gu(0.6)
                    horizontalAlignment: Text.AlignRight
                    text: i18nApp.tr("Enter to send · Shift+Enter for newline")
                    color: appTheme.textMuted
                    textSize: Label.XSmall
                    visible: page.wideMode
                    opacity: input.activeFocus ? 0.75 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }
        }
    }

    // ---- narrow-mode overlay sidebar ----
    Rectangle {
        id: backdrop
        anchors.fill: parent
        anchors.topMargin: page.header.height
        color: "black"
        opacity: (sidebarOpen && !wideMode) ? 0.45 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        MouseArea {
            anchors.fill: parent
            onClicked: sidebarOpen = false
        }
    }

    Item {
        id: overlaySidebarHolder
        anchors {
            top: page.header.bottom
            bottom: parent.bottom
            left: parent.left
        }
        width: Math.min(parent.width * 0.85, units.gu(32))
        visible: !wideMode && (sidebarOpen || slideAnim.running)
        clip: false

        transform: Translate {
            id: slideTrans
            x: (sidebarOpen && !wideMode) ? 0 : -overlaySidebarHolder.width
            Behavior on x {
                NumberAnimation { id: slideAnim; duration: 200; easing.type: Easing.OutCubic }
            }
        }

        ConversationList {
            anchors.fill: parent
            appTheme: page.appTheme
            i18nApp: page.i18nApp
            conversations: page.conversations
            topics: page.topics
            currentId: page.currentConvId
            wideMode: page.wideMode
            onNewChatRequested: newConversation()
            onConversationSelected: selectConversation(id)
            onRenameRequested: openRenameDialog(id, currentTitle)
            onDeleteRequested: openDeleteDialog(id, currentTitle)
        }
    }

    // ---- dialogs ----
    function openRenameDialog(id, currentTitle) {
        PopupUtils.open(renameDialog, page, { convId: id, currentTitle: currentTitle });
    }
    function openDeleteDialog(id, currentTitle) {
        PopupUtils.open(deleteDialog, page, { convId: id, currentTitle: currentTitle });
    }

    Component {
        id: renameDialog
        Dialog {
            id: dlg
            property int convId: -1
            property string currentTitle: ""
            title: i18nApp.tr("Rename conversation")
            text: i18nApp.tr("Title")

            TextField {
                id: titleField
                text: dlg.currentTitle
            }
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
                        var t = titleField.text.trim();
                        if (t.length > 0) {
                            Store.renameConversation(dlg.convId, t);
                            refreshConversations();
                        }
                        PopupUtils.close(dlg);
                    }
                }
            }
        }
    }

    Component {
        id: deleteDialog
        Dialog {
            id: dlg
            property int convId: -1
            property string currentTitle: ""
            title: i18nApp.tr("Delete conversation")
            text: i18nApp.tr("Delete \"%1\"? This cannot be undone.").replace("%1", currentTitle || i18nApp.tr("Untitled"))

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
                        var wasCurrent = (dlg.convId === currentConvId);
                        Store.deleteConversation(dlg.convId);
                        refreshConversations();
                        if (wasCurrent) newConversation();
                        PopupUtils.close(dlg);
                    }
                }
            }
        }
    }

    // ---- topic picker popover ----
    Component {
        id: topicPicker
        Popover {
            id: pop
            contentWidth: units.gu(28)

            Column {
                anchors { left: parent.left; right: parent.right }
                spacing: 0

                // Header
                Item {
                    width: parent.width
                    height: units.gu(4)
                    Label {
                        anchors {
                            left: parent.left; verticalCenter: parent.verticalCenter
                            leftMargin: units.gu(1.4)
                        }
                        text: i18nApp.tr("Choose topic")
                        textSize: Label.Small
                        color: appTheme.textSecondary
                        font.bold: true
                    }
                }

                Rectangle { width: parent.width; height: 1; color: appTheme.border; opacity: 0.5 }

                // Auto row
                Rectangle {
                    width: parent.width
                    height: units.gu(4.2)
                    color: autoMouse.containsMouse ? appTheme.surfaceHover : "transparent"

                    RowLayout {
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: units.gu(1.4)
                            rightMargin: units.gu(1.4)
                        }
                        spacing: units.gu(0.8)

                        Rectangle {
                            Layout.preferredWidth: units.gu(1.2)
                            Layout.preferredHeight: units.gu(1.2)
                            radius: width / 2
                            color: "transparent"
                            border.color: appTheme.textMuted
                            border.width: 1
                        }
                        Label {
                            Layout.fillWidth: true
                            text: i18nApp.tr("Auto (classify per query)")
                            color: appTheme.text
                            textSize: Label.Small
                            font.bold: currentTopicId <= 0
                        }
                        Icon {
                            visible: currentTopicId <= 0
                            Layout.preferredWidth: units.gu(1.6)
                            Layout.preferredHeight: units.gu(1.6)
                            name: "ok"
                            color: appTheme.primary
                        }
                    }
                    MouseArea {
                        id: autoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            selectTopic(-1);
                            PopupUtils.close(pop);
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: appTheme.border; opacity: 0.3 }

                // Topic rows
                Repeater {
                    model: topics
                    Rectangle {
                        width: parent.width
                        height: units.gu(4.2)
                        color: rowMouse.containsMouse ? appTheme.surfaceHover : "transparent"

                        RowLayout {
                            anchors {
                                left: parent.left; right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: units.gu(1.4)
                                rightMargin: units.gu(1.4)
                            }
                            spacing: units.gu(0.8)

                            Rectangle {
                                Layout.preferredWidth: units.gu(1.2)
                                Layout.preferredHeight: units.gu(1.2)
                                radius: width / 2
                                color: topicColor(modelData)
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: appTheme.text
                                textSize: Label.Small
                                font.bold: currentTopicId === modelData.id
                                elide: Text.ElideRight
                            }
                            Icon {
                                visible: currentTopicId === modelData.id
                                Layout.preferredWidth: units.gu(1.6)
                                Layout.preferredHeight: units.gu(1.6)
                                name: "ok"
                                color: appTheme.primary
                            }
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                selectTopic(modelData.id);
                                PopupUtils.close(pop);
                            }
                        }
                    }
                }
            }
        }
    }
}
