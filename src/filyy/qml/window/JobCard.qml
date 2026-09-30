pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../motion"
import "../controls"
import "../format.js" as Format

// One running copy, move, duplicate or extract: what, where to, how far, how fast; pause and cancel.
Rectangle {
    id: root

    // One row of JobStack's model.
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

    width: 340
    height: body.implicitHeight + 2 * Theme.space3
    radius: Theme.radius
    color: Theme.raise2
    opacity: Math.min(1, reveal.value)
    transform: Translate {
        y: Theme.reducedMotion ? 0 : (1 - reveal.value) * Theme.space2
    }

    Component.onCompleted: reveal.target = 1

    Spring {
        id: reveal

        motion: Theme.settle
        instant: false
        precision: 0.002
    }

    Column {
        id: body

        x: Theme.space3
        y: Theme.space3
        width: parent.width - 2 * Theme.space3 - buttons.width - Theme.space2
        spacing: Theme.space1

        Text {
            width: parent.width
            text: {
                const what = Format.tr(I18n.strings, ({
                        copy: "Kopiere {items} nach {folder}",
                        move: "Verschiebe {items} nach {folder}",
                        duplicate: "Dupliziere {items}",
                        extract: "Entpacke {items} nach {folder}"
                    })[root.kind], {
                    items: Format.tr(I18n.strings, root.count === 1 ? "{n} Element" : "{n} Elemente", {
                        n: root.count
                    }),
                    folder: root.folder.slice(root.folder.lastIndexOf("/") + 1)
                });
                return root.paused ? Format.tr(I18n.strings, "Pausiert: {what}", {
                    what: what
                }) : what;
            }
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBody
            font.bold: true
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.current
            elide: Text.ElideMiddle
            color: Theme.sub
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
        }

        Rectangle {
            width: parent.width
            height: Theme.space1
            radius: Theme.radiusBar
            color: Theme.raise3

            Rectangle {
                width: parent.width * root.fraction
                height: parent.height
                radius: parent.radius
                color: root.paused ? Theme.sub : Theme.fg

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.motionFast
                    }
                }
            }
        }

        Text {
            text: Format.tr(I18n.strings, "{done} von {total}", {
                done: Format.size(root.done),
                total: Format.size(root.total)
            }) + (root.paused || root.rate < 1 ? "" : "  ·  " + Format.size(root.rate) + "/s")
            color: Theme.sub
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            font.features: {
                "tnum": 1
            }
        }
    }

    Row {
        id: buttons

        anchors.right: parent.right
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space1

        IconButton {
            glyph: root.paused ? Theme.glyph.play : Theme.glyph.pause
            label: root.paused ? Format.tr(I18n.strings, "Fortsetzen") : Format.tr(I18n.strings, "Pausieren")
            onClicked: Jobs.pause(root.jobId, !root.paused)
        }

        IconButton {
            glyph: Theme.glyph.cancel
            label: Format.tr(I18n.strings, "Abbrechen")
            onClicked: Jobs.cancel(root.jobId)
        }
    }
}
