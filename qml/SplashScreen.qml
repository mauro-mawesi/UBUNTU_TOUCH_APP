import QtQuick 2.7
import Lomiri.Components 1.3

Item {
    id: splash
    property var appTheme
    property var i18nApp
    // Set this to true from outside once the app has finished its initial
    // work. The splash still respects minVisibleMs so it never flashes by.
    property bool ready: false
    property int minVisibleMs: 900
    signal finished()

    z: 1000

    property bool _dismissing: false
    property double _bornAt: 0

    Component.onCompleted: {
        _bornAt = Date.now();
        introAnim.start();
    }

    onReadyChanged: _maybeDismiss()

    function _maybeDismiss() {
        if (!ready || _dismissing) return;
        var elapsed = Date.now() - _bornAt;
        if (elapsed >= minVisibleMs) {
            _dismiss();
        } else {
            holdTimer.interval = minVisibleMs - elapsed;
            holdTimer.start();
        }
    }

    function _dismiss() {
        if (_dismissing) return;
        _dismissing = true;
        outroAnim.start();
    }

    Timer {
        id: holdTimer
        repeat: false
        onTriggered: splash._dismiss()
    }

    // ---- background gradient ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: appTheme ? appTheme.bgGradientStart : "#0b0f17" }
            GradientStop { position: 0.6; color: appTheme ? appTheme.primary : "#6366f1" }
            GradientStop { position: 1.0; color: appTheme ? appTheme.secondary : "#8b5cf6" }
        }
    }
    // soft darkening for legibility on light themes
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.16)
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: 0

        // ---- pulsing halo rings (behind logo) ----
        Item {
            id: haloAnchor
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -units.gu(4)
            width: units.gu(11); height: width

            Repeater {
                model: 2
                Rectangle {
                    anchors.centerIn: parent
                    width: haloAnchor.width
                    height: haloAnchor.height
                    radius: width / 2
                    color: "transparent"
                    border.color: "white"
                    border.width: 2
                    opacity: 0
                    transformOrigin: Item.Center

                    SequentialAnimation {
                        loops: Animation.Infinite
                        running: true
                        PauseAnimation { duration: index * 600 }
                        ParallelAnimation {
                            NumberAnimation {
                                target: parent
                                property: "opacity"
                                from: 0.5; to: 0.0
                                duration: 1200
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: parent
                                property: "scale"
                                from: 0.6; to: 1.8
                                duration: 1200
                                easing.type: Easing.OutCubic
                            }
                        }
                        PauseAnimation { duration: (1 - index) * 600 }
                    }
                }
            }
        }

        // ---- logo bubble ----
        Rectangle {
            id: logoBubble
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -units.gu(4)
            width: units.gu(11); height: width
            radius: width / 2
            scale: 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: appTheme ? Qt.lighter(appTheme.primary, 1.25) : "#a5b4fc" }
                GradientStop { position: 1.0; color: appTheme ? appTheme.secondary : "#8b5cf6" }
            }
            // soft inner glow
            Rectangle {
                anchors.fill: parent
                anchors.margins: units.gu(0.4)
                radius: width / 2
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.35)
                border.width: 1
            }
            Label {
                anchors.centerIn: parent
                text: "✦"
                color: "white"
                font.pixelSize: units.gu(5.5)
            }
        }

        // ---- title ----
        Label {
            id: titleLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: logoBubble.bottom
            anchors.topMargin: units.gu(3)
            text: i18nApp ? i18nApp.tr("RAG Assistant") : "RAG Assistant"
            color: "white"
            font.bold: true
            font.pixelSize: units.gu(3.4)
            opacity: 0
        }

        // ---- tagline ----
        Label {
            id: taglineLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: titleLabel.bottom
            anchors.topMargin: units.gu(0.8)
            text: i18nApp ? i18nApp.tr("Smart answers from your documents")
                          : "Smart answers from your documents"
            color: Qt.rgba(1, 1, 1, 0.82)
            font.pixelSize: units.gu(1.7)
            opacity: 0
        }
    }

    // ---- intro: stage fades in, logo pops, text fades up ----
    SequentialAnimation {
        id: introAnim
        NumberAnimation {
            target: stage; property: "opacity"
            from: 0; to: 1.0
            duration: 260; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: logoBubble; property: "scale"
            from: 0.0; to: 1.0
            duration: 440; easing.type: Easing.OutBack
        }
        PauseAnimation { duration: 60 }
        NumberAnimation {
            target: titleLabel; property: "opacity"
            from: 0; to: 1.0
            duration: 280; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: taglineLabel; property: "opacity"
            from: 0; to: 1.0
            duration: 280; easing.type: Easing.OutCubic
        }
    }

    // ---- outro: subtle scale-up + fade ----
    SequentialAnimation {
        id: outroAnim
        ParallelAnimation {
            NumberAnimation {
                target: stage; property: "opacity"
                to: 0
                duration: 280; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: stage; property: "scale"
                from: 1.0; to: 1.05
                duration: 280; easing.type: Easing.InCubic
            }
        }
        NumberAnimation {
            target: splash; property: "opacity"
            to: 0
            duration: 120
        }
        ScriptAction {
            script: {
                splash.visible = false;
                splash.finished();
            }
        }
    }
}
