pragma ComponentBehavior: Bound

import QtQuick
import "../../paths.js" as Paths

// Click, multi-select, context menu, middle click and drag-out for one entry, shared by every view.
MouseArea {
    id: area

    required property var pane
    required property int index
    required property var entry
    property int pressModifiers: 0

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    drag.target: proxy
    drag.threshold: 8
    // Without this the view steals the drag for scrolling and files never leave the window.
    preventStealing: true

    onPressed: mouse => {
        pane.focusList();
        pressModifiers = mouse.modifiers;
        if (mouse.button === Qt.MiddleButton) {
            if (entry.dir)
                pane.app.newTab(entry.path);
            return;
        }
        // A press on an already picked entry keeps the group so it can be dragged together.
        if (!pane.picked[entry.path] || mouse.modifiers !== Qt.NoModifier)
            pane.select(index, mouse.modifiers);
        if (mouse.button === Qt.RightButton) {
            const at = mapToItem(pane.app.contentItem, mouse.x, mouse.y);
            pane.app.showMenu(entry, at.x, at.y);
        }
    }
    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton && pressModifiers === Qt.NoModifier && pane.pickedPaths.length > 1)
            pane.select(index, 0);
    }
    onDoubleClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            pane.activate(entry);
    }
    onReleased: {
        proxy.x = 0;
        proxy.y = 0;
    }

    Item {
        id: proxy

        Drag.active: area.drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.mimeData: ({
                "text/uri-list": area.pane.targets.map(p => Paths.fileUrl(p)).join("\r\n")
            })
    }
}
