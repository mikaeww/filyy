pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Filyy
import "../theme"
import "../controls"
import "../browser"
import "../paths.js" as Paths
import "../format.js" as Format

// Video and audio for quick look; loaded on demand so a system without Qt Multimedia only loses this part.
Item {
    id: root

    property string path: ""
    property bool video: false

    function toggle() {
        if (player.playbackState === MediaPlayer.PlayingState)
            player.pause();
        else
            player.play();
    }

    Component.onDestruction: player.stop()

    MediaPlayer {
        id: player

        source: root.path ? Paths.fileUrl(root.path) : ""
        audioOutput: AudioOutput {}
        onSourceChanged: if (source.toString())
            play()
        videoOutput: output
    }

    VideoOutput {
        id: output

        visible: root.video
        anchors.fill: parent
        anchors.bottomMargin: Theme.ctlH + Theme.space3
    }

    FileIcon {
        visible: !root.video
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Theme.space5
        width: 96
        height: 96
        kind: "audio"
    }

    MouseArea {
        anchors.fill: output
        onClicked: root.toggle()
    }

    Row {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.ctlH
        spacing: Theme.space3

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            glyph: player.playbackState === MediaPlayer.PlayingState ? Theme.glyph.pause : Theme.glyph.play
            label: Format.tr(I18n.strings, "Abspielen")
            onClicked: root.toggle()
        }

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.ctlH - time.width - 2 * Theme.space3
            height: Theme.space1
            radius: Theme.radiusBar
            color: Theme.raise3

            Rectangle {
                width: player.duration > 0 ? parent.width * player.position / player.duration : 0
                height: parent.height
                radius: parent.radius
                color: Theme.fg
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.space2
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => player.position = player.duration * Math.max(0, Math.min(1, (mouse.x - Theme.space2) / track.width))
            }
        }

        Text {
            id: time

            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(new Date(player.position), "mm:ss") + " / " + Qt.formatTime(new Date(player.duration), "mm:ss")
            color: Theme.sub
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            font.features: {
                "tnum": 1
            }
        }
    }
}
