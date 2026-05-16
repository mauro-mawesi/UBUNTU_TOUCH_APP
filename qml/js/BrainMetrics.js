.pragma library
.import QtQuick.LocalStorage 2.0 as LS

// Helpers feeding BrainPage. All network helpers follow the same shape:
//   fn(args..., onOk, onErr) — onErr(reasonString).
// onOk receives a plain JS object/array.

function _trimUrl(u) { return (u || "").replace(/\/+$/, ""); }

function _xhr(method, url, headers, body, onOk, onErr) {
    var xhr = new XMLHttpRequest();
    var t0 = Date.now();
    try { xhr.open(method, url); }
    catch (e) { onErr("bad URL: " + url); return; }
    if (headers) {
        for (var k in headers) {
            if (headers.hasOwnProperty(k)) xhr.setRequestHeader(k, headers[k]);
        }
    }
    if (body && !headers) xhr.setRequestHeader("Content-Type", "application/json");
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        var dt = Date.now() - t0;
        if (xhr.status === 0) { onErr("unreachable"); return; }
        if (xhr.status >= 200 && xhr.status < 300) {
            var data = null;
            if (xhr.responseText && xhr.responseText.length > 0) {
                try { data = JSON.parse(xhr.responseText); }
                catch (e) { onErr("parse error: " + e); return; }
            }
            onOk(data, dt);
        } else {
            onErr("HTTP " + xhr.status);
        }
    };
    try { xhr.send(body ? JSON.stringify(body) : null); }
    catch (e) { onErr("send error"); }
}

// ---- service health ----
// Returns onDone(ok:bool, detail:string). Mirrors SettingsPage._ping so callers
// can use either interchangeably. Reused by BrainPage's health card.
function pingService(method, url, authHeader, onDone) {
    var headers = authHeader ? { "Authorization": authHeader } : null;
    _xhr(method, url, headers, null,
         function(_data, dt) { onDone(true, dt + "ms"); },
         function(err)       { onDone(false, err); });
}

// ---- Chroma ----
function listChromaCollections(chromaUrl, tenant, database, onOk, onErr) {
    var url = _trimUrl(chromaUrl)
            + "/api/v2/tenants/" + encodeURIComponent(tenant)
            + "/databases/" + encodeURIComponent(database)
            + "/collections";
    _xhr("GET", url, null, null, function(data) {
        var items = (data && data.length !== undefined) ? data : [];
        var out = [];
        for (var i = 0; i < items.length; i++) {
            var c = items[i] || {};
            out.push({
                id: c.id || "",
                name: c.name || "",
                dimension: (c.dimension !== undefined && c.dimension !== null) ? c.dimension : "",
                metadata: c.metadata || {}
            });
        }
        onOk(out);
    }, onErr);
}

function countChromaCollection(chromaUrl, tenant, database, collectionId, onOk, onErr) {
    var url = _trimUrl(chromaUrl)
            + "/api/v2/tenants/" + encodeURIComponent(tenant)
            + "/databases/" + encodeURIComponent(database)
            + "/collections/" + encodeURIComponent(collectionId)
            + "/count";
    _xhr("GET", url, null, null, function(data) {
        // Chroma returns the integer as the raw body (no envelope).
        var n = (typeof data === "number") ? data : parseInt(data, 10);
        onOk(isNaN(n) ? 0 : n);
    }, onErr);
}

// ---- Ollama ----
function listOllamaModels(ollamaUrl, onOk, onErr) {
    _xhr("GET", _trimUrl(ollamaUrl) + "/api/tags", null, null, function(data) {
        var models = (data && data.models) ? data.models : [];
        var out = [];
        for (var i = 0; i < models.length; i++) {
            var m = models[i] || {};
            out.push({
                name: m.name || "",
                sizeBytes: m.size || 0,
                family: (m.details && m.details.family) || "",
                parameterSize: (m.details && m.details.parameter_size) || ""
            });
        }
        onOk(out);
    }, onErr);
}

// ---- Local SQLite ----
// Reads counts straight from the same DB Store.js uses. Synchronous: Qt's
// LocalStorage callbacks are always synchronous, so this returns directly.
function localDbStats() {
    var stats = { conversations: 0, messages: 0, topics: 0, byRole: {},
                  oldestMs: 0, newestMs: 0 };
    try {
        var db = LS.LocalStorage.openDatabaseSync(
            "ragassistant", "1.0", "RAG Assistant local database", 5 * 1024 * 1024);
        db.readTransaction(function(tx) {
            var c = tx.executeSql("SELECT COUNT(*) AS n FROM conversations");
            stats.conversations = c.rows.item(0).n;

            var m = tx.executeSql("SELECT COUNT(*) AS n FROM messages");
            stats.messages = m.rows.item(0).n;

            var t = tx.executeSql("SELECT COUNT(*) AS n FROM topics");
            stats.topics = t.rows.item(0).n;

            var r = tx.executeSql("SELECT role, COUNT(*) AS n FROM messages GROUP BY role");
            for (var i = 0; i < r.rows.length; i++) {
                var row = r.rows.item(i);
                stats.byRole[row.role] = row.n;
            }

            if (stats.messages > 0) {
                var ext = tx.executeSql(
                    "SELECT MIN(created_at) AS oldest, MAX(created_at) AS newest FROM messages");
                stats.oldestMs = ext.rows.item(0).oldest || 0;
                stats.newestMs = ext.rows.item(0).newest || 0;
            }
        });
    } catch (e) {
        stats.error = String(e.message || e);
    }
    return stats;
}

// ---- formatting helpers ----
function humanBytes(n) {
    if (!n || n <= 0) return "—";
    var units = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
    return (i === 0 ? n.toFixed(0) : n.toFixed(1)) + " " + units[i];
}

function humanDate(ms) {
    if (!ms || ms <= 0) return "—";
    var d = new Date(ms);
    return d.toISOString().substring(0, 10);
}
