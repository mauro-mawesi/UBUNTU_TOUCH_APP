import QtQuick 2.7
import QtGraphicalEffects 1.0
import Lomiri.Components 1.3

// Label whose text comes from `i18nApp.tr(key)` and animates a blur+fade
// transition every time `i18nApp.language` changes. Pass `staggerIndex`
// to space animations across labels (or leave at -1 to auto-claim one
// from i18nApp.nextStaggerIndex()).
//
// Visually: old text fades out while a blur radius ramps up → text swaps
// invisibly at the apex → new text fades back in while blur ramps down.
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
    property int staggerIndex: -1     // -1 = auto-assigned from i18nApp
    property int staggerStep: 45      // ms per index
    property real maxBlur: 6
    property int outDur: 140
    property int inDur: 240

    property string _displayed: ""
    property int _stagger: 0

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
        // FastBlur needs the source as a texture; layer.enabled only while
        // we're actually animating so the rest of the time we render the
        // Label directly (no texture overhead).
        layer.enabled: blur.radius > 0.01
    }

    FastBlur {
        id: blur
        anchors.fill: textItem
        source: textItem
        radius: 0
        visible: radius > 0.01
        cached: false
    }

    Connections {
        target: root.i18nApp
        ignoreUnknownSignals: true
        onLanguageChanged: delayTimer.restart()
    }

    Timer {
        id: delayTimer
        interval: root._stagger * root.staggerStep
        repeat: false
        onTriggered: anim.start()
    }

    SequentialAnimation {
        id: anim
        ParallelAnimation {
            NumberAnimation {
                target: blur; property: "radius"
                from: 0; to: root.maxBlur
                duration: root.outDur
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: textItem; property: "opacity"
                from: 1; to: 0
                duration: root.outDur
                easing.type: Easing.OutQuad
            }
        }
        ScriptAction {
            script: {
                root._displayed = root.i18nApp ? root.i18nApp.tr(root.key) : root.key;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: blur; property: "radius"
                from: root.maxBlur; to: 0
                duration: root.inDur
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: textItem; property: "opacity"
                from: 0; to: 1
                duration: root.inDur
                easing.type: Easing.OutCubic
            }
        }
    }
}
