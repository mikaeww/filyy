import QtQuick

// A pixel icon from assets/icons, drawn at a whole multiple of its 16 px grid so it stays crisp.
Image {
    property string kind: "file"

    source: "../assets/icons/" + kind + ".svg"
    sourceSize: Qt.size(width, height)
    smooth: false
    asynchronous: false
}
