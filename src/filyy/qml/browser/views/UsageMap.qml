pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../../theme"
import "../../controls"
import "../../format.js" as Format
import ".."

// The storage map: every child of the folder as a bar relative to the largest one, largest first, filled in
// while the sizes are still being measured.
ListView {
    id: map

    required property var pane
    readonly property real largest: pane.usageRows.length ? Math.max(1, pane.usageRows[0].size) : 1

    model: visible ? pane.shown : []
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    headerPositioning: ListView.OverlayHeader

    header: Rectangle {
        width: map.width
        height: Theme.ctlH
        color: Theme.raise1
        z: 2

        SectionLabel {
            x: Theme.space2 + Theme.iconSmall + Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            text: Format.tr(I18n.strings, "{size} belegt", {
                size: Format.size(map.pane.usageTotal)
            }) + (map.pane.usageDone ? "" : "  ·  " + Format.tr(I18n.strings, "misst …"))
        }
    }

    EmptyArea {
        parent: map
        pane: map.pane
    }

    delegate: Rectangle {
        id: bar

        required property var modelData
        required property int index
        readonly property bool isPicked: map.pane.picked[modelData.path] === true

        width: map.width
        height: Theme.rowH
        radius: Theme.radiusSmall
        color: Theme.tint(isPicked, barArea.containsMouse || (index === map.pane.cursor && map.pane.listFocused))

        Behavior on color {
            ColorAnimation {
                duration: Theme.motionFast
            }
        }

        FileIcon {
            id: barIcon

            x: Theme.space2
            width: Theme.iconSmall
            height: Theme.iconSmall
            anchors.verticalCenter: parent.verticalCenter
            kind: bar.modelData.kind
        }

        Text {
            id: barName

            anchors.left: barIcon.right
            anchors.leftMargin: Theme.space2
            width: Math.min(260, parent.width * 0.32)
            anchors.verticalCenter: parent.verticalCenter
            text: bar.modelData.name
            elide: Text.ElideMiddle
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBody
        }

        Rectangle {
            anchors.left: barName.right
            anchors.leftMargin: Theme.space3
            anchors.right: barSize.left
            anchors.rightMargin: Theme.space3
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.space2
            radius: Theme.radiusBar
            color: Theme.raise3

            Rectangle {
                width: Math.max(Theme.space2, parent.width * bar.modelData.size / map.largest)
                height: parent.height
                radius: parent.radius
                color: bar.modelData.dir ? Theme.sub : Theme.faint

                Behavior on width {
                    NumberAnimation {
                        duration: 2 * Theme.motionFast
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Text {
            id: barSize

            anchors.right: barShare.left
            anchors.rightMargin: Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            width: 72
            horizontalAlignment: Text.AlignRight
            text: bar.modelData.pending ? "…" : Format.size(bar.modelData.size)
            color: bar.modelData.pending ? Theme.faint : Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            font.features: {
                "tnum": 1
            }
        }

        Text {
            id: barShare

            anchors.right: parent.right
            anchors.rightMargin: Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            text: map.pane.usageTotal > 0 && !bar.modelData.pending ? Math.round(100 * bar.modelData.size / map.pane.usageTotal) + " %" : ""
            color: Theme.sub
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            font.features: {
                "tnum": 1
            }
        }

        EntryArea {
            id: barArea

            pane: map.pane
            index: bar.index
            entry: bar.modelData
        }
    }

    ScrollHint {
        parent: map.parent
        flick: map
    }
}
