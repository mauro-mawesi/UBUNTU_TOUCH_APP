import QtQuick 2.7
import QtGraphicalEffects 1.0

// Full-screen overlay that paints a diagonal "beam of light" the colour of
// the incoming accent, sweeping TL→BR across the whole UI. The theme
// mutation is fired around mid-sweep so the band visually "deposits" the
// new accent as it passes — combined with AppTheme's color Behavior the
// switch reads as one continuous wave instead of an abrupt swap.
//
// Use:
//   accentSweep.run(presets[i].primary, presets[i].secondary);
//   accentSweep.apply.connect(function() {
//       appSettings.themePresetIndex = i;
//   });
//
// Sits below ThemeTransition (z 99999) and any popups; above page content.
Item {
    id: root
    z: 99998
    anchors.fill: parent
    visible: running

    property bool running: false
    property color c1: "white"      // edge colour (outer fade)
    property color c2: "white"      // crest colour (centre of beam)
    property int duration: 620

    signal apply()

    // Beam geometry. _diag is the screen diagonal; the beam is a slab of
    // thickness `_beamLen` (along the diagonal axis) that travels from
    // just-before-TL to just-past-BR.
    readonly property real _diag: Math.sqrt(width * width + height * height)
    readonly property real _beamLen: _diag * 0.32

    // progress is a scalar along the diagonal: when progress = -_beamLen
    // the beam is entirely off-screen above TL; when progress = _diag it
    // has fully cleared BR.
    property real progress: -_beamLen

    function run(primary, secondary) {
        if (running || width <= 0) return;
        c1 = primary;
        c2 = secondary;
        running = true;
        sweepAnim.restart();
        midpoint.restart();
    }

    LinearGradient {
        id: beam
        anchors.fill: parent
        // Project `progress` and `progress + _beamLen` along the diagonal
        // (W,H)/_diag, expressed in pixel coordinates that LinearGradient
        // expects for start/end.
        start: Qt.point(root.progress * root.width / root._diag,
                        root.progress * root.height / root._diag)
        end:   Qt.point((root.progress + root._beamLen) * root.width  / root._diag,
                        (root.progress + root._beamLen) * root.height / root._diag)
        // Stops 0.0 and 1.0 carry alpha 0 so anything outside the segment
        // (most of the screen, most of the time) renders transparent.
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(root.c1.r, root.c1.g, root.c1.b, 0.0) }
            GradientStop { position: 0.30; color: Qt.rgba(root.c1.r, root.c1.g, root.c1.b, 0.55) }
            GradientStop { position: 0.50; color: Qt.rgba(root.c2.r, root.c2.g, root.c2.b, 0.85) }
            GradientStop { position: 0.70; color: Qt.rgba(root.c1.r, root.c1.g, root.c1.b, 0.55) }
            GradientStop { position: 1.00; color: Qt.rgba(root.c1.r, root.c1.g, root.c1.b, 0.0) }
        }
    }

    NumberAnimation {
        id: sweepAnim
        target: root
        property: "progress"
        from: -root._beamLen
        to: root._diag
        duration: root.duration
        easing.type: Easing.InOutQuad
        onStopped: root.running = false
    }

    // Apply the theme mutation slightly before geometric midpoint so the
    // user reads "the bright crest paints the new colour" rather than
    // "the colour shows after the beam already passed".
    Timer {
        id: midpoint
        interval: root.duration * 0.42
        repeat: false
        onTriggered: root.apply()
    }

    // Lets touches/clicks pass through to the UI underneath while sweeping
    // — the overlay is purely visual.
    MouseArea {
        anchors.fill: parent
        enabled: false
    }
}
