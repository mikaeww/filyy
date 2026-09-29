import QtQuick
import Filyy
import "Util.js" as Util

Rectangle {
    id: button

    property string label: ""
    property bool primary: false
    property bool danger: false
    signal clicked()

    width: Math.max(96, caption.implicitWidth + 32)
    height: 34
    radius: Theme.control
    color: danger ? Theme.danger : primary ? Theme.accent
        : Qt.alpha(Theme.fg, pointer.containsMouse ? 0.09 : 0.06)
    Behavior on color { ColorAnimation { duration: Theme.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }
    Accessible.role: Accessible.Button
    Accessible.name: label

    Text {
        id: caption
        anchors.centerIn: parent
        text: button.label
        color: button.danger ? Theme.bg : button.primary ? Theme.accentText : Theme.fg
        font.family: Theme.fontUi
        font.pixelSize: 12
        font.weight: button.primary || button.danger ? Font.DemiBold : Font.Normal
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
