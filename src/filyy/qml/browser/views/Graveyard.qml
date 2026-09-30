pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../controls"
import ".."

// The trash as a graveyard: a pixel tombstone per item, with where it lived and when it went.
GridView {
    id: graves

    required property var pane
    readonly property int columns: Math.max(1, Math.floor(width / 150))

    model: visible ? pane.shown : []
    cellWidth: Math.floor(width / columns)
    cellHeight: Theme.space2 + 64 + Theme.space2 + Theme.fsBody + 2 * Theme.fsSmall + 3 * Theme.space1 + Theme.space3
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    EmptyArea {
        parent: graves
        pane: graves.pane
    }

    delegate: Item {
        id: grave

        required property var modelData
        required property int index
        readonly property bool isPicked: graves.pane.picked[modelData.path] === true

        width: graves.cellWidth
        height: graves.cellHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.space1
            radius: Theme.radiusSmall
            color: Theme.tint(grave.isPicked, graveArea.containsMouse || (grave.index === graves.pane.cursor && graves.pane.listFocused))

            Behavior on color {
                ColorAnimation {
                    duration: Theme.motionFast
                }
            }
        }

        Image {
            id: stone

            x: (parent.width - width) / 2
            y: Theme.space2
            // The tombstone is drawn on a 16 px grid like the file icons.
            width: 64
            height: 64
            source: "../../../../../assets/grave.svg"
            sourceSize: Qt.size(64, 64)
            smooth: false

            FileIcon {
                x: 16
                y: 26
                width: 32
                height: 32
                kind: grave.modelData.kind
            }
        }

        Column {
            x: Theme.space2
            y: stone.y + stone.height + Theme.space2
            width: parent.width - 2 * Theme.space2
            spacing: Theme.space1

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: grave.modelData.name
                elide: Text.ElideMiddle
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBody
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: grave.modelData.original ? grave.modelData.original.slice(0, grave.modelData.original.lastIndexOf("/")).replace(graves.pane.app.home, "~") : ""
                elide: Text.ElideMiddle
                color: Theme.sub
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: grave.modelData.deleted ? "† " + Qt.formatDateTime(new Date(grave.modelData.deleted), "dd.MM.yyyy") : ""
                color: Theme.faint
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
                font.features: {
                    "tnum": 1
                }
            }
        }

        EntryArea {
            id: graveArea

            pane: graves.pane
            index: grave.index
            entry: grave.modelData
        }
    }

    ScrollHint {
        parent: graves.parent
        flick: graves
    }
}
