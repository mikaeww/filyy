import QtQuick
import Filyy
import "Util.js" as Util

// Places and devices; it always acts on the active pane.
Item {
    id: root

    required property var app
    readonly property bool compact: app.compact
    readonly property real padding: compact ? 14 : 20
    readonly property string path: app.pane ? app.pane.path : ""

    Row {
        id: brand

        x: root.compact ? (root.width - 32) / 2 : root.padding
        y: root.padding
        height: 36
        spacing: 10

        Ghost {
            anchors.verticalCenter: parent.verticalCenter
            mood: root.app.busy ? "busy" : "idle"
        }

        Text {
            visible: !root.compact
            anchors.verticalCenter: parent.verticalCenter
            text: "filyy"
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
    }

    Flickable {
        id: scroll

        anchors.top: brand.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.padding
        width: parent.width
        contentWidth: width
        contentHeight: column.height + 8
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Item {
            id: selection

            readonly property int activeIndex: root.app.places.findIndex(place => place.path === root.path)
            readonly property Item target: repeater.count >= 0 && activeIndex >= 0 ? repeater.itemAt(activeIndex) : null
            readonly property real targetY: target ? column.y + target.y + target.height - 44 : 0

            Glide {
                id: glide
                target: selection.targetY
                animated: root.app.shown
            }

            x: column.x
            y: glide.value
            width: column.width
            height: 44
            opacity: target ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.quickMs } }

            Rectangle {
                anchors.fill: parent
                radius: Theme.control
                color: Qt.alpha(Theme.accent, 0.13)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: parent.height - 16
                radius: Theme.square ? 0 : 1
                color: Theme.accent
            }
        }

        Column {
            id: column

            x: root.compact ? 8 : root.padding - 8
            width: scroll.width - 2 * x

            Repeater {
                id: repeater

                model: root.app.places

                Item {
                    id: place

                    required property var modelData
                    required property int index
                    readonly property bool active: root.path === modelData.path
                    readonly property bool groupStart: index === 0 || root.app.places[index - 1].group !== modelData.group

                    width: column.width
                    height: (!groupStart ? 0 : root.compact ? (index === 0 ? 0 : 12)
                        : groupLabel.height + (index === 0 ? 4 : 16)) + 44

                    SectionLabel {
                        id: groupLabel
                        visible: place.groupStart && !root.compact
                        x: 12
                        y: place.index === 0 ? 4 : 16
                        text: place.modelData.group
                        bottomPadding: 6
                    }

                    Rectangle {
                        id: row

                        y: parent.height - 44
                        width: parent.width
                        height: 44
                        radius: Theme.control
                        color: !place.active && (pointer.containsMouse || drop.containsDrag) ? Qt.alpha(Theme.fg, 0.04) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }

                        Rectangle {
                            id: icon
                            x: root.compact ? (parent.width - width) / 2 : 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            radius: Theme.square ? 0 : 9
                            color: Qt.alpha(Theme.accent, place.active ? 0.32 : 0.14)
                            Behavior on color { ColorAnimation { duration: Theme.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }

                            Text {
                                anchors.centerIn: parent
                                text: Util.placeGlyphs[place.modelData.icon] ?? Util.glyphs.folder
                                color: Theme.fg
                                font.family: Theme.iconFont
                                font.pixelSize: 15
                            }
                        }

                        Text {
                            visible: !root.compact
                            anchors.left: icon.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: place.modelData.name
                            elide: Text.ElideRight
                            color: place.active ? Theme.fg : Theme.fgMuted
                            Behavior on color { ColorAnimation { duration: Theme.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                            font.weight: place.active ? Font.DemiBold : Font.Normal
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
                                root.app.newTab(place.modelData.path)
                            else if (root.app.pane)
                                root.app.pane.navigate(place.modelData.path)
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
}
