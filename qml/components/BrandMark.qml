import QtQuick 2.7
import Lomiri.Components 1.3

// Brand glyph used in splash, sidebar header, empty state, assistant avatar.
// Renders the ✦ inside a gradient disc with a soft inner highlight; the
// outer ring gives the splash treatment.
Item {
    id: root
    property var appTheme
    property real size: units.gu(4)
    property bool withRing: false
    property color textColor: "white"

    width: size
    height: size

    Rectangle {
        id: ring
        visible: root.withRing
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: width / 2
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.35)
        border.width: 1
    }

    Rectangle {
        id: disc
        anchors.centerIn: parent
        width:  parent.width  * (root.withRing ? 0.88 : 1.0)
        height: parent.height * (root.withRing ? 0.88 : 1.0)
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.appTheme ? root.appTheme.primary   : "#6366f1" }
            GradientStop { position: 1.0; color: root.appTheme ? root.appTheme.secondary : "#8b5cf6" }
        }

        // Top-left "specular" highlight to fake 3D depth.
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: parent.width * 0.10
            anchors.topMargin: parent.height * 0.10
            width: parent.width * 0.35
            height: parent.height * 0.18
            radius: height
            color: Qt.rgba(1, 1, 1, 0.22)
            rotation: -20
        }

        // Subtle inner edge highlight.
        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.width * 0.06
            radius: width / 2
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
        }

        Label {
            anchors.centerIn: parent
            text: "✦"
            color: root.textColor
            font.pixelSize: disc.width * 0.6
        }

    }
}
