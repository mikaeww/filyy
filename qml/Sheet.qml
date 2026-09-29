import QtQuick
import Filyy
import "Util.js" as Util

// A centred dialog over a scrim, with the settings panel's entrance: fade plus a hint of scale.
Item {
    id: root

    property bool open: false
    property int cardWidth: 440
    property real reveal: 0
    default property alias content: column.data
    readonly property alias card: card
    signal dismissed()
    signal accepted()

    anchors.fill: parent
    visible: reveal > 0
    z: 10

    onOpenChanged: {
        if (open) {
            hide.stop()
            show.restart()
            card.forceActiveFocus()
        } else {
            show.stop()
            hide.restart()
        }
    }

    NumberAnimation { id: show; target: root; property: "reveal"; to: 1; duration: Theme.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
    NumberAnimation { id: hide; target: root; property: "reveal"; to: 0; duration: Theme.exitMs; easing.type: Easing.OutCubic }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        opacity: root.reveal
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Rectangle {
        id: card

        width: Math.min(root.cardWidth, root.width - 32)
        height: Math.min(column.implicitHeight + 48, root.height - 32)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        radius: Theme.radius
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.hairline
        opacity: root.reveal
        scale: 0.97 + 0.03 * root.reveal
        Keys.onEscapePressed: root.dismissed()
        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()

        MouseArea { anchors.fill: parent }

        Column {
            id: column
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 16
        }
    }
}
