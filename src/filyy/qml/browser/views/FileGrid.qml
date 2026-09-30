pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../../theme"
import "../../controls"
import "../../paths.js" as Paths
import ".."

// The grid view: a large pixel icon or a thumbnail per entry, the name below in up to two lines.
GridView {
    id: grid

    required property var pane
    readonly property int columns: Math.max(1, Math.floor(width / 112))

    model: visible ? pane.shown : []
    cellWidth: Math.floor(width / columns)
    cellHeight: Theme.space3 + Theme.iconLarge + 2 * Theme.space2 + 2 * Theme.fsBody + Theme.space3
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    reuseItems: true

    EmptyArea {
        parent: grid
        pane: grid.pane
    }

    delegate: Item {
        id: tile

        required property var modelData
        required property int index
        readonly property bool isPicked: grid.pane.picked[modelData.path] === true
        readonly property bool isCut: grid.pane.app.board.cut && grid.pane.app.board.paths.includes(modelData.path)
        // Bound, not set once: the grid reuses delegates for other files.
        readonly property string cachedThumb: modelData.kind === "video" ? Thumbs.video(modelData.path) : ""
        property var madeThumb: ({
                path: "",
                url: ""
            })
        readonly property string videoThumb: madeThumb.path === modelData.path ? madeThumb.url : cachedThumb

        width: grid.cellWidth
        height: grid.cellHeight
        opacity: isCut ? 0.45 : 1

        Connections {
            function onReady(path, url) {
                if (path === tile.modelData.path)
                    tile.madeThumb = {
                        path: path,
                        url: url
                    };
            }

            target: tile.modelData.kind === "video" ? Thumbs : null
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.space1
            radius: Theme.radiusSmall
            color: Theme.tint(tile.isPicked, tileArea.containsMouse || tileDrop.containsDrag || (tile.index === grid.pane.cursor && grid.pane.listFocused))

            Behavior on color {
                ColorAnimation {
                    duration: Theme.motionFast
                }
            }
        }

        Item {
            id: preview

            x: (parent.width - width) / 2
            y: Theme.space3
            width: Theme.iconLarge + Theme.space5
            height: Theme.iconLarge

            Image {
                id: thumb

                anchors.fill: parent
                visible: status === Image.Ready
                source: tile.modelData.kind === "image" ? Paths.fileUrl(tile.modelData.path) : tile.videoThumb
                sourceSize: Qt.size(2 * width, 2 * height)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
            }

            FileIcon {
                anchors.centerIn: parent
                visible: !thumb.visible
                width: Theme.iconLarge
                height: Theme.iconLarge
                kind: tile.modelData.kind
            }

            Rectangle {
                visible: thumb.visible && tile.modelData.kind === "video"
                anchors.centerIn: parent
                width: Theme.ctlH
                height: Theme.ctlH
                radius: Theme.radiusSmall
                color: Theme.scrim

                Text {
                    anchors.centerIn: parent
                    text: Theme.glyph.play
                    color: Theme.fg
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fsTitle
                }
            }
        }

        Text {
            x: Theme.space2
            y: preview.y + preview.height + Theme.space2
            width: parent.width - 2 * Theme.space2
            horizontalAlignment: Text.AlignHCenter
            text: tile.modelData.name
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 2
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBody
        }

        EntryArea {
            id: tileArea

            pane: grid.pane
            index: tile.index
            entry: tile.modelData
        }

        DropArea {
            id: tileDrop

            anchors.fill: parent
            enabled: tile.modelData.dir
            onDropped: drop => grid.pane.app.dropInto(drop, tile.modelData.path)
        }
    }

    ScrollHint {
        parent: grid.parent
        flick: grid
    }
}
