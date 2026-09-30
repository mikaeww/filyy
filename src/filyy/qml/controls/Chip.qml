pragma ComponentBehavior: Bound

import QtQuick
import "../theme"

// A toggle or choice; the active one is the inverted block.
Rectangle {
    id: chip

    property string label: ""
    property bool active: false
    signal clicked

    implicitWidth: caption.implicitWidth + 2 * Theme.space2 + 2
    implicitHeight: Theme.ctlH
    radius: Theme.radiusSmall
    opacity: enabled ? 1 : 0.45
    color: active ? Theme.chipOn : activeFocus || hover.hovered ? Theme.raise3 : Theme.raise2
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: active
    Accessible.onPressAction: clicked()
    Keys.onSpacePressed: clicked()

    Behavior on color {
        ColorAnimation {
            duration: Theme.motionFast
        }
    }

    Text {
        id: caption

        anchors.centerIn: parent
        text: chip.label
        color: chip.active ? Theme.chipOnFg : Theme.fg
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBody
        font.bold: chip.active
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: chip.clicked()
    }
}
