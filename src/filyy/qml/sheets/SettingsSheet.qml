pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../controls"
import "../format.js" as Format

// Looks and language. Each language names itself, so it can be found whichever one is active.
Sheet {
    id: root

    required property var app

    cardWidth: 420
    open: app.settingsOpen
    onDismissed: close()
    onAccepted: close()

    function close() {
        app.settingsOpen = false;
        if (app.pane)
            app.pane.focusList();
    }

    Title {
        text: Format.tr(I18n.strings, "Einstellungen")
    }

    SectionLabel {
        topPadding: Theme.space2
        text: Format.tr(I18n.strings, "Darstellung")
    }

    Segmented {
        options: [["system", Format.tr(I18n.strings, "System")], ["dark", Format.tr(I18n.strings, "Dunkel")], ["light", Format.tr(I18n.strings, "Hell")]]
        current: Theme.mode
        onPicked: value => Theme.setMode(value)
    }

    SectionLabel {
        topPadding: Theme.space2
        text: Format.tr(I18n.strings, "Sprache")
    }

    Segmented {
        options: [["en", "English"], ["de", "Deutsch"]]
        current: I18n.lang
        onPicked: value => I18n.setLang(value)
    }
}
