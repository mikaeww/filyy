import QtQuick
import Filyy
import "Util.js" as Util

// A small toggle pill.
Rectangle {
    id: root

    property string label: ""
    property bool active: false
    signal clicked()

    width: caption.implicitWidth + 24
    height: 30
    radius: Theme.square ? 0 : height / 2
    color: active ? Qt.alpha(Theme.accent, 0.2) : Qt.alpha(Theme.fg, pointer.containsMouse ? 0.08 : 0.05)
    border.width: active ? 1 : 0
    border.color: Qt.alpha(Theme.accent, 0.5)
    Behavior on color { ColorAnimation { duration: Theme.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: active

    Text {
        id: caption
        anchors.centerIn: parent
        text: root.label
        color: root.active ? Theme.fg : Theme.fgMuted
        font.family: Theme.fontUi
        font.pixelSize: 12
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
