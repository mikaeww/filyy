pragma ComponentBehavior: Bound

import QtQuick
import "../theme"
import "../motion"

// A dialog over a scrim. It rises a few pixels and fades in on the settle spring; with reduced motion it only
// fades. Every key on the card reaches keyPressed first; left unaccepted, Esc dismisses and Enter accepts.
Item {
    id: root

    property bool open: false
    property int cardWidth: 460
    // -1 centres the card; a value pins its top, like a launcher.
    property int cardTop: -1
    default property alias content: column.data
    readonly property alias card: card
    signal dismissed
    signal accepted
    signal keyPressed(var event)

    anchors.fill: parent
    visible: reveal.value > 0.001
    z: 10

    onOpenChanged: {
        reveal.target = open ? 1 : 0;
        if (open)
            card.forceActiveFocus();
    }

    Spring {
        id: reveal

        motion: Theme.settle
        // A fade stays with reduced motion; only the travel goes.
        instant: false
        precision: 0.002
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: Math.min(1, reveal.value)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Rectangle {
        id: card

        readonly property int topSpace: root.cardTop >= 0 ? root.cardTop : Theme.space5

        width: Math.min(root.cardWidth, root.width - 2 * Theme.space5)
        height: Math.min(column.implicitHeight + 2 * Theme.space4, root.height - card.topSpace - Theme.space5)
        x: Math.round((root.width - width) / 2)
        y: (root.cardTop >= 0 ? root.cardTop : Math.round((root.height - height) / 2)) + (Theme.reducedMotion ? 0 : (1 - reveal.value) * Theme.space3)
        radius: Theme.radius
        color: Theme.raise1
        opacity: Math.min(1, reveal.value)
        clip: true
        Keys.onPressed: event => {
            root.keyPressed(event);
            if (event.accepted)
                return;
            if (event.key === Qt.Key_Escape)
                root.dismissed();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.accepted();
            else
                return;
            event.accepted = true;
        }

        // Takes presses inside the card exclusively, so they never reach the scrim and dismiss it.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            x: Theme.space4
            y: Theme.space4
            width: parent.width - 2 * Theme.space4
            spacing: Theme.space3
        }
    }
}
