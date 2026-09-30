pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../motion"
import "../controls"
import "../format.js" as Format

// The sidebar on the window background: name, places and devices, settings. The active place is one block that
// glides on a spring from row to row. Compact, it keeps only the icons. It always acts on the active pane.
Item {
    id: root

    required property var app
    readonly property bool compact: app.compact
    readonly property string path: app.pane ? app.pane.path : ""

    Row {
        id: brand

        x: root.compact ? (root.width - Theme.fsHead - 3) / 2 : Theme.space2
        height: Theme.ctlH + Theme.space2
        spacing: Theme.space2

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fsHead + 3
            height: width
            source: "../../../../assets/filyy.png"
            sourceSize: Qt.size(2 * width, 2 * height)
            mipmap: true
        }

        Text {
            visible: !root.compact
            anchors.verticalCenter: parent.verticalCenter
            text: "Filyy"
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsHead
            font.bold: true
            font.letterSpacing: -0.3
        }
    }

    Flickable {
        id: scroll

        anchors.top: brand.bottom
        anchors.topMargin: Theme.space3
        anchors.bottom: settings.top
        anchors.bottomMargin: Theme.space2
        width: parent.width
        contentWidth: width
        contentHeight: column.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Item {
            id: selection

            readonly property int activeIndex: root.app.places.findIndex(place => place.path === root.path)
            readonly property Item target: activeIndex >= 0 && repeater.count > activeIndex ? repeater.itemAt(activeIndex) : null

            y: glide.value
            width: column.width
            height: Theme.rowH
            opacity: target ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.motionFast
                }
            }

            Spring {
                id: glide

                // No glide in from the top while the window is still coming up.
                instant: Theme.reducedMotion || root.app.restoring
                target: selection.target ? selection.target.y + selection.target.height - Theme.rowH : 0
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: Theme.raise2
            }
        }

        Column {
            id: column

            width: scroll.width

            Repeater {
                id: repeater

                model: root.app.places

                Item {
                    id: place

                    required property var modelData
                    required property int index
                    readonly property bool active: root.path === modelData.path
                    readonly property bool groupStart: index === 0 || root.app.places[index - 1].group !== modelData.group
                    readonly property int labelSpace: !groupStart ? 0 : root.compact ? (index === 0 ? 0 : Theme.space3) : Theme.ctlH + (index === 0 ? 0 : Theme.space3)

                    width: column.width
                    height: labelSpace + Theme.rowH

                    SectionLabel {
                        visible: place.groupStart && !root.compact
                        x: Theme.space2
                        y: place.labelSpace - Theme.ctlH
                        height: Theme.ctlH
                        verticalAlignment: Text.AlignVCenter
                        text: place.modelData.group
                    }

                    Rectangle {
                        id: row

                        y: place.labelSpace
                        width: parent.width
                        height: Theme.rowH
                        radius: Theme.radiusSmall
                        color: !place.active && (pointer.containsMouse || drop.containsDrag) ? Theme.raise1 : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.motionFast
                            }
                        }

                        Text {
                            id: icon

                            x: root.compact ? (parent.width - width) / 2 : Theme.space2
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.fsTitle
                            horizontalAlignment: Text.AlignHCenter
                            text: Theme.glyph[place.modelData.icon] ?? Theme.glyph.folder
                            color: place.active ? Theme.fg : Theme.sub
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fsBody
                        }

                        Text {
                            visible: !root.compact
                            anchors.left: icon.right
                            anchors.leftMargin: Theme.space2
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.space2
                            anchors.verticalCenter: parent.verticalCenter
                            text: place.modelData.name
                            elide: Text.ElideRight
                            color: place.active ? Theme.fg : Theme.sub
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsBody
                            font.bold: place.active
                        }
                    }

                    MouseArea {
                        id: pointer

                        anchors.fill: row
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Link
                        Accessible.name: place.modelData.name
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton)
                                root.app.newTab(place.modelData.path);
                            else if (root.app.pane)
                                root.app.pane.navigate(place.modelData.path);
                        }
                    }

                    DropArea {
                        id: drop

                        anchors.fill: row
                        onDropped: event => root.app.dropInto(event, place.modelData.path)
                    }
                }
            }
        }
    }

    IconButton {
        id: settings

        x: root.compact ? (root.width - width) / 2 : 0
        anchors.bottom: parent.bottom
        glyph: Theme.glyph.settings
        label: Format.tr(I18n.strings, "Einstellungen")
        onClicked: root.app.settingsOpen = true
    }
}
