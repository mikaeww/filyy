import QtQuick
import QtQuick.Window
import Filyy
import "Util.js" as Util

Window {
    id: win

    required property string startPath

    readonly property string home: Files.home()
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
    property bool failed: false
    property var places: Files.places()
    property var board: Files.clipboard()
    // "" | "mkdir" | "rename" | "trash" | "delete"
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
        const targets = pane ? pane.targets : []
        if (kind !== "mkdir" && targets.length === 0)
            return
        if (kind === "rename" && targets.length !== 1)
            return say("Umbenennen geht nur mit einem Element", true)
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
        else
            return
        closeSheet()
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
        // ponytail: drags from inside Filyy move, drags from other apps copy; Dolphin asks instead.
        const move = drop.source !== null
        Files.transfer(paths, folder, move)
        drop.accept(move ? Qt.MoveAction : Qt.CopyAction)
    }

    function menuFor(entry) {
        const has = board.paths.length > 0
        const p = pane
        if (!entry) {
            return [
                { label: "Neuer Ordner", glyph: Util.glyphs.newFolder, hint: "Strg+Shift+N", run: () => openSheet("mkdir") },
                { label: "Einfügen", glyph: Util.glyphs.paste, hint: "Strg+V", enabled: has, run: () => Files.paste(p.path) },
                { label: "Terminal hier", glyph: Util.glyphs.terminal, hint: "Shift+F4", run: () => Files.terminal(p.path) },
                { separator: true },
                { label: p.showHidden ? "Versteckte ausblenden" : "Versteckte zeigen", glyph: p.showHidden ? Util.glyphs.eyeOff : Util.glyphs.eye, hint: "Strg+H", run: () => p.toggleHidden() },
                { label: p.view === "list" ? "Als Raster" : "Als Liste", glyph: p.view === "list" ? Util.glyphs.grid : Util.glyphs.list, hint: p.view === "list" ? "Strg+2" : "Strg+1", run: () => p.view = p.view === "list" ? "grid" : "list" },
                { label: split ? "Teilung schließen" : "Geteilte Ansicht", glyph: Util.glyphs.split, hint: "F3", run: () => toggleSplit() },
                { label: "Neu laden", glyph: Util.glyphs.refresh, hint: "F5", run: () => p.reload() }
            ]
        }
        const several = p.targets.length > 1
        return [
            { label: "Öffnen", glyph: Util.glyphs.open, hint: "Enter", enabled: !several, run: () => p.activate(entry) },
            { label: "In neuem Tab", glyph: Util.glyphs.tab, hint: "Mittelklick", enabled: entry.dir && !several, run: () => newTab(entry.path) },
            { label: "Im Terminal öffnen", glyph: Util.glyphs.terminal, enabled: entry.dir && !several, run: () => Files.terminal(entry.path) },
            { separator: true },
            { label: "Ausschneiden", glyph: Util.glyphs.cut, hint: "Strg+X", run: () => cut(p.targets) },
            { label: "Kopieren", glyph: Util.glyphs.copy, hint: "Strg+C", run: () => copy(p.targets) },
            { label: "Hier hinein einfügen", glyph: Util.glyphs.paste, enabled: has && entry.dir && !several, run: () => Files.paste(entry.path) },
            { label: "Duplizieren", glyph: Util.glyphs.duplicate, hint: "Strg+D", run: () => Files.duplicate(p.targets) },
            { label: "Umbenennen", glyph: Util.glyphs.rename, hint: "F2", enabled: !several, run: () => openSheet("rename") },
            { label: "Pfad kopieren", glyph: Util.glyphs.link, hint: "Strg+Shift+C", run: () => Files.copyPaths(p.targets) },
            { separator: true },
            { label: "In den Papierkorb", glyph: Util.glyphs.trash, hint: "Entf", danger: true, run: () => openSheet("trash") }
        ]
    }

    function showMenu(entry, x, y) {
        menu.items = menuFor(entry)
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

    Shortcut { sequence: "Ctrl+L"; onActivated: win.pane.editPath() }
    Shortcut { sequence: "Ctrl+F"; onActivated: win.pane.focusFilter() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: win.close() }
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
        width: 250
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
            text: ({ mkdir: "Neuer Ordner", rename: "Umbenennen", trash: "In den Papierkorb legen?", delete: "Endgültig löschen?" })[win.sheet] ?? ""
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            visible: !nameSheet.asksName
            text: win.sheet === "delete"
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
                label: ({ mkdir: "Erstellen", rename: "Umbenennen", trash: "In den Papierkorb", delete: "Löschen" })[win.sheet] ?? "OK"
                primary: win.sheet !== "delete"
                danger: win.sheet === "delete"
                onClicked: win.confirmSheet()
            }
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
