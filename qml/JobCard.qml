import QtQuick
import Filyy
import "Util.js" as Util

// One running copy or move: what, where to, how far, how fast; pause and cancel.
Rectangle {
    id: root

    // One row of the job model in Main.qml.
    required property int jobId
    required property string kind
    required property string jobState
    required property int count
    required property string folder
    required property string current
    required property real done
    required property real total
    required property real rate
    readonly property real fraction: total > 0 ? Math.min(1, done / total) : 0
    readonly property bool paused: jobState === "paused"
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
            text: {
                const what = Util.tr(I18n.strings, ({ copy: "Kopiere {items} nach {folder}", move: "Verschiebe {items} nach {folder}",
                                                     duplicate: "Dupliziere {items}", extract: "Entpacke {items} nach {folder}" })[root.kind], {
                    items: Util.tr(I18n.strings, root.count === 1 ? "{n} Element" : "{n} Elemente", { n: root.count }),
                    folder: root.folder.slice(root.folder.lastIndexOf("/") + 1)
                })
                return root.paused ? Util.tr(I18n.strings, "Pausiert: {what}", { what: what }) : what
            }
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.current
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
            text: Util.tr(I18n.strings, "{done} von {total}", { done: Util.size(root.done), total: Util.size(root.total) })
                + (root.paused || root.rate < 1 ? "" : "  ·  " + Util.size(root.rate) + "/s")
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
            label: root.paused ? Util.tr(I18n.strings, "Fortsetzen") : Util.tr(I18n.strings, "Pausieren")
            onClicked: Jobs.pause(root.jobId, !root.paused)
        }

        IconButton {
            glyph: Util.glyphs.cancel
            label: Util.tr(I18n.strings, "Abbrechen")
            onClicked: Jobs.cancel(root.jobId)
        }
    }
}
