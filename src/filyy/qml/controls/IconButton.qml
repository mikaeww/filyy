pragma ComponentBehavior: Bound

import QtQuick
import "../theme"

// A square button with one glyph, centred; quiet until hovered. `active` marks a switched-on toggle.
Rectangle {
    id: button

    property string glyph: ""
    property string label: ""
    property bool active: false
    signal clicked

    implicitWidth: Theme.ctlH
    implicitHeight: Theme.ctlH
    radius: Theme.radiusSmall
    opacity: enabled ? 1 : 0.45
    color: active ? Theme.raise3 : activeFocus || hover.hovered ? Theme.raise2 : "transparent"
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.checked: active
    Accessible.onPressAction: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()

    Behavior on color {
        ColorAnimation {
            duration: Theme.motionFast
        }
    }

    Text {
        anchors.centerIn: parent
        text: button.glyph
        color: button.active || hover.hovered ? Theme.fg : Theme.sub
        font.family: Theme.iconFont
        font.pixelSize: Theme.fsTitle
    }

    HoverHandler {
        id: hover

        enabled: button.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: button.clicked()
    }
}
