/*
 * Copyright (C) 2026  MAURICIO ARIAS
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * ragassistant is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'ragassistant.ragassistant'
    automaticOrientation: true

    width: units.gu(50)
    height: units.gu(85)

    backgroundColor: appTheme.bg

    Component.onCompleted: {
        i18nApp.language = appSettings.language.length > 0
                           ? appSettings.language
                           : i18nApp.detect(Qt.locale().name);
    }

    Connections {
        target: appSettings
        onLanguageChanged: {
            if (appSettings.language.length > 0) i18nApp.language = appSettings.language;
        }
    }

    AppI18n { id: i18nApp }

    AppTheme {
        id: appTheme
        mode: appSettings.themeMode
        presetIndex: appSettings.themePresetIndex
    }

    Settings {
        id: appSettings
        property string language: ""
        property string themeMode: "dark"
        property int themePresetIndex: 0

        property string apiKey: ""
        property string model: "google/gemini-2.5-pro"
        property string openrouterUrl: "https://openrouter.ai/api/v1"

        property string chromaUrl: "http://172.28.18.200:8000"
        property string tenant: "default_tenant"
        property string database: "default_database"
        property string collectionId: "7e001a88-467b-45bc-8bf0-169042f7b943"
        property int topK: 5

        property string ollamaUrl: "http://172.28.18.200:11434"
        property string embedModel: "nomic-embed-text"
    }

    PageStack {
        id: pageStack
        Component.onCompleted: push(chatPage)
    }

    ChatPage {
        id: chatPage
        visible: false
        appSettings: appSettings
        pageStack: pageStack
        settingsPage: settingsPage
        i18nApp: i18nApp
        appTheme: appTheme
    }

    SettingsPage {
        id: settingsPage
        visible: false
        appSettings: appSettings
        i18nApp: i18nApp
        appTheme: appTheme
    }
}
