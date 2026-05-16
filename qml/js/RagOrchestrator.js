.pragma library
.import "ChromaClient.js" as Chroma
.import "OpenRouterClient.js" as OR

var CONTEXT_HEADER = {
    "en": "Retrieved context (use as the source of truth; cite the file when relevant):\n",
    "es": "Contexto recuperado (úsalo como fuente de verdad; cita el archivo cuando aplique):\n",
    "nl": "Opgehaalde context (gebruik dit als bron van waarheid; vermeld het bestand indien relevant):\n"
};

function buildContextBlock(items, language) {
    if (!items || items.length === 0) return "";
    var header = CONTEXT_HEADER[language] || CONTEXT_HEADER["en"];
    var parts = [header];
    for (var i = 0; i < items.length; i++) {
        var it = items[i];
        var meta = it.metadata || {};
        var src = meta.file_name || meta.storage_ref || meta.source_id || "doc-" + (i+1);
        parts.push("--- [" + (i+1) + "] " + src + " ---\n" + it.document);
    }
    return parts.join("\n");
}

var LANGUAGE_NAMES = {
    "en": "English",
    "es": "Spanish",
    "nl": "Dutch"
};

function defaultSystemPrompt(language, topicAddon) {
    var langName = LANGUAGE_NAMES[language] || "English";
    var base = "You are a retrieval-augmented assistant. " +
               "Always respond in " + langName + ", concise and precise. " +
               "Use ONLY the provided context as the source of truth. " +
               "If the answer is not in the context, say so explicitly. " +
               "Cite documents by their file name when you use them.";
    if (topicAddon && topicAddon.length > 0) {
        base += "\n\nTopic-specific guidance:\n" + topicAddon;
    }
    return base;
}

// settings: { chromaUrl, tenant, database, collectionId, ollamaUrl, embedModel, topK,
//             openrouterUrl, apiKey, model, appTitle, topicAddon, tools, toolRegistry }
// history: [{ role, content }, ...]  (does NOT include the new user message)
// userMessage: string
// callbacks: onSources(items), onDelta(text), onDone(fullText),
//            onToolStart(call), onToolDone(call, result), onError(msg)
function ask(settings, history, userMessage, callbacks) {
    Chroma.retrieve({
        chromaUrl: settings.chromaUrl,
        tenant: settings.tenant || "default_tenant",
        database: settings.database || "default_database",
        collectionId: settings.collectionId,
        ollamaUrl: settings.ollamaUrl,
        embedModel: settings.embedModel || "nomic-embed-text",
        topK: settings.topK || 5
    }, userMessage,
    function(items) {
        if (callbacks.onSources) callbacks.onSources(items);
        var ctx = buildContextBlock(items, settings.language);
        var messages = [{ role: "system", content: defaultSystemPrompt(settings.language, settings.topicAddon) }];
        if (ctx.length > 0) messages.push({ role: "system", content: ctx });
        for (var i = 0; i < history.length; i++) messages.push(history[i]);
        messages.push({ role: "user", content: userMessage });

        runWithTools(settings, messages, callbacks, 0);
    },
    function(err) {
        if (callbacks.onError) callbacks.onError("Chroma/embed: " + err);
    });
}

// runWithTools — drives the tool-calling loop. Streams a chat completion; if
// the model returns tool_calls, executes each, appends the assistant message
// and the role:"tool" replies, and recurses. Bounded by MAX_TOOL_DEPTH so a
// looping model can't run away.
var MAX_TOOL_DEPTH = 5;

function runWithTools(settings, messages, callbacks, depth) {
    depth = depth || 0;
    if (depth > MAX_TOOL_DEPTH) {
        if (callbacks.onError) callbacks.onError("Tool loop exceeded max depth (" + MAX_TOOL_DEPTH + ")");
        return;
    }

    // Round > 0 starts a new assistant turn. The very first round reuses the
    // placeholder ChatPage created before retrieval.
    if (depth > 0 && callbacks.onRoundStart) callbacks.onRoundStart(depth);

    var roundText = "";

    var streamOpts = {
        baseUrl: settings.openrouterUrl,
        apiKey: settings.apiKey,
        model: settings.model,
        appTitle: settings.appTitle || "ragassistant"
    };
    if (settings.tools && settings.tools.length > 0) {
        streamOpts.tools = settings.tools;
    }

    return OR.streamChat(streamOpts, messages, {
        onDelta: function(t) {
            roundText += t;
            if (callbacks.onDelta) callbacks.onDelta(t);
        },
        onDone: function(full, usage, toolCalls) {
            if (!toolCalls || toolCalls.length === 0) {
                if (callbacks.onDone) callbacks.onDone(full || roundText, usage);
                return;
            }

            // The model asked for tools. Echo the assistant message verbatim
            // (content can be null when only tool_calls were emitted) and then
            // append one role:"tool" reply per call.
            var assistantMsg = {
                role: "assistant",
                content: (full && full.length > 0) ? full : null,
                tool_calls: []
            };
            for (var i = 0; i < toolCalls.length; i++) {
                var c = toolCalls[i];
                assistantMsg.tool_calls.push({
                    id: c.id,
                    type: "function",
                    "function": { name: c.name, arguments: c.argumentsString || "{}" }
                });
            }
            messages.push(assistantMsg);

            // Signal the UI that the current assistant turn ended with tool
            // calls — gives ChatPage a chance to finalize/clean the placeholder
            // before tool result bubbles get appended.
            if (callbacks.onPreTools) callbacks.onPreTools(full || roundText, toolCalls);

            var registry = settings.toolRegistry;
            if (!registry) {
                if (callbacks.onError) callbacks.onError("Model requested tools but no registry is configured");
                return;
            }

            var pending = toolCalls.length;
            for (var j = 0; j < toolCalls.length; j++) {
                (function(call) {
                    if (callbacks.onToolStart) callbacks.onToolStart(call);
                    registry.execute(call.name, call.arguments, function(result) {
                        if (callbacks.onToolDone) callbacks.onToolDone(call, result);
                        messages.push({
                            role: "tool",
                            tool_call_id: call.id,
                            name: call.name,
                            content: JSON.stringify(result)
                        });
                        pending--;
                        if (pending === 0) {
                            runWithTools(settings, messages, callbacks, depth + 1);
                        }
                    });
                })(toolCalls[j]);
            }
        },
        onError: callbacks.onError
    });
}

// classifyTopic — pick one topic id for the given query.
// settings: { openrouterUrl, apiKey, model, appTitle }
// topics:   [{ id, name, systemPromptAddon }, ...]
// cb:       (topicId | -1) -- never throws; on any failure returns -1 so the
//           caller can fall back to its default behavior.
function classifyTopic(settings, topics, query, cb) {
    if (!topics || topics.length === 0) { cb(-1); return; }
    if (topics.length === 1) { cb(topics[0].id); return; }

    var lines = ["Available topics:"];
    for (var i = 0; i < topics.length; i++) {
        var t = topics[i];
        var hint = (t.systemPromptAddon || "").replace(/\s+/g, " ").trim();
        if (hint.length > 140) hint = hint.substring(0, 140) + "...";
        lines.push("- id=" + t.id + " name=\"" + t.name + "\"" + (hint.length > 0 ? " — " + hint : ""));
    }
    var sys = "You are a router. Pick the single most relevant topic for the user's query. " +
              "Respond with ONLY a compact JSON object: {\"topic_id\": <id>}. " +
              "No prose, no markdown, no code fences.";
    var user = lines.join("\n") + "\n\nUser query: " + query;

    OR.chatOnce({
        baseUrl: settings.openrouterUrl,
        apiKey: settings.apiKey,
        model: settings.model,
        appTitle: settings.appTitle || "ragassistant",
        temperature: 0,
        maxTokens: 32
    }, [
        { role: "system", content: sys },
        { role: "user", content: user }
    ], {
        onDone: function(text) {
            var picked = -1;
            try {
                // Be lenient: model might wrap the JSON in fences despite the system prompt.
                var m = (text || "").match(/\{[^{}]*"topic_id"\s*:\s*(\d+)[^{}]*\}/);
                if (m) picked = parseInt(m[1]);
            } catch (e) { picked = -1; }
            // Validate it's a known topic id.
            var ok = false;
            for (var j = 0; j < topics.length; j++) {
                if (topics[j].id === picked) { ok = true; break; }
            }
            cb(ok ? picked : -1);
        },
        onError: function(err) {
            console.log("[classifier] error: " + err);
            cb(-1);
        }
    });
}
