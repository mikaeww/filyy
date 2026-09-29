import QtQuick
import Filyy
import "Util.js" as Util

// A quiet card while inside a git repository: branch, the last commit and when it happened.
Rectangle {
    id: root

    required property var info
    property real reveal: 0
    readonly property bool shown: info && info.repo !== undefined

    width: 300
    height: body.implicitHeight + 24
    radius: Theme.control + 4
    color: Theme.panelBg
    border.width: 1
    border.color: Theme.hairline
    visible: reveal > 0
    opacity: reveal
    scale: 0.97 + 0.03 * reveal

    onShownChanged: shown ? (hide.stop(), show.restart()) : (show.stop(), hide.restart())
    NumberAnimation { id: show; target: root; property: "reveal"; to: 1; duration: Theme.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
    NumberAnimation { id: hide; target: root; property: "reveal"; to: 0; duration: Theme.exitMs; easing.type: Easing.OutCubic }

    Column {
        id: body

        x: 12
        y: 12
        width: parent.width - 24
        spacing: 5

        Row {
            width: parent.width
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Util.glyphs.git
                color: Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: 15
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - branch.width - 32)
                text: root.info.repo ?? ""
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: branch
                anchors.verticalCenter: parent.verticalCenter
                visible: (root.info.branch ?? "") !== ""
                width: branchText.implicitWidth + 26
                height: 20
                radius: Theme.square ? 0 : height / 2
                color: Qt.alpha(Theme.accent, 0.14)

                Text {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: Util.glyphs.branch
                    color: Theme.fgMuted
                    font.family: Theme.iconFont
                    font.pixelSize: 11
                }

                Text {
                    id: branchText
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.info.branch ?? ""
                    color: Theme.fg
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                }
            }
        }

        Text {
            width: parent.width
            text: root.info.subject || "Noch kein Commit"
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 12
        }

        Text {
            width: parent.width
            visible: (root.info.hash ?? "") !== ""
            text: (root.info.hash ?? "") + "  ·  " + Util.ago(root.info.time ?? 0) + "  ·  " + (root.info.author ?? "")
            elide: Text.ElideRight
            color: Theme.fgMuted
            font.family: Theme.fontMono
            font.pixelSize: 10
        }

        Text {
            visible: (root.info.changes ?? -1) >= 0
            text: root.info.changes === 0 ? "Alles committet" : root.info.changes + (root.info.changes === 1 ? " offene Änderung" : " offene Änderungen")
            color: root.info.changes === 0 ? Theme.fgMuted : Theme.warn
            font.family: Theme.fontUi
            font.pixelSize: 11
        }
    }
}
