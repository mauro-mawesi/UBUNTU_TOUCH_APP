import QtQuick 2.7
import Lomiri.Components 1.3

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

    // Animated color morph: changing presetIndex re-evaluates the bindings
    // below, and the Behavior on each interpolates from the old color to
    // the new one. Every downstream property derived from primary/secondary
    // (chipBg, bubbleAssistant, gradients, etc.) inherits the animation
    // for free via binding re-evaluation.
    property color _primaryAnim:   presets[presetIndex].primary
    property color _secondaryAnim: presets[presetIndex].secondary
    Behavior on _primaryAnim   { ColorAnimation { duration: 520; easing.type: Easing.InOutCubic } }
    Behavior on _secondaryAnim { ColorAnimation { duration: 520; easing.type: Easing.InOutCubic } }

    readonly property color primary:   _primaryAnim
    readonly property color secondary: _secondaryAnim

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
    readonly property string border:        isDark ? "#262e3d" : "#cdd3e0"
    readonly property string borderStrong:  isDark ? "#323b4d" : "#b3bccd"
    readonly property string borderFocus:   primary

    // ---- text ----
    readonly property string text:          isDark ? "#e6edf3" : "#0f172a"
    readonly property string textSecondary: isDark ? "#9ba3af" : "#475569"
    readonly property string textMuted:     isDark ? "#8b95a4" : "#64748b"
    readonly property string textOnPrimary: "#ffffff"

    // ---- semantic ----
    readonly property string danger:  "#dc2626"
    readonly property string warning: isDark ? "#fbbf24" : "#d97706"
    readonly property string success: isDark ? "#10b981" : "#059669"
    readonly property string info:    isDark ? "#60a5fa" : "#3b82f6"
    readonly property color  selectionBg: withAlpha(primary, 0.20)

    // ---- bubbles ----
    readonly property string bubbleAssistantBg:     isDark ? "#1a2030" : "#ffffff"
    readonly property string bubbleAssistantBorder: isDark ? "#262e3d" : "#dde1ec"
    readonly property string bubbleAssistantText:   text
    readonly property string bubbleUserText:        "#ffffff"
    readonly property string bubbleSystemBg:        isDark ? "#3a2a1a" : "#fef3c7"
    readonly property string bubbleSystemBorder:    isDark ? "#7a4a1f" : "#f59e0b"
    readonly property string bubbleSystemText:      isDark ? "#fbbf24" : "#92400e"

    // ---- markdown / chips ----
    readonly property string codeBg:   isDark ? "#13192a" : "#eef0f7"
    readonly property string codeText: isDark ? "#e6edf3" : "#0f172a"
    readonly property string linkColor: isDark ? "#a5b4fc" : "#4f46e5"
    readonly property color  chipBg:    withAlpha(primary, isDark ? 0.22 : 0.16)
    readonly property color  chipBorder: withAlpha(primary, isDark ? 0.40 : 0.30)
    readonly property string chipText:   isDark ? lighten(primary, 0.45) : darken(primary, 0.15)

    // ---- type scale ----
    // Sizes are pixel sizes (real). Use as `font.pixelSize: appTheme.type.bodySize`.
    // Pesos van separados para emparejar con Font.Weight.
    readonly property var type: ({
        displaySize:  units.gu(3.2),  displayWeight: Font.DemiBold,
        h1Size:       units.gu(2.4),  h1Weight:      Font.DemiBold,
        h2Size:       units.gu(1.9),  h2Weight:      Font.Medium,
        bodySize:     units.gu(1.6),  bodyWeight:    Font.Normal,
        captionSize:  units.gu(1.3),  captionWeight: Font.Normal,
        mono:        "Ubuntu Mono"
    })

    // ---- radii ----
    readonly property real radiusSm:   units.gu(0.6)
    readonly property real radiusMd:   units.gu(1.0)
    readonly property real radiusLg:   units.gu(1.5)
    readonly property real radiusPill: units.gu(99)

    // ---- elevation ----
    // Values consumed by RectangularGlow (QtGraphicalEffects). Use:
    //   RectangularGlow { glowRadius: appTheme.elev1.blur; color: appTheme.elev1.color; ... }
    readonly property var elev1: ({
        color:  isDark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(15/255, 23/255, 42/255, 0.10),
        blur:   units.gu(0.8),
        spread: 0.10
    })
    readonly property var elev2: ({
        color:  isDark ? Qt.rgba(0, 0, 0, 0.60) : Qt.rgba(15/255, 23/255, 42/255, 0.16),
        blur:   units.gu(1.6),
        spread: 0.15
    })

    // Accepts either a "#rrggbb" hex string OR a QColor (from animated
    // properties like primary/secondary). Returns a Qt color with `a` alpha.
    function withAlpha(c, a) {
        var col = (typeof c === "string") ? Qt.color(c) : c;
        if (!col) return Qt.rgba(0, 0, 0, a);
        return Qt.rgba(col.r, col.g, col.b, a);
    }

    function lighten(c, t) {
        var col = (typeof c === "string") ? Qt.color(c) : c;
        if (!col) return c;
        return Qt.rgba(col.r + (1 - col.r) * t,
                       col.g + (1 - col.g) * t,
                       col.b + (1 - col.b) * t, 1);
    }

    function darken(c, t) {
        var col = (typeof c === "string") ? Qt.color(c) : c;
        if (!col) return c;
        return Qt.rgba(col.r * (1 - t),
                       col.g * (1 - t),
                       col.b * (1 - t), 1);
    }
}
