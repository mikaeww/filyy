import QtQuick
import Filyy

// The shell's pill text field: a soft tint that deepens while it has focus.
Rectangle {
    id: root

    property alias input: input
    property alias text: input.text
    property string placeholder: ""
    property string glyph: ""
    property bool mono: false
    signal keyPressed(var event)

    height: 36
    radius: Theme.square ? 0 : height / 2
    color: Qt.alpha(Theme.fg, input.activeFocus ? 0.09 : 0.06)
    Behavior on color { ColorAnimation { duration: Theme.quickMs } }

    Text {
        id: icon
        visible: root.glyph !== ""
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyph
        color: Theme.fgMuted
        font.family: Theme.iconFont
        font.pixelSize: 14
    }

    TextInput {
        id: input

        anchors.left: icon.visible ? icon.right : parent.left
        anchors.leftMargin: icon.visible ? 8 : 16
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.fg
        selectionColor: Qt.alpha(Theme.accent, 0.35)
        selectedTextColor: Theme.fg
        font.family: root.mono ? Theme.fontMono : Theme.fontUi
        font.pixelSize: 12
        clip: true
        Accessible.name: root.placeholder
        Keys.onPressed: event => root.keyPressed(event)

        Text {
            visible: input.text === ""
            text: root.placeholder
            color: Theme.fgMuted
            font: input.font
        }
    }
}
