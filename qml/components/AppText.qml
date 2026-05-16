import QtQuick 2.7
import Lomiri.Components 1.3

// Themed Label that pulls size + weight from appTheme.type by `variant`.
// Falls back gracefully if appTheme is not yet wired.
Label {
    id: root
    property var appTheme
    property string variant: "body"   // "display" | "h1" | "h2" | "body" | "caption"

    function _size() {
        if (!appTheme || !appTheme.type) return units.gu(1.6);
        switch (variant) {
            case "display": return appTheme.type.displaySize;
            case "h1":      return appTheme.type.h1Size;
            case "h2":      return appTheme.type.h2Size;
            case "caption": return appTheme.type.captionSize;
            default:        return appTheme.type.bodySize;
        }
    }
    function _weight() {
        if (!appTheme || !appTheme.type) return Font.Normal;
        switch (variant) {
            case "display": return appTheme.type.displayWeight;
            case "h1":      return appTheme.type.h1Weight;
            case "h2":      return appTheme.type.h2Weight;
            case "caption": return appTheme.type.captionWeight;
            default:        return appTheme.type.bodyWeight;
        }
    }

    font.pixelSize: _size()
    font.weight: _weight()
    color: appTheme ? appTheme.text : "#e6edf3"
    wrapMode: Text.Wrap
}
