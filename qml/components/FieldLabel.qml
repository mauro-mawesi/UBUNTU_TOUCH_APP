import QtQuick 2.7
import Lomiri.Components 1.3

Label {
    property var appTheme
    textSize: Label.XSmall
    color: appTheme ? appTheme.textSecondary : "#8b949e"
    font.bold: true
}
