import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

Rectangle {
    id: card
    property string sectionTitle: ""
    property var appTheme
    default property alias content: inner.data

    radius: units.gu(1.5)
    color: appTheme ? appTheme.surface : "#1a1f29"
    border.color: appTheme ? appTheme.border : "#2a3140"
    border.width: 1
    implicitHeight: outerCol.implicitHeight + units.gu(3)

    ColumnLayout {
        id: outerCol
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            leftMargin: units.gu(1.5)
            rightMargin: units.gu(1.5)
            topMargin: units.gu(1.5)
        }
        spacing: units.gu(0.8)

        Label {
            text: card.sectionTitle
            textSize: Label.Medium
            color: appTheme ? appTheme.text : "#e6edf3"
            font.bold: true
            visible: text.length > 0
            Layout.bottomMargin: units.gu(0.3)
        }

        ColumnLayout {
            id: inner
            Layout.fillWidth: true
            spacing: units.gu(0.6)
        }
    }
}
