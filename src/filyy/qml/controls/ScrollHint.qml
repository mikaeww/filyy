pragma ComponentBehavior: Bound

import QtQuick
import "../theme"

// A thin position hint beside a scrolling view; brighter while it moves. Not a scrollbar to drag.
Rectangle {
    id: hint

    required property Flickable flick

    visible: flick.visible && flick.contentHeight > flick.height
    x: flick.x + flick.width - width - 2
    y: flick.y + flick.visibleArea.yPosition * flick.height
    width: 3
    height: Math.max(Theme.space5, flick.visibleArea.heightRatio * flick.height)
    radius: 1
    color: Theme.faint
    opacity: flick.moving ? 0.8 : 0.35

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.motionFast
        }
    }
}
