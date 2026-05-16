import QtQuick 2.7
import Lomiri.Components 1.3

// Label whose text comes from `i18nApp.tr(key)` and animates a Solari /
// split-flap "char roll" transition every time `i18nApp.language` changes.
// Each character index ticks through random glyphs before settling on its
// final letter, staggered left-to-right so longer phrases cascade like an
// airport departure board.
//
// API kept compatible with the previous blur+fade implementation:
//   key, i18nApp, color, fontPixelSize, bold, wrapMode, elide,
//   horizontalAlignment, staggerIndex (label-level extra delay).
Item {
    id: root

    property var i18nApp
    property string key: ""

    // Label-like passthroughs (kept minimal).
    property color color: "black"
    property real fontPixelSize: units.gu(1.6)
    property bool bold: false
    property int wrapMode: Text.NoWrap
    property int elide: Text.ElideNone
    property int horizontalAlignment: Text.AlignLeft

    // Transition tuning.
    property int staggerIndex: -1     // -1 = auto-claim from i18nApp
    property int staggerStep: 45      // ms between each label starting

    // Per-character roll parameters. Total animation length ≈
    // charStagger * len + rollDuration. Tick interval controls how often a
    // rolling char is randomized — small enough to feel "alive", large
    // enough that the label doesn't thrash.
    property int charStagger: 35
    property int rollDuration: 260
    property int tickInterval: 55

    // Glyph alphabet used while rolling. Mixed-case + digits keeps the
    // texture "noisy" without dragging in non-renderable codepoints. Pure
    // ASCII so it works in every locale.
    readonly property string _alphabet:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
        "abcdefghijklmnopqrstuvwxyz" +
        "0123456789"

    property string _displayed: ""
    property int _stagger: 0

    // Animation state. _animOld / _animNew hold the strings we're morphing
    // between; _animStart is the wall-clock ms when this label's roll
    // actually begins (already past the label-level stagger).
    property string _animOld: ""
    property string _animNew: ""
    property real _animStart: 0

    implicitWidth: textItem.implicitWidth
    implicitHeight: textItem.implicitHeight

    Component.onCompleted: {
        _displayed = i18nApp ? i18nApp.tr(key) : key;
        _stagger = staggerIndex >= 0
                   ? staggerIndex
                   : (i18nApp && i18nApp.nextStaggerIndex
                      ? i18nApp.nextStaggerIndex()
                      : 0);
    }

    Label {
        id: textItem
        anchors.fill: parent
        text: root._displayed
        color: root.color
        font.pixelSize: root.fontPixelSize
        font.bold: root.bold
        wrapMode: root.wrapMode
        elide: root.elide
        horizontalAlignment: root.horizontalAlignment
    }

    Connections {
        target: root.i18nApp
        ignoreUnknownSignals: true
        onLanguageChanged: root._scheduleFlip()
    }

    function _randChar() {
        var a = _alphabet;
        return a.charAt(Math.floor(Math.random() * a.length));
    }

    function _scheduleFlip() {
        if (!i18nApp) return;
        var next = i18nApp.tr(key);
        if (next === _displayed) return;
        _animOld = _displayed;
        _animNew = next;
        // Label-level stagger (lets multiple labels start in sequence).
        delayTimer.interval = _stagger * staggerStep;
        delayTimer.restart();
    }

    Timer {
        id: delayTimer
        repeat: false
        onTriggered: {
            root._animStart = Date.now();
            ticker.restart();
            // Render the first frame synchronously so we never flash the
            // old text past the apex.
            root._tick();
        }
    }

    Timer {
        id: ticker
        interval: root.tickInterval
        repeat: true
        onTriggered: root._tick()
    }

    function _tick() {
        var elapsed = Date.now() - _animStart;
        var oldT = _animOld;
        var newT = _animNew;
        var len = Math.max(oldT.length, newT.length);
        var built = "";
        var done = true;
        for (var i = 0; i < len; i++) {
            var start = i * charStagger;
            var settle = start + rollDuration;
            if (elapsed >= settle) {
                // Char i has landed. Empty string = letter dropped (newT shorter).
                if (i < newT.length) built += newT.charAt(i);
            } else if (elapsed >= start) {
                // Rolling: spit out a random glyph. Preserve whitespace
                // separators in the destination so the layout stays readable
                // during the roll, even if the final char is a space.
                if (i < newT.length && newT.charAt(i) === " ") {
                    built += " ";
                } else {
                    built += _randChar();
                }
                done = false;
            } else {
                // Not yet started: keep the old glyph if available so the
                // label only changes left-to-right.
                if (i < oldT.length) built += oldT.charAt(i);
                else built += _randChar();   // edge: newT longer than oldT
                done = false;
            }
        }
        _displayed = built;
        if (done) {
            ticker.stop();
            // Final safety: snap to exact target (paranoia around float math
            // edge cases when the very last tick lands microseconds early).
            _displayed = newT;
        }
    }
}
