import QtQuick
import Filyy
import "Util.js" as Util

// A centred dialog over a scrim, with the settings panel's entrance: fade plus a hint of scale.
Item {
    id: root

    property bool open: false
    property int cardWidth: 440
    // -1 centres the card; a value pins its top, like a launcher.
    property int cardTop: -1
    property real reveal: 0
    default property alias content: column.data
    readonly property alias card: card
    signal dismissed()
    signal accepted()
    // Every key on the card first; leave it unaccepted to get Esc = dismiss, Enter = accept.
    signal keyPressed(var event)

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
        height: Math.min(column.implicitHeight + 48, root.height - (root.cardTop >= 0 ? root.cardTop : 16) - 16)
        clip: true
        x: Math.round((root.width - width) / 2)
        y: root.cardTop >= 0 ? root.cardTop : Math.round((root.height - height) / 2)
        radius: Theme.radius
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.hairline
        opacity: root.reveal
        scale: 0.97 + 0.03 * root.reveal
        Keys.onPressed: event => {
            root.keyPressed(event)
            if (event.accepted)
                return
            if (event.key === Qt.Key_Escape)
                root.dismissed()
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.accepted()
            else
                return
            event.accepted = true
        }

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
