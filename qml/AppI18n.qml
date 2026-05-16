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
}
