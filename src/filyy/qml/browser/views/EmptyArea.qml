pragma ComponentBehavior: Bound

import QtQuick

// Empty space of a view: a click clears the selection, a right click opens the folder menu. It sits under the
// view's content, so entries still get their own presses first.
MouseArea {
    id: area

    required property var pane

    anchors.fill: parent
    z: -1
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: mouse => {
        pane.focusList();
        pane.picked = {};
        if (mouse.button === Qt.RightButton) {
            const at = mapToItem(pane.app.contentItem, mouse.x, mouse.y);
            pane.app.showMenu(null, at.x, at.y);
        }
    }
}
