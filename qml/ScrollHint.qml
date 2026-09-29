import QtQuick
import Filyy

Rectangle {
    required property Flickable flick

    visible: flick.visible && flick.contentHeight > flick.height
    x: flick.x + flick.width + 4
    y: flick.y + flick.visibleArea.yPosition * flick.height
    width: 3
    height: Math.max(24, flick.visibleArea.heightRatio * flick.height)
    radius: Theme.square ? 0 : 1.5
    color: Theme.fgMuted
    opacity: flick.moving ? 0.5 : 0.25
    Behavior on opacity { NumberAnimation { duration: Theme.quickMs } }
}
