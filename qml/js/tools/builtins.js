.pragma library

// All builtins follow the same shape:
//   fn(argsObject, callback) -> callback(resultObject)
// On failure: callback({ error: "human readable message" }).

function getCurrentTime(args, cb, ctx) {
    var tz = (args && args.timezone) ? String(args.timezone) : "UTC";

    // Qt 5.12's V4 engine ignores the `timeZone` option of toLocaleString and
    // silently uses the system timezone, which made "what time is it in Tokyo?"
    // return the user's local time. Delegate to the C++ TimeUtil helper which
    // uses QTimeZone (full IANA support).
    if (ctx && ctx.timeUtil && typeof ctx.timeUtil.nowInTimezone === "function") {
        var res = ctx.timeUtil.nowInTimezone(tz);
        if (res && res.error) { cb({ error: res.error }); return; }
        cb(res);
        return;
    }

    // Fallback path (no TimeUtil wired): return UTC only so we never lie about
    // the timezone the way toLocaleString would.
    var now = new Date();
    if (tz !== "UTC") {
        cb({ error: "Timezone support unavailable in this build (TimeUtil not registered). " +
                    "Only UTC is reliable here." });
        return;
    }
    cb({
        iso: now.toISOString(),
        unix_ms: now.getTime(),
        timezone: "UTC",
        local: now.toISOString().replace("T", " ").substring(0, 19) + " UTC"
    });
}

// Sandboxed math expression evaluator. Allows digits, operators, parentheses,
// dots, commas, whitespace, and a whitelist of Math.* functions plus pi/e.
// Anything outside the whitelist is rejected before evaluation.
//
// Defense in depth: the identifier whitelist below already rejects __proto__,
// constructor, etc. by name, but we also (1) drop underscore from the char
// allow-list so suspicious identifiers fail the cheap regex first, (2) cap
// expression length to prevent DoS via huge expressions, and (3) explicitly
// reject a list of dangerous names before the whitelist check just in case
// the allow-list is broadened later.
function calculator(args, cb) {
    var expr = (args && args.expression) ? String(args.expression) : "";
    if (expr.length === 0) { cb({ error: "expression is required" }); return; }
    if (expr.length > 200) { cb({ error: "expression too long (max 200 chars)" }); return; }

    if (!/^[\d\s+\-*\/%().,a-zA-Z]+$/.test(expr)) {
        cb({ error: "expression contains disallowed characters" });
        return;
    }

    var DENY = /\b(constructor|prototype|__proto__|__defineGetter__|__defineSetter__|Function|eval|globalThis|window|self|this)\b/;
    if (DENY.test(expr)) {
        cb({ error: "expression contains a forbidden identifier" });
        return;
    }

    var allowed = [
        "abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "exp",
        "floor", "log", "max", "min", "pow", "round", "sin", "sqrt", "tan"
    ];

    var transformed;
    try {
        transformed = expr.replace(/[a-zA-Z]+/g, function(name) {
            var lc = name.toLowerCase();
            if (lc === "pi") return "Math.PI";
            if (lc === "e")  return "Math.E";
            if (allowed.indexOf(lc) >= 0) return "Math." + lc;
            throw new Error("disallowed identifier: " + name);
        });
    } catch (e) {
        cb({ error: String(e.message || e) });
        return;
    }

    try {
        var f = new Function("return (" + transformed + ");");
        var result = f();
        if (typeof result !== "number" || isNaN(result) || !isFinite(result)) {
            cb({ error: "result is not a finite number" });
            return;
        }
        cb({ expression: expr, result: result });
    } catch (e) {
        cb({ error: String(e.message || e) });
    }
}
