pragma ComponentBehavior: Bound

import QtQuick

// A pixel icon from assets/icons, drawn at a whole multiple of its 16 px grid so it stays crisp. The one place
// with colour: the icon tells the file type, like a thumbnail (ADR 0002).
Image {
    property string kind: "file"

    source: Qt.resolvedUrl("../../../../assets/icons/" + kind + ".svg")
    sourceSize: Qt.size(width, height)
    smooth: false
    asynchronous: false
}
