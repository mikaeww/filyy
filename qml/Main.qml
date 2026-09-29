import QtQuick
import QtQuick.Window
import Filyy
import "Util.js" as Util

Window {
    id: win

    required property string startPath

    readonly property string home: Files.home()
    readonly property string trashPath: Files.trashPath()
    readonly property alias quickLook: quickLook
    // Hyprland tiles and groups ignore minimumWidth, so the layout has to fold instead.
    readonly property bool compact: card.width < 980
    readonly property bool shown: card.opacity > 0
    readonly property var tab: tabs.count > tabIndex ? tabs.itemAt(tabIndex) : null
    readonly property bool split: tab ? tab.split : false

    // The pane the rail, the shortcuts and the menus act on.
    property var pane: null
    property int tabIndex: 0
    property string message: ""
    // True while a copy or move runs; the ghost looks busy.
    readonly property bool busy: Jobs.busy
    // The first job waiting for an answer about an existing file, if any.
    readonly property var conflict: Jobs.items.find(job => job.state === "conflict") ?? null
    property bool conflictForAll: false
    property bool renaming: false
    property var renameTargets: []
    property var renameRows: []
    property var renameOptions: ({ find: "", replace: "", regex: false, template: "{name}", start: 1, case: "" })
    readonly property int renameErrors: renameRows.filter(row => row.error).length
    readonly property int renameChanges: renameRows.filter(row => row.new !== row.old && !row.error).length
    property string openWithFile: ""
    property var openWithHandlers: []
    property var openWithApps: []
    property int openWithIndex: 0
    property bool openWithDefault: false
    property bool searching: false
    property string searchFolder: ""
    property int searchId: -1
    property var searchRows: []
    property int searchIndex: -1
    property bool searchRegex: false
    property bool searchHidden: false
    property string searchState: ""
    property bool jumping: false
    property var jumpResults: []
    property int jumpIndex: 0
    property bool failed: false
    property var places: Files.places()
    property var board: Files.clipboard()
    // "" | "mkdir" | "rename" | "trash" | "delete" | "purge" | "empty"
    property string sheet: ""
    property var sheetTargets: []

    width: 1180
    height: 720
    minimumWidth: 480
    minimumHeight: 460
    visible: true
    color: Theme.bg
    title: "Filyy – " + (pane ? pane.title : "")

    Component.onCompleted: {
        tabModel.append({ start: startPath, split: false })
        entrance.start()
    }

    onActiveChanged: if (active) places = Files.places()

    function focusPane(browser) {
        pane = browser
        const owner = tabs.itemAt(tabIndex)
        if (owner && (owner.first === browser || owner.second === browser))
            owner.lastPane = browser
    }

    function newTab(path) {
        tabModel.append({ start: path, split: false })
        Qt.callLater(() => switchTab(tabModel.count - 1))
    }

    function switchTab(index) {
        if (index < 0 || index >= tabModel.count)
            return
        tabIndex = index
        const owner = tabs.itemAt(index)
        if (owner && owner.lastPane) {
            pane = owner.lastPane
            pane.focusList()
        }
    }

    function closeTab(index) {
        if (tabModel.count === 1)
            return win.close()
        tabModel.remove(index)
        switchTab(Math.min(index <= tabIndex ? Math.max(0, tabIndex - 1) : tabIndex, tabModel.count - 1))
    }

    function toggleSplit() {
        const owner = tabs.itemAt(tabIndex)
        if (!owner)
            return
        tabModel.setProperty(tabIndex, "split", !owner.split)
        Qt.callLater(() => {
            focusPane(owner.split ? owner.second : owner.first)
            pane.focusList()
        })
    }

    function otherPane() {
        const owner = tabs.itemAt(tabIndex)
        if (owner && owner.split) {
            focusPane(pane === owner.first ? owner.second : owner.first)
            pane.focusList()
        }
    }

    function say(text, bad) {
        message = text
        failed = bad
        messageTimer.restart()
    }

    function openSheet(kind) {
        const targets = !pane ? [] : kind === "empty" ? pane.entries.map(entry => entry.path) : pane.targets
        if (kind !== "mkdir" && targets.length === 0)
            return
        if (kind === "rename" && targets.length > 1)
            return openBatchRename(targets)
        sheetTargets = targets
        sheet = kind
        sheetField.text = kind === "rename" ? sheetTargets[0].slice(sheetTargets[0].lastIndexOf("/") + 1) : ""
        if (kind === "mkdir" || kind === "rename") {
            sheetField.input.forceActiveFocus()
            // Select the name without its extension, like every other file manager.
            const dot = sheetField.text.lastIndexOf(".")
            sheetField.input.select(0, kind === "rename" && dot > 0 ? dot : sheetField.text.length)
        }
    }

    function closeSheet() {
        sheet = ""
        if (pane)
            pane.focusList()
    }

    function confirmSheet() {
        const name = sheetField.text.trim()
        if (sheet === "mkdir" && name)
            Files.mkdir(pane.path, name)
        else if (sheet === "rename" && name)
            Files.rename(sheetTargets[0], name)
        else if (sheet === "trash")
            Files.trash(sheetTargets)
        else if (sheet === "delete")
            Files.remove(sheetTargets)
        else if (sheet === "purge" || sheet === "empty")
            Files.purge(sheetTargets)
        else
            return
        closeSheet()
    }

    function openBatchRename(targets) {
        renameTargets = targets
        renameOptions = { find: "", replace: "", regex: false, template: "{name}", start: 1, case: "" }
        findField.text = ""
        replaceField.text = ""
        templateField.text = "{name}"
        startField.text = "1"
        renameRows = Rename.preview(targets, renameOptions)
        renaming = true
        findField.input.forceActiveFocus()
    }

    function setRenameOption(key, value) {
        const next = Object.assign({}, renameOptions)
        next[key] = value
        renameOptions = next
        renameRows = Rename.preview(renameTargets, next)
    }

    function closeBatchRename() {
        renaming = false
        if (pane)
            pane.focusList()
    }

    function applyBatchRename() {
        if (renameErrors || !renameChanges)
            return
        Rename.run(renameRows)
        closeBatchRename()
    }

    function openWith(path) {
        openWithFile = path
        openWithHandlers = Apps.forFile(path)
        openWithField.text = ""
        openWithApps = openWithHandlers
        openWithIndex = 0
        openWithDefault = false
        openWithField.input.forceActiveFocus()
    }

    function filterOpenWith(query) {
        const needle = query.trim().toLowerCase()
        if (!needle) {
            openWithApps = openWithHandlers
        } else {
            const own = openWithHandlers.filter(app => app.name.toLowerCase().includes(needle))
            const ids = own.map(app => app.id)
            openWithApps = own.concat(Apps.everything().filter(app => !ids.includes(app.id) && app.name.toLowerCase().includes(needle)))
        }
        openWithIndex = 0
    }

    function launchWith(index) {
        const app = openWithApps[index]
        if (app)
            Apps.launch(app.id, app.path, openWithFile, openWithDefault)
        closeOpenWith()
    }

    function closeOpenWith() {
        openWithFile = ""
        if (pane)
            pane.focusList()
    }

    // Starts with whatever the pane's filter holds, so filtering can turn into a content search.
    function openSearch(query) {
        searchFolder = pane.path
        searchRows = []
        searchIndex = -1
        searchState = Search.ready() ? "" : "ripgrep (rg) ist nicht installiert"
        searchField.text = query ?? pane.filterText
        searching = true
        searchField.input.forceActiveFocus()
    }

    function runSearch() {
        searchRows = []
        searchIndex = -1
        searchState = searchField.text.trim() ? "Suche …" : ""
        searchId = Search.start(searchFolder, searchField.text, searchRegex, searchHidden)
    }

    function stepSearch(delta) {
        const matches = searchRows.map((row, i) => row.file ? -1 : i).filter(i => i >= 0)
        if (!matches.length)
            return
        const at = matches.indexOf(searchIndex)
        searchIndex = matches[(at + delta + matches.length) % matches.length]
    }

    function takeSearch(open) {
        const row = searchRows[searchIndex]
        if (!row || row.file)
            return
        closeSearch()
        if (open) {
            Files.open(row.path)
            return
        }
        pane.pendingSelect = row.path
        pane.navigate(row.path.slice(0, row.path.lastIndexOf("/")) || "/")
    }

    function closeSearch() {
        Search.cancel()
        searching = false
        if (pane)
            pane.focusList()
    }

    function openJump() {
        jumpField.text = ""
        jumpResults = Jump.search("")
        jumpIndex = 0
        jumping = true
        jumpField.input.forceActiveFocus()
    }

    function closeJump() {
        jumping = false
        if (pane)
            pane.focusList()
    }

    function takeJump(inNewTab) {
        const hit = jumpResults[jumpIndex]
        closeJump()
        if (!hit)
            return
        if (inNewTab)
            newTab(hit.path)
        else
            pane.navigate(hit.path)
    }

    function answerConflict(answer) {
        Jobs.resolve(conflict.id, answer, conflictForAll)
        conflictForAll = false
    }

    function cut(paths) {
        if (paths.length) {
            Files.setClipboard(paths, true)
            say(paths.length + " ausgeschnitten", false)
        }
    }

    function copy(paths) {
        if (paths.length) {
            Files.setClipboard(paths, false)
            say(paths.length + " kopiert", false)
        }
    }

    function dropInto(drop, folder) {
        const paths = drop.urls.map(url => String(url)).filter(url => url.startsWith("file://"))
            .map(url => decodeURIComponent(url.slice(7)))
        if (paths.length === 0)
            return
        if (Files.inArchive(paths[0])) {
            Files.extract(paths, folder)
            drop.accept(Qt.CopyAction)
            return
        }
        // ponytail: drags from inside Filyy move, drags from other apps copy; Dolphin asks instead.
        const move = drop.source !== null
        Files.transfer(paths, folder, move)
        drop.accept(move ? Qt.MoveAction : Qt.CopyAction)
    }

    function menuFor(entry) {
        const has = board.paths.length > 0
        const p = pane
        if (p.isTrash) {
            if (!entry)
                return [{ label: "Papierkorb leeren", glyph: Util.glyphs.trash, danger: true, enabled: p.entries.length > 0, run: () => openSheet("empty") }]
            return [
                { label: "Wiederherstellen", glyph: Util.glyphs.restore, hint: "Enter", run: () => Files.restore(p.targets) },
                { label: "Herkunft öffnen", glyph: Util.glyphs.open, enabled: p.targets.length === 1 && entry.original !== "", run: () => p.navigate(entry.original.slice(0, entry.original.lastIndexOf("/")) || "/") },
                { separator: true },
                { label: "Endgültig löschen", glyph: Util.glyphs.trash, hint: "Entf", danger: true, run: () => openSheet("purge") }
            ]
        }
        if (p.inArchive) {
            const archiveFile = archiveOf(p.path)
            if (!entry)
                return [{ label: "Alles entpacken", glyph: Util.glyphs.extract, run: () => Files.extractAll(archiveFile) }]
            const other = split && tab ? (p === tab.first ? tab.second : tab.first) : null
            return [
                { label: "Öffnen", glyph: Util.glyphs.open, hint: "Enter", enabled: p.targets.length === 1, run: () => p.activate(entry) },
                { separator: true },
                { label: "Neben das Archiv entpacken", glyph: Util.glyphs.extract, run: () => Files.extract(p.targets, Files.archiveFolder(p.path)) },
                { label: "In andere Seite entpacken", glyph: Util.glyphs.split, enabled: other !== null && !other.readOnly, run: () => Files.extract(p.targets, other.path) }
            ]
        }
        if (!entry) {
            return [
                { label: "Neuer Ordner", glyph: Util.glyphs.newFolder, hint: "Strg+Shift+N", run: () => openSheet("mkdir") },
                { label: "Einfügen", glyph: Util.glyphs.paste, hint: "Strg+V", enabled: has, run: () => Files.paste(p.path) },
                { label: "Terminal hier", glyph: Util.glyphs.terminal, hint: "Shift+F4", run: () => Files.terminal(p.path) },
                { label: Undo.label ? "Rückgängig: " + Undo.label : "Rückgängig", glyph: Util.glyphs.undo, hint: "Strg+Z", enabled: Undo.label !== "", run: () => Undo.undo() },
                { separator: true },
                { label: p.showHidden ? "Versteckte ausblenden" : "Versteckte zeigen", glyph: p.showHidden ? Util.glyphs.eyeOff : Util.glyphs.eye, hint: "Strg+H", run: () => p.toggleHidden() },
                { label: p.view === "list" ? "Als Raster" : "Als Liste", glyph: p.view === "list" ? Util.glyphs.grid : Util.glyphs.list, hint: p.view === "list" ? "Strg+2" : "Strg+1", run: () => p.view = p.view === "list" ? "grid" : "list" },
                { label: split ? "Teilung schließen" : "Geteilte Ansicht", glyph: Util.glyphs.split, hint: "F3", run: () => toggleSplit() },
                { label: "Neu laden", glyph: Util.glyphs.refresh, hint: "F5", run: () => p.reload() }
            ]
        }
        const several = p.targets.length > 1
        const packed = !entry.dir && Files.isArchive(entry.path)
        return [
            { label: packed ? "Durchsuchen" : "Öffnen", glyph: Util.glyphs.open, hint: "Enter", enabled: !several, run: () => p.activate(entry) },
            { label: "Hier entpacken", glyph: Util.glyphs.extract, visible: packed, enabled: !several, run: () => Files.extractAll(entry.path) },
            { label: "Vorschau", glyph: Util.glyphs.preview, hint: "Leertaste", enabled: !several, run: () => quickLook.show(p.shown, p.cursor) },
            { label: "Öffnen mit …", glyph: Util.glyphs.apps, enabled: !several && !entry.dir, run: () => openWith(entry.path) },
            { label: "In neuem Tab", glyph: Util.glyphs.tab, hint: "Mittelklick", enabled: entry.dir && !several, run: () => newTab(entry.path) },
            { label: "Im Terminal öffnen", glyph: Util.glyphs.terminal, enabled: entry.dir && !several, run: () => Files.terminal(entry.path) },
            { separator: true },
            { label: "Ausschneiden", glyph: Util.glyphs.cut, hint: "Strg+X", run: () => cut(p.targets) },
            { label: "Kopieren", glyph: Util.glyphs.copy, hint: "Strg+C", run: () => copy(p.targets) },
            { label: "Hier hinein einfügen", glyph: Util.glyphs.paste, enabled: has && entry.dir && !several, run: () => Files.paste(entry.path) },
            { label: "Duplizieren", glyph: Util.glyphs.duplicate, hint: "Strg+D", run: () => Files.duplicate(p.targets) },
            { label: several ? "Mehrere umbenennen …" : "Umbenennen", glyph: several ? Util.glyphs.batch : Util.glyphs.rename, hint: "F2", run: () => openSheet("rename") },
            { label: "Pfad kopieren", glyph: Util.glyphs.link, hint: "Strg+Shift+C", run: () => Files.copyPaths(p.targets) },
            { separator: true },
            { label: "In den Papierkorb", glyph: Util.glyphs.trash, hint: "Entf", danger: true, run: () => openSheet("trash") }
        ]
    }

    // The archive file a virtual path like pack.zip/dir points into.
    function archiveOf(path) {
        const folder = Files.archiveFolder(path)
        return folder + "/" + path.slice(folder.length + 1).split("/")[0]
    }

    function showMenu(entry, x, y) {
        menu.items = menuFor(entry).filter(item => item.visible !== false)
        menu.x = Math.min(x, win.width - menu.width - 8)
        menu.y = Math.min(y, win.height - menu.implicitHeight - 8)
        menuOut.stop()
        menu.visible = true
        menuIn.restart()
        menu.forceActiveFocus()
    }

    function hideMenu() {
        menuIn.stop()
        menuOut.restart()
        if (pane)
            pane.focusList()
    }

    Timer {
        id: messageTimer
        interval: 4000
        onTriggered: win.message = ""
    }

    Connections {
        target: Files

        function onDone(ok, text, select) {
            win.say(text, !ok)
        }

        function onClipboardChanged() {
            win.board = Files.clipboard()
        }
    }

    Connections {
        target: Search

        function onFound(id, matches) {
            if (id !== win.searchId)
                return
            const rows = win.searchRows.slice()
            for (const match of matches) {
                const last = rows.length ? rows[rows.length - 1] : null
                if (!last || last.path !== match.path)
                    rows.push({ file: true, path: match.path, relative: match.relative })
                rows.push(match)
            }
            win.searchRows = rows
            if (win.searchIndex < 0)
                win.stepSearch(1)
        }

        function onFinished(id, total, truncated) {
            if (id === win.searchId)
                win.searchState = !total ? (searchField.text.trim() ? "Nichts gefunden" : "")
                    : total + " Treffer" + (truncated ? ", bei " + total + " abgebrochen" : "")
        }
    }

    Connections {
        target: Rename

        function onDone(ok, text, steps) {
            win.say(text, !ok)
        }
    }

    Connections {
        target: Undo

        function onDone(ok, text) {
            win.say(text, !ok)
        }
    }

    Shortcut { sequence: "Ctrl+L"; onActivated: win.pane.editPath() }
    Shortcut { sequence: "Ctrl+F"; onActivated: win.pane.focusFilter() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: win.close() }
    Shortcut { sequence: "Ctrl+Z"; onActivated: Undo.undo() }
    Shortcut { sequences: ["Ctrl+K", "Ctrl+P"]; onActivated: win.openJump() }
    Shortcut { sequence: "Ctrl+Shift+F"; onActivated: win.openSearch() }
    Shortcut { sequence: "Ctrl+T"; onActivated: win.newTab(win.pane.path) }
    Shortcut { sequence: "Ctrl+W"; onActivated: win.closeTab(win.tabIndex) }
    Shortcut { sequences: ["Ctrl+Tab", "Ctrl+PgDown"]; onActivated: win.switchTab((win.tabIndex + 1) % tabModel.count) }
    Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab", "Ctrl+PgUp"]; onActivated: win.switchTab((win.tabIndex + tabModel.count - 1) % tabModel.count) }
    Shortcut { sequence: "F3"; onActivated: win.toggleSplit() }
    Shortcut { sequence: "F6"; onActivated: win.otherPane() }
    Shortcut { sequence: "F5"; onActivated: win.pane.reload() }
    Shortcut { sequence: "Ctrl+H"; onActivated: win.pane.toggleHidden() }
    Shortcut { sequence: "Alt+Left"; onActivated: win.pane.stepHistory(-1) }
    Shortcut { sequence: "Alt+Right"; onActivated: win.pane.stepHistory(1) }
    Shortcut { sequence: "Alt+Up"; onActivated: win.pane.up() }
    Shortcut { sequence: "Ctrl+1"; onActivated: win.pane.view = "list" }
    Shortcut { sequence: "Ctrl+2"; onActivated: win.pane.view = "grid" }
    Shortcut { sequence: "Ctrl+3"; onActivated: win.pane.view = "usage" }

    ListModel { id: tabModel }

    Item {
        id: card

        readonly property real railWidth: win.compact ? 64 : 260
        readonly property real gap: 12

        x: 12
        y: 12
        width: parent.width - 24
        height: parent.height - 24
        opacity: 0
        scale: 0.97

        ParallelAnimation {
            id: entrance
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: Theme.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
        }

        Rectangle {
            width: card.railWidth
            height: card.height
            radius: Theme.radius
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.hairline

            Rail {
                anchors.fill: parent
                app: win
            }
        }

        Rectangle {
            id: surface

            x: card.railWidth + card.gap
            width: card.width - x
            height: card.height
            radius: Theme.radius
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.hairline

            Row {
                id: tabStrip

                visible: tabModel.count > 1
                x: 14
                y: 10
                height: visible ? 30 : 0
                spacing: 4

                Repeater {
                    model: tabModel

                    Rectangle {
                        id: chip

                        required property int index
                        readonly property bool current: index === win.tabIndex
                        readonly property var owner: tabs.count > index ? tabs.itemAt(index) : null

                        width: Math.min(200, Math.max(110, chipText.implicitWidth + 48))
                        height: 30
                        radius: Theme.control
                        color: current ? Qt.alpha(Theme.accent, 0.13) : chipPointer.containsMouse ? Qt.alpha(Theme.fg, 0.05) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }

                        Text {
                            id: chipText
                            x: 12
                            width: parent.width - 40
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.owner && chip.owner.lastPane ? chip.owner.lastPane.title : ""
                            elide: Text.ElideRight
                            color: chip.current ? Theme.fg : Theme.fgMuted
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: chip.current ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: chipPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => mouse.button === Qt.MiddleButton ? win.closeTab(chip.index) : win.switchTab(chip.index)
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: Util.glyphs.close
                            color: closePointer.containsMouse ? Theme.fg : Qt.alpha(Theme.fgMuted, 0.7)
                            font.family: Theme.iconFont
                            font.pixelSize: 12

                            MouseArea {
                                id: closePointer
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.closeTab(chip.index)
                            }
                        }
                    }
                }
            }

            Item {
                id: panes

                anchors.top: tabStrip.visible ? tabStrip.bottom : parent.top
                anchors.bottom: parent.bottom
                width: parent.width

                Repeater {
                    id: tabs

                    model: tabModel

                    Item {
                        id: tabItem

                        required property int index
                        required property string start
                        required property bool split
                        property var lastPane: first
                        readonly property alias first: first
                        readonly property var second: secondLoader.item

                        width: panes.width
                        height: panes.height
                        visible: index === win.tabIndex

                        onVisibleChanged: if (visible && win.pane !== lastPane) Qt.callLater(() => win.switchTab(index))

                        Browser {
                            id: first
                            app: win
                            startPath: tabItem.start
                            width: tabItem.split ? Math.floor((parent.width - 1) / 2) : parent.width
                            height: parent.height
                            Component.onCompleted: if (!win.pane) win.focusPane(first)
                        }

                        Rectangle {
                            visible: tabItem.split
                            x: first.width
                            y: 16
                            width: 1
                            height: parent.height - 32
                            color: Theme.hairline
                        }

                        Loader {
                            id: secondLoader
                            active: tabItem.split
                            x: first.width + 1
                            width: parent.width - x
                            height: parent.height
                            onActiveChanged: if (!active && win.pane !== tabItem.first) win.focusPane(tabItem.first)

                            sourceComponent: Browser {
                                app: win
                                startPath: first.path
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: menu.visible
        z: 5

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: win.hideMenu()
        }
    }

    Rectangle {
        id: menu

        property var items: []

        visible: false
        z: 6
        width: 270
        implicitHeight: menuColumn.height + 12
        height: implicitHeight
        radius: Theme.control + 4
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.hairline
        opacity: 0
        scale: 0.97
        transformOrigin: Item.TopLeft
        focus: visible
        Keys.onEscapePressed: win.hideMenu()

        ParallelAnimation {
            id: menuIn
            NumberAnimation { target: menu; property: "opacity"; to: 1; duration: Theme.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
            NumberAnimation { target: menu; property: "scale"; to: 1; duration: Theme.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
        }

        ParallelAnimation {
            id: menuOut
            NumberAnimation { target: menu; property: "opacity"; to: 0; duration: Theme.exitMs; easing.type: Easing.OutCubic }
            NumberAnimation { target: menu; property: "scale"; to: 0.97; duration: Theme.exitMs; easing.type: Easing.OutCubic }
            onFinished: menu.visible = false
        }

        Column {
            id: menuColumn

            x: 6
            y: 6
            width: parent.width - 12

            Repeater {
                model: menu.items

                Item {
                    id: menuEntry

                    required property var modelData
                    readonly property bool usable: modelData.enabled !== false

                    width: menuColumn.width
                    height: modelData.separator ? 9 : 34

                    Rectangle {
                        visible: menuEntry.modelData.separator === true
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Qt.alpha(Theme.hairline, 0.7)
                    }

                    Rectangle {
                        visible: !menuEntry.modelData.separator
                        anchors.fill: parent
                        radius: Theme.control
                        opacity: menuEntry.usable ? 1 : 0.35
                        color: menuPointer.containsMouse && menuEntry.usable
                            ? (menuEntry.modelData.danger ? Qt.alpha(Theme.danger, 0.16) : Qt.alpha(Theme.accent, 0.13)) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }

                        Text {
                            id: menuGlyph
                            x: 10
                            width: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: menuEntry.modelData.glyph ?? ""
                            color: menuEntry.modelData.danger ? Theme.danger : Theme.fgMuted
                            font.family: Theme.iconFont
                            font.pixelSize: 15
                        }

                        Text {
                            anchors.left: menuGlyph.right
                            anchors.leftMargin: 10
                            anchors.right: menuHint.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: menuEntry.modelData.label ?? ""
                            elide: Text.ElideRight
                            color: menuEntry.modelData.danger ? Theme.danger : Theme.fg
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                        }

                        Text {
                            id: menuHint
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: menuEntry.modelData.hint ?? ""
                            color: Qt.alpha(Theme.fgMuted, 0.7)
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: menuPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: menuEntry.usable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.hideMenu()
                                menuEntry.modelData.run()
                            }
                        }
                    }
                }
            }
        }
    }

    Column {
        anchors.right: parent.right
        anchors.rightMargin: 32
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        spacing: 8
        z: 4

        Repeater {
            model: Jobs.items
            JobCard { required property var modelData; job: modelData }
        }
    }

    Sheet {
        id: nameSheet

        readonly property bool asksName: win.sheet === "mkdir" || win.sheet === "rename"
        readonly property string names: win.sheetTargets.slice(0, 4).map(p => p.slice(p.lastIndexOf("/") + 1)).join(", ")
            + (win.sheetTargets.length > 4 ? " und " + (win.sheetTargets.length - 4) + " weitere" : "")

        open: win.sheet !== ""
        onDismissed: win.closeSheet()
        onAccepted: win.confirmSheet()

        Text {
            width: parent.width
            text: ({ mkdir: "Neuer Ordner", rename: "Umbenennen", trash: "In den Papierkorb legen?", delete: "Endgültig löschen?",
                     purge: "Endgültig löschen?", empty: "Papierkorb leeren?" })[win.sheet] ?? ""
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            visible: !nameSheet.asksName
            text: win.sheet === "empty"
                ? "Alle " + win.sheetTargets.length + " Elemente im Papierkorb werden gelöscht. Das lässt sich nicht rückgängig machen."
                : win.sheet === "delete" || win.sheet === "purge"
                ? nameSheet.names + " wird sofort gelöscht, ohne Papierkorb. Das lässt sich nicht rückgängig machen."
                : nameSheet.names + " landet im Papierkorb und lässt sich von dort zurückholen."
            wrapMode: Text.Wrap
            color: Theme.fgMuted
            font.family: Theme.fontUi
            font.pixelSize: 12
            lineHeight: 1.2
        }

        Field {
            id: sheetField
            visible: nameSheet.asksName
            width: parent.width
            placeholder: "Name …"
            onKeyPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.confirmSheet()
                else if (event.key === Qt.Key_Escape) win.closeSheet()
                else return
                event.accepted = true
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            TextButton { label: "Abbrechen"; onClicked: win.closeSheet() }
            TextButton {
                label: ({ mkdir: "Erstellen", rename: "Umbenennen", trash: "In den Papierkorb", delete: "Löschen", purge: "Löschen", empty: "Leeren" })[win.sheet] ?? "OK"
                primary: !danger
                danger: ["delete", "purge", "empty"].includes(win.sheet)
                onClicked: win.confirmSheet()
            }
        }
    }

    QuickLook {
        id: quickLook
        app: win
    }

    Sheet {
        id: renameSheet

        open: win.renaming
        cardWidth: 760
        onDismissed: win.closeBatchRename()
        onAccepted: win.applyBatchRename()

        Text {
            text: win.renameTargets.length + " Elemente umbenennen"
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        Row {
            width: parent.width
            spacing: 8

            Field {
                id: findField
                width: (parent.width - regexChip.width - 16) / 2
                placeholder: "Suchen"
                onTextChanged: win.setRenameOption("find", text)
                onKeyPressed: event => { if (event.key === Qt.Key_Escape) { win.closeBatchRename(); event.accepted = true } }
            }

            Field {
                id: replaceField
                width: findField.width
                placeholder: "Ersetzen durch"
                onTextChanged: win.setRenameOption("replace", text)
            }

            Chip {
                id: regexChip
                anchors.verticalCenter: parent.verticalCenter
                label: "Regex"
                active: win.renameOptions.regex
                onClicked: win.setRenameOption("regex", !win.renameOptions.regex)
            }
        }

        Row {
            width: parent.width
            spacing: 8

            Field {
                id: templateField
                width: parent.width - startField.width - 8
                mono: true
                placeholder: "Vorlage, z. B. {date}-{name}-{n}"
                text: "{name}"
                onTextChanged: win.setRenameOption("template", text)
            }

            Field {
                id: startField
                width: 110
                mono: true
                placeholder: "Nummer ab"
                text: "1"
                input.validator: IntValidator { bottom: 0; top: 99999 }
                onTextChanged: win.setRenameOption("start", parseInt(text) || 1)
            }
        }

        Row {
            spacing: 6

            SectionLabel { text: "Schreibweise"; anchors.verticalCenter: parent.verticalCenter; rightPadding: 6 }
            Repeater {
                model: [{ key: "", label: "unverändert" }, { key: "lower", label: "klein" }, { key: "upper", label: "GROSS" }, { key: "kebab", label: "kebab-case" }]
                Chip {
                    required property var modelData
                    label: modelData.label
                    active: win.renameOptions.case === modelData.key
                    onClicked: win.setRenameOption("case", modelData.key)
                }
            }
        }

        Text {
            width: parent.width
            text: "{name} Name  ·  {n} Nummer  ·  {date} Aufnahme- oder Änderungsdatum  ·  {ext} Endung"
            color: Theme.fgMuted
            font.family: Theme.fontMono
            font.pixelSize: 10
            elide: Text.ElideRight
        }

        Rectangle {
            width: parent.width
            height: Math.min(260, previewList.contentHeight + 12)
            radius: Theme.control
            color: Qt.alpha(Theme.fg, 0.03)
            border.width: 1
            border.color: Qt.alpha(Theme.hairline, 0.6)

            ListView {
                id: previewList
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.renameRows

                delegate: Item {
                    required property var modelData
                    width: previewList.width
                    height: 26

                    Text {
                        id: oldName
                        x: 8
                        width: (parent.width - 40) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.old
                        elide: Text.ElideMiddle
                        color: Theme.fgMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }

                    Text {
                        x: oldName.x + oldName.width + 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "→"
                        color: Qt.alpha(Theme.fgMuted, 0.6)
                        font.pixelSize: 11
                    }

                    Text {
                        x: oldName.x + oldName.width + 28
                        width: parent.width - x - 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.error ? parent.modelData.new + "  ·  " + parent.modelData.error : parent.modelData.new
                        elide: Text.ElideMiddle
                        color: parent.modelData.error ? Theme.danger : parent.modelData.new === parent.modelData.old ? Theme.fgMuted : Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        font.weight: parent.modelData.new !== parent.modelData.old ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            TextButton { label: "Abbrechen"; onClicked: win.closeBatchRename() }
            TextButton {
                label: win.renameErrors ? win.renameErrors + " Konflikt" + (win.renameErrors === 1 ? "" : "e")
                    : win.renameChanges + " umbenennen"
                primary: true
                opacity: win.renameErrors || !win.renameChanges ? 0.45 : 1
                onClicked: win.applyBatchRename()
            }
        }
    }

    Sheet {
        id: openWithSheet

        open: win.openWithFile !== ""
        cardWidth: 520
        onDismissed: win.closeOpenWith()

        Text {
            width: parent.width
            text: "„" + win.openWithFile.slice(win.openWithFile.lastIndexOf("/") + 1) + "“ öffnen mit"
            elide: Text.ElideMiddle
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        Field {
            id: openWithField
            width: parent.width
            glyph: Util.glyphs.search
            placeholder: "App suchen …"
            onTextChanged: win.filterOpenWith(text)
            onKeyPressed: event => {
                const count = win.openWithApps.length
                if (event.key === Qt.Key_Down) win.openWithIndex = count ? (win.openWithIndex + 1) % count : 0
                else if (event.key === Qt.Key_Up) win.openWithIndex = count ? (win.openWithIndex + count - 1) % count : 0
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.launchWith(win.openWithIndex)
                else if (event.key === Qt.Key_Escape) win.closeOpenWith()
                else return
                event.accepted = true
            }
        }

        ListView {
            id: appList
            width: parent.width
            height: Math.min(8, Math.max(1, count)) * 42
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: win.openWithApps
            currentIndex: win.openWithIndex
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                id: appRow

                required property var modelData
                required property int index
                readonly property bool current: index === win.openWithIndex

                width: appList.width
                height: 42
                radius: Theme.control
                color: current ? Qt.alpha(Theme.accent, 0.13) : appPointer.containsMouse ? Qt.alpha(Theme.fg, 0.04) : "transparent"

                Image {
                    id: appIcon
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    source: appRow.modelData.icon ? "image://appicon/" + appRow.modelData.icon : ""
                    sourceSize: Qt.size(48, 48)
                }

                Text {
                    anchors.left: appIcon.right
                    anchors.leftMargin: 12
                    anchors.right: badge.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: appRow.modelData.name
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                }

                Text {
                    id: badge
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: appRow.modelData.default ? "Standard" : ""
                    color: Theme.fgMuted
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                }

                MouseArea {
                    id: appPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.launchWith(appRow.index)
                }
            }
        }

        Text {
            visible: win.openWithApps.length === 0
            text: "Keine passende App gefunden"
            color: Theme.fgMuted
            font.family: Theme.fontUi
            font.pixelSize: 12
        }

        Row {
            width: parent.width

            Chip {
                label: "Als Standard für diesen Dateityp merken"
                active: win.openWithDefault
                onClicked: win.openWithDefault = !win.openWithDefault
            }

            Item { width: parent.width - 330; height: 1 }
        }
    }

    Timer {
        id: searchDelay
        interval: 250
        onTriggered: win.runSearch()
    }

    Sheet {
        id: searchSheet

        open: win.searching
        cardWidth: 820
        cardTop: Math.round(win.height * 0.1)
        onDismissed: win.closeSearch()

        Row {
            width: parent.width
            spacing: 8

            Field {
                id: searchField
                width: parent.width - regexToggle.width - hiddenToggle.width - 16
                height: 42
                glyph: Util.glyphs.textSearch
                placeholder: "In Dateien suchen …"
                input.font.pixelSize: 15
                onTextChanged: searchDelay.restart()
                onKeyPressed: event => {
                    if (event.key === Qt.Key_Down) win.stepSearch(1)
                    else if (event.key === Qt.Key_Up) win.stepSearch(-1)
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.takeSearch(event.modifiers & Qt.ControlModifier)
                    else if (event.key === Qt.Key_Escape) win.closeSearch()
                    else return
                    event.accepted = true
                }
            }

            Chip {
                id: regexToggle
                anchors.verticalCenter: parent.verticalCenter
                label: "Regex"
                active: win.searchRegex
                onClicked: { win.searchRegex = !win.searchRegex; win.runSearch() }
            }

            Chip {
                id: hiddenToggle
                anchors.verticalCenter: parent.verticalCenter
                label: "Versteckte"
                active: win.searchHidden
                onClicked: { win.searchHidden = !win.searchHidden; win.runSearch() }
            }
        }

        Text {
            width: parent.width
            text: "in " + win.searchFolder.replace(win.home, "~") + (win.searchState ? "  ·  " + win.searchState : "")
            elide: Text.ElideMiddle
            color: Theme.fgMuted
            font.family: Theme.fontUi
            font.pixelSize: 11
        }

        ListView {
            id: searchList
            width: parent.width
            height: Math.min(Math.round(win.height * 0.6), Math.max(0, contentHeight))
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: win.searchRows
            currentIndex: win.searchIndex
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                id: result

                required property var modelData
                required property int index
                readonly property bool current: index === win.searchIndex

                width: searchList.width
                height: modelData.file ? 34 : 26
                radius: Theme.control
                color: current ? Qt.alpha(Theme.accent, 0.13) : !modelData.file && resultPointer.containsMouse ? Qt.alpha(Theme.fg, 0.04) : "transparent"

                FileIcon {
                    id: resultIcon
                    visible: result.modelData.file === true
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    kind: "text"
                }

                Text {
                    visible: result.modelData.file === true
                    anchors.left: resultIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: result.modelData.relative
                    elide: Text.ElideMiddle
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Text {
                    id: lineNumber
                    visible: !result.modelData.file
                    x: 34
                    width: 44
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: result.modelData.line ?? ""
                    color: Qt.alpha(Theme.fgMuted, 0.8)
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }

                Text {
                    visible: !result.modelData.file
                    anchors.left: lineNumber.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.StyledText
                    elide: Text.ElideRight
                    // Only the match is marked up; everything around it is escaped first.
                    text: result.modelData.file ? "" : (() => {
                        const t = result.modelData.text.replace(/\t/g, "  ")
                        const s = result.modelData.start, e = result.modelData.end
                        return Util.escapeHtml(t.slice(0, s).replace(/^\s+/, "")) + "<b><font color=\"" + Theme.accent + "\">"
                            + Util.escapeHtml(t.slice(s, e)) + "</font></b>" + Util.escapeHtml(t.slice(e))
                    })()
                    color: Theme.fgMuted
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }

                MouseArea {
                    id: resultPointer
                    anchors.fill: parent
                    enabled: !result.modelData.file
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        win.searchIndex = result.index
                        win.takeSearch(mouse.modifiers & Qt.ControlModifier)
                    }
                }
            }
        }

        Text {
            text: "↑ ↓  Treffer     Enter  Datei zeigen     Strg+Enter  Öffnen"
            color: Theme.fgMuted
            font.family: Theme.fontUi
            font.pixelSize: 11
        }
    }

    Sheet {
        id: jumpSheet

        open: win.jumping
        cardWidth: 600
        cardTop: Math.round(win.height * 0.16)
        onDismissed: win.closeJump()

        Field {
            id: jumpField

            width: parent.width
            height: 42
            glyph: Util.glyphs.jump
            placeholder: "Zu Ordner springen …"
            input.font.pixelSize: 15

            onTextChanged: {
                win.jumpResults = Jump.search(text)
                win.jumpIndex = 0
            }
            onKeyPressed: event => {
                const count = win.jumpResults.length
                if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier))
                    win.jumpIndex = count ? (win.jumpIndex + 1) % count : 0
                else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier))
                    win.jumpIndex = count ? (win.jumpIndex + count - 1) % count : 0
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    win.takeJump(event.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))
                else if (event.key === Qt.Key_Escape)
                    win.closeJump()
                else
                    return
                event.accepted = true
            }
        }

        Column {
            width: parent.width

            Repeater {
                // As many hits as fit below the field, so the card never runs off the window.
                model: win.jumpResults.slice(0, Math.max(3, Math.floor((win.height * 0.84 - 200) / 42)))

                Rectangle {
                    id: hit

                    required property var modelData
                    required property int index
                    readonly property bool current: index === win.jumpIndex

                    width: parent.width
                    height: 42
                    radius: Theme.control
                    color: current ? Qt.alpha(Theme.accent, 0.13) : hitPointer.containsMouse ? Qt.alpha(Theme.fg, 0.04) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }

                    FileIcon {
                        id: hitIcon
                        x: 12
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "folder"
                    }

                    Text {
                        id: hitName
                        anchors.left: hitIcon.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: hit.modelData.name
                        color: Theme.fg
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        font.weight: hit.current ? Font.DemiBold : Font.Normal
                    }

                    Text {
                        anchors.left: hitName.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: hit.modelData.parent
                        elide: Text.ElideLeft
                        color: Theme.fgMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: hitPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.jumpIndex = hit.index
                            win.takeJump(false)
                        }
                    }
                }
            }
        }

        Text {
            text: win.jumpResults.length ? "↑ ↓  Auswählen     Enter  Springen     Strg+Enter  Neuer Tab" : "Kein passender Ordner"
            color: Theme.fgMuted
            font.family: Theme.fontUi
            font.pixelSize: 11
        }
    }

    Sheet {
        id: conflictSheet

        readonly property var source: win.conflict ? Files.info(win.conflict.conflict.source) : ({})
        readonly property var target: win.conflict ? Files.info(win.conflict.conflict.target) : ({})

        open: win.conflict !== null
        cardWidth: 480
        onDismissed: win.answerConflict("skip")
        onAccepted: win.answerConflict("keep")

        Text {
            width: parent.width
            text: "„" + (conflictSheet.target.name ?? "") + "“ gibt es dort schon"
            wrapMode: Text.Wrap
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        Repeater {
            model: [{ label: "Neu", info: conflictSheet.source }, { label: "Vorhanden", info: conflictSheet.target }]

            Row {
                required property var modelData
                spacing: 12

                SectionLabel { width: 90; text: parent.modelData.label; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (parent.modelData.info.dir ? "Ordner" : Util.size(parent.modelData.info.size ?? 0))
                        + "  ·  " + Qt.formatDateTime(new Date(parent.modelData.info.mtime ?? 0), "dd.MM.yyyy  HH:mm")
                    color: Theme.fgMuted
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                }
            }
        }

        Item {
            width: forAll.width
            height: forAll.height

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: win.conflictForAll = !win.conflictForAll
            }

            Row {
                id: forAll
                spacing: 10

                Rectangle {
                    width: 18
                    height: 18
                    radius: Theme.square ? 0 : 5
                    color: win.conflictForAll ? Theme.accent : "transparent"
                    border.width: win.conflictForAll ? 0 : 1
                    border.color: Theme.hairline

                    Text {
                        anchors.centerIn: parent
                        visible: win.conflictForAll
                        text: "\u{F012C}"
                        color: Theme.accentText
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Für alle weiteren Konflikte"
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            TextButton { label: "Überspringen"; onClicked: win.answerConflict("skip") }
            TextButton { label: "Ersetzen"; onClicked: win.answerConflict("replace") }
            TextButton { label: "Beide behalten"; primary: true; onClicked: win.answerConflict("keep") }
        }
    }
}
