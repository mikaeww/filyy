pragma ComponentBehavior: Bound

import QtQuick
import "../theme"

// A text input: raise2 at rest, raise3 while it has focus. The placeholder names what goes in. Every key reaches
// keyPressed first; leave it unaccepted for the input's own handling.
Rectangle {
    id: field

    property alias input: input
    property alias text: input.text
    property string placeholder: ""
    property string glyph: ""
    property bool mono: false
    property int size: Theme.fsBody
    signal keyPressed(var event)

    implicitWidth: 200
    implicitHeight: Math.max(Theme.ctlH, size * 2 + 2)
    radius: Theme.radiusSmall
    color: input.activeFocus ? Theme.raise3 : hover.hovered ? Theme.mix(Theme.raise2, Theme.raise3, 0.5) : Theme.raise2

    Behavior on color {
        ColorAnimation {
            duration: Theme.motionFast
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.IBeamCursor
    }

    TapHandler {
        onTapped: input.forceActiveFocus()
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.space2
        anchors.rightMargin: Theme.space2
        spacing: Theme.space2

        Text {
            visible: field.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: field.glyph
            color: Theme.sub
            font.family: Theme.iconFont
            font.pixelSize: field.size
        }

        TextInput {
            id: input

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (field.glyph !== "" ? field.size + Theme.space2 : 0)
            color: Theme.fg
            selectionColor: Theme.raise3
            selectedTextColor: Theme.fg
            selectByMouse: true
            clip: true
            font.family: field.mono ? Theme.fontMono : Theme.fontUi
            font.pixelSize: field.size
            Accessible.name: field.placeholder
            Keys.onPressed: event => field.keyPressed(event)

            Text {
                visible: input.text === ""
                text: field.placeholder
                color: Theme.faint
                font: input.font
            }
        }
    }
}
