pragma ComponentBehavior: Bound

import QtQuick
import "../theme"
import "../browser"

// Every tab's panes, only the current tab visible: one Browser, or two side by side or stacked with a gap between
// them. While a tab is dragged over, the half it would take is lit.
Item {
    id: root

    required property var app
    required property var model

    function tabAt(index) {
        return index >= 0 && tabs.count > index ? tabs.itemAt(index) : null;
    }

    Rectangle {
        visible: root.app.tabDropZone !== ""
        x: root.app.tabDropZone === "right" ? root.width / 2 + Theme.space2 : 0
        y: root.app.tabDropZone === "bottom" ? root.height / 2 + Theme.space2 : 0
        width: root.app.tabDropZone === "right" ? root.width / 2 - Theme.space2 : root.width
        height: root.app.tabDropZone === "bottom" ? root.height / 2 - Theme.space2 : root.height
        z: 50
        radius: Theme.radius
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
    }

    Repeater {
        id: tabs

        model: root.model

        Item {
            id: tabItem

            required property int index
            required property string start
            required property string second
            required property bool split
            required property bool vertical
            property var lastPane: first
            readonly property alias first: first
            readonly property var secondPane: secondLoader.item

            width: root.width
            height: root.height
            visible: index === root.app.tabIndex

            onVisibleChanged: if (visible && root.app.pane !== lastPane)
                Qt.callLater(() => root.app.switchTab(index))

            Browser {
                id: first

                app: root.app
                startPath: tabItem.start
                width: tabItem.split && !tabItem.vertical ? Math.floor((parent.width - Theme.space3) / 2) : parent.width
                height: tabItem.split && tabItem.vertical ? Math.floor((parent.height - Theme.space3) / 2) : parent.height
                Component.onCompleted: if (!root.app.pane)
                    root.app.focusPane(first)
            }

            Loader {
                id: secondLoader

                active: tabItem.split
                x: tabItem.vertical ? 0 : first.width + Theme.space3
                y: tabItem.vertical ? first.height + Theme.space3 : 0
                width: parent.width - x
                height: parent.height - y
                onActiveChanged: if (!active && root.app.pane !== tabItem.first)
                    root.app.focusPane(tabItem.first)

                sourceComponent: Browser {
                    app: root.app
                    startPath: tabItem.second
                    startView: first.view
                }
            }
        }
    }
}
