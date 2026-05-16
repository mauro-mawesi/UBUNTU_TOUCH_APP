import QtQuick 2.7

// Circular-reveal overlay used when switching theme mode.
// Usage: themeTransition.run(sceneX, sceneY, "light"|"dark")
//   - grabs `captureSource` to a snapshot
//   - emits `apply(mode)` so the caller switches the theme (UI redraws under the overlay)
//   - animates a growing circle that erases the snapshot, revealing the new theme
Item {
    id: root
    z: 99999
    visible: running

    property Item captureSource
    property real px: 0
    property real py: 0
    property string pendingMode: ""
    property bool running: false

    signal apply(string mode)

    function run(x, y, mode) {
        if (running || pendingMode !== "" || !captureSource) return;
        px = x;
        py = y;
        pendingMode = mode;
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
            if (status === Image.Ready && pendingMode !== "" && !revealAnim.running) {
                root.running = true;
                root.apply(pendingMode);
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
        // Concatenated single-line literals so xgettext doesn't trip on the
        // multiline string (warnings: "unterminated string") during build.
        fragmentShader:
            "uniform sampler2D src;\n" +
            "uniform highp float centerU;\n" +
            "uniform highp float centerV;\n" +
            "uniform highp float radius;\n" +
            "uniform highp float ratio;\n" +
            "uniform lowp  float qt_Opacity;\n" +
            "varying highp vec2 qt_TexCoord0;\n" +
            "void main() {\n" +
            "    highp vec2 d = vec2((qt_TexCoord0.x - centerU) * ratio,\n" +
            "                        qt_TexCoord0.y - centerV);\n" +
            "    highp float r = length(d);\n" +
            "    highp float edge = 0.004;\n" +
            "    highp float a = smoothstep(radius - edge, radius + edge, r);\n" +
            "    lowp vec4 c = texture2D(src, qt_TexCoord0);\n" +
            "    gl_FragColor = c * a * qt_Opacity;\n" +
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
            root.pendingMode = "";
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
