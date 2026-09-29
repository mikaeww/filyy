import QtQuick
import Filyy
import "Util.js" as Util

// Space opens a large preview of the entry under the cursor; ←/→ step through the folder.
Sheet {
    id: root

    required property var app
    property var items: []
    property int index: 0
    property int page: 0
    readonly property var entry: items[index] ?? null
    readonly property string kind: entry ? entry.kind : ""
    readonly property var text: entry && ["text", "code", "file"].includes(kind) ? Preview.text(entry.path) : null
    readonly property bool showsText: text !== null && !text.binary
    readonly property bool media: kind === "video" || kind === "audio"

    function show(list, at) {
        items = list
        index = at
        page = 0
        open = true
    }

    function step(delta) {
        if (!items.length)
            return
        index = (index + delta + items.length) % items.length
        page = 0
        app.pane.select(index, 0)
    }

    cardWidth: Math.round(app.width * 0.82)
    onDismissed: {
        open = false
        app.pane.focusList()
    }

    onKeyPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Escape) root.dismissed()
        else if (event.key === Qt.Key_Right) step(1)
        else if (event.key === Qt.Key_Left) step(-1)
        else if (kind === "pdf" && (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown)) page = Math.min(pdf.frameCount - 1, page + 1)
        else if (kind === "pdf" && (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp)) page = Math.max(0, page - 1)
        else if (media && event.key === Qt.Key_Return) mediaLoader.item.toggle()
        else return
        event.accepted = true
    }

    Item {
        width: parent.width
        height: 36

        FileIcon {
            id: headIcon
            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter
            kind: root.kind || "file"
        }

        Column {
            anchors.left: headIcon.right
            anchors.leftMargin: 12
            anchors.right: counter.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: root.entry ? root.entry.name : ""
                elide: Text.ElideMiddle
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: root.entry ? (root.entry.dir ? "Ordner" : Util.size(root.entry.size)) + "  ·  " + Files.mimeName(root.entry.path)
                    + (root.kind === "pdf" && pdf.frameCount > 0 ? "  ·  Seite " + (root.page + 1) + " / " + pdf.frameCount : "") : ""
                elide: Text.ElideRight
                color: Theme.fgMuted
                font.family: Theme.fontUi
                font.pixelSize: 11
            }
        }

        Text {
            id: counter
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (root.index + 1) + " / " + root.items.length + "   ← →"
            color: Theme.fgMuted
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
    }

    Rectangle {
        width: parent.width
        height: Math.round(root.app.height * 0.72)
        radius: Theme.control
        color: Qt.alpha(Theme.fg, 0.03)
        clip: true

        Image {
            anchors.fill: parent
            anchors.margins: 12
            visible: root.kind === "image"
            source: visible ? Util.fileUrl(root.entry.path) : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
        }

        Loader {
            id: pdf
            readonly property int frameCount: item ? item.pageCount : 0
            anchors.fill: parent
            anchors.margins: 12
            active: root.open && root.kind === "pdf"
            source: "PreviewPdf.qml"
            onLoaded: {
                item.path = Qt.binding(() => root.entry.path)
                item.page = Qt.binding(() => root.page)
            }
        }

        Loader {
            id: mediaLoader
            anchors.fill: parent
            anchors.margins: 12
            active: root.open && root.media
            source: "PreviewMedia.qml"
            onLoaded: {
                item.path = Qt.binding(() => root.entry.path)
                item.video = Qt.binding(() => root.kind === "video")
            }
        }

        Flickable {
            id: textView
            anchors.fill: parent
            anchors.margins: 12
            visible: root.showsText
            contentWidth: Math.max(width, code.implicitWidth)
            contentHeight: code.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            TextEdit {
                id: code
                text: root.showsText ? root.text.text + (root.text.truncated ? "\n\n… gekürzt, nur die ersten 256 KB" : "") : ""
                readOnly: true
                selectByMouse: true
                color: Theme.fg
                selectionColor: Qt.alpha(Theme.accent, 0.35)
                font.family: Theme.fontMono
                font.pixelSize: 12
                textFormat: TextEdit.PlainText
                // The highlighter follows the document's own edits, so it is only swapped when the language
                // changes; re-attaching on every text change would recurse through its own formatting.
                readonly property string language: root.showsText ? root.text.language : ""
                onLanguageChanged: Preview.highlight(textDocument, language)
                Component.onCompleted: Preview.highlight(textDocument, language)
            }
        }

        ScrollHint { flick: textView }

        Column {
            anchors.centerIn: parent
            visible: !root.showsText && !["image", "pdf", "video", "audio"].includes(root.kind)
            spacing: 10

            FileIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 96
                kind: root.kind || "file"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !root.entry ? "" : root.entry.dir ? Files.count(root.entry.path) + " Elemente"
                    : "Keine Vorschau für diesen Dateityp"
                color: Theme.fgMuted
                font.family: Theme.fontUi
                font.pixelSize: 12
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.entry !== null
                text: root.entry ? "Geändert " + Qt.formatDateTime(new Date(root.entry.mtime), "dd.MM.yyyy  HH:mm") : ""
                color: Theme.fgMuted
                font.family: Theme.fontMono
                font.pixelSize: 11
            }
        }
    }
}
