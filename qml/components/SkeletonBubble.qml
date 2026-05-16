import QtQuick 2.7
import Lomiri.Components 1.3

// Placeholder bubble shown briefly while a conversation is loading from
// storage. Cheap shimmer effect built with a translating gradient — no
// QtGraphicalEffects dependency required.
Rectangle {
    id: root
    property var appTheme
    property real bubbleWidth: units.gu(28)

    radius: units.gu(1.8)
    color: appTheme ? appTheme.surfaceAlt : "#1c2230"
    border.color: appTheme ? appTheme.border : "#262e3d"
    border.width: 1
    implicitWidth: bubbleWidth
    implicitHeight: units.gu(6.4)
    clip: true

    Rectangle {
        id: shimmer
        height: parent.height
        width: parent.width * 0.4
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.07) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        NumberAnimation on x {
            from: -shimmer.width
            to: root.width
            duration: 1200
            loops: Animation.Infinite
            running: root.visible
        }
    }
}
