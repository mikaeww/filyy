pragma ComponentBehavior: Bound

import QtQuick
import "../theme"
import "../motion"

// One choice out of a few: the active option is a compact inverted block that glides on a spring to its new place.
// Options are [value, label] or [value, label, glyph]; with a glyph the label is only read out, not shown.
Rectangle {
    id: root

    property var options: []
    property string current: ""
    signal picked(string value)

    readonly property int index: options.findIndex(option => option[0] === current)
    readonly property Item activeItem: index >= 0 && repeater.count > index ? repeater.itemAt(index) : null

    implicitWidth: row.implicitWidth + 4
    implicitHeight: Theme.ctlH
    radius: Theme.radiusSmall
    color: Theme.raise2
    Accessible.role: Accessible.PageTabList

    Spring {
        id: glide

        target: root.activeItem ? root.activeItem.x : 0
    }

    Spring {
        id: stretch

        target: root.activeItem ? root.activeItem.width : 0
    }

    Rectangle {
        visible: root.activeItem !== null
        x: 2 + glide.value
        y: 2
        width: stretch.value
        height: root.height - 4
        radius: Theme.radiusSmall - 2
        color: Theme.chipOn
    }

    Row {
        id: row

        x: 2
        y: 2

        Repeater {
            id: repeater

            model: root.options

            Item {
                id: option

                required property var modelData
                readonly property bool active: root.current === modelData[0]
                readonly property bool iconic: modelData.length > 2

                width: iconic ? root.height - 4 : label.implicitWidth + 2 * Theme.space2 + 4
                height: root.height - 4
                activeFocusOnTab: true
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData[1]
                Accessible.selected: active
                Keys.onSpacePressed: root.picked(modelData[0])

                Rectangle {
                    anchors.fill: parent
                    visible: !option.active && (option.activeFocus || hover.hovered)
                    radius: Theme.radiusSmall - 2
                    color: Theme.raise3
                }

                Text {
                    id: label

                    anchors.centerIn: parent
                    text: option.iconic ? option.modelData[2] : option.modelData[1]
                    color: option.active ? Theme.chipOnFg : Theme.sub
                    font.family: option.iconic ? Theme.iconFont : Theme.fontUi
                    font.pixelSize: option.iconic ? Theme.fsTitle : Theme.fsBody
                    font.bold: option.active && !option.iconic

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.motionFast
                        }
                    }
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.picked(option.modelData[0])
                }
            }
        }
    }
}
