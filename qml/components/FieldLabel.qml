import QtQuick 2.7
import Lomiri.Components 1.3

// Small bold form-label. Set `text` for a static string (legacy callers)
// or `textKey` + `i18nApp` to get the animated blur+fade transition on
// language change.
Item {
    id: root
    property var appTheme
    property var i18nApp
    property string text: ""
    property string textKey: ""

    implicitWidth: (root.textKey.length > 0 ? animated.implicitWidth : staticLbl.implicitWidth)
    implicitHeight: (root.textKey.length > 0 ? animated.implicitHeight : staticLbl.implicitHeight)

    Label {
        id: staticLbl
        anchors.fill: parent
        visible: root.textKey.length === 0
        text: root.text
        textSize: Label.XSmall
        color: appTheme ? appTheme.textSecondary : "#8b949e"
        font.bold: true
    }
    TransLabel {
        id: animated
        anchors.fill: parent
        visible: root.textKey.length > 0
        i18nApp: root.i18nApp
        key: root.textKey
        color: appTheme ? appTheme.textSecondary : "#8b949e"
        bold: true
        fontPixelSize: FontUtils.sizeToPixels("x-small")
    }
}
