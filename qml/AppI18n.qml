import QtQuick 2.7
import "js/I18nData.js" as Data

QtObject {
    property string language: "en"

    function tr(key) {
        // Read `language` so that bindings using tr() track changes.
        var lang = language;
        var dict = Data.dictionaries[lang] || Data.dictionaries["en"] || {};
        return dict[key] || key;
    }

    function detect(localeName) {
        return Data.detectFromSystem(localeName);
    }

    // Hands out a monotonically increasing stagger index to TransLabel
    // instances so the language-switch animation cascades across the UI
    // in the order labels are created (top-down). Wraps modulo 24 to
    // cap the total cascade duration.
    property int _staggerCounter: 0
    function nextStaggerIndex() {
        var n = _staggerCounter;
        _staggerCounter = (_staggerCounter + 1) % 24;
        return n;
    }
}
