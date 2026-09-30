pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../../theme"
import "../../controls"
import "../../format.js" as Format
import ".."

// The list view: name, size and date per row, column labels on top. Columns drop away on narrow panes instead
// of running into the name.
ListView {
    id: list

    required property var pane
    readonly property int dateWidth: width > 580 ? 128 : 0
    readonly property int sizeWidth: width > 420 ? 72 : 0

    model: visible ? pane.shown : []
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    reuseItems: true
    headerPositioning: ListView.OverlayHeader

    // Rows scroll under the labels, so they carry the surface colour.
    header: Rectangle {
        width: list.width
        color: Theme.raise1
        height: Theme.ctlH
        z: 2

        SectionLabel {
            x: Theme.space2 + Theme.iconSmall + Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            text: "Name"
        }

        SectionLabel {
            visible: list.sizeWidth > 0
            x: parent.width - list.dateWidth - list.sizeWidth - Theme.space4
            width: list.sizeWidth
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Format.tr(I18n.strings, "Größe")
        }

        SectionLabel {
            visible: list.dateWidth > 0
            x: parent.width - list.dateWidth
            anchors.verticalCenter: parent.verticalCenter
            text: Format.tr(I18n.strings, "Geändert")
        }
    }

    EmptyArea {
        parent: list
        pane: list.pane
    }

    delegate: Rectangle {
        id: row

        required property var modelData
        required property int index
        readonly property bool isPicked: list.pane.picked[modelData.path] === true
        readonly property bool isCut: list.pane.app.board.cut && list.pane.app.board.paths.includes(modelData.path)

        width: list.width
        height: Theme.rowH
        radius: Theme.radiusSmall
        color: Theme.tint(isPicked, rowArea.containsMouse || rowDrop.containsDrag || (index === list.pane.cursor && list.pane.listFocused))
        opacity: isCut ? 0.45 : 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.motionFast
            }
        }

        FileIcon {
            id: rowIcon

            x: Theme.space2
            width: Theme.iconSmall
            height: Theme.iconSmall
            anchors.verticalCenter: parent.verticalCenter
            kind: row.modelData.kind
        }

        Text {
            anchors.left: rowIcon.right
            anchors.leftMargin: Theme.space2
            anchors.right: rowSize.left
            anchors.rightMargin: Theme.space3
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.name
            elide: Text.ElideMiddle
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBody
        }

        Text {
            id: rowSize

            x: parent.width - list.dateWidth - list.sizeWidth - Theme.space4
            width: list.sizeWidth
            visible: list.sizeWidth > 0
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: row.modelData.dir ? "" : Format.size(row.modelData.size)
            color: Theme.sub
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            font.features: {
                "tnum": 1
            }
        }

        Text {
            visible: list.dateWidth > 0
            x: parent.width - list.dateWidth
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.mtime ? Qt.formatDateTime(new Date(row.modelData.mtime), "dd.MM.yyyy  HH:mm") : ""
            color: Theme.sub
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            font.features: {
                "tnum": 1
            }
        }

        EntryArea {
            id: rowArea

            pane: list.pane
            index: row.index
            entry: row.modelData
        }

        DropArea {
            id: rowDrop

            anchors.fill: parent
            enabled: row.modelData.dir
            onDropped: drop => list.pane.app.dropInto(drop, row.modelData.path)
        }
    }

    ScrollHint {
        parent: list.parent
        flick: list
    }
}
