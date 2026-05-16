import QtQuick 2.7

QtObject {
    id: theme

    // ---- configurable ----
    property string mode: "dark"      // "dark" | "light"
    property int presetIndex: 0       // index into `presets`

    // ---- presets ----
    readonly property var presets: [
        { name: "Indigo",  primary: "#6366f1", secondary: "#8b5cf6" },
        { name: "Cyan",    primary: "#0ea5e9", secondary: "#06b6d4" },
        { name: "Emerald", primary: "#10b981", secondary: "#14b8a6" },
        { name: "Violet",  primary: "#a855f7", secondary: "#d946ef" },
        { name: "Rose",    primary: "#ec4899", secondary: "#f43f5e" },
        { name: "Sunset",  primary: "#f97316", secondary: "#ef4444" }
    ]

    readonly property bool isDark: mode === "dark"
    readonly property string primary:   presets[presetIndex].primary
    readonly property string secondary: presets[presetIndex].secondary

    // ---- backgrounds ----
    readonly property string bg:               isDark ? "#0b0f17" : "#f6f7fb"
    readonly property string bgGradientStart:  isDark ? "#0b0f17" : "#f6f7fb"
    readonly property string bgGradientMid:    isDark ? "#0e131f" : "#eef0fa"
    readonly property string bgGradientEnd:    isDark ? "#141a28" : "#e7eaf6"
    readonly property string bgAccent:         withAlpha(primary, isDark ? 0.08 : 0.06)

    // ---- surfaces ----
    readonly property string surface:        isDark ? "#161b26" : "#ffffff"
    readonly property string surfaceAlt:     isDark ? "#1c2230" : "#f1f3f9"
    readonly property string surfaceHover:   isDark ? "#222a3a" : "#e8ecf3"
    readonly property string surfaceElevated: isDark ? "#1a2030" : "#fafbff"

    // ---- borders ----
    readonly property string border:        isDark ? "#262e3d" : "#dde1ec"
    readonly property string borderStrong:  isDark ? "#323b4d" : "#c7cdda"
    readonly property string borderFocus:   primary

    // ---- text ----
    readonly property string text:          isDark ? "#e6edf3" : "#0f172a"
    readonly property string textSecondary: isDark ? "#9ba3af" : "#475569"
    readonly property string textMuted:     isDark ? "#6b7280" : "#94a3b8"
    readonly property string textOnPrimary: "#ffffff"

    // ---- semantic ----
    readonly property string danger:  "#dc2626"
    readonly property string warning: isDark ? "#fbbf24" : "#d97706"
    readonly property string success: isDark ? "#10b981" : "#059669"

    // ---- bubbles ----
    readonly property string bubbleAssistantBg:     isDark ? "#1a2030" : "#ffffff"
    readonly property string bubbleAssistantBorder: isDark ? "#262e3d" : "#dde1ec"
    readonly property string bubbleAssistantText:   text
    readonly property string bubbleUserText:        "#ffffff"
    readonly property string bubbleSystemBg:        isDark ? "#3a2a1a" : "#fef3c7"
    readonly property string bubbleSystemBorder:    isDark ? "#7a4a1f" : "#f59e0b"
    readonly property string bubbleSystemText:      isDark ? "#fbbf24" : "#92400e"

    // ---- markdown / chips ----
    readonly property string codeBg:   isDark ? "#0b0f17" : "#eef0f7"
    readonly property string codeText: isDark ? "#e6edf3" : "#0f172a"
    readonly property string linkColor: isDark ? "#a5b4fc" : "#4f46e5"
    readonly property string chipBg:    withAlpha(primary, isDark ? 0.16 : 0.10)
    readonly property string chipBorder: withAlpha(primary, isDark ? 0.40 : 0.30)
    readonly property string chipText:   isDark ? lighten(primary, 0.45) : darken(primary, 0.15)

    function withAlpha(hex, a) {
        if (!hex || hex.length < 7) return Qt.rgba(0, 0, 0, a);
        var r = parseInt(hex.substring(1, 3), 16) / 255;
        var g = parseInt(hex.substring(3, 5), 16) / 255;
        var b = parseInt(hex.substring(5, 7), 16) / 255;
        return Qt.rgba(r, g, b, a);
    }

    function _comp(v, t) { return Math.round((v + (1 - v) * t) * 255); }
    function _compD(v, t) { return Math.round(v * (1 - t) * 255); }

    function lighten(hex, t) {
        if (!hex || hex.length < 7) return hex;
        var r = parseInt(hex.substring(1, 3), 16) / 255;
        var g = parseInt(hex.substring(3, 5), 16) / 255;
        var b = parseInt(hex.substring(5, 7), 16) / 255;
        return Qt.rgba(r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t, 1);
    }

    function darken(hex, t) {
        if (!hex || hex.length < 7) return hex;
        var r = parseInt(hex.substring(1, 3), 16) / 255;
        var g = parseInt(hex.substring(3, 5), 16) / 255;
        var b = parseInt(hex.substring(5, 7), 16) / 255;
        return Qt.rgba(r * (1 - t), g * (1 - t), b * (1 - t), 1);
    }
}
