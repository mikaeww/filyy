import QtQuick
import Filyy

// The app's ghost: floats, blinks, looks around while busy and gets sad in empty folders.
Item {
    id: root

    // "idle" | "sad" | "busy"
    property string mood: "idle"
    // A whole multiple of the 32 px grid keeps every pixel square.
    property int size: 32
    property bool blinking: false
    property bool lookRight: false
    property real phase: 0
    readonly property int pixel: size / 32
    readonly property bool moving: !Theme.reducedMotion && visible
    readonly property string frame: mood === "sad" ? "sad"
        : mood === "busy" ? (lookRight ? "busy-right" : "busy-left")
        : blinking ? "blink" : "idle"

    width: size
    height: size + 4 * pixel

    Image {
        width: root.size
        height: root.size
        // Bobs in whole grid pixels, like a sprite, instead of sliding smoothly.
        y: (2 + Math.round(Math.sin(root.phase) * 2)) * root.pixel
        source: "../assets/ghost/" + root.frame + ".svg"
        sourceSize: Qt.size(root.size, root.size)
        smooth: false
    }

    NumberAnimation on phase {
        from: 0
        to: 2 * Math.PI
        duration: root.mood === "busy" ? 1200 : 2600
        loops: Animation.Infinite
        running: root.moving && root.mood !== "sad"
    }

    Timer {
        interval: 2600 + Math.random() * 3400
        repeat: true
        running: root.moving && root.mood === "idle"
        onTriggered: {
            root.blinking = true
            unblink.restart()
            interval = 2600 + Math.random() * 3400
        }
    }

    Timer {
        id: unblink
        interval: 140
        onTriggered: root.blinking = false
    }

    Timer {
        interval: 420
        repeat: true
        running: root.moving && root.mood === "busy"
        onTriggered: root.lookRight = !root.lookRight
    }
}
