import QtQuick 2.7

// Old-CRT "power down + scanline glow" overlay used for accent transitions.
// The snapshot of the current UI is compressed vertically toward a thin
// bright horizontal line (TV-collapsing-to-a-dot vibe) with R/G/B vertical
// fringing, then fades out revealing the real UI below — which is already
// morphing accent colors via Behavior on AppTheme.primary/secondary.
//
// Usage:
//   crtTransition.tintColor = appTheme.presets[idx].primary;  // optional
//   crtTransition.run(idx);
//   // emits apply(idx) once the snapshot is ready, so caller can mutate state
Item {
    id: root
    z: 99999
    visible: running

    property Item captureSource
    property color tintColor: Qt.rgba(0, 0, 0, 0)

    property var _pending: null
    property bool _pendingValid: false
    property bool running: false

    signal apply(var payload)

    function run(payload) {
        if (running || _pendingValid || !captureSource) return;
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
            if (status === Image.Ready && root._pendingValid && !crtAnim.running) {
                root.running = true;
                root.apply(root._pending);
                crtAnim.start();
            }
        }
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        property variant src: snap
        property real progress: 0
        property color tintColor: root.tintColor

        // Phased CRT power-down shader:
        //   0.00 – 0.40 : vertical compression, R/G/B fringe, tint toward newColor
        //   0.40 – 0.55 : holds at fully-compressed bright scanline
        //   0.55 – 1.00 : alpha fades, area outside scanline fades to black-to-transparent
        //                 (the real UI under us is already morphing colors via AppTheme.Behavior)
        fragmentShader:
            "uniform sampler2D src;\n" +
            "uniform highp float progress;\n" +
            "uniform lowp  vec4  tintColor;\n" +
            "uniform lowp  float qt_Opacity;\n" +
            "varying highp vec2  qt_TexCoord0;\n" +
            "void main() {\n" +
            "    // 0→1 ramp of how much the picture is collapsed.\n" +
            "    highp float c;\n" +
            "    if (progress < 0.40) c = progress / 0.40;\n" +
            "    else if (progress < 0.55) c = 1.0;\n" +
            "    else c = 1.0 - (progress - 0.55) / 0.45;\n" +
            "    c = clamp(c, 0.0, 1.0);\n" +
            "    c = smoothstep(0.0, 1.0, c);\n" +
            "    \n" +
            "    highp float scale = mix(1.0, 0.04, c);\n" +
            "    highp float dy = qt_TexCoord0.y - 0.5;\n" +
            "    highp float sampleY = 0.5 + dy / scale;\n" +
            "    \n" +
            "    // Outside the squished band → black border that fades to transparent.\n" +
            "    if (sampleY < 0.0 || sampleY > 1.0) {\n" +
            "        highp float bg = 1.0 - smoothstep(0.55, 1.0, progress);\n" +
            "        gl_FragColor = vec4(0.0, 0.0, 0.0, bg * qt_Opacity);\n" +
            "        return;\n" +
            "    }\n" +
            "    \n" +
            "    // R/G/B vertical fringing — strongest at peak compression.\n" +
            "    highp float offs = c * 0.004;\n" +
            "    lowp float r = texture2D(src, vec2(qt_TexCoord0.x, clamp(sampleY - offs, 0.0, 1.0))).r;\n" +
            "    lowp float g = texture2D(src, vec2(qt_TexCoord0.x, sampleY)).g;\n" +
            "    lowp float b = texture2D(src, vec2(qt_TexCoord0.x, clamp(sampleY + offs, 0.0, 1.0))).b;\n" +
            "    lowp float a = texture2D(src, vec2(qt_TexCoord0.x, sampleY)).a;\n" +
            "    lowp vec3 col = vec3(r, g, b);\n" +
            "    \n" +
            "    // Brighten the band as it squishes.\n" +
            "    col *= 1.0 + 1.4 * c;\n" +
            "    \n" +
            "    // Crossfade old palette toward the incoming accent color while squishing.\n" +
            "    col = mix(col, tintColor.rgb, c * tintColor.a * 0.65);\n" +
            "    \n" +
            "    // Horizontal scanline glow, centered, only when collapsed.\n" +
            "    highp float line = exp(-abs(dy) * 90.0) * c * 0.55;\n" +
            "    col += vec3(line);\n" +
            "    \n" +
            "    // Final alpha — full while collapsing, fades after the bright hold.\n" +
            "    highp float alpha = a * (1.0 - smoothstep(0.55, 1.0, progress));\n" +
            "    gl_FragColor = vec4(col, alpha) * qt_Opacity;\n" +
            "}\n"
    }

    NumberAnimation {
        id: crtAnim
        target: fx
        property: "progress"
        from: 0
        to: 1
        duration: 800
        easing.type: Easing.InOutQuad
        onStopped: {
            root.running = false;
            root._pending = null;
            root._pendingValid = false;
            root.tintColor = Qt.rgba(0, 0, 0, 0);
            snap.source = "";
            fx.progress = 0;
        }
    }
}
