pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../format.js" as Format

// The pane's status line at the bottom of its surface: counts or the selection, the last message, free space.
// A failed action says so in bold, not in red.
Item {
    id: root

    required property var pane
    readonly property bool speaks: pane.isActive && pane.app.message !== ""

    height: Theme.ctlH

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Theme.space2
        anchors.right: space.left
        anchors.rightMargin: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: {
            if (root.speaks)
                return root.pane.app.message;
            const count = root.pane.pickedPaths.length;
            if (count > 0) {
                const bytes = root.pane.shown.filter(entry => root.pane.picked[entry.path] && !entry.dir).reduce((sum, entry) => sum + entry.size, 0);
                return Format.tr(I18n.strings, "{n} ausgewählt", {
                    n: count
                }) + (bytes ? "  ·  " + Format.size(bytes) : "");
            }
            const folders = root.pane.shown.filter(entry => entry.dir).length;
            const files = root.pane.shown.length - folders;
            return Format.tr(I18n.strings, "{n} Ordner", {
                n: folders
            }) + "  ·  " + Format.tr(I18n.strings, files === 1 ? "{n} Datei" : "{n} Dateien", {
                n: files
            });
        }
        color: root.speaks ? Theme.fg : Theme.sub
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSmall
        font.bold: root.speaks && root.pane.app.failed
        font.features: {
            "tnum": 1
        }
    }

    Text {
        id: space

        anchors.right: parent.right
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        // Reading I18n.lang re-asks the backend, which words "free", when the language changes.
        text: I18n.lang && root.pane.path ? Files.space(root.pane.path) : ""
        color: Theme.faint
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSmall
        font.features: {
            "tnum": 1
        }
    }
}
