import QtQuick 2.7

// Drop-in MouseArea replacement that adds a subtle press-scale feedback
// on the parent item. Usage:
//
//   Rectangle { ...; PressEffect { onClicked: doX() } }
//
// The parent's `scale` is animated to `pressedScale` on press and back to
// 1.0 on release — no Behavior declaration needed on the caller side.
MouseArea {
    id: fx
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    property real pressedScale: 0.97
    property int  animDuration: 90

    NumberAnimation {
        id: scaleAnim
        target: fx.parent
        property: "scale"
        duration: fx.animDuration
        easing.type: Easing.OutCubic
    }

    onPressed: { scaleAnim.to = pressedScale; scaleAnim.restart(); }
    onReleased: { scaleAnim.to = 1.0; scaleAnim.restart(); }
    onCanceled: { scaleAnim.to = 1.0; scaleAnim.restart(); }
}
