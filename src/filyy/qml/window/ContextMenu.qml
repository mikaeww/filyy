pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../motion"
import "../paths.js" as Paths
import "../format.js" as Format

// The right-click menu for an entry, the empty folder, the trash or an archive. It settles in on a spring; a gap
// separates groups instead of a line, and destructive actions are told apart by weight, not by red.
Item {
    id: root

    required property var app
    property var items: []
    readonly property bool open: reveal.target > 0

    function t(text, values) {
        return Format.tr(I18n.strings, text, values);
    }

    function trashItems(p, entry) {
        if (!entry)
            return [
                {
                    label: t("Papierkorb leeren"),
                    glyph: Theme.glyph.trash,
                    strong: true,
                    enabled: p.entries.length > 0,
                    run: () => app.openSheet("empty")
                }
            ];
        return [
            {
                label: t("Vorschau"),
                glyph: Theme.glyph.preview,
                hint: t("Leertaste"),
                enabled: p.targets.length === 1,
                run: () => app.quickLook.show(p.shown, p.cursor)
            },
            {
                label: t("Wiederherstellen"),
                glyph: Theme.glyph.restore,
                run: () => Files.restore(p.targets)
            },
            {
                label: t("Herkunft öffnen"),
                glyph: Theme.glyph.open,
                enabled: p.targets.length === 1 && entry.original !== "",
                run: () => p.navigate(Paths.parentOf(entry.original))
            },
            {
                separator: true
            },
            {
                label: t("Endgültig löschen"),
                glyph: Theme.glyph.trash,
                hint: t("Entf"),
                strong: true,
                run: () => app.openSheet("purge")
            }
        ];
    }

    function archiveItems(p, entry) {
        if (!entry)
            return [
                {
                    label: t("Alles entpacken"),
                    glyph: Theme.glyph.extract,
                    run: () => Files.extractAll(app.archiveOf(p.path))
                }
            ];
        const other = app.otherPaneOf(p);
        return [
            {
                label: t("Öffnen"),
                glyph: Theme.glyph.open,
                hint: "Enter",
                enabled: p.targets.length === 1,
                run: () => p.activate(entry)
            },
            {
                separator: true
            },
            {
                label: t("Neben das Archiv entpacken"),
                glyph: Theme.glyph.extract,
                run: () => Files.extract(p.targets, Files.archiveFolder(p.path))
            },
            {
                label: t("In andere Seite entpacken"),
                glyph: Theme.glyph.split,
                enabled: other !== null && !other.readOnly,
                run: () => Files.extract(p.targets, other.path)
            }
        ];
    }

    function folderItems(p) {
        const list = p.view === "list";
        return [
            {
                label: t("Neuer Ordner"),
                glyph: Theme.glyph.newFolder,
                hint: t("Strg+Shift+N"),
                run: () => app.openSheet("mkdir")
            },
            {
                label: t("Einfügen"),
                glyph: Theme.glyph.paste,
                hint: t("Strg+V"),
                enabled: app.board.paths.length > 0,
                run: () => Files.paste(p.path)
            },
            {
                label: t("Terminal hier"),
                glyph: Theme.glyph.terminal,
                hint: "Shift+F4",
                run: () => Files.terminal(p.path)
            },
            {
                label: Undo.label ? t("Rückgängig: {label}", {
                    label: t(Undo.label)
                }) : t("Rückgängig"),
                glyph: Theme.glyph.undo,
                hint: t("Strg+Z"),
                enabled: Undo.label !== "",
                run: () => Undo.undo()
            },
            {
                separator: true
            },
            {
                label: p.showHidden ? t("Versteckte ausblenden") : t("Versteckte zeigen"),
                glyph: p.showHidden ? Theme.glyph.eyeOff : Theme.glyph.eye,
                hint: t("Strg+H"),
                run: () => p.toggleHidden()
            },
            {
                label: list ? t("Als Raster") : t("Als Liste"),
                glyph: list ? Theme.glyph.grid : Theme.glyph.list,
                hint: list ? t("Strg+2") : t("Strg+1"),
                run: () => p.view = list ? "grid" : "list"
            },
            {
                label: app.split ? t("Teilung schließen") : t("Geteilte Ansicht"),
                glyph: Theme.glyph.split,
                hint: "F3",
                run: () => app.toggleSplit()
            },
            {
                label: t("Neu laden"),
                glyph: Theme.glyph.refresh,
                hint: "F5",
                run: () => p.reload()
            }
        ];
    }

    function entryItems(p, entry) {
        const several = p.targets.length > 1;
        const packed = !entry.dir && Files.isArchive(entry.path);
        const single = !several;
        return [
            {
                label: packed ? t("Durchsuchen") : t("Öffnen"),
                glyph: Theme.glyph.open,
                hint: "Enter",
                enabled: single,
                run: () => p.activate(entry)
            },
            {
                label: t("Hier entpacken"),
                glyph: Theme.glyph.extract,
                visible: packed,
                enabled: single,
                run: () => Files.extractAll(entry.path)
            },
            {
                label: t("Vorschau"),
                glyph: Theme.glyph.preview,
                hint: t("Leertaste"),
                enabled: single,
                run: () => app.quickLook.show(p.shown, p.cursor)
            },
            {
                label: t("Öffnen mit …"),
                glyph: Theme.glyph.apps,
                enabled: single && !entry.dir,
                run: () => app.openWith(entry.path)
            },
            {
                label: t("In neuem Tab"),
                glyph: Theme.glyph.tab,
                hint: t("Mittelklick"),
                enabled: entry.dir && single,
                run: () => app.newTab(entry.path)
            },
            {
                label: t("Im Terminal öffnen"),
                glyph: Theme.glyph.terminal,
                enabled: entry.dir && single,
                run: () => Files.terminal(entry.path)
            },
            {
                separator: true
            },
            {
                label: t("Ausschneiden"),
                glyph: Theme.glyph.cut,
                hint: t("Strg+X"),
                run: () => app.cut(p.targets)
            },
            {
                label: t("Kopieren"),
                glyph: Theme.glyph.copy,
                hint: t("Strg+C"),
                run: () => app.copy(p.targets)
            },
            {
                label: t("Hier hinein einfügen"),
                glyph: Theme.glyph.paste,
                enabled: app.board.paths.length > 0 && entry.dir && single,
                run: () => Files.paste(entry.path)
            },
            {
                label: t("Duplizieren"),
                glyph: Theme.glyph.duplicate,
                hint: t("Strg+D"),
                run: () => Files.duplicate(p.targets)
            },
            {
                label: several ? t("Mehrere umbenennen …") : t("Umbenennen"),
                glyph: several ? Theme.glyph.batch : Theme.glyph.rename,
                hint: "F2",
                run: () => app.openSheet("rename")
            },
            {
                label: t("Pfad kopieren"),
                glyph: Theme.glyph.link,
                hint: t("Strg+Shift+C"),
                run: () => Files.copyPaths(p.targets)
            },
            {
                separator: true
            },
            {
                label: t("In den Papierkorb"),
                glyph: Theme.glyph.trash,
                hint: t("Entf"),
                strong: true,
                run: () => app.openSheet("trash")
            }
        ];
    }

    function itemsFor(p, entry) {
        if (p.isTrash)
            return trashItems(p, entry);
        if (p.inArchive)
            return archiveItems(p, entry);
        return entry ? entryItems(p, entry) : folderItems(p);
    }

    function show(entry, x, y) {
        items = itemsFor(app.pane, entry).filter(item => item.visible !== false);
        card.x = Math.min(x, root.width - card.width - Theme.space2);
        card.y = Math.min(y, root.height - card.height - Theme.space2);
        reveal.target = 1;
        card.forceActiveFocus();
    }

    function hide() {
        reveal.target = 0;
        if (app.pane)
            app.pane.focusList();
    }

    anchors.fill: parent
    visible: reveal.value > 0.001
    z: 6

    Spring {
        id: reveal

        motion: Theme.settle
        instant: false
        precision: 0.002
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.hide()
    }

    Rectangle {
        id: card

        width: 260
        height: column.height + 2 * Theme.space1
        radius: Theme.radius
        color: Theme.raise2
        opacity: Math.min(1, reveal.value)
        transform: Translate {
            y: Theme.reducedMotion ? 0 : (reveal.value - 1) * Theme.space1
        }
        Keys.onEscapePressed: root.hide()

        Column {
            id: column

            x: Theme.space1
            y: Theme.space1
            width: parent.width - 2 * Theme.space1

            Repeater {
                model: root.items

                Rectangle {
                    id: entry

                    required property var modelData
                    readonly property bool usable: modelData.enabled !== false

                    width: column.width
                    height: modelData.separator ? Theme.space2 : Theme.ctlH + Theme.space1
                    radius: Theme.radiusSmall
                    opacity: usable ? 1 : 0.45
                    color: !modelData.separator && usable && pointer.containsMouse ? Theme.raise3 : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.motionFast
                        }
                    }

                    Text {
                        id: glyph

                        visible: !entry.modelData.separator
                        x: Theme.space2
                        width: Theme.fsBody
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.glyph ?? ""
                        color: Theme.sub
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fsBody
                    }

                    Text {
                        visible: !entry.modelData.separator
                        anchors.left: glyph.right
                        anchors.leftMargin: Theme.space2
                        anchors.right: hint.left
                        anchors.rightMargin: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.label ?? ""
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBody
                        font.bold: entry.modelData.strong === true
                    }

                    Text {
                        id: hint

                        visible: !entry.modelData.separator
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.hint ?? ""
                        color: Theme.faint
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSmall
                    }

                    MouseArea {
                        id: pointer

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !entry.modelData.separator && entry.usable
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.hide();
                            entry.modelData.run();
                        }
                    }
                }
            }
        }
    }
}
