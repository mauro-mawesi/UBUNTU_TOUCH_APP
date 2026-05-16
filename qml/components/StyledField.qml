import QtQuick 2.7
import Lomiri.Components 1.3

Rectangle {
    id: field
    property alias text: input.text
    property alias placeholderText: input.placeholderText
    property alias echoMode: input.echoMode
    property alias inputMethodHints: input.inputMethodHints
    readonly property bool inputFocused: input.activeFocus
    property var appTheme

    implicitHeight: units.gu(4.5)
    radius: units.gu(0.8)
    color: appTheme ? appTheme.surfaceAlt : "#0d1117"
    border.color: input.activeFocus
                  ? (appTheme ? appTheme.borderFocus : "#6366f1")
                  : (appTheme ? appTheme.border : "#2a3140")
    border.width: 1
    Behavior on border.color { ColorAnimation { duration: 120 } }

    TextInput {
        id: input
        anchors {
            left: parent.left; right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: units.gu(1.2)
            rightMargin: units.gu(1.2)
        }
        color: appTheme ? appTheme.text : "#e6edf3"
        selectionColor: appTheme ? appTheme.primary : "#6366f1"
        selectedTextColor: "white"
        font.pixelSize: FontUtils.sizeToPixels("medium")
        clip: true
        property string placeholderText: ""

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: input.placeholderText
            color: appTheme ? appTheme.textMuted : "#6b7280"
            visible: input.text.length === 0 && !input.activeFocus
            textSize: Label.Medium
        }
    }
}
