import QtQuick 2.7
import Lomiri.Components 1.3

Row {
    id: indicator
    spacing: units.gu(0.6)
    property color dotColor: Qt.rgba(1, 1, 1, 0.65)
    property real dotSize: units.gu(0.9)
    property real waveAmplitude: units.gu(0.7)
    property int dotCount: 3
    property int waveDuration: 280
    property int waveStagger: 140

    height: dotSize + waveAmplitude * 2

    Repeater {
        model: indicator.dotCount

        delegate: Item {
            width: indicator.dotSize
            height: indicator.height

            Rectangle {
                id: dot
                width: indicator.dotSize
                height: indicator.dotSize
                radius: width / 2
                color: indicator.dotColor
                anchors.centerIn: parent
                opacity: 0.35

                transform: Translate { id: tr; y: 0 }

                // Vertical wave
                SequentialAnimation {
                    loops: Animation.Infinite
                    running: indicator.visible
                    PauseAnimation { duration: index * indicator.waveStagger }
                    NumberAnimation {
                        target: tr; property: "y"
                        to: -indicator.waveAmplitude
                        duration: indicator.waveDuration
                        easing.type: Easing.OutSine
                    }
                    NumberAnimation {
                        target: tr; property: "y"
                        to: 0
                        duration: indicator.waveDuration
                        easing.type: Easing.InSine
                    }
                    PauseAnimation { duration: (indicator.dotCount - index - 1) * indicator.waveStagger + 240 }
                }

                // Brightness pulse synced to vertical position
                SequentialAnimation {
                    loops: Animation.Infinite
                    running: indicator.visible
                    PauseAnimation { duration: index * indicator.waveStagger }
                    NumberAnimation {
                        target: dot; property: "opacity"
                        to: 1.0
                        duration: indicator.waveDuration
                        easing.type: Easing.OutSine
                    }
                    NumberAnimation {
                        target: dot; property: "opacity"
                        to: 0.35
                        duration: indicator.waveDuration
                        easing.type: Easing.InSine
                    }
                    PauseAnimation { duration: (indicator.dotCount - index - 1) * indicator.waveStagger + 240 }
                }
            }
        }
    }
}
