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

function embed(ollamaUrl, model, text, onOk, onErr) {
    _post(ollamaUrl.replace(/\/+$/, "") + "/api/embeddings",
          { model: model, prompt: text },
          function(res) {
              if (res && res.embedding) onOk(res.embedding);
              else onErr("no embedding in response");
          },
          onErr);
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
    embed(opts.ollamaUrl, opts.embedModel, query,
          function(vec) {
              queryByEmbedding(opts.chromaUrl, opts.tenant, opts.database, opts.collectionId,
                               vec, opts.topK || 5, onOk, onErr);
          },
          onErr);
}
