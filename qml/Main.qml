import QtQuick
import QtQuick.Window
import Filyy
import "Util.js" as Util

Window {
    id: win

    required property string startPath

    readonly property string home: Files.home()
    readonly property string iconFont: "Monofur Nerd Font"
    readonly property int control: Theme.square ? 0 : Math.round(Theme.radius / 2)
    readonly property int enterMs: Theme.reducedMotion ? 0 : 220
    readonly property int exitMs: Theme.reducedMotion ? 0 : 150
    readonly property int quickMs: Theme.reducedMotion ? 0 : 140

    property string path: ""
    property var history: ({ list: [], index: -1 })
    property var entries: []
    property string error: ""
    property bool showHidden: false
    property string view: "list"
    // Picked entries as {path: true}; `cursor` is the keyboard position, `anchor` the start of a shift range.
    property var picked: ({})
    property int cursor: 0
    property int anchor: 0
    property string pendingSelect: ""
    property string message: ""
    property bool failed: false
    property var places: Files.places()
    property var board: Files.clipboard()
    // "" | "mkdir" | "rename" | "trash" | "delete"
    property string sheet: ""
    property var sheetTargets: []

    readonly property var shown: {
        const needle = filterField.text.trim().toLowerCase()
        return needle ? entries.filter(entry => entry.name.toLowerCase().includes(needle)) : entries
    }
    readonly property var current: shown[cursor] ?? null
    readonly property var pickedPaths: Object.keys(picked)
    readonly property var targets: pickedPaths.length ? pickedPaths : (current ? [current.path] : [])
    readonly property Flickable activeView: view === "grid" ? grid : list

    width: 1180
    height: 720
    minimumWidth: 480
    minimumHeight: 460
    visible: true
    color: Theme.bg
    title: "Filyy – " + (path === home ? "Home" : path.slice(path.lastIndexOf("/") + 1) || "/")

    Component.onCompleted: {
        navigate(startPath)
        entrance.start()
        browser.forceActiveFocus()
    }

    onActiveChanged: if (active) places = Files.places()

    function fileUrl(p) {
        return "file://" + p.split("/").map(encodeURIComponent).join("/")
    }

    function navigate(target) {
        const clean = target.trim().replace(/^~(?=\/|$)/, home).replace(/(.)\/+$/, "$1")
        if (!clean.startsWith("/"))
            return
        history = Util.visit(history, clean)
        open(clean)
    }

    function stepHistory(delta) {
        const index = history.index + delta
        if (index < 0 || index >= history.list.length)
            return
        history = { list: history.list, index: index }
        open(history.list[index])
    }

    function up() {
        if (path === "/")
            return
        pendingSelect = path
        navigate(path.slice(0, path.lastIndexOf("/")) || "/")
    }

    // A folder change, with the settings' page entrance; reload() is the quiet variant.
    function open(target) {
        path = target
        filterField.text = ""
        editingPath = false
        picked = {}
        cursor = 0
        anchor = 0
        reload()
        activeView.contentY = 0
        pageIn.stop()
        body.opacity = 0
        rise.y = 8
        pageIn.start()
    }

    function reload() {
        const result = Files.list(path, showHidden)
        entries = result.entries
        error = result.error
        const kept = {}
        for (const entry of entries)
            if (picked[entry.path])
                kept[entry.path] = true
        const wanted = pendingSelect || (current ? current.path : "")
        const index = shown.findIndex(entry => entry.path === wanted)
        if (pendingSelect && index >= 0) {
            kept[pendingSelect] = true
            pendingSelect = ""
        }
        picked = kept
        cursor = Math.max(0, Math.min(index >= 0 ? index : cursor, shown.length - 1))
        if (index >= 0)
            Qt.callLater(() => activeView.positionViewAtIndex(cursor, ListView.Contain))
    }

    function activate(entry) {
        if (!entry)
            return
        if (entry.dir)
            navigate(entry.path)
        else
            Files.open(entry.path)
    }

    function select(index, modifiers) {
        const entry = shown[index]
        if (!entry)
            return
        if (modifiers & Qt.ShiftModifier) {
            selectRange(anchor, index)
        } else if (modifiers & Qt.ControlModifier) {
            const next = Object.assign({}, picked)
            if (next[entry.path])
                delete next[entry.path]
            else
                next[entry.path] = true
            picked = next
            anchor = index
        } else {
            picked = { [entry.path]: true }
            anchor = index
        }
        cursor = index
    }

    function selectRange(from, to) {
        const next = {}
        for (let i = Math.min(from, to); i <= Math.max(from, to); i++)
            next[shown[i].path] = true
        picked = next
    }

    function moveCursor(delta, extend) {
        if (shown.length === 0)
            return
        const next = Math.max(0, Math.min(shown.length - 1, cursor + delta))
        if (extend) {
            cursor = next
            selectRange(anchor, next)
        } else {
            select(next, 0)
        }
        activeView.positionViewAtIndex(next, ListView.Contain)
    }

    function say(text, bad) {
        message = text
        failed = bad
        messageTimer.restart()
    }

    function openSheet(kind) {
        if (kind !== "mkdir" && targets.length === 0)
            return
        if (kind === "rename" && targets.length !== 1)
            return say("Umbenennen geht nur mit einem Element", true)
        sheetTargets = targets
        sheet = kind
        sheetField.text = kind === "rename" ? sheetTargets[0].slice(sheetTargets[0].lastIndexOf("/") + 1) : ""
        sheetOut.stop()
        sheetIn.restart()
        if (kind === "mkdir" || kind === "rename") {
            sheetField.forceActiveFocus()
            // Select the name without its extension, like every other file manager.
            const dot = sheetField.text.lastIndexOf(".")
            sheetField.select(0, kind === "rename" && dot > 0 ? dot : sheetField.text.length)
        } else {
            sheetCard.forceActiveFocus()
        }
    }

    function closeSheet() {
        sheet = ""
        sheetIn.stop()
        sheetOut.restart()
        browser.forceActiveFocus()
    }

    function confirmSheet() {
        const name = sheetField.text.trim()
        if (sheet === "mkdir" && name)
            Files.mkdir(path, name)
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
        if (!entry) {
            return [
                { label: "Neuer Ordner", glyph: Util.glyphs.newFolder, hint: "Strg+Shift+N", run: () => openSheet("mkdir") },
                { label: "Einfügen", glyph: Util.glyphs.paste, hint: "Strg+V", enabled: has, run: () => Files.paste(path) },
                { label: "Terminal hier", glyph: Util.glyphs.terminal, hint: "⇧+F4", run: () => Files.terminal(path) },
                { separator: true },
                { label: showHidden ? "Versteckte ausblenden" : "Versteckte zeigen", glyph: showHidden ? Util.glyphs.eyeOff : Util.glyphs.eye, hint: "Strg+H", run: () => toggleHidden() },
                { label: view === "list" ? "Als Raster" : "Als Liste", glyph: view === "list" ? Util.glyphs.grid : Util.glyphs.list, hint: view === "list" ? "Strg+2" : "Strg+1", run: () => view = view === "list" ? "grid" : "list" },
                { label: "Neu laden", glyph: Util.glyphs.refresh, hint: "F5", run: () => reload() }
            ]
        }
        const several = targets.length > 1
        return [
            { label: "Öffnen", glyph: Util.glyphs.open, hint: "Enter", enabled: !several, run: () => activate(entry) },
            { label: "Im Terminal öffnen", glyph: Util.glyphs.terminal, enabled: entry.dir && !several, run: () => Files.terminal(entry.path) },
            { separator: true },
            { label: "Ausschneiden", glyph: Util.glyphs.cut, hint: "Strg+X", run: () => cut(targets) },
            { label: "Kopieren", glyph: Util.glyphs.copy, hint: "Strg+C", run: () => copy(targets) },
            { label: "Hier hinein einfügen", glyph: Util.glyphs.paste, enabled: has && entry.dir && !several, run: () => Files.paste(entry.path) },
            { label: "Duplizieren", glyph: Util.glyphs.duplicate, hint: "Strg+D", run: () => Files.duplicate(targets) },
            { label: "Umbenennen", glyph: Util.glyphs.rename, hint: "F2", enabled: !several, run: () => openSheet("rename") },
            { label: "Pfad kopieren", glyph: Util.glyphs.link, hint: "Strg+Shift+C", run: () => Files.copyPaths(targets) },
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
        browser.forceActiveFocus()
    }

    function toggleHidden() {
        showHidden = !showHidden
        reload()
    }

    property bool editingPath: false

    Timer {
        id: messageTimer
        interval: 4000
        onTriggered: win.message = ""
    }

    Connections {
        target: Files

        function onFolderChanged(changed) {
            if (changed === win.path)
                win.reload()
        }

        function onDone(ok, text, select) {
            if (ok && select)
                win.pendingSelect = select
            win.say(text, !ok)
            win.reload()
        }

        function onClipboardChanged() {
            win.board = Files.clipboard()
        }
    }

    Shortcut { sequence: "Ctrl+L"; onActivated: { win.editingPath = true; pathField.forceActiveFocus(); pathField.selectAll() } }
    Shortcut { sequence: "Ctrl+F"; onActivated: filterField.forceActiveFocus() }
    Shortcut { sequences: ["Ctrl+Q", "Ctrl+W"]; onActivated: win.close() }
    Shortcut { sequence: "F5"; onActivated: win.reload() }
    Shortcut { sequence: "Ctrl+H"; onActivated: win.toggleHidden() }
    Shortcut { sequence: "Alt+Left"; onActivated: win.stepHistory(-1) }
    Shortcut { sequence: "Alt+Right"; onActivated: win.stepHistory(1) }
    Shortcut { sequence: "Alt+Up"; onActivated: win.up() }
    Shortcut { sequence: "Ctrl+1"; onActivated: win.view = "list" }
    Shortcut { sequence: "Ctrl+2"; onActivated: win.view = "grid" }

    component SectionLabel: Text {
        color: Qt.alpha(Theme.fgMuted, 0.75)
        font.family: Theme.fontMono
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1.4
        font.capitalization: Font.AllUppercase
    }

    component Surface: Rectangle {
        height: card.height
        radius: Theme.radius
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.hairline
    }

    component IconButton: Rectangle {
        id: button

        property string glyph: ""
        property bool active: false
        property string label: ""
        signal clicked()

        width: 32
        height: 32
        radius: win.control
        opacity: enabled ? 1 : 0.35
        color: active ? Qt.alpha(Theme.accent, 0.18)
            : buttonPointer.containsMouse ? Qt.alpha(Theme.fg, 0.06) : "transparent"
        Behavior on color { ColorAnimation { duration: win.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }
        Accessible.role: Accessible.Button
        Accessible.name: label

        Text {
            anchors.centerIn: parent
            text: button.glyph
            color: Theme.fg
            font.family: win.iconFont
            font.pixelSize: 16
        }

        MouseArea {
            id: buttonPointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component TextButton: Rectangle {
        id: textButton

        property string label: ""
        property bool primary: false
        property bool danger: false
        signal clicked()

        width: Math.max(96, buttonText.implicitWidth + 32)
        height: 34
        radius: win.control
        color: danger ? Theme.danger : primary ? Theme.accent
            : Qt.alpha(Theme.fg, textPointer.containsMouse ? 0.09 : 0.06)
        Behavior on color { ColorAnimation { duration: win.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }
        Accessible.role: Accessible.Button
        Accessible.name: label

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: textButton.label
            color: textButton.danger ? Theme.bg : textButton.primary ? Theme.accentText : Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 12
            font.weight: textButton.primary || textButton.danger ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: textPointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: textButton.clicked()
        }
    }

    component ScrollHint: Rectangle {
        required property Flickable flick
        visible: flick.contentHeight > flick.height
        x: flick.x + flick.width + 4
        y: flick.y + flick.visibleArea.yPosition * flick.height
        width: 3
        height: Math.max(24, flick.visibleArea.heightRatio * flick.height)
        radius: Theme.square ? 0 : 1.5
        color: Theme.fgMuted
        opacity: flick.moving ? 0.5 : 0.25
        Behavior on opacity { NumberAnimation { duration: win.quickMs } }
    }

    // Click, multi-select, context menu and drag-out for one entry, shared by list and grid.
    component EntryArea: MouseArea {
        id: area

        required property int index
        required property var entry
        property int pressModifiers: 0

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        drag.target: proxy
        drag.threshold: 8
        // Without this the view steals the drag for scrolling and files never leave the window.
        preventStealing: true

        onPressed: mouse => {
            browser.forceActiveFocus()
            pressModifiers = mouse.modifiers
            // A press on an already picked entry keeps the group so it can be dragged together.
            if (!win.picked[entry.path] || mouse.modifiers !== Qt.NoModifier)
                win.select(index, mouse.modifiers)
            if (mouse.button === Qt.RightButton) {
                const at = mapToItem(win.contentItem, mouse.x, mouse.y)
                win.showMenu(entry, at.x, at.y)
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && pressModifiers === Qt.NoModifier && win.pickedPaths.length > 1)
                win.select(index, 0)
        }
        onDoubleClicked: mouse => { if (mouse.button === Qt.LeftButton) win.activate(entry) }
        onReleased: { proxy.x = 0; proxy.y = 0 }

        Item {
            id: proxy
            Drag.active: area.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
            Drag.mimeData: ({ "text/uri-list": win.targets.map(p => win.fileUrl(p)).join("\r\n") })
        }
    }

    // Empty space of a view: a click clears the selection, a right click opens the folder menu.
    // It sits under the view's content, so entries still get their own presses first.
    component EmptyArea: MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            browser.forceActiveFocus()
            win.picked = {}
            if (mouse.button === Qt.RightButton) {
                const at = mapToItem(win.contentItem, mouse.x, mouse.y)
                win.showMenu(null, at.x, at.y)
            }
        }
    }

    Item {
        id: card

        // Hyprland tiles and groups ignore minimumWidth, so the layout has to fold instead.
        readonly property bool compact: width < 980
        readonly property real railWidth: compact ? 64 : 260
        readonly property real gap: 12
        readonly property real padding: compact ? 14 : 20

        x: 12
        y: 12
        width: parent.width - 24
        height: parent.height - 24
        opacity: 0
        scale: 0.97

        ParallelAnimation {
            id: entrance
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: win.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: win.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
        }

        Surface { width: card.railWidth }
        Surface { x: card.railWidth + card.gap; width: card.width - x }

        Item {
            id: rail

            width: card.railWidth
            height: card.height

            Row {
                id: brand

                x: card.compact ? (card.railWidth - 30) / 2 : card.padding
                y: card.padding
                height: 36
                spacing: 10

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    source: "../assets/filyy.svg"
                    sourceSize: Qt.size(60, 60)
                }

                Text {
                    visible: !card.compact
                    anchors.verticalCenter: parent.verticalCenter
                    text: "filyy"
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
            }

            Flickable {
                id: railScroll

                anchors.top: brand.bottom
                anchors.topMargin: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: card.padding
                width: parent.width
                contentWidth: width
                contentHeight: placeColumn.height + 8
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Item {
                    id: railSelection

                    readonly property int activeIndex: win.places.findIndex(place => place.path === win.path)
                    readonly property Item target: placeRepeater.count >= 0 && activeIndex >= 0 ? placeRepeater.itemAt(activeIndex) : null
                    readonly property real targetY: target ? placeColumn.y + target.y + target.height - 44 : 0

                    Glide {
                        id: railGlide
                        target: railSelection.targetY
                        animated: card.opacity > 0
                    }

                    x: placeColumn.x
                    y: railGlide.value
                    width: placeColumn.width
                    height: 44
                    opacity: target ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: win.quickMs } }

                    Rectangle {
                        anchors.fill: parent
                        radius: win.control
                        color: Qt.alpha(Theme.accent, 0.13)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: parent.height - 16
                        radius: Theme.square ? 0 : 1
                        color: Theme.accent
                    }
                }

                Column {
                    id: placeColumn

                    x: card.compact ? 8 : card.padding - 8
                    width: railScroll.width - 2 * x

                    Repeater {
                        id: placeRepeater

                        model: win.places

                        Item {
                            id: placeItem

                            required property var modelData
                            required property int index
                            readonly property bool active: win.path === modelData.path
                            readonly property bool groupStart: index === 0 || win.places[index - 1].group !== modelData.group

                            width: placeColumn.width
                            height: (!groupStart ? 0 : card.compact ? (index === 0 ? 0 : 12)
                                : groupLabel.height + (index === 0 ? 4 : 16)) + 44

                            SectionLabel {
                                id: groupLabel
                                visible: placeItem.groupStart && !card.compact
                                x: 12
                                y: placeItem.index === 0 ? 4 : 16
                                text: placeItem.modelData.group
                                bottomPadding: 6
                            }

                            Rectangle {
                                id: placeRow

                                y: parent.height - 44
                                width: parent.width
                                height: 44
                                radius: win.control
                                color: !placeItem.active && (placePointer.containsMouse || placeDrop.containsDrag)
                                    ? Qt.alpha(Theme.fg, 0.04) : "transparent"
                                Behavior on color { ColorAnimation { duration: win.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }

                                Rectangle {
                                    id: placeIcon
                                    x: card.compact ? (parent.width - width) / 2 : 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28
                                    height: 28
                                    radius: Theme.square ? 0 : 9
                                    color: Qt.alpha(Theme.accent, placeItem.active ? 0.32 : 0.14)
                                    Behavior on color { ColorAnimation { duration: win.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Util.placeGlyphs[placeItem.modelData.icon] ?? Util.glyphs.folder
                                        color: Theme.fg
                                        font.family: win.iconFont
                                        font.pixelSize: 15
                                    }
                                }

                                Text {
                                    visible: !card.compact
                                    anchors.left: placeIcon.right
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: placeItem.modelData.name
                                    elide: Text.ElideRight
                                    color: placeItem.active ? Theme.fg : Theme.fgMuted
                                    Behavior on color { ColorAnimation { duration: win.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }
                                    font.family: Theme.fontUi
                                    font.pixelSize: 13
                                    font.weight: placeItem.active ? Font.DemiBold : Font.Normal
                                }
                            }

                            MouseArea {
                                id: placePointer
                                anchors.fill: placeRow
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Link
                                Accessible.name: placeItem.modelData.name
                                onClicked: win.navigate(placeItem.modelData.path)
                            }

                            DropArea {
                                id: placeDrop
                                anchors.fill: placeRow
                                onDropped: drop => win.dropInto(drop, placeItem.modelData.path)
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: pane

            x: card.railWidth + card.gap
            width: card.width - x
            height: card.height

            Item {
                id: header

                x: card.padding
                y: card.padding
                width: parent.width - 2 * card.padding
                height: 36

                Row {
                    id: nav
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    IconButton { glyph: Util.glyphs.back; label: "Zurück"; enabled: win.history.index > 0; onClicked: win.stepHistory(-1) }
                    IconButton { glyph: Util.glyphs.forward; label: "Vor"; enabled: win.history.index < win.history.list.length - 1; onClicked: win.stepHistory(1) }
                    IconButton { glyph: Util.glyphs.up; label: "Hoch"; enabled: win.path !== "/"; onClicked: win.up() }
                }

                Rectangle {
                    id: crumbBox

                    anchors.left: nav.right
                    anchors.leftMargin: 12
                    anchors.right: tools.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 36
                    radius: Theme.square ? 0 : height / 2
                    color: Qt.alpha(Theme.fg, win.editingPath ? 0.09 : crumbPointer.containsMouse ? 0.06 : 0.04)
                    Behavior on color { ColorAnimation { duration: win.quickMs } }
                    clip: true

                    MouseArea {
                        id: crumbPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: {
                            win.editingPath = true
                            pathField.forceActiveFocus()
                            pathField.selectAll()
                        }
                    }

                    Row {
                        id: crumbs

                        visible: !win.editingPath
                        anchors.verticalCenter: parent.verticalCenter
                        // Keeps the deepest folder in view when the path is longer than the bar.
                        x: Math.min(14, crumbBox.width - width - 14)
                        spacing: 2

                        Repeater {
                            model: Util.crumbs(win.path, win.home)

                            Row {
                                id: crumb

                                required property var modelData
                                required property int index

                                spacing: 2

                                Text {
                                    visible: crumb.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Util.glyphs.chevron
                                    color: Qt.alpha(Theme.fgMuted, 0.6)
                                    font.family: win.iconFont
                                    font.pixelSize: 13
                                }

                                Rectangle {
                                    width: crumbText.implicitWidth + 14
                                    height: 26
                                    radius: win.control
                                    color: crumbHover.containsMouse ? Qt.alpha(Theme.fg, 0.07) : "transparent"
                                    Behavior on color { ColorAnimation { duration: win.quickMs } }

                                    Text {
                                        id: crumbText
                                        anchors.centerIn: parent
                                        text: crumb.modelData.name
                                        color: crumb.modelData.path === win.path ? Theme.fg : Theme.fgMuted
                                        font.family: Theme.fontUi
                                        font.pixelSize: 13
                                        font.weight: crumb.modelData.path === win.path ? Font.DemiBold : Font.Normal
                                    }

                                    MouseArea {
                                        id: crumbHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.navigate(crumb.modelData.path)
                                    }

                                    DropArea {
                                        anchors.fill: parent
                                        onDropped: drop => win.dropInto(drop, crumb.modelData.path)
                                    }
                                }
                            }
                        }
                    }

                    TextInput {
                        id: pathField

                        visible: win.editingPath
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.path.replace(win.home, "~")
                        color: Theme.fg
                        selectionColor: Qt.alpha(Theme.accent, 0.35)
                        selectedTextColor: Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: 13
                        clip: true
                        Accessible.name: "Pfad"

                        onActiveFocusChanged: if (!activeFocus) win.editingPath = false
                        Keys.onReturnPressed: { win.navigate(text); browser.forceActiveFocus() }
                        Keys.onEnterPressed: { win.navigate(text); browser.forceActiveFocus() }
                        Keys.onEscapePressed: {
                            text = Qt.binding(() => win.path.replace(win.home, "~"))
                            browser.forceActiveFocus()
                        }
                    }
                }

                Row {
                    id: tools

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Rectangle {
                        width: pane.width < 760 ? 130 : 210
                        height: 36
                        radius: Theme.square ? 0 : height / 2
                        color: Qt.alpha(Theme.fg, filterField.activeFocus ? 0.09 : 0.06)
                        Behavior on color { ColorAnimation { duration: win.quickMs } }

                        Text {
                            id: filterIcon
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: Util.glyphs.search
                            color: Theme.fgMuted
                            font.family: win.iconFont
                            font.pixelSize: 14
                        }

                        TextInput {
                            id: filterField

                            anchors.left: filterIcon.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.fg
                            selectionColor: Qt.alpha(Theme.accent, 0.35)
                            selectedTextColor: Theme.fg
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            clip: true
                            Accessible.name: "Filtern"

                            onTextChanged: {
                                win.cursor = 0
                                win.anchor = 0
                                win.picked = {}
                            }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    text = ""
                                    browser.forceActiveFocus()
                                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    browser.forceActiveFocus()
                                    if (event.key !== Qt.Key_Down) win.activate(win.current)
                                } else {
                                    return
                                }
                                event.accepted = true
                            }

                            Text {
                                visible: filterField.text === ""
                                text: "Filtern …"
                                color: Theme.fgMuted
                                font: filterField.font
                            }
                        }
                    }

                    Item { width: 8; height: 1 }

                    IconButton { visible: pane.width >= 560; glyph: Util.glyphs.list; label: "Liste"; active: win.view === "list"; onClicked: win.view = "list" }
                    IconButton { visible: pane.width >= 560; glyph: Util.glyphs.grid; label: "Raster"; active: win.view === "grid"; onClicked: win.view = "grid" }
                    IconButton { visible: pane.width >= 560; glyph: win.showHidden ? Util.glyphs.eye : Util.glyphs.eyeOff; label: "Versteckte Dateien"; active: win.showHidden; onClicked: win.toggleHidden() }
                    IconButton { glyph: Util.glyphs.newFolder; label: "Neuer Ordner"; onClicked: win.openSheet("mkdir") }
                }
            }

            FocusScope {
                id: browser

                anchors.top: header.bottom
                anchors.topMargin: 16
                anchors.bottom: footer.top
                anchors.bottomMargin: 8
                x: card.padding - 8
                width: parent.width - 2 * (card.padding - 8)
                focus: true

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    const shift = event.modifiers & Qt.ShiftModifier
                    const columns = win.view === "grid" ? Math.max(1, Math.floor(grid.width / grid.cellWidth)) : 1
                    if (event.key === Qt.Key_Down) win.moveCursor(columns, shift)
                    else if (event.key === Qt.Key_Up) win.moveCursor(-columns, shift)
                    else if (event.key === Qt.Key_Right && win.view === "grid") win.moveCursor(1, shift)
                    else if (event.key === Qt.Key_Left && win.view === "grid") win.moveCursor(-1, shift)
                    else if (event.key === Qt.Key_Home) win.moveCursor(-win.shown.length, shift)
                    else if (event.key === Qt.Key_End) win.moveCursor(win.shown.length, shift)
                    else if (event.key === Qt.Key_PageDown) win.moveCursor(10 * columns, shift)
                    else if (event.key === Qt.Key_PageUp) win.moveCursor(-10 * columns, shift)
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.activate(win.current)
                    else if (event.key === Qt.Key_Backspace) win.up()
                    else if (event.key === Qt.Key_Delete) win.openSheet(shift ? "delete" : "trash")
                    else if (event.key === Qt.Key_F2) win.openSheet("rename")
                    else if (event.key === Qt.Key_F10 || (ctrl && shift && event.key === Qt.Key_N)) win.openSheet("mkdir")
                    else if (shift && event.key === Qt.Key_F4) Files.terminal(win.path)
                    else if (ctrl && shift && event.key === Qt.Key_C) Files.copyPaths(win.targets)
                    else if (ctrl && event.key === Qt.Key_A) win.selectRange(0, win.shown.length - 1)
                    else if (ctrl && event.key === Qt.Key_C) win.copy(win.targets)
                    else if (ctrl && event.key === Qt.Key_X) win.cut(win.targets)
                    else if (ctrl && event.key === Qt.Key_V) Files.paste(win.path)
                    else if (ctrl && event.key === Qt.Key_D) Files.duplicate(win.targets)
                    else if (event.key === Qt.Key_Menu || (shift && event.key === Qt.Key_F10)) {
                        const row = win.activeView.itemAtIndex ? win.activeView.itemAtIndex(win.cursor) : null
                        const at = row ? row.mapToItem(win.contentItem, 24, row.height / 2) : Qt.point(win.width / 2, win.height / 2)
                        win.showMenu(win.current, at.x, at.y)
                    } else if (event.key === Qt.Key_Escape) {
                        if (win.pickedPaths.length) win.picked = {}
                        else filterField.text = ""
                    } else if (event.text.length === 1 && event.text >= " " && !ctrl) {
                        // Typing anywhere starts filtering, like Dolphin's type-ahead.
                        filterField.text += event.text
                        filterField.forceActiveFocus()
                    } else {
                        return
                    }
                    event.accepted = true
                }

                Item {
                    id: body

                    anchors.fill: parent
                    transform: Translate { id: rise }

                    ParallelAnimation {
                        id: pageIn
                        NumberAnimation { target: body; property: "opacity"; to: 1; duration: Theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic }
                        NumberAnimation { target: rise; property: "y"; to: 0; duration: Theme.reducedMotion ? 0 : 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
                    }

                    DropArea {
                        anchors.fill: parent
                        onDropped: drop => win.dropInto(drop, win.path)
                    }


                    Item {
                        id: columnHeads

                        visible: win.view === "list"
                        width: parent.width - 8
                        height: visible ? 24 : 0

                        SectionLabel { x: 44; anchors.verticalCenter: parent.verticalCenter; text: "Name" }
                        SectionLabel { visible: list.sizeWidth > 0; x: parent.width - list.dateWidth - list.sizeWidth; width: 84; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: "Größe" }
                        SectionLabel { visible: list.dateWidth > 0; x: parent.width - list.dateWidth; anchors.verticalCenter: parent.verticalCenter; text: "Geändert" }
                    }

                    ListView {
                        id: list

                        // Columns drop away on narrow windows instead of running into the name.
                        readonly property int dateWidth: width > 580 ? 150 : 0
                        readonly property int sizeWidth: width > 420 ? 96 : 0

                        visible: win.view === "list"
                        anchors.top: columnHeads.bottom
                        anchors.topMargin: 4
                        anchors.bottom: parent.bottom
                        width: parent.width - 8
                        model: visible ? win.shown : []
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        reuseItems: true

                        EmptyArea { parent: list }

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            required property int index
                            readonly property bool isPicked: win.picked[modelData.path] === true
                            readonly property bool isCut: win.board.cut && win.board.paths.includes(modelData.path)

                            width: list.width
                            height: 36
                            radius: win.control
                            color: isPicked ? Qt.alpha(Theme.accent, 0.13)
                                : rowArea.containsMouse || rowDrop.containsDrag ? Qt.alpha(Theme.fg, 0.04) : "transparent"
                            border.width: index === win.cursor && browser.activeFocus && !isPicked ? 1 : 0
                            border.color: Qt.alpha(Theme.accent, 0.35)
                            opacity: isCut ? 0.45 : 1
                            Behavior on color { ColorAnimation { duration: win.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }

                            Rectangle {
                                visible: row.isPicked
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: parent.height - 14
                                radius: Theme.square ? 0 : 1
                                color: Theme.accent
                            }

                            Text {
                                id: rowGlyph
                                x: 16
                                width: 18
                                anchors.verticalCenter: parent.verticalCenter
                                text: Util.glyphs[row.modelData.kind] ?? Util.glyphs.file
                                color: row.modelData.dir || row.isPicked ? Theme.fg : Theme.fgMuted
                                font.family: win.iconFont
                                font.pixelSize: 16
                            }

                            Text {
                                anchors.left: rowGlyph.right
                                anchors.leftMargin: 10
                                anchors.right: rowSize.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.name
                                elide: Text.ElideMiddle
                                color: Theme.fg
                                font.family: Theme.fontUi
                                font.pixelSize: 13
                                font.italic: row.modelData.link
                            }

                            Text {
                                id: rowSize
                                visible: list.sizeWidth > 0
                                x: parent.width - list.dateWidth - list.sizeWidth
                                width: list.sizeWidth ? 84 : 0
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.dir ? "" : Util.size(row.modelData.size)
                                color: Theme.fgMuted
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                            }

                            Text {
                                visible: list.dateWidth > 0
                                x: parent.width - list.dateWidth
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDateTime(new Date(row.modelData.mtime), "dd.MM.yyyy  HH:mm")
                                color: Theme.fgMuted
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                            }

                            EntryArea {
                                id: rowArea
                                index: row.index
                                entry: row.modelData
                            }

                            DropArea {
                                id: rowDrop
                                anchors.fill: parent
                                enabled: row.modelData.dir
                                onDropped: drop => win.dropInto(drop, row.modelData.path)
                            }
                        }
                    }

                    ScrollHint { flick: list; visible: list.visible && list.contentHeight > list.height }

                    GridView {
                        id: grid

                        visible: win.view === "grid"
                        anchors.fill: parent
                        anchors.rightMargin: 8
                        model: visible ? win.shown : []
                        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 124)))
                        cellHeight: 136
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        reuseItems: true

                        EmptyArea { parent: grid }

                        delegate: Item {
                            id: tile

                            required property var modelData
                            required property int index
                            readonly property bool isPicked: win.picked[modelData.path] === true
                            readonly property bool isCut: win.board.cut && win.board.paths.includes(modelData.path)

                            width: grid.cellWidth
                            height: grid.cellHeight
                            opacity: isCut ? 0.45 : 1

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: win.control
                                color: tile.isPicked ? Qt.alpha(Theme.accent, 0.13)
                                    : tileArea.containsMouse || tileDrop.containsDrag ? Qt.alpha(Theme.fg, 0.04) : "transparent"
                                border.width: tile.index === win.cursor && browser.activeFocus ? 1 : 0
                                border.color: Qt.alpha(Theme.accent, tile.isPicked ? 0.5 : 0.35)
                                Behavior on color { ColorAnimation { duration: win.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }
                            }

                            Item {
                                id: preview
                                x: (parent.width - width) / 2
                                y: 14
                                width: 72
                                height: 64

                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    visible: status === Image.Ready
                                    source: tile.modelData.kind === "image" ? win.fileUrl(tile.modelData.path) : ""
                                    sourceSize: Qt.size(144, 128)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !thumb.visible
                                    text: Util.glyphs[tile.modelData.kind] ?? Util.glyphs.file
                                    color: tile.modelData.dir ? Theme.fg : Theme.fgMuted
                                    font.family: win.iconFont
                                    font.pixelSize: 46
                                }
                            }

                            Text {
                                x: 10
                                y: preview.y + preview.height + 8
                                width: parent.width - 20
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.modelData.name
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                color: Theme.fg
                                font.family: Theme.fontUi
                                font.pixelSize: 12
                                font.italic: tile.modelData.link
                            }

                            EntryArea {
                                id: tileArea
                                index: tile.index
                                entry: tile.modelData
                            }

                            DropArea {
                                id: tileDrop
                                anchors.fill: parent
                                enabled: tile.modelData.dir
                                onDropped: drop => win.dropInto(drop, tile.modelData.path)
                            }
                        }
                    }

                    ScrollHint { flick: grid; visible: grid.visible && grid.contentHeight > grid.height }

                    Column {
                        anchors.centerIn: parent
                        visible: win.shown.length === 0
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: win.error ? "Kein Zugriff" : filterField.text ? "Nichts passt zu „" + filterField.text + "“" : "Dieser Ordner ist leer"
                            color: Theme.fg
                            font.family: Theme.fontUi
                            font.pixelSize: 14
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: text !== ""
                            text: win.error
                            color: Theme.fgMuted
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                        }
                    }
                }
            }

            Item {
                id: footer

                x: card.padding
                width: parent.width - 2 * card.padding
                height: 32
                anchors.bottom: parent.bottom
                anchors.bottomMargin: card.padding - 6

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Theme.hairline, 0.6)
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: space.left
                    anchors.rightMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    elide: Text.ElideRight
                    text: {
                        if (win.message)
                            return win.message
                        const count = win.pickedPaths.length
                        if (count > 0) {
                            const bytes = win.shown.filter(entry => win.picked[entry.path] && !entry.dir)
                                .reduce((sum, entry) => sum + entry.size, 0)
                            return count + " ausgewählt" + (bytes ? "  ·  " + Util.size(bytes) : "")
                        }
                        const folders = win.shown.filter(entry => entry.dir).length
                        return folders + " Ordner  ·  "
                            + (win.shown.length - folders) + (win.shown.length - folders === 1 ? " Datei" : " Dateien")
                    }
                    color: win.message && win.failed ? Theme.danger : Theme.fgMuted
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                }

                Text {
                    id: space
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    text: win.path ? Files.space(win.path) : ""
                    color: Theme.fgMuted
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }
            }
        }
    }

    Item {
        id: menuLayer

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
        radius: win.control + 4
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
            NumberAnimation { target: menu; property: "opacity"; to: 1; duration: win.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
            NumberAnimation { target: menu; property: "scale"; to: 1; duration: win.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
        }

        ParallelAnimation {
            id: menuOut
            NumberAnimation { target: menu; property: "opacity"; to: 0; duration: win.exitMs; easing.type: Easing.OutCubic }
            NumberAnimation { target: menu; property: "scale"; to: 0.97; duration: win.exitMs; easing.type: Easing.OutCubic }
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
                        radius: win.control
                        opacity: menuEntry.usable ? 1 : 0.35
                        color: menuPointer.containsMouse && menuEntry.usable
                            ? (menuEntry.modelData.danger ? Qt.alpha(Theme.danger, 0.16) : Qt.alpha(Theme.accent, 0.13)) : "transparent"
                        Behavior on color { ColorAnimation { duration: win.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }

                        Text {
                            id: menuGlyph
                            x: 10
                            width: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: menuEntry.modelData.glyph ?? ""
                            color: menuEntry.modelData.danger ? Theme.danger : Theme.fgMuted
                            font.family: win.iconFont
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

    Item {
        id: sheetLayer

        property real reveal: 0

        anchors.fill: parent
        visible: reveal > 0
        z: 10

        NumberAnimation {
            id: sheetIn
            target: sheetLayer
            property: "reveal"
            to: 1
            duration: win.enterMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Util.enter
        }

        NumberAnimation {
            id: sheetOut
            target: sheetLayer
            property: "reveal"
            to: 0
            duration: win.exitMs
            easing.type: Easing.OutCubic
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            opacity: sheetLayer.reveal
        }

        MouseArea {
            anchors.fill: parent
            onClicked: win.closeSheet()
        }

        Rectangle {
            id: sheetCard

            readonly property bool asksName: win.sheet === "mkdir" || win.sheet === "rename"
            readonly property string names: win.sheetTargets.slice(0, 4).map(p => p.slice(p.lastIndexOf("/") + 1)).join(", ")
                + (win.sheetTargets.length > 4 ? " und " + (win.sheetTargets.length - 4) + " weitere" : "")

            width: 440
            height: sheetColumn.height + 48
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            radius: Theme.radius
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.hairline
            opacity: sheetLayer.reveal
            scale: 0.97 + 0.03 * sheetLayer.reveal
            Keys.onReturnPressed: win.confirmSheet()
            Keys.onEnterPressed: win.confirmSheet()
            Keys.onEscapePressed: win.closeSheet()

            MouseArea { anchors.fill: parent }

            Column {
                id: sheetColumn

                x: 24
                y: 24
                width: parent.width - 48
                spacing: 16

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
                    visible: !sheetCard.asksName
                    text: win.sheet === "delete"
                        ? sheetCard.names + " wird sofort gelöscht, ohne Papierkorb. Das lässt sich nicht rückgängig machen."
                        : sheetCard.names + " landet im Papierkorb und lässt sich von dort zurückholen."
                    wrapMode: Text.Wrap
                    color: Theme.fgMuted
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    lineHeight: 1.2
                }

                Rectangle {
                    visible: sheetCard.asksName
                    width: parent.width
                    height: 38
                    radius: Theme.square ? 0 : height / 2
                    color: Qt.alpha(Theme.fg, sheetField.activeFocus ? 0.09 : 0.06)

                    TextInput {
                        id: sheetField

                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.fg
                        selectionColor: Qt.alpha(Theme.accent, 0.35)
                        selectedTextColor: Theme.fg
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        clip: true
                        Accessible.name: "Name"
                        Keys.onReturnPressed: win.confirmSheet()
                        Keys.onEnterPressed: win.confirmSheet()
                        Keys.onEscapePressed: win.closeSheet()

                        Text {
                            visible: sheetField.text === ""
                            text: "Name …"
                            color: Theme.fgMuted
                            font: sheetField.font
                        }
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
        }
    }
}
