.pragma library
.import "builtins.js" as Builtins

// Schemas in OpenAI's tools format. OpenRouter passes these to the underlying
// model verbatim (Gemini 2.5 Pro understands them natively).
var SCHEMAS = [
    {
        type: "function",
        function: {
            name: "get_current_time",
            description: "Returns the current date and time in ISO 8601 format. " +
                         "Optionally formats it in a specific IANA timezone " +
                         "(e.g. UTC, America/Bogota, Europe/Madrid).",
            parameters: {
                type: "object",
                properties: {
                    timezone: {
                        type: "string",
                        description: "IANA timezone name. Defaults to UTC if omitted."
                    }
                }
            }
        }
    },
    {
        type: "function",
        function: {
            name: "calculator",
            description: "Evaluates a numeric expression and returns the result. " +
                         "Supports +, -, *, /, %, parentheses, the constants pi and e, " +
                         "and Math functions: abs, acos, asin, atan, atan2, ceil, cos, " +
                         "exp, floor, log, max, min, pow, round, sin, sqrt, tan. " +
                         "Use this instead of doing arithmetic in your head.",
            parameters: {
                type: "object",
                properties: {
                    expression: {
                        type: "string",
                        description: "Math expression to evaluate, e.g. '2 + 2 * sin(pi/3)'."
                    }
                },
                required: ["expression"]
            }
        }
    }
];

var EXECUTORS = {
    "get_current_time": Builtins.getCurrentTime,
    "calculator": Builtins.calculator
};

// Runtime context injected from QML so .pragma library executors can reach
// C++-backed helpers (e.g. TimeUtil for IANA timezone math). Set once at
// startup via setContext({ timeUtil: ... }).
var _ctx = {};

function setContext(ctx) { _ctx = ctx || {}; }

function getAll() { return SCHEMAS; }

function execute(name, args, cb) {
    var fn = EXECUTORS[name];
    if (!fn) { cb({ error: "Unknown tool: " + name }); return; }
    try { fn(args || {}, cb, _ctx); }
    catch (e) { cb({ error: String(e.message || e) }); }
}
