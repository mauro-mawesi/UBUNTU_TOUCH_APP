import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3
import "components"
import "js/RagOrchestrator.js" as Rag
import "js/Store.js" as Store

Page {
    id: page
    property var appSettings
    property var pageStack
    property var settingsPage
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
                phase: ""
            });
            if (m.role === "user" || m.role === "assistant") {
                history.push({ role: m.role, content: m.content });
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
        if (!wideMode) sidebarOpen = false;
    }

    function ensureConvExists(seedText) {
        if (currentConvId > 0) return currentConvId;
        var id = Store.createConversation(Store.deriveTitle(seedText), appSettings.collectionId);
        currentConvId = id;
        return id;
    }

    Component.onCompleted: {
        Store.init();
        refreshConversations();
        if (conversations.length > 0) {
            selectConversation(conversations[0].id);
        }
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
                iconName: "settings"
                text: i18nApp.tr("Settings")
                onTriggered: pageStack.push(settingsPage, { appSettings: appSettings })
            }
        ]
    }

    ListModel { id: messagesModel }

    function appendMessage(role, content, sources, streaming, phase) {
        messagesModel.append({
            role: role,
            content: content || "",
            sources: sources || [],
            streaming: streaming === true,
            phase: phase || ""
        });
        // F9: user-sent messages re-anchor at the tail; otherwise respect
        // wherever the user is reading.
        if (role === "user") listView.stickToBottom = true;
        Qt.callLater(function() {
            if (listView.stickToBottom) listView.positionViewAtEnd();
        });
    }

    function updateLast(content, streaming) {
        if (messagesModel.count === 0) return;
        var idx = messagesModel.count - 1;
        messagesModel.setProperty(idx, "content", content);
        if (streaming !== undefined) messagesModel.setProperty(idx, "streaming", streaming);
        Qt.callLater(function() {
            if (listView.stickToBottom) listView.positionViewAtEnd();
        });
    }

    function updateLastSources(items) {
        if (messagesModel.count === 0) return;
        var idx = messagesModel.count - 1;
        messagesModel.setProperty(idx, "sources", items);
    }

    function setLastPhase(p) {
        if (messagesModel.count === 0) return;
        messagesModel.setProperty(messagesModel.count - 1, "phase", p || "");
    }

    function sendQuery(text) {
        var q = (text || "").trim();
        if (q.length === 0 || busy) return;
        if (!appSettings.apiKey || appSettings.apiKey.length === 0) {
            appendMessage("system", i18nApp.tr("Set your OpenRouter API Key in Settings."), [], false);
            return;
        }

        var convId = -1;
        try { convId = ensureConvExists(q); }
        catch (e) { console.log("[chat] ensureConvExists failed: " + e); }

        try { Store.addMessage(convId, "user", q, []); }
        catch (e) { console.log("[chat] persist user msg failed: " + e); }

        appendMessage("user", q, [], false);

        streamingMsgId = -1;
        try { streamingMsgId = Store.addMessage(convId, "assistant", "", []); }
        catch (e) { console.log("[chat] persist assistant msg failed: " + e); }

        appendMessage("assistant", "", [], true, "retrieving");

        input.text = "";
        busy = true;

        var assistantText = "";
        var assistantSources = [];

        var settingsWithLang = {
            apiKey: appSettings.apiKey, model: appSettings.model, openrouterUrl: appSettings.openrouterUrl,
            chromaUrl: appSettings.chromaUrl, tenant: appSettings.tenant, database: appSettings.database,
            collectionId: appSettings.collectionId, topK: appSettings.topK,
            ollamaUrl: appSettings.ollamaUrl, embedModel: appSettings.embedModel,
            language: i18nApp.language,
            appTitle: "ragassistant"
        };

        console.log("[chat] sendQuery convId=" + convId + " q=" + q.substring(0,40));
        console.log("[chat] settings: chroma=" + settingsWithLang.chromaUrl
                    + " collection=" + settingsWithLang.collectionId
                    + " ollama=" + settingsWithLang.ollamaUrl
                    + " model=" + settingsWithLang.model
                    + " hasApiKey=" + (!!settingsWithLang.apiKey));

        activeXhr = Rag.ask(settingsWithLang, history.slice(), q, {
            onSources: function(items) {
                console.log("[chat] onSources items=" + (items ? items.length : 0));
                assistantSources = items;
                updateLastSources(items);
                setLastPhase("thinking");
            },
            onDelta: function(t) {
                if (assistantText.length === 0) {
                    console.log("[chat] first delta arrived");
                    setLastPhase("");
                }
                assistantText += t;
                updateLast(assistantText, true);
            },
            onDone: function(full) {
                console.log("[chat] onDone len=" + (full ? full.length : 0));
                var finalText = full.length > 0 ? full : assistantText;
                updateLast(finalText, false);
                history.push({ role: "user", content: q });
                history.push({ role: "assistant", content: finalText });
                if (streamingMsgId > 0) {
                    Store.updateMessage(streamingMsgId, finalText, assistantSources);
                    streamingMsgId = -1;
                }
                refreshConversations();
                busy = false;
                activeXhr = null;
            },
            onError: function(err) {
                console.log("[chat] onError: " + err);
                var prefix = assistantText.length > 0 ? assistantText + "\n\n" : "";
                var finalText = prefix + "⚠ " + err;
                updateLast(finalText, false);
                if (streamingMsgId > 0) {
                    Store.updateMessage(streamingMsgId, finalText, assistantSources);
                    streamingMsgId = -1;
                }
                busy = false;
                activeXhr = null;
            }
        });
    }

    // ---- responsive layout ----
    RowLayout {
        anchors {
            top: page.header.bottom
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
            currentId: page.currentConvId
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

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Item {
                        anchors.fill: parent
                        anchors.margins: units.gu(3)
                        visible: messagesModel.count === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, units.gu(50))
                            spacing: units.gu(1.5)

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: units.gu(8)
                                Layout.preferredHeight: units.gu(8)
                                radius: width / 2
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: appTheme.primary }
                                    GradientStop { position: 1.0; color: appTheme.secondary }
                                }
                                Label {
                                    anchors.centerIn: parent
                                    text: "✦"
                                    color: "white"
                                    font.pixelSize: units.gu(4.5)
                                }
                            }

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                text: i18nApp.tr("Ask anything about your documents")
                                textSize: Label.Large
                                color: appTheme.text
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                text: i18nApp.tr("Your assistant retrieves relevant context from the knowledge base and answers using a language model.")
                                textSize: Label.Small
                                color: appTheme.textSecondary
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }

                            Item { Layout.preferredHeight: units.gu(1.5) }

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
                                appTheme: page.appTheme
                                title: i18nApp.tr("List the vacation rules")
                                subtitle: i18nApp.tr("From HR documents")
                                onClicked: sendQuery(title)
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

                        delegate: MessageBubble {
                            width: listView.width
                            role: model.role
                            text: model.content
                            sources: model.sources
                            streaming: model.streaming
                            phase: model.phase || ""
                            i18nApp: page.i18nApp
                            appTheme: page.appTheme
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

                        MouseArea {
                            id: jumpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                listView.stickToBottom = true;
                                listView.positionViewAtEnd();
                            }
                        }
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
                            placeholderText: i18nApp.tr("Ask about your documents…")
                            wrapMode: TextEdit.Wrap
                            color: appTheme.text
                            autoSize: true
                            maximumLineCount: 6
                            Keys.onReturnPressed: {
                                if (event.modifiers & Qt.ShiftModifier) { event.accepted = false; }
                                else { event.accepted = true; sendQuery(input.text); }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: units.gu(4.5)
                            Layout.preferredHeight: units.gu(4.5)
                            radius: width / 2
                            color: page.busy ? appTheme.danger
                                             : (input.text.trim().length === 0 ? appTheme.surfaceHover
                                               : (sendMouse.containsMouse ? appTheme.secondary : appTheme.primary))
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Icon {
                                anchors.centerIn: parent
                                width: units.gu(2.2); height: width
                                name: page.busy ? "media-playback-stop" : "send"
                                color: "white"
                            }

                            MouseArea {
                                id: sendMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: input.text.trim().length > 0 || page.busy
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
        Behavior on opacity { NumberAnimation { duration: 180 } }
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
            currentId: page.currentConvId
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
}
