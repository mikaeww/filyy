import QtQuick
import Filyy
import "Util.js" as Util

// One running copy or move: what, where to, how far, how fast; pause and cancel.
Rectangle {
    id: root

    required property var job
    readonly property real fraction: job.total > 0 ? Math.min(1, job.done / job.total) : 0
    readonly property bool paused: job.state === "paused"
    property real reveal: 0

    width: 340
    height: body.implicitHeight + 28
    radius: Theme.control + 4
    color: Theme.panelBg
    border.width: 1
    border.color: Theme.hairline
    opacity: reveal
    scale: 0.97 + 0.03 * reveal

    Component.onCompleted: show.start()
    NumberAnimation { id: show; target: root; property: "reveal"; to: 1; duration: Theme.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }

    Column {
        id: body

        x: 14
        y: 14
        width: parent.width - 28 - buttons.width - 8
        spacing: 6

        Text {
            width: parent.width
            text: (root.paused ? "Pausiert: " : "")
                + ({ copy: "Kopiere ", move: "Verschiebe ", duplicate: "Dupliziere " })[root.job.kind]
                + root.job.count + (root.job.count === 1 ? " Element" : " Elemente")
                + (root.job.kind === "duplicate" ? "" : " nach " + root.job.folder.slice(root.job.folder.lastIndexOf("/") + 1))
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.job.current
            elide: Text.ElideMiddle
            color: Theme.fgMuted
            font.family: Theme.fontUi
            font.pixelSize: 11
        }

        Rectangle {
            width: parent.width
            height: 4
            radius: Theme.square ? 0 : 2
            color: Qt.alpha(Theme.fg, 0.08)

            Rectangle {
                width: parent.width * root.fraction
                height: parent.height
                radius: parent.radius
                color: root.paused ? Theme.fgMuted : Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.quickMs } }
            }
        }

        Text {
            text: Util.size(root.job.done) + " von " + Util.size(root.job.total)
                + (root.paused || root.job.rate < 1 ? "" : "  ·  " + Util.size(root.job.rate) + "/s")
            color: Theme.fgMuted
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
    }

    Row {
        id: buttons

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        IconButton {
            glyph: root.paused ? Util.glyphs.play : Util.glyphs.pause
            label: root.paused ? "Fortsetzen" : "Pausieren"
            onClicked: Jobs.pause(root.job.id, !root.paused)
        }

        IconButton {
            glyph: Util.glyphs.cancel
            label: "Abbrechen"
            onClicked: Jobs.cancel(root.job.id)
        }
    }
}
