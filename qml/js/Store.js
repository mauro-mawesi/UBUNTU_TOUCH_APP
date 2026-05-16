.pragma library
.import QtQuick.LocalStorage 2.0 as LS

var DB_NAME = "ragassistant";
var DB_DESC = "RAG Assistant local database";
var DB_VERSION = "1.0";
var DB_SIZE = 5 * 1024 * 1024;

function _db() {
    return LS.LocalStorage.openDatabaseSync(DB_NAME, DB_VERSION, DB_DESC, DB_SIZE);
}

function init() {
    _db().transaction(function(tx) {
        tx.executeSql(
            "CREATE TABLE IF NOT EXISTS conversations (" +
            "  id INTEGER PRIMARY KEY AUTOINCREMENT," +
            "  title TEXT NOT NULL DEFAULT ''," +
            "  collection_id TEXT NOT NULL DEFAULT ''," +
            "  created_at INTEGER NOT NULL," +
            "  updated_at INTEGER NOT NULL" +
            ")"
        );
        tx.executeSql(
            "CREATE TABLE IF NOT EXISTS messages (" +
            "  id INTEGER PRIMARY KEY AUTOINCREMENT," +
            "  conversation_id INTEGER NOT NULL," +
            "  role TEXT NOT NULL," +
            "  content TEXT NOT NULL DEFAULT ''," +
            "  sources TEXT NOT NULL DEFAULT '[]'," +
            "  created_at INTEGER NOT NULL" +
            ")"
        );
        tx.executeSql("CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id, id)");
    });
}

function listConversations() {
    var rows = [];
    _db().readTransaction(function(tx) {
        var rs = tx.executeSql(
            "SELECT c.id, c.title, c.collection_id, c.created_at, c.updated_at," +
            " (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id) AS message_count," +
            " (SELECT content FROM messages m WHERE m.conversation_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_message" +
            " FROM conversations c ORDER BY c.updated_at DESC"
        );
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i);
            rows.push({
                id: r.id,
                title: r.title,
                collectionId: r.collection_id,
                createdAt: r.created_at,
                updatedAt: r.updated_at,
                messageCount: r.message_count,
                lastMessage: r.last_message || ""
            });
        }
    });
    return rows;
}

function createConversation(title, collectionId) {
    var id = -1;
    var now = Date.now();
    _db().transaction(function(tx) {
        var r = tx.executeSql(
            "INSERT INTO conversations(title, collection_id, created_at, updated_at) VALUES (?,?,?,?)",
            [title || "", collectionId || "", now, now]
        );
        id = r.insertId;
    });
    return id;
}

function renameConversation(id, title) {
    _db().transaction(function(tx) {
        tx.executeSql("UPDATE conversations SET title = ?, updated_at = ? WHERE id = ?",
                      [title, Date.now(), id]);
    });
}

function deleteConversation(id) {
    _db().transaction(function(tx) {
        tx.executeSql("DELETE FROM messages WHERE conversation_id = ?", [id]);
        tx.executeSql("DELETE FROM conversations WHERE id = ?", [id]);
    });
}

function touchConversation(id) {
    _db().transaction(function(tx) {
        tx.executeSql("UPDATE conversations SET updated_at = ? WHERE id = ?", [Date.now(), id]);
    });
}

function _normalizeSources(s) {
    return (s && typeof s === "object" && s.length !== undefined) ? s : [];
}

function getMessages(convId) {
    var rows = [];
    _db().readTransaction(function(tx) {
        var rs = tx.executeSql(
            "SELECT id, role, content, sources, created_at FROM messages" +
            " WHERE conversation_id = ? ORDER BY id ASC", [convId]
        );
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i);
            var sources = [];
            try {
                var parsed = JSON.parse(r.sources || "[]");
                sources = _normalizeSources(parsed);
            } catch (e) {}
            rows.push({
                id: r.id,
                role: r.role,
                content: r.content,
                sources: sources,
                createdAt: r.created_at
            });
        }
    });
    return rows;
}

function addMessage(convId, role, content, sources) {
    var id = -1;
    var now = Date.now();
    _db().transaction(function(tx) {
        var r = tx.executeSql(
            "INSERT INTO messages(conversation_id, role, content, sources, created_at)" +
            " VALUES (?,?,?,?,?)",
            [convId, role, content || "", JSON.stringify(_normalizeSources(sources)), now]
        );
        id = r.insertId;
        tx.executeSql("UPDATE conversations SET updated_at = ? WHERE id = ?", [now, convId]);
    });
    return id;
}

function updateMessage(msgId, content, sources) {
    _db().transaction(function(tx) {
        if (sources !== undefined) {
            tx.executeSql("UPDATE messages SET content = ?, sources = ? WHERE id = ?",
                          [content, JSON.stringify(_normalizeSources(sources)), msgId]);
        } else {
            tx.executeSql("UPDATE messages SET content = ? WHERE id = ?", [content, msgId]);
        }
    });
}

function deleteMessage(msgId) {
    _db().transaction(function(tx) {
        tx.executeSql("DELETE FROM messages WHERE id = ?", [msgId]);
    });
}

function deriveTitle(text) {
    var t = (text || "").replace(/\s+/g, " ").trim();
    if (t.length > 60) t = t.substring(0, 57) + "…";
    return t || "Untitled";
}
