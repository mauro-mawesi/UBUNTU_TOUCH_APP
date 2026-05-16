.pragma library
.import QtQuick.LocalStorage 2.0 as LS

var DB_NAME = "ragassistant";
var DB_DESC = "RAG Assistant local database";
var DB_VERSION = "1.0";
var DB_SIZE = 5 * 1024 * 1024;

function _db() {
    return LS.LocalStorage.openDatabaseSync(DB_NAME, DB_VERSION, DB_DESC, DB_SIZE);
}

// init(defaultCollectionId, defaultTopicName) — used to seed the first topic
// on a fresh install so the multi-topic feature works transparently for users
// coming from the single-collection era. defaultTopicName lets the caller pass
// a translated name (e.g. i18nApp.tr("General")).
function init(defaultCollectionId, defaultTopicName) {
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

        // icon and system_prompt_addon are nullable on purpose: QML's LocalStorage
        // param binding turns JS "" into SQL NULL, which would clash with a
        // NOT NULL constraint. Reads coerce NULL back to "".
        tx.executeSql(
            "CREATE TABLE IF NOT EXISTS topics (" +
            "  id INTEGER PRIMARY KEY AUTOINCREMENT," +
            "  name TEXT NOT NULL DEFAULT ''," +
            "  collection_id TEXT NOT NULL DEFAULT ''," +
            "  color_preset_index INTEGER NOT NULL DEFAULT 0," +
            "  icon TEXT," +
            "  system_prompt_addon TEXT," +
            "  created_at INTEGER NOT NULL," +
            "  updated_at INTEGER NOT NULL" +
            ")"
        );

        // Add topic_id to conversations if missing (SQLite has no IF NOT EXISTS on ALTER).
        try { tx.executeSql("ALTER TABLE conversations ADD COLUMN topic_id INTEGER"); }
        catch (e) { /* already exists */ }
    });

    // Seed default topic + backfill — outside the schema tx because reads happen.
    _db().transaction(function(tx) {
        var rs = tx.executeSql("SELECT COUNT(*) AS n FROM topics");
        var count = rs.rows.item(0).n;
        if (count === 0) {
            var now = Date.now();
            var seedCollection = defaultCollectionId || "";
            var seedName = defaultTopicName || "General";
            // Skip icon + system_prompt_addon: QML's LocalStorage param binding
            // turns "" into NULL, which conflicts with NOT NULL — let the
            // schema DEFAULT '' kick in instead.
            var r = tx.executeSql(
                "INSERT INTO topics(name, collection_id, color_preset_index," +
                " created_at, updated_at) VALUES (?,?,?,?,?)",
                [seedName, seedCollection, 0, now, now]
            );
            var seedId = r.insertId;
            tx.executeSql("UPDATE conversations SET topic_id = ? WHERE topic_id IS NULL", [seedId]);
        }
    });
}

function listConversations() {
    var rows = [];
    _db().readTransaction(function(tx) {
        var rs = tx.executeSql(
            "SELECT c.id, c.title, c.collection_id, c.topic_id, c.created_at, c.updated_at," +
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
                topicId: (r.topic_id === null || r.topic_id === undefined) ? -1 : r.topic_id,
                createdAt: r.created_at,
                updatedAt: r.updated_at,
                messageCount: r.message_count,
                lastMessage: r.last_message || ""
            });
        }
    });
    return rows;
}

function createConversation(title, collectionId, topicId) {
    var id = -1;
    var now = Date.now();
    _db().transaction(function(tx) {
        var r = tx.executeSql(
            "INSERT INTO conversations(title, collection_id, topic_id, created_at, updated_at) VALUES (?,?,?,?,?)",
            [title || "", collectionId || "", (topicId && topicId > 0) ? topicId : null, now, now]
        );
        id = r.insertId;
    });
    return id;
}

function setConversationTopic(convId, topicId, collectionId) {
    _db().transaction(function(tx) {
        tx.executeSql(
            "UPDATE conversations SET topic_id = ?, collection_id = ?, updated_at = ? WHERE id = ?",
            [(topicId && topicId > 0) ? topicId : null, collectionId || "", Date.now(), convId]
        );
    });
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
    var sourcesJson = JSON.stringify(_normalizeSources(sources));
    _db().transaction(function(tx) {
        // Gotcha #14: QML LocalStorage binds JS "" as SQL NULL, which violates
        // NOT NULL on `content`. Omit empty content so DEFAULT '' applies —
        // hits the assistant placeholder seeded before streaming.
        var r;
        if (content && content.length > 0) {
            r = tx.executeSql(
                "INSERT INTO messages(conversation_id, role, content, sources, created_at)" +
                " VALUES (?,?,?,?,?)",
                [convId, role, content, sourcesJson, now]
            );
        } else {
            r = tx.executeSql(
                "INSERT INTO messages(conversation_id, role, sources, created_at)" +
                " VALUES (?,?,?,?)",
                [convId, role, sourcesJson, now]
            );
        }
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

// ---------------- Topics ----------------

function _rowToTopic(r) {
    return {
        id: r.id,
        name: r.name,
        collectionId: r.collection_id,
        colorPresetIndex: r.color_preset_index,
        icon: r.icon || "",
        systemPromptAddon: r.system_prompt_addon || "",
        createdAt: r.created_at,
        updatedAt: r.updated_at
    };
}

function listTopics() {
    var rows = [];
    _db().readTransaction(function(tx) {
        var rs = tx.executeSql(
            "SELECT id, name, collection_id, color_preset_index, icon," +
            " system_prompt_addon, created_at, updated_at" +
            " FROM topics ORDER BY id ASC"
        );
        for (var i = 0; i < rs.rows.length; i++) rows.push(_rowToTopic(rs.rows.item(i)));
    });
    return rows;
}

function getTopic(id) {
    var out = null;
    _db().readTransaction(function(tx) {
        var rs = tx.executeSql(
            "SELECT id, name, collection_id, color_preset_index, icon," +
            " system_prompt_addon, created_at, updated_at" +
            " FROM topics WHERE id = ?", [id]
        );
        if (rs.rows.length > 0) out = _rowToTopic(rs.rows.item(0));
    });
    return out;
}

function createTopic(fields) {
    var id = -1;
    var now = Date.now();
    _db().transaction(function(tx) {
        var r = tx.executeSql(
            "INSERT INTO topics(name, collection_id, color_preset_index, icon," +
            " system_prompt_addon, created_at, updated_at) VALUES (?,?,?,?,?,?,?)",
            [fields.name || "",
             fields.collectionId || "",
             (fields.colorPresetIndex >= 0) ? fields.colorPresetIndex : 0,
             fields.icon || "",
             fields.systemPromptAddon || "",
             now, now]
        );
        id = r.insertId;
    });
    return id;
}

function updateTopic(id, fields) {
    _db().transaction(function(tx) {
        tx.executeSql(
            "UPDATE topics SET name = ?, collection_id = ?, color_preset_index = ?," +
            " icon = ?, system_prompt_addon = ?, updated_at = ? WHERE id = ?",
            [fields.name || "",
             fields.collectionId || "",
             (fields.colorPresetIndex >= 0) ? fields.colorPresetIndex : 0,
             fields.icon || "",
             fields.systemPromptAddon || "",
             Date.now(), id]
        );
    });
}

function deleteTopic(id) {
    // Detach any conversations pinned to this topic; they become "Auto" again.
    _db().transaction(function(tx) {
        tx.executeSql("UPDATE conversations SET topic_id = NULL WHERE topic_id = ?", [id]);
        tx.executeSql("DELETE FROM topics WHERE id = ?", [id]);
    });
}
