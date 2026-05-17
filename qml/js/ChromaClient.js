.pragma library

function _post(url, body, onOk, onErr) {
    console.log("[chroma] POST " + url);
    var xhr = new XMLHttpRequest();
    xhr.open("POST", url);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        console.log("[chroma] response status=" + xhr.status + " for " + url);
        if (xhr.status === 0) {
            onErr("service unreachable: " + url + " (check network / base URL)");
            return;
        }
        if (xhr.status >= 200 && xhr.status < 300) {
            try { onOk(JSON.parse(xhr.responseText)); }
            catch (e) { onErr("parse error: " + e); }
        } else {
            onErr("HTTP " + xhr.status + ": " + xhr.responseText);
        }
    };
    xhr.send(JSON.stringify(body));
}

// Like _post but supports custom headers. Used for Gemini (x-goog-api-key).
// For googleapis.com URLs, error bodies are redacted defensively — Google
// could echo the API key in error.detail strings.
function _postWithHeader(url, headers, body, onOk, onErr) {
    console.log("[chroma] POST " + url);
    var xhr = new XMLHttpRequest();
    xhr.open("POST", url);
    xhr.setRequestHeader("Content-Type", "application/json");
    if (headers) {
        for (var k in headers) {
            if (headers.hasOwnProperty(k)) xhr.setRequestHeader(k, headers[k]);
        }
    }
    var isGoogle = url.indexOf("googleapis.com") >= 0;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        console.log("[chroma] response status=" + xhr.status + " for " + url);
        if (xhr.status === 0) {
            onErr("service unreachable: " + url + " (check network / base URL)");
            return;
        }
        if (xhr.status >= 200 && xhr.status < 300) {
            try { onOk(JSON.parse(xhr.responseText)); }
            catch (e) { onErr("parse error: " + e); }
        } else if (isGoogle) {
            onErr("HTTP " + xhr.status + " from Gemini (body redacted)");
        } else {
            onErr("HTTP " + xhr.status + ": " + xhr.responseText);
        }
    };
    xhr.send(JSON.stringify(body));
}

function embedOllama(ollamaUrl, model, text, onOk, onErr) {
    _post(ollamaUrl.replace(/\/+$/, "") + "/api/embeddings",
          { model: model, prompt: text },
          function(res) {
              if (res && res.embedding) onOk(res.embedding);
              else onErr("no embedding in response");
          },
          onErr);
}

function embedGemini(geminiUrl, model, apiKey, text, onOk, onErr) {
    var base = (geminiUrl || "https://generativelanguage.googleapis.com/v1beta").replace(/\/+$/, "");
    var url = base + "/models/" + model + ":embedContent";
    _postWithHeader(url,
          { "x-goog-api-key": apiKey },
          { model: "models/" + model,
            content: { parts: [ { text: text } ] },
            outputDimensionality: 768 },
          function(res) {
              if (!res || !res.embedding || !res.embedding.values) {
                  onErr("no embedding.values in Gemini response");
                  return;
              }
              var vec = res.embedding.values;
              if (vec.length !== 768) {
                  onErr("Gemini embedding dim mismatch: got " + vec.length + " expected 768");
                  return;
              }
              onOk(vec);
          },
          onErr);
}

function embedWith(opts, text, onOk, onErr) {
    if (opts && opts.embedderProvider === "gemini") {
        return embedGemini(opts.geminiEmbedUrl, opts.geminiEmbedModel, opts.geminiApiKey,
                           text, onOk, onErr);
    }
    return embedOllama(opts.ollamaUrl, opts.embedModel, text, onOk, onErr);
}

// Back-compat wrapper — kept for any direct callers.
function embed(ollamaUrl, model, text, onOk, onErr) {
    return embedOllama(ollamaUrl, model, text, onOk, onErr);
}

function queryByEmbedding(chromaUrl, tenant, database, collectionId, embedding, nResults, onOk, onErr) {
    var url = chromaUrl.replace(/\/+$/, "")
            + "/api/v2/tenants/" + tenant
            + "/databases/" + database
            + "/collections/" + collectionId
            + "/query";
    _post(url,
          { query_embeddings: [embedding], n_results: nResults, include: ["documents", "metadatas", "distances"] },
          function(res) {
              var docs = (res.documents && res.documents[0]) || [];
              var metas = (res.metadatas && res.metadatas[0]) || [];
              var dists = (res.distances && res.distances[0]) || [];
              var items = [];
              for (var i = 0; i < docs.length; i++) {
                  items.push({ document: docs[i], metadata: metas[i] || {}, distance: dists[i] });
              }
              onOk(items);
          },
          onErr);
}

function retrieve(opts, query, onOk, onErr) {
    console.log("[chroma] retrieve provider=" + (opts.embedderProvider || "ollama")
                + " coll=" + opts.collectionId);
    embedWith(opts, query,
          function(vec) {
              queryByEmbedding(opts.chromaUrl, opts.tenant, opts.database, opts.collectionId,
                               vec, opts.topK || 5, onOk, onErr);
          },
          onErr);
}
