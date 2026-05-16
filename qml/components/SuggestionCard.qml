import QtQuick 2.7
import Lomiri.Components 1.3

Rectangle {
    id: card
    property string title: ""
    property string subtitle: ""
    property var appTheme
    signal clicked()

    implicitHeight: contentCol.implicitHeight + units.gu(2.4)
    radius: units.gu(1.5)
    color: !appTheme ? "#171b22"
                     : (mouseArea.pressed ? appTheme.surfaceHover
                       : (mouseArea.containsMouse ? appTheme.surface : appTheme.surfaceElevated))
    border.color: mouseArea.containsMouse && appTheme
                  ? appTheme.borderFocus
                  : (appTheme ? appTheme.border : "#2a3140")
    border.width: 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Column {
        id: contentCol
        anchors {
            left: parent.left; right: parent.right
            top: parent.top
            margins: units.gu(1.2)
        }
        spacing: units.gu(0.4)

        Label {
            width: parent.width
            text: card.title
            textSize: Label.Medium
            color: appTheme ? appTheme.text : "#e6edf3"
            font.bold: true
            wrapMode: Text.Wrap
        }

        Label {
            width: parent.width
            text: card.subtitle
            textSize: Label.Small
            color: appTheme ? appTheme.textSecondary : "#8b949e"
            wrapMode: Text.Wrap
            visible: card.subtitle.length > 0
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.clicked()
    }
}
