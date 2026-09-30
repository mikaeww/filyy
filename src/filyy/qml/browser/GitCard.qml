pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../motion"
import "../format.js" as Format

// A quiet card while inside a git repository: branch, the last commit, when it happened, what is uncommitted.
Rectangle {
    id: root

    required property var info
    readonly property bool shown: info && info.repo !== undefined

    height: body.implicitHeight + 2 * Theme.space3
    radius: Theme.radius
    color: Theme.raise2
    visible: reveal.value > 0.001
    opacity: Math.min(1, reveal.value)
    transform: Translate {
        y: Theme.reducedMotion ? 0 : (1 - reveal.value) * Theme.space2
    }

    onShownChanged: reveal.target = shown ? 1 : 0

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
        width: parent.width - 2 * Theme.space3
        spacing: Theme.space1

        Row {
            width: parent.width
            spacing: Theme.space2

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.glyph.git
                color: Theme.fg
                font.family: Theme.iconFont
                font.pixelSize: Theme.fsBody
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - branch.implicitWidth - 2 * Theme.space2 - Theme.fsBody)
                text: root.info.repo ?? ""
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBody
                font.bold: true
            }

            Text {
                id: branch

                anchors.verticalCenter: parent.verticalCenter
                visible: (root.info.branch ?? "") !== ""
                text: Theme.glyph.branch + " " + (root.info.branch ?? "")
                color: Theme.sub
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
            }
        }

        Text {
            width: parent.width
            text: root.info.subject || Format.tr(I18n.strings, "Noch kein Commit")
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBody
        }

        Text {
            width: parent.width
            visible: (root.info.hash ?? "") !== ""
            text: (root.info.hash ?? "") + "  ·  " + Format.ago(I18n.strings, root.info.time ?? 0) + "  ·  " + (root.info.author ?? "")
            elide: Text.ElideRight
            color: Theme.faint
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
        }

        Text {
            visible: (root.info.changes ?? -1) >= 0
            text: root.info.changes === 0 ? Format.tr(I18n.strings, "Alles committet") : Format.tr(I18n.strings, root.info.changes === 1 ? "{n} offene Änderung" : "{n} offene Änderungen", {
                n: root.info.changes
            })
            color: root.info.changes === 0 ? Theme.sub : Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            font.bold: root.info.changes > 0
        }
    }
}
