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

    function finish(isError, errMsg) {
        if (finished) return;
        finished = true;
        if (isError) {
            if (callbacks.onError) callbacks.onError(errMsg);
        } else {
            if (callbacks.onDone) callbacks.onDone(full, usage);
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

    xhr.send(JSON.stringify(body));
    return xhr;
}
