import QtQuick 2.7

// Circular-reveal overlay used for theme transitions (dark/light mode AND
// accent preset). Usage:
//
//   themeTransition.tintColor = appTheme.presets[idx].primary;  // optional
//   themeTransition.run(sceneX, sceneY, payload);
//
//   - `payload` is forwarded to the `apply` signal — string ("dark"/"light")
//     for mode toggles, int (preset index) for accent changes. Any var works.
//   - grabs `captureSource` to a snapshot
//   - emits `apply(payload)` so the caller mutates the underlying theme
//     (real UI repaints under the overlay)
//   - animates a growing circle that erases the snapshot; if `tintColor`
//     is non-transparent, the leading edge is highlighted with that color
//     (the "splash" effect on accent change)
Item {
    id: root
    z: 99999
    visible: running

    property Item captureSource
    property real px: 0
    property real py: 0
    // Tint applied to the wavefront. Default transparent = no tint
    // (current behavior for mode toggles). Set before `run()` and reset
    // automatically when the animation finishes.
    property color tintColor: Qt.rgba(0, 0, 0, 0)

    property var _pending: null
    property bool _pendingValid: false
    property bool running: false

    signal apply(var payload)

    function run(x, y, payload) {
        if (running || _pendingValid || !captureSource) return;
        px = x;
        py = y;
        _pending = payload;
        _pendingValid = true;
        captureSource.grabToImage(function (result) {
            snap.source = result.url;
        });
    }

    Image {
        id: snap
        anchors.fill: parent
        cache: false
        visible: false
        layer.enabled: true
        onStatusChanged: {
            if (status === Image.Ready && root._pendingValid && !revealAnim.running) {
                root.running = true;
                root.apply(root._pending);
                revealAnim.to = root._maxRadius();
                revealAnim.start();
            }
        }
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        property variant src: snap
        property real centerU: root.width  > 0 ? root.px / root.width  : 0.5
        property real centerV: root.height > 0 ? root.py / root.height : 0.5
        property real radius: 0
        property real ratio:  root.height > 0 ? root.width / root.height : 1
        property color tintColor: root.tintColor

        // Concatenated single-line literals so xgettext doesn't trip on the
        // multiline string (warnings: "unterminated string") during build.
        //
        // The shader:
        //   - alpha-erases the snapshot inside the growing circle (so the
        //     real UI below reveals through)
        //   - paints a colored ring at the leading edge of the wave when
        //     tintColor.a > 0, producing a "splash of new color" feel for
        //     accent changes
        fragmentShader:
            "uniform sampler2D src;\n" +
            "uniform highp float centerU;\n" +
            "uniform highp float centerV;\n" +
            "uniform highp float radius;\n" +
            "uniform highp float ratio;\n" +
            "uniform lowp  vec4  tintColor;\n" +
            "uniform lowp  float qt_Opacity;\n" +
            "varying highp vec2 qt_TexCoord0;\n" +
            "void main() {\n" +
            "    highp vec2 d = vec2((qt_TexCoord0.x - centerU) * ratio,\n" +
            "                        qt_TexCoord0.y - centerV);\n" +
            "    highp float r = length(d);\n" +
            "    highp float edge = 0.004;\n" +
            "    highp float a = smoothstep(radius - edge, radius + edge, r);\n" +
            "    lowp vec4 c = texture2D(src, qt_TexCoord0);\n" +
            "    lowp vec4 result = c * a;\n" +
            "    // Tint band: peaks AT the boundary, falls off ~0.06 wide.\n" +
            "    highp float band = 1.0 - smoothstep(0.0, 0.06, abs(r - radius));\n" +
            "    highp float ti = tintColor.a * band;\n" +
            "    result.rgb = mix(result.rgb, tintColor.rgb, ti);\n" +
            "    result.a   = max(result.a, ti);\n" +
            "    gl_FragColor = result * qt_Opacity;\n" +
            "}\n"
    }

    NumberAnimation {
        id: revealAnim
        target: fx
        property: "radius"
        from: 0
        duration: 500
        easing.type: Easing.OutCubic
        onStopped: {
            root.running = false;
            root._pending = null;
            root._pendingValid = false;
            root.tintColor = Qt.rgba(0, 0, 0, 0);  // reset for next run
            snap.source = "";
            fx.radius = 0;
        }
    }

    function _maxRadius() {
        var w = Math.max(root.width, 1);
        var h = Math.max(root.height, 1);
        var u = px / w;
        var v = py / h;
        var r = w / h;
        function corner(cu, cv) {
            var dx = (u - cu) * r;
            var dy = (v - cv);
            return Math.sqrt(dx * dx + dy * dy);
        }
        return Math.max(corner(0, 0), corner(1, 0),
                        corner(0, 1), corner(1, 1)) + 0.02;
    }
}
