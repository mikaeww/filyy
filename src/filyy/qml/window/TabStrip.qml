pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../motion"
import "../format.js" as Format

// The open tabs, shown once there is more than one. The current tab is a block that glides on a spring; a click
// switches, a middle click closes, dragging a tab onto the panes splits (see Main.dropTab).
Item {
    id: root

    required property var app
    required property var model
    readonly property Item currentChip: repeater.count > app.tabIndex ? repeater.itemAt(app.tabIndex) : null

    height: Theme.ctlH

    Spring {
        id: glide

        instant: Theme.reducedMotion || root.app.restoring
        target: root.currentChip ? root.currentChip.x : 0
    }

    Spring {
        id: stretch

        instant: Theme.reducedMotion || root.app.restoring
        target: root.currentChip ? root.currentChip.width : 0
    }

    Rectangle {
        visible: root.currentChip !== null
        x: glide.value
        width: stretch.value
        height: parent.height
        radius: Theme.radiusSmall
        color: Theme.raise2
    }

    Row {
        id: row

        height: parent.height
        spacing: Theme.space1

        Repeater {
            id: repeater

            model: root.model

            Rectangle {
                id: chip

                required property int index
                readonly property bool current: index === root.app.tabIndex
                readonly property var owner: root.app.tabAt(index)

                width: Math.min(200, Math.max(110, caption.implicitWidth + 2 * Theme.space2 + Theme.ctlH))
                height: root.height
                radius: Theme.radiusSmall
                color: !current && pointer.containsMouse ? Theme.raise1 : "transparent"
                Accessible.role: Accessible.PageTab
                Accessible.name: caption.text
                Accessible.selected: current

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.motionFast
                    }
                }

                Text {
                    id: caption

                    x: Theme.space2
                    width: parent.width - Theme.space2 - Theme.ctlH
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.owner && chip.owner.lastPane ? chip.owner.lastPane.title : ""
                    elide: Text.ElideRight
                    color: chip.current ? Theme.fg : Theme.sub
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBody
                    font.bold: chip.current
                }

                MouseArea {
                    id: pointer

                    property point pressAt
                    property bool dragging: false

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    onPressed: mouse => {
                        pressAt = Qt.point(mouse.x, mouse.y);
                        dragging = false;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed || mouse.buttons !== Qt.LeftButton)
                            return;
                        if (!dragging && Math.hypot(mouse.x - pressAt.x, mouse.y - pressAt.y) > 8)
                            dragging = true;
                        if (dragging) {
                            const at = mapToItem(root.app.contentItem, mouse.x, mouse.y);
                            root.app.tabDrag = {
                                index: chip.index,
                                x: at.x,
                                y: at.y,
                                title: caption.text
                            };
                        }
                    }
                    onReleased: mouse => {
                        if (dragging) {
                            const at = mapToItem(root.app.contentItem, mouse.x, mouse.y);
                            dragging = false;
                            root.app.dropTab(chip.index, at.x, at.y);
                        } else if (containsMouse) {
                            if (mouse.button === Qt.MiddleButton)
                                root.app.closeTab(chip.index);
                            else
                                root.app.switchTab(chip.index);
                        }
                    }
                    onCanceled: {
                        dragging = false;
                        root.app.tabDrag = null;
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.ctlH
                    height: Theme.ctlH
                    radius: Theme.radiusSmall
                    color: closePointer.containsMouse ? Theme.raise3 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: Theme.glyph.close
                        color: closePointer.containsMouse ? Theme.fg : Theme.faint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fsBody
                    }

                    MouseArea {
                        id: closePointer

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: Format.tr(I18n.strings, "Tab schließen")
                        onClicked: root.app.closeTab(chip.index)
                    }
                }
            }
        }
    }
}
