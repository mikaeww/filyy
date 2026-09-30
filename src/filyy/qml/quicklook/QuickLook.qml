pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../controls"
import "../browser"
import "../paths.js" as Paths
import "../format.js" as Format

// Space opens a large preview of the entry under the cursor; ←/→ step through the folder. Images, PDFs, video,
// audio, text and code, and what a folder or archive holds; everything else says there is no preview.
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
    // Space on a folder (or an archive) shows what is inside it.
    readonly property bool folderish: entry !== null && (entry.dir || Files.isArchive(entry.path))
    readonly property var inside: open && folderish ? Files.peek(entry.path) : []

    function show(list, at) {
        items = list;
        index = at;
        page = 0;
        open = true;
    }

    function step(delta) {
        if (!items.length)
            return;
        index = (index + delta + items.length) % items.length;
        page = 0;
        app.pane.select(index, 0);
    }

    cardWidth: Math.round(app.width * 0.82)
    onDismissed: {
        open = false;
        app.pane.focusList();
    }
    onKeyPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Escape)
            root.dismissed();
        else if (event.key === Qt.Key_Right)
            step(1);
        else if (event.key === Qt.Key_Left)
            step(-1);
        else if (kind === "pdf" && (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown))
            page = Math.min(pdf.frameCount - 1, page + 1);
        else if (kind === "pdf" && (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp))
            page = Math.max(0, page - 1);
        else if (media && event.key === Qt.Key_Return)
            mediaLoader.player.toggle();
        else
            return;
        event.accepted = true;
    }

    Item {
        width: parent.width
        height: Theme.rowH

        FileIcon {
            id: headIcon

            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter
            kind: root.kind || "file"
        }

        Column {
            anchors.left: headIcon.right
            anchors.leftMargin: Theme.space3
            anchors.right: counter.left
            anchors.rightMargin: Theme.space3
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: root.entry ? root.entry.name : ""
                elide: Text.ElideMiddle
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsTitle
                font.bold: true
            }

            Text {
                width: parent.width
                text: !root.entry ? "" : (root.folderish ? Format.tr(I18n.strings, "{n} Elemente", {
                        n: root.inside.length
                    }) : Format.size(root.entry.size) + "  ·  " + Files.mimeName(root.entry.path)) + (root.kind === "pdf" && pdf.frameCount > 0 ? "  ·  " + Format.tr(I18n.strings, "Seite {page} / {count}", {
                        page: root.page + 1,
                        count: pdf.frameCount
                    }) : "")
                elide: Text.ElideRight
                color: Theme.sub
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
            }
        }

        Text {
            id: counter

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (root.index + 1) + " / " + root.items.length + "   ← →"
            color: Theme.faint
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            font.features: {
                "tnum": 1
            }
        }
    }

    Rectangle {
        width: parent.width
        height: Math.round(root.app.height * 0.72)
        radius: Theme.radiusSmall
        color: Theme.raise2
        clip: true

        Image {
            anchors.fill: parent
            anchors.margins: Theme.space3
            visible: root.kind === "image"
            source: visible ? Paths.fileUrl(root.entry.path) : ""
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
        }

        Loader {
            id: pdf

            // var, not QObject: the loaded page viewer adds pageCount.
            readonly property var viewer: item
            readonly property int frameCount: viewer ? viewer.pageCount : 0

            anchors.fill: parent
            anchors.margins: Theme.space3
            active: root.open && root.kind === "pdf"
            source: "PreviewPdf.qml"
            onLoaded: {
                item.path = Qt.binding(() => root.entry.path);
                item.page = Qt.binding(() => root.page);
            }
        }

        Loader {
            id: mediaLoader

            readonly property var player: item

            anchors.fill: parent
            anchors.margins: Theme.space3
            active: root.open && root.media
            source: "PreviewMedia.qml"
            onLoaded: {
                item.path = Qt.binding(() => root.entry.path);
                item.video = Qt.binding(() => root.kind === "video");
            }
        }

        Flickable {
            id: textView

            anchors.fill: parent
            anchors.margins: Theme.space3
            visible: root.showsText
            contentWidth: Math.max(width, code.implicitWidth)
            contentHeight: code.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            TextEdit {
                id: code

                // The highlighter follows the document's own edits, so it is only swapped when the language or the
                // palette changes; re-attaching on every text change would recurse through its own formatting.
                readonly property string language: root.showsText ? root.text.language : ""

                text: root.showsText ? root.text.text + (root.text.truncated ? "\n\n" + Format.tr(I18n.strings, "… gekürzt, nur die ersten 256 KB") : "") : ""
                readOnly: true
                selectByMouse: true
                color: Theme.fg
                selectionColor: Theme.raise3
                selectedTextColor: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsBody
                textFormat: TextEdit.PlainText
                onLanguageChanged: Preview.highlight(textDocument, language, Theme.dark)
                Component.onCompleted: Preview.highlight(textDocument, language, Theme.dark)

                Connections {
                    function onDarkChanged() {
                        Preview.highlight(code.textDocument, code.language, Theme.dark);
                    }

                    target: Theme
                }
            }
        }

        ScrollHint {
            flick: textView
        }

        GridView {
            id: insideGrid

            anchors.fill: parent
            anchors.margins: Theme.space3
            visible: root.folderish && root.inside.length > 0
            model: visible ? root.inside : []
            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 112)))
            cellHeight: Theme.iconLarge + 2 * Theme.space3 + Theme.fsBody + Theme.space2
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: child

                required property var modelData

                width: insideGrid.cellWidth
                height: insideGrid.cellHeight

                FileIcon {
                    id: insideIcon

                    x: (parent.width - width) / 2
                    y: Theme.space3
                    width: Theme.iconLarge
                    height: Theme.iconLarge
                    kind: child.modelData.kind
                }

                Text {
                    x: Theme.space1
                    y: insideIcon.y + insideIcon.height + Theme.space2
                    width: parent.width - 2 * Theme.space1
                    horizontalAlignment: Text.AlignHCenter
                    text: child.modelData.name
                    elide: Text.ElideMiddle
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall
                }
            }
        }

        ScrollHint {
            flick: insideGrid
        }

        Column {
            anchors.centerIn: parent
            visible: !root.showsText && !["image", "pdf", "video", "audio"].includes(root.kind) && !insideGrid.visible
            spacing: Theme.space2

            FileIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 96
                kind: root.kind || "file"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !root.entry ? "" : root.entry.dir ? Format.tr(I18n.strings, "{n} Elemente", {
                    n: Files.count(root.entry.path)
                }) : Format.tr(I18n.strings, "Keine Vorschau für diesen Dateityp")
                color: Theme.sub
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBody
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.entry !== null
                text: root.entry ? Format.tr(I18n.strings, "Geändert {date}", {
                    date: Qt.formatDateTime(new Date(root.entry.mtime), "dd.MM.yyyy  HH:mm")
                }) : ""
                color: Theme.faint
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
            }
        }
    }
}
