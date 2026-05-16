.pragma library

// Streams a chat completion from OpenRouter (OpenAI-compatible SSE).
// callbacks: onDelta(text), onDone(fullText, usage), onError(msg)
// returns the XHR so caller can abort.
function streamChat(opts, messages, callbacks) {
    var xhr = new XMLHttpRequest();
    var url = (opts.baseUrl || "https://openrouter.ai/api/v1").replace(/\/+$/, "") + "/chat/completions";
    console.log("[openrouter] POST " + url + " model=" + opts.model + " hasKey=" + (!!opts.apiKey) + " msgCount=" + messages.length);
    xhr.open("POST", url);
    xhr.setRequestHeader("Authorization", "Bearer " + opts.apiKey);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("Accept", "text/event-stream");
    if (opts.appTitle) xhr.setRequestHeader("X-Title", opts.appTitle);
    if (opts.referer) xhr.setRequestHeader("HTTP-Referer", opts.referer);

    var lastIdx = 0;
    var buffer = "";
    var full = "";
    var usage = null;
    var done = false;
    var aborted = false;
    var finished = false;

    // tool_calls accumulator keyed by `index`. Each entry collects id, name,
    // and concatenated arguments-as-JSON-string. We parse arguments only at
    // the end so streamed JSON fragments don't fail mid-flight.
    var toolBuf = {};

    function _materializeToolCalls() {
        var out = [];
        var keys = Object.keys(toolBuf);
        keys.sort(function(a, b) { return parseInt(a) - parseInt(b); });
        for (var i = 0; i < keys.length; i++) {
            var c = toolBuf[keys[i]];
            var parsed = {};
            try { parsed = c.argsStr ? JSON.parse(c.argsStr) : {}; }
            catch (e) { parsed = { _raw: c.argsStr, _parseError: String(e) }; }
            out.push({
                id: c.id || "",
                name: c.name || "",
                arguments: parsed,
                argumentsString: c.argsStr || "{}"
            });
        }
        return out;
    }

    function finish(isError, errMsg) {
        if (finished) return;
        finished = true;
        if (isError) {
            if (callbacks.onError) callbacks.onError(errMsg);
        } else {
            if (callbacks.onDone) callbacks.onDone(full, usage, _materializeToolCalls());
        }
    }

    // Make abort() preserve whatever has streamed so far instead of surfacing
    // it as a network error. Caller in ChatPage.qml does activeXhr.abort()
    // directly, so we intercept on the xhr itself.
    var origAbort = xhr.abort;
    xhr.abort = function() {
        aborted = true;
        try { origAbort.call(xhr); } catch (e) {}
        console.log("[openrouter] aborted by user; partial len=" + full.length);
        finish(false);
    };

    function handleEvent(eventStr) {
        var lines = eventStr.split("\n");
        var dataParts = [];
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.indexOf("data:") === 0) {
                dataParts.push(line.substring(5).replace(/^ /, ""));
            }
        }
        if (dataParts.length === 0) return;
        var payload = dataParts.join("\n");
        if (payload === "[DONE]") { done = true; return; }
        try {
            var obj = JSON.parse(payload);
            if (obj.usage) usage = obj.usage;
            var choices = obj.choices || [];
            for (var c = 0; c < choices.length; c++) {
                var delta = choices[c].delta || {};
                if (delta.content) {
                    full += delta.content;
                    if (callbacks.onDelta) callbacks.onDelta(delta.content);
                }
                // Streamed tool_calls: each chunk carries one or more partial
                // entries keyed by `index`. The first chunk for a given index
                // usually has id+name; subsequent chunks append to arguments.
                if (delta.tool_calls && delta.tool_calls.length) {
                    for (var k = 0; k < delta.tool_calls.length; k++) {
                        var tc = delta.tool_calls[k];
                        var idx = (tc.index !== undefined) ? tc.index : k;
                        if (!toolBuf[idx]) toolBuf[idx] = { id: "", name: "", argsStr: "" };
                        if (tc.id) toolBuf[idx].id = tc.id;
                        var fn = tc["function"] || {};
                        if (fn.name) toolBuf[idx].name = fn.name;
                        if (fn.arguments) toolBuf[idx].argsStr += fn.arguments;
                    }
                }
            }
        } catch (e) {
            // Comments (": ping") or non-JSON lines: ignore.
        }
    }

    function drain(finalFlush) {
        var chunk = xhr.responseText.substring(lastIdx);
        lastIdx = xhr.responseText.length;
        buffer += chunk;
        var sep;
        while ((sep = buffer.indexOf("\n\n")) >= 0) {
            var event = buffer.substring(0, sep);
            buffer = buffer.substring(sep + 2);
            if (event.length > 0) handleEvent(event);
        }
        if (finalFlush && buffer.length > 0) {
            handleEvent(buffer);
            buffer = "";
        }
    }

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
            console.log("[openrouter] headers received status=" + xhr.status);
        }
        if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
            if (aborted) return;
            if (xhr.status === 0 && xhr.readyState === XMLHttpRequest.DONE) {
                console.log("[openrouter] network error (status=0)");
                finish(true, "network error");
                return;
            }
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status >= 400) {
                console.log("[openrouter] HTTP " + xhr.status + " body=" + xhr.responseText.substring(0, 200));
                finish(true, "HTTP " + xhr.status + ": " + xhr.responseText);
                return;
            }
            drain(xhr.readyState === XMLHttpRequest.DONE);
            if (xhr.readyState === XMLHttpRequest.DONE) {
                console.log("[openrouter] DONE total len=" + full.length);
                finish(false);
            }
        }
    };

    var body = {
        model: opts.model,
        messages: messages,
        stream: true
    };
    if (opts.temperature !== undefined) body.temperature = opts.temperature;
    if (opts.maxTokens) body.max_tokens = opts.maxTokens;
    if (opts.tools && opts.tools.length > 0) {
        body.tools = opts.tools;
        if (opts.toolChoice) body.tool_choice = opts.toolChoice;
    }

    xhr.send(JSON.stringify(body));
    return xhr;
}

// One-shot non-streaming completion. Used for short auxiliary calls like the
// topic classifier where we don't need token-by-token rendering.
// callbacks: onDone(text, usage), onError(msg)
function chatOnce(opts, messages, callbacks) {
    var xhr = new XMLHttpRequest();
    var url = (opts.baseUrl || "https://openrouter.ai/api/v1").replace(/\/+$/, "") + "/chat/completions";
    console.log("[openrouter] one-shot POST " + url + " model=" + opts.model + " msgCount=" + messages.length);
    xhr.open("POST", url);
    xhr.setRequestHeader("Authorization", "Bearer " + opts.apiKey);
    xhr.setRequestHeader("Content-Type", "application/json");
    if (opts.appTitle) xhr.setRequestHeader("X-Title", opts.appTitle);

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status === 0) { if (callbacks.onError) callbacks.onError("network error"); return; }
        if (xhr.status < 200 || xhr.status >= 300) {
            if (callbacks.onError) callbacks.onError("HTTP " + xhr.status + ": " + xhr.responseText);
            return;
        }
        try {
            var obj = JSON.parse(xhr.responseText);
            var text = "";
            if (obj.choices && obj.choices[0] && obj.choices[0].message) {
                text = obj.choices[0].message.content || "";
            }
            if (callbacks.onDone) callbacks.onDone(text, obj.usage || null);
        } catch (e) {
            if (callbacks.onError) callbacks.onError("parse error: " + e);
        }
    };

    var body = {
        model: opts.model,
        messages: messages,
        stream: false
    };
    if (opts.temperature !== undefined) body.temperature = opts.temperature;
    if (opts.maxTokens) body.max_tokens = opts.maxTokens;

    xhr.send(JSON.stringify(body));
    return xhr;
}
