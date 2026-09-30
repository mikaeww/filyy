pragma ComponentBehavior: Bound

import QtQuick
import "../theme"

// The heading of a sheet.
Text {
    wrapMode: Text.Wrap
    color: Theme.fg
    font.family: Theme.fontUi
    font.pixelSize: Theme.fsHead
    font.bold: true
    font.letterSpacing: -0.3
}
