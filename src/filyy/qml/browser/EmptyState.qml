pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../format.js" as Format

// Why a pane shows nothing: no access, nothing matches the filter, or the folder or trash is empty.
Column {
    id: root

    required property var pane

    spacing: Theme.space2

    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !root.pane.error
        width: 96
        height: 96
        source: "../../../../assets/filyy.png"
        sourceSize: Qt.size(192, 192)
        mipmap: true
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.pane.error ? Format.tr(I18n.strings, "Kein Zugriff") : root.pane.filterText ? Format.tr(I18n.strings, "Nichts passt zu „{filter}“", {
            filter: root.pane.filterText
        }) : root.pane.isTrash ? Format.tr(I18n.strings, "Der Papierkorb ist leer") : Format.tr(I18n.strings, "Dieser Ordner ist leer")
        color: Theme.fg
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsTitle
        font.bold: true
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: text !== ""
        text: root.pane.error
        color: Theme.sub
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBody
    }
}
