pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../controls"
import "../browser"
import "../paths.js" as Paths
import "../format.js" as Format

// Content search with ripgrep below one folder: results stream in grouped by file; Enter shows the file in its
// folder, Ctrl+Enter opens it. The match is set in bold, the rest of the line stays faint.
Sheet {
    id: root

    required property var app
    property bool active: false
    property string folder: ""
    property int searchId: -1
    property var rows: []
    property int index: -1
    property bool regex: false
    property bool hidden: false
    property string status: ""

    function start(inFolder, query) {
        folder = inFolder;
        rows = [];
        index = -1;
        status = Search.ready() ? "" : Format.tr(I18n.strings, "ripgrep (rg) ist nicht installiert");
        field.text = query;
        active = true;
        field.input.forceActiveFocus();
    }

    function run() {
        rows = [];
        index = -1;
        status = field.text.trim() ? Format.tr(I18n.strings, "Suche …") : "";
        searchId = Search.start(folder, field.text, regex, hidden);
    }

    function step(delta) {
        const matches = rows.map((row, i) => row.file ? -1 : i).filter(i => i >= 0);
        if (!matches.length)
            return;
        const at = matches.indexOf(index);
        index = matches[(at + delta + matches.length) % matches.length];
    }

    function take(openIt) {
        const row = rows[index];
        if (!row || row.file)
            return;
        close();
        if (openIt) {
            Files.open(row.path);
            return;
        }
        app.pane.pendingSelect = row.path;
        app.pane.navigate(Paths.parentOf(row.path));
    }

    function close() {
        Search.cancel();
        active = false;
        if (app.pane)
            app.pane.focusList();
    }

    function marked(row) {
        const text = row.text.replace(/\t/g, "  ");
        return Format.escapeHtml(text.slice(0, row.start).replace(/^\s+/, "")) + "<b><font color=\"" + Theme.fg + "\">" + Format.escapeHtml(text.slice(row.start, row.end)) + "</font></b>" + Format.escapeHtml(text.slice(row.end));
    }

    open: active
    cardWidth: 820
    cardTop: Math.round(height * 0.1)
    onDismissed: close()
    onKeyPressed: event => {
        if (event.key === Qt.Key_Down)
            step(1);
        else if (event.key === Qt.Key_Up)
            step(-1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            take(event.modifiers & Qt.ControlModifier);
        else
            return;
        event.accepted = true;
    }

    Connections {
        function onFound(id, matches) {
            if (id !== root.searchId)
                return;
            const rows = root.rows.slice();
            for (const match of matches) {
                const last = rows.length ? rows[rows.length - 1] : null;
                if (!last || last.path !== match.path)
                    rows.push({
                        file: true,
                        path: match.path,
                        relative: match.relative
                    });
                rows.push(match);
            }
            root.rows = rows;
            if (root.index < 0)
                root.step(1);
        }

        function onFinished(id, total, truncated) {
            if (id === root.searchId)
                root.status = !total ? (field.text.trim() ? Format.tr(I18n.strings, "Nichts gefunden") : "") : Format.tr(I18n.strings, truncated ? "{n} Treffer, bei {n} abgebrochen" : "{n} Treffer", {
                    n: total
                });
        }

        target: Search
    }

    Timer {
        id: delay

        interval: 250
        onTriggered: root.run()
    }

    Row {
        width: parent.width
        spacing: Theme.space2

        Field {
            id: field

            width: parent.width - regexChip.width - hiddenChip.width - 2 * Theme.space2
            size: Theme.fsTitle
            glyph: Theme.glyph.textSearch
            placeholder: Format.tr(I18n.strings, "In Dateien suchen …")
            onTextChanged: if (root.active)
                delay.restart()
        }

        Chip {
            id: regexChip

            anchors.verticalCenter: parent.verticalCenter
            label: "Regex"
            active: root.regex
            onClicked: {
                root.regex = !root.regex;
                root.run();
            }
        }

        Chip {
            id: hiddenChip

            anchors.verticalCenter: parent.verticalCenter
            label: Format.tr(I18n.strings, "Versteckte")
            active: root.hidden
            onClicked: {
                root.hidden = !root.hidden;
                root.run();
            }
        }
    }

    Text {
        width: parent.width
        text: Format.tr(I18n.strings, "in {folder}", {
            folder: root.folder.replace(root.app.home, "~")
        }) + (root.status ? "  ·  " + root.status : "")
        elide: Text.ElideMiddle
        color: Theme.sub
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSmall
    }

    ListView {
        id: list

        width: parent.width
        height: Math.min(Math.round(root.height * 0.6), Math.max(0, contentHeight))
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.rows
        currentIndex: root.index
        onCurrentIndexChanged: if (currentIndex >= 0)
            positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: result

            required property var modelData
            required property int index

            width: list.width
            height: modelData.file ? Theme.rowH : Theme.ctlH
            radius: Theme.radiusSmall
            color: Theme.tint(index === root.index, !modelData.file && pointer.containsMouse)

            FileIcon {
                id: icon

                visible: result.modelData.file === true
                x: Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSmall
                height: Theme.iconSmall
                kind: "text"
            }

            Text {
                visible: result.modelData.file === true
                anchors.left: icon.right
                anchors.leftMargin: Theme.space2
                anchors.right: parent.right
                anchors.rightMargin: Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                text: result.modelData.relative ?? ""
                elide: Text.ElideMiddle
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBody
                font.bold: true
            }

            Text {
                id: lineNumber

                visible: !result.modelData.file
                x: Theme.space2
                width: Theme.iconSmall + 3 * Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: result.modelData.line ?? ""
                color: Theme.faint
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsSmall
            }

            Text {
                visible: !result.modelData.file
                anchors.left: lineNumber.right
                anchors.leftMargin: Theme.space3
                anchors.right: parent.right
                anchors.rightMargin: Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.StyledText
                elide: Text.ElideRight
                // Only the match is marked up; everything around it is escaped first.
                text: result.modelData.file ? "" : root.marked(result.modelData)
                color: Theme.sub
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsSmall
            }

            MouseArea {
                id: pointer

                anchors.fill: parent
                enabled: !result.modelData.file
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    root.index = result.index;
                    root.take(mouse.modifiers & Qt.ControlModifier);
                }
            }
        }
    }

    Text {
        text: Format.tr(I18n.strings, "↑ ↓  Treffer     Enter  Datei zeigen     Strg+Enter  Öffnen")
        color: Theme.faint
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSmall
    }
}
