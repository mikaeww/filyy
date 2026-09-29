import QtQuick
import Filyy
import "Util.js" as Util

Rectangle {
    id: button

    property string glyph: ""
    property bool active: false
    property string label: ""
    signal clicked()

    width: 32
    height: 32
    radius: Theme.control
    opacity: enabled ? 1 : 0.35
    color: active ? Qt.alpha(Theme.accent, 0.18)
        : pointer.containsMouse ? Qt.alpha(Theme.fg, 0.06) : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }
    Accessible.role: Accessible.Button
    Accessible.name: label

    Text {
        anchors.centerIn: parent
        text: button.glyph
        color: Theme.fg
        font.family: Theme.iconFont
        font.pixelSize: 16
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
