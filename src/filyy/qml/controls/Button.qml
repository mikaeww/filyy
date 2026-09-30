pragma ComponentBehavior: Bound

import QtQuick
import "../theme"

// A text button: primary is the one inverted action of its context, everything else a raise step.
Rectangle {
    id: button

    property string label: ""
    property bool primary: false
    property bool strong: false
    signal clicked

    implicitWidth: caption.implicitWidth + 2 * Theme.space2 + 2
    implicitHeight: Theme.ctlH
    radius: Theme.radiusSmall
    opacity: enabled ? 1 : 0.45
    color: primary ? (hover.hovered || activeFocus ? Theme.mix(Theme.chipOn, Theme.bg, 0.12) : Theme.chipOn) : activeFocus || hover.hovered ? Theme.raise3 : Theme.raise2
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()

    Behavior on color {
        ColorAnimation {
            duration: Theme.motionFast
        }
    }

    Text {
        id: caption

        anchors.centerIn: parent
        text: button.label
        color: button.primary ? Theme.chipOnFg : Theme.fg
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBody
        font.bold: button.primary || button.strong
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: button.clicked()
    }
}
