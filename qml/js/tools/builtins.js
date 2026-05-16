.pragma library

// All builtins follow the same shape:
//   fn(argsObject, callback) -> callback(resultObject)
// On failure: callback({ error: "human readable message" }).

function getCurrentTime(args, cb) {
    var tz = (args && args.timezone) ? String(args.timezone) : "UTC";
    var now = new Date();
    var iso = now.toISOString();
    var local;
    try {
        local = now.toLocaleString("en-US", { timeZone: tz });
    } catch (e) {
        cb({ error: "Invalid timezone: " + tz });
        return;
    }
    cb({
        iso: iso,
        unix_ms: now.getTime(),
        timezone: tz,
        local: local
    });
}

// Sandboxed math expression evaluator. Allows digits, operators, parentheses,
// dots, commas, whitespace, and a whitelist of Math.* functions plus pi/e.
// Anything outside the whitelist is rejected before evaluation.
function calculator(args, cb) {
    var expr = (args && args.expression) ? String(args.expression) : "";
    if (expr.length === 0) { cb({ error: "expression is required" }); return; }

    if (!/^[\d\s+\-*\/%().,a-zA-Z_]+$/.test(expr)) {
        cb({ error: "expression contains disallowed characters" });
        return;
    }

    var allowed = [
        "abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "exp",
        "floor", "log", "max", "min", "pow", "round", "sin", "sqrt", "tan"
    ];

    var transformed;
    try {
        transformed = expr.replace(/[a-zA-Z_]+/g, function(name) {
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
