pragma ComponentBehavior: Bound

import QtQuick
import "../theme"

// Uppercase, widely spaced, faint: the hierarchy between sections, instead of lines.
Text {
    color: Theme.faint
    font.family: Theme.fontUi
    font.pixelSize: Theme.fsMicro
    font.bold: true
    font.letterSpacing: 1.4
    font.capitalization: Font.AllUppercase
    elide: Text.ElideRight
}
