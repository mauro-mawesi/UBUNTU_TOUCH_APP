import QtQuick 2.7
import Lomiri.Components 1.3

// Drops a brief CRT-style flicker on top of its parent every time the
// supplied appTheme's `presetIndex` changes. Two layers:
//   - a white "bright" overlay that flashes the parent
//   - a thin horizontal scanline that sweeps top → bottom
//
// Usage:
//   Rectangle { color: appTheme.primary; AccentFlicker { appTheme: appTheme } }
//
// Respects the parent's `radius` so flashes stay within rounded buttons.
Item {
    id: root
    property var appTheme

    anchors.fill: parent
    visible: bright.opacity > 0.01 || scanline.opacity > 0.01
    clip: true

    readonly property real _parentRadius: parent && parent.radius !== undefined ? parent.radius : 0

    Rectangle {
        id: bright
        anchors.fill: parent
        radius: root._parentRadius
        color: "white"
        opacity: 0
    }

    Rectangle {
        id: scanline
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(units.gu(0.2), parent ? parent.height * 0.08 : units.gu(0.4))
        y: parent ? parent.height * 0.5 - height / 2 : 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
        opacity: 0
    }

    Connections {
        target: root.appTheme
        ignoreUnknownSignals: true
        onPresetIndexChanged: if (root.visible || root.parent) flickerAnim.restart()
    }

    SequentialAnimation {
        id: flickerAnim
        ParallelAnimation {
            NumberAnimation {
                target: bright; property: "opacity"
                from: 0; to: 0.55
                duration: 90; easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: scanline; property: "opacity"
                from: 0; to: 1.0
                duration: 90
            }
            NumberAnimation {
                target: scanline; property: "y"
                from: -scanline.height
                to: (root.parent ? root.parent.height : root.height)
                duration: 320; easing.type: Easing.InOutQuad
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: bright; property: "opacity"
                to: 0; duration: 380; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: scanline; property: "opacity"
                to: 0; duration: 180
            }
        }
    }
}
