pragma ComponentBehavior: Bound

import QtQuick
import "../theme"
import "curves.js" as Curves

// Follows `target` on a damped spring driven by the render loop. A new target keeps the current position and
// velocity, so a retarget never jerks. Reduced motion jumps straight to the target.
Item {
    id: spring

    property real target: 0
    // Set once at start, never bound: a binding to target could update before onTargetChanged sees the old value.
    property real value: 0
    property real velocity: 0
    // Smallest visible difference in the value's own unit (pixels by default).
    property real precision: 0.1
    property var motion: Theme.glide
    property bool instant: Theme.reducedMotion

    property real _error: 0
    property real _errorVelocity: 0

    function jump(to) {
        frame.stop();
        value = to;
        velocity = 0;
        target = to;
    }

    Component.onCompleted: value = target

    onTargetChanged: {
        if (instant) {
            frame.stop();
            value = target;
            velocity = 0;
            return;
        }
        _error = value - target;
        _errorVelocity = velocity;
        frame.restart();
    }

    FrameAnimation {
        id: frame

        onTriggered: {
            const state = Curves.spring(spring._error, spring._errorVelocity, spring.motion.response, spring.motion.damping, frame.elapsedTime);
            if (Curves.settled(state, spring.precision)) {
                frame.stop();
                spring.value = spring.target;
                spring.velocity = 0;
                return;
            }
            spring.value = spring.target + state.x;
            spring.velocity = state.v;
        }
    }
}
