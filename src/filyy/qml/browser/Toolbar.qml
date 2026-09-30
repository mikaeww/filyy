pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../controls"
import "../paths.js" as Paths
import "../format.js" as Format

// Above a pane, on the window background: back and forward, the path as breadcrumbs (a click beside them edits
// it as text), the filter, the view choice and the folder actions. Narrow panes drop the view tools first.
Item {
    id: root

    required property var pane
    readonly property alias filter: filter
    property bool editingPath: false
    readonly property bool roomy: width >= 640

    function editPath() {
        editingPath = true;
        pathField.text = root.pane.path.replace(root.pane.app.home, "~");
        pathField.input.forceActiveFocus();
        pathField.input.selectAll();
    }

    height: Theme.ctlH + Theme.space2

    Row {
        id: nav

        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space1

        IconButton {
            glyph: Theme.glyph.back
            label: Format.tr(I18n.strings, "Zurück")
            enabled: root.pane.history.index > 0
            onClicked: root.pane.stepHistory(-1)
        }

        IconButton {
            glyph: Theme.glyph.forward
            label: Format.tr(I18n.strings, "Vor")
            enabled: root.pane.history.index < root.pane.history.list.length - 1
            onClicked: root.pane.stepHistory(1)
        }
    }

    Item {
        id: crumbBox

        anchors.left: nav.right
        anchors.leftMargin: Theme.space2
        anchors.right: tools.left
        anchors.rightMargin: Theme.space3
        height: parent.height
        clip: true

        // Under the crumbs, so only a press beside them edits the path.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: root.editPath()
        }

        Row {
            visible: !root.editingPath
            anchors.verticalCenter: parent.verticalCenter
            // Keeps the deepest folder in view when the path is longer than the bar.
            x: Math.min(0, crumbBox.width - width)
            spacing: 0

            Repeater {
                model: root.pane.isTrash ? [
                    {
                        name: Format.tr(I18n.strings, "Papierkorb"),
                        path: root.pane.path
                    }
                ] : Paths.crumbs(root.pane.path, root.pane.app.home)

                Row {
                    id: crumb

                    required property var modelData
                    required property int index
                    readonly property bool last: modelData.path === root.pane.path

                    Text {
                        visible: crumb.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.glyph.chevron
                        color: Theme.faint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fsBody
                    }

                    Rectangle {
                        width: crumbText.implicitWidth + 2 * Theme.space2
                        height: Theme.ctlH
                        radius: Theme.radiusSmall
                        color: crumbPointer.containsMouse || crumbDrop.containsDrag ? Theme.raise2 : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.motionFast
                            }
                        }

                        Text {
                            id: crumbText

                            anchors.centerIn: parent
                            text: crumb.modelData.name
                            color: crumb.last ? Theme.fg : Theme.sub
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsTitle
                            font.bold: crumb.last
                        }

                        MouseArea {
                            id: crumbPointer

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pane.navigate(crumb.modelData.path)
                        }

                        DropArea {
                            id: crumbDrop

                            anchors.fill: parent
                            onDropped: drop => root.pane.app.dropInto(drop, crumb.modelData.path)
                        }
                    }
                }
            }
        }

        Field {
            id: pathField

            visible: root.editingPath
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            mono: true
            placeholder: Format.tr(I18n.strings, "Pfad")
            input.onActiveFocusChanged: if (!input.activeFocus)
                root.editingPath = false
            onKeyPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.pane.navigate(text);
                else if (event.key !== Qt.Key_Escape)
                    return;
                root.pane.focusList();
                event.accepted = true;
            }
        }
    }

    Row {
        id: tools

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space1

        Field {
            id: filter

            width: root.roomy ? 180 : 120
            glyph: Theme.glyph.search
            placeholder: Format.tr(I18n.strings, "Filtern …")
            onTextChanged: {
                root.pane.cursor = 0;
                root.pane.anchor = 0;
                root.pane.picked = {};
            }
            onKeyPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    text = "";
                    root.pane.focusList();
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.pane.focusList();
                    if (event.key !== Qt.Key_Down)
                        root.pane.activate(root.pane.current);
                } else {
                    return;
                }
                event.accepted = true;
            }
        }

        Item {
            width: Theme.space1
            height: 1
        }

        Segmented {
            visible: root.roomy && !root.pane.isTrash
            options: [["list", Format.tr(I18n.strings, "Liste"), Theme.glyph.list], ["grid", Format.tr(I18n.strings, "Raster"), Theme.glyph.grid], ["usage", Format.tr(I18n.strings, "Speicher-Karte"), Theme.glyph.usage]]
            current: root.pane.view
            onPicked: value => root.pane.view = value
        }

        IconButton {
            visible: root.roomy && !root.pane.isTrash
            glyph: root.pane.showHidden ? Theme.glyph.eye : Theme.glyph.eyeOff
            label: Format.tr(I18n.strings, "Versteckte Dateien")
            active: root.pane.showHidden
            onClicked: root.pane.toggleHidden()
        }

        IconButton {
            visible: !root.pane.readOnly
            glyph: Theme.glyph.newFolder
            label: Format.tr(I18n.strings, "Neuer Ordner")
            onClicked: root.pane.app.openSheet("mkdir")
        }

        Button {
            visible: root.pane.inArchive
            label: Format.tr(I18n.strings, "Alles entpacken")
            onClicked: Files.extractAll(root.pane.app.archiveOf(root.pane.path))
        }

        Button {
            visible: root.pane.isTrash
            label: Format.tr(I18n.strings, "Papierkorb leeren")
            enabled: root.pane.entries.length > 0
            onClicked: root.pane.app.openSheet("empty")
        }
    }
}
