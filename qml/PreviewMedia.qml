import QtQuick
import QtMultimedia
import Filyy
import "Util.js" as Util

// Video and audio for quick look; loaded on demand so a system without Qt Multimedia only loses this part.
Item {
    id: root

    property string path: ""
    property bool video: false

    function toggle() {
        player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
    }

    function seek(seconds) {
        player.position = Math.max(0, Math.min(player.duration, player.position + seconds * 1000))
    }

    Component.onDestruction: player.stop()

    MediaPlayer {
        id: player
        source: root.path ? Util.fileUrl(root.path) : ""
        audioOutput: AudioOutput {}
        onSourceChanged: if (source.toString()) play()
        videoOutput: output
    }

    VideoOutput {
        id: output
        visible: root.video
        anchors.fill: parent
        anchors.bottomMargin: 40
    }

    FileIcon {
        visible: !root.video
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -20
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
        height: 32
        spacing: 12

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            glyph: player.playbackState === MediaPlayer.PlayingState ? Util.glyphs.pause : Util.glyphs.play
            label: Util.tr(I18n.strings, "Abspielen")
            onClicked: root.toggle()
        }

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 32 - time.width - 36
            height: 4
            radius: Theme.square ? 0 : 2
            color: Qt.alpha(Theme.fg, 0.1)

            Rectangle {
                width: player.duration > 0 ? parent.width * player.position / player.duration : 0
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => player.position = player.duration * Math.max(0, Math.min(1, (mouse.x - 8) / track.width))
            }
        }

        Text {
            id: time
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(new Date(player.position), "mm:ss") + " / " + Qt.formatTime(new Date(player.duration), "mm:ss")
            color: Theme.fgMuted
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
    }
}
