import QtQuick
import Filyy
import "Util.js" as Util

// Follows `target` on a spring; retargeting mid-flight starts from the current value.
Item {
    id: root

    property real target: 0
    property var spring: Util.glide
    property bool animated: true
    property real start: target
    property real end: target
    property real phase: 1
    readonly property real value: start + (end - start) * spring.at(phase)

    onTargetChanged: {
        if (!animated || Theme.reducedMotion) {
            anim.stop()
            start = end = target
            phase = 1
            return
        }
        start = value
        end = target
        anim.restart()
    }

    NumberAnimation {
        id: anim
        target: root
        property: "phase"
        from: 0
        to: 1
        duration: root.spring.ms
    }
}
