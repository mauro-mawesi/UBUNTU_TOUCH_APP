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

function defaultSystemPrompt(language) {
    var langName = LANGUAGE_NAMES[language] || "English";
    return "You are a retrieval-augmented assistant. " +
           "Always respond in " + langName + ", concise and precise. " +
           "Use ONLY the provided context as the source of truth. " +
           "If the answer is not in the context, say so explicitly. " +
           "Cite documents by their file name when you use them.";
}

// settings: { chromaUrl, tenant, database, collectionId, ollamaUrl, embedModel, topK,
//             openrouterUrl, apiKey, model, appTitle }
// history: [{ role, content }, ...]  (does NOT include the new user message)
// userMessage: string
// callbacks: onSources(items), onDelta(text), onDone(fullText), onError(msg)
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
        var messages = [{ role: "system", content: defaultSystemPrompt(settings.language) }];
        if (ctx.length > 0) messages.push({ role: "system", content: ctx });
        for (var i = 0; i < history.length; i++) messages.push(history[i]);
        messages.push({ role: "user", content: userMessage });

        OR.streamChat({
            baseUrl: settings.openrouterUrl,
            apiKey: settings.apiKey,
            model: settings.model,
            appTitle: settings.appTitle || "ragassistant"
        }, messages, {
            onDelta: callbacks.onDelta,
            onDone: callbacks.onDone,
            onError: callbacks.onError
        });
    },
    function(err) {
        if (callbacks.onError) callbacks.onError("Chroma/embed: " + err);
    });
}
