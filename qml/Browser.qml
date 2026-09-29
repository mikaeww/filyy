import QtQuick
import Filyy
import "Util.js" as Util

// One folder view with its own history, selection, filter and view mode; tabs and the split
// view are just more of these.
FocusScope {
    id: root

    required property var app
    property string startPath: app.home

    readonly property bool isActive: app.pane === root
    readonly property real padding: app.compact ? 14 : 20

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
    property bool editingPath: false

    readonly property var shown: {
        const needle = filterField.text.trim().toLowerCase()
        return needle ? entries.filter(entry => entry.name.toLowerCase().includes(needle)) : entries
    }
    readonly property var current: shown[cursor] ?? null
    readonly property var pickedPaths: Object.keys(picked)
    readonly property var targets: pickedPaths.length ? pickedPaths : (current ? [current.path] : [])
    readonly property Flickable activeView: view === "grid" ? grid : list
    readonly property string title: path === app.home ? "Home" : path.slice(path.lastIndexOf("/") + 1) || "/"

    Component.onCompleted: navigate(startPath)

    function navigate(target) {
        const clean = target.trim().replace(/^~(?=\/|$)/, app.home).replace(/(.)\/+$/, "$1")
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

    function toggleHidden() {
        showHidden = !showHidden
        reload()
    }

    function focusFilter() {
        filterField.input.forceActiveFocus()
    }

    function editPath() {
        editingPath = true
        pathField.forceActiveFocus()
        pathField.selectAll()
    }

    function focusList() {
        root.forceActiveFocus()
    }

    // Right edge of an entry in window coordinates, for menus opened from the keyboard.
    function anchorOf(index) {
        const item = activeView.itemAtIndex ? activeView.itemAtIndex(index) : null
        return item ? item.mapToItem(app.contentItem, 24, item.height / 2) : Qt.point(app.width / 2, app.height / 2)
    }

    Connections {
        target: Files

        function onFolderChanged(changed) {
            if (changed === root.path)
                root.reload()
        }

        function onDone(ok, text, select) {
            if (ok && select && select.slice(0, select.lastIndexOf("/")) === root.path)
                root.pendingSelect = select
            root.reload()
        }
    }

    // Any press inside makes this the pane that the rail, shortcuts and menus act on.
    MouseArea {
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            root.app.focusPane(root)
            mouse.accepted = false
        }
    }

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier
        const shift = event.modifiers & Qt.ShiftModifier
        const columns = view === "grid" ? Math.max(1, Math.floor(grid.width / grid.cellWidth)) : 1
        if (event.key === Qt.Key_Down) moveCursor(columns, shift)
        else if (event.key === Qt.Key_Up) moveCursor(-columns, shift)
        else if (event.key === Qt.Key_Right && view === "grid") moveCursor(1, shift)
        else if (event.key === Qt.Key_Left && view === "grid") moveCursor(-1, shift)
        else if (event.key === Qt.Key_Home) moveCursor(-shown.length, shift)
        else if (event.key === Qt.Key_End) moveCursor(shown.length, shift)
        else if (event.key === Qt.Key_PageDown) moveCursor(10 * columns, shift)
        else if (event.key === Qt.Key_PageUp) moveCursor(-10 * columns, shift)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) activate(current)
        else if (event.key === Qt.Key_Backspace) up()
        else if (event.key === Qt.Key_Delete) app.openSheet(shift ? "delete" : "trash")
        else if (event.key === Qt.Key_F2) app.openSheet("rename")
        else if (event.key === Qt.Key_F10 && !shift || (ctrl && shift && event.key === Qt.Key_N)) app.openSheet("mkdir")
        else if (shift && event.key === Qt.Key_F4) Files.terminal(path)
        else if (ctrl && shift && event.key === Qt.Key_C) Files.copyPaths(targets)
        else if (ctrl && event.key === Qt.Key_A) selectRange(0, shown.length - 1)
        else if (ctrl && event.key === Qt.Key_C) app.copy(targets)
        else if (ctrl && event.key === Qt.Key_X) app.cut(targets)
        else if (ctrl && event.key === Qt.Key_V) Files.paste(path)
        else if (ctrl && event.key === Qt.Key_D) Files.duplicate(targets)
        else if (event.key === Qt.Key_Menu || (shift && event.key === Qt.Key_F10)) {
            const at = anchorOf(cursor)
            app.showMenu(current, at.x, at.y)
        } else if (event.key === Qt.Key_Escape) {
            if (pickedPaths.length) picked = {}
            else filterField.text = ""
        } else if (event.text.length === 1 && event.text > " " && !ctrl) {
            // Typing anywhere starts filtering, like Dolphin's type-ahead.
            filterField.text += event.text
            focusFilter()
        } else {
            return
        }
        event.accepted = true
    }

    // Click, multi-select, context menu and drag-out for one entry, shared by list and grid.
    component EntryArea: MouseArea {
        id: area

        required property int index
        required property var entry
        property int pressModifiers: 0

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        drag.target: proxy
        drag.threshold: 8
        // Without this the view steals the drag for scrolling and files never leave the window.
        preventStealing: true

        onPressed: mouse => {
            root.focusList()
            pressModifiers = mouse.modifiers
            if (mouse.button === Qt.MiddleButton) {
                if (entry.dir)
                    root.app.newTab(entry.path)
                return
            }
            // A press on an already picked entry keeps the group so it can be dragged together.
            if (!root.picked[entry.path] || mouse.modifiers !== Qt.NoModifier)
                root.select(index, mouse.modifiers)
            if (mouse.button === Qt.RightButton) {
                const at = mapToItem(root.app.contentItem, mouse.x, mouse.y)
                root.app.showMenu(entry, at.x, at.y)
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && pressModifiers === Qt.NoModifier && root.pickedPaths.length > 1)
                root.select(index, 0)
        }
        onDoubleClicked: mouse => { if (mouse.button === Qt.LeftButton) root.activate(entry) }
        onReleased: { proxy.x = 0; proxy.y = 0 }

        Item {
            id: proxy
            Drag.active: area.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
            Drag.mimeData: ({ "text/uri-list": root.targets.map(p => Util.fileUrl(p)).join("\r\n") })
        }
    }

    // Empty space of a view: a click clears the selection, a right click opens the folder menu.
    // It sits under the view's content, so entries still get their own presses first.
    component EmptyArea: MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            root.focusList()
            root.picked = {}
            if (mouse.button === Qt.RightButton) {
                const at = mapToItem(root.app.contentItem, mouse.x, mouse.y)
                root.app.showMenu(null, at.x, at.y)
            }
        }
    }

    Item {
        id: header

        x: root.padding
        y: root.padding
        width: parent.width - 2 * root.padding
        height: 36
        opacity: root.isActive || !root.app.split ? 1 : 0.55
        Behavior on opacity { NumberAnimation { duration: Theme.quickMs } }

        Row {
            id: nav
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            IconButton { glyph: Util.glyphs.back; label: "Zurück"; enabled: root.history.index > 0; onClicked: root.stepHistory(-1) }
            IconButton { glyph: Util.glyphs.forward; label: "Vor"; enabled: root.history.index < root.history.list.length - 1; onClicked: root.stepHistory(1) }
            IconButton { glyph: Util.glyphs.up; label: "Hoch"; enabled: root.path !== "/"; onClicked: root.up() }
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
            color: Qt.alpha(Theme.fg, root.editingPath ? 0.09 : crumbPointer.containsMouse ? 0.06 : 0.04)
            Behavior on color { ColorAnimation { duration: Theme.quickMs } }
            clip: true

            MouseArea {
                id: crumbPointer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onClicked: root.editPath()
            }

            Row {
                visible: !root.editingPath
                anchors.verticalCenter: parent.verticalCenter
                // Keeps the deepest folder in view when the path is longer than the bar.
                x: Math.min(14, crumbBox.width - width - 14)
                spacing: 2

                Repeater {
                    model: Util.crumbs(root.path, root.app.home)

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
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                        }

                        Rectangle {
                            width: crumbText.implicitWidth + 14
                            height: 26
                            radius: Theme.control
                            color: crumbHover.containsMouse || crumbDrop.containsDrag ? Qt.alpha(Theme.fg, 0.07) : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.quickMs } }

                            Text {
                                id: crumbText
                                anchors.centerIn: parent
                                text: crumb.modelData.name
                                color: crumb.modelData.path === root.path ? Theme.fg : Theme.fgMuted
                                font.family: Theme.fontUi
                                font.pixelSize: 13
                                font.weight: crumb.modelData.path === root.path ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: crumbHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.navigate(crumb.modelData.path)
                            }

                            DropArea {
                                id: crumbDrop
                                anchors.fill: parent
                                onDropped: drop => root.app.dropInto(drop, crumb.modelData.path)
                            }
                        }
                    }
                }
            }

            TextInput {
                id: pathField

                visible: root.editingPath
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.path.replace(root.app.home, "~")
                color: Theme.fg
                selectionColor: Qt.alpha(Theme.accent, 0.35)
                selectedTextColor: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: 13
                clip: true
                Accessible.name: "Pfad"

                onActiveFocusChanged: if (!activeFocus) root.editingPath = false
                Keys.onReturnPressed: { root.navigate(text); root.focusList() }
                Keys.onEnterPressed: { root.navigate(text); root.focusList() }
                Keys.onEscapePressed: {
                    text = Qt.binding(() => root.path.replace(root.app.home, "~"))
                    root.focusList()
                }
            }
        }

        Row {
            id: tools

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Field {
                id: filterField

                width: root.width < 760 ? 130 : 210
                glyph: Util.glyphs.search
                placeholder: "Filtern …"

                onTextChanged: {
                    root.cursor = 0
                    root.anchor = 0
                    root.picked = {}
                }
                onKeyPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        text = ""
                        root.focusList()
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.focusList()
                        if (event.key !== Qt.Key_Down) root.activate(root.current)
                    } else {
                        return
                    }
                    event.accepted = true
                }
            }

            Item { width: 8; height: 1 }

            IconButton { visible: root.width >= 560; glyph: Util.glyphs.list; label: "Liste"; active: root.view === "list"; onClicked: root.view = "list" }
            IconButton { visible: root.width >= 560; glyph: Util.glyphs.grid; label: "Raster"; active: root.view === "grid"; onClicked: root.view = "grid" }
            IconButton { visible: root.width >= 560; glyph: root.showHidden ? Util.glyphs.eye : Util.glyphs.eyeOff; label: "Versteckte Dateien"; active: root.showHidden; onClicked: root.toggleHidden() }
            IconButton { glyph: Util.glyphs.newFolder; label: "Neuer Ordner"; onClicked: root.app.openSheet("mkdir") }
        }
    }

    Item {
        id: body

        anchors.top: header.bottom
        anchors.topMargin: 16
        anchors.bottom: footer.top
        anchors.bottomMargin: 8
        x: root.padding - 8
        width: parent.width - 2 * (root.padding - 8)
        transform: Translate { id: rise }

        ParallelAnimation {
            id: pageIn
            NumberAnimation { target: body; property: "opacity"; to: 1; duration: Theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: rise; property: "y"; to: 0; duration: Theme.reducedMotion ? 0 : 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.enter }
        }

        DropArea {
            anchors.fill: parent
            onDropped: drop => root.app.dropInto(drop, root.path)
        }

        Item {
            id: columnHeads

            visible: root.view === "list"
            width: parent.width - 8
            height: visible ? 24 : 0

            SectionLabel { x: 44; anchors.verticalCenter: parent.verticalCenter; text: "Name" }
            SectionLabel { visible: list.sizeWidth > 0; x: parent.width - list.dateWidth - list.sizeWidth; width: 84; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: "Größe" }
            SectionLabel { visible: list.dateWidth > 0; x: parent.width - list.dateWidth; anchors.verticalCenter: parent.verticalCenter; text: "Geändert" }
        }

        ListView {
            id: list

            // Columns drop away on narrow panes instead of running into the name.
            readonly property int dateWidth: width > 580 ? 150 : 0
            readonly property int sizeWidth: width > 420 ? 96 : 0

            visible: root.view === "list"
            anchors.top: columnHeads.bottom
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            width: parent.width - 8
            model: visible ? root.shown : []
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            reuseItems: true

            EmptyArea { parent: list }

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index
                readonly property bool isPicked: root.picked[modelData.path] === true
                readonly property bool isCut: root.app.board.cut && root.app.board.paths.includes(modelData.path)

                width: list.width
                height: 36
                radius: Theme.control
                color: isPicked ? Qt.alpha(Theme.accent, 0.13)
                    : rowArea.containsMouse || rowDrop.containsDrag ? Qt.alpha(Theme.fg, 0.04) : "transparent"
                border.width: index === root.cursor && root.activeFocus && !isPicked ? 1 : 0
                border.color: Qt.alpha(Theme.accent, 0.35)
                opacity: isCut ? 0.45 : 1
                Behavior on color { ColorAnimation { duration: Theme.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }

                Rectangle {
                    visible: row.isPicked
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: parent.height - 14
                    radius: Theme.square ? 0 : 1
                    color: Theme.accent
                }

                FileIcon {
                    id: rowGlyph
                    x: 16
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    kind: row.modelData.kind
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
                    onDropped: drop => root.app.dropInto(drop, row.modelData.path)
                }
            }
        }

        ScrollHint { flick: list }

        GridView {
            id: grid

            visible: root.view === "grid"
            anchors.fill: parent
            anchors.rightMargin: 8
            model: visible ? root.shown : []
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
                readonly property bool isPicked: root.picked[modelData.path] === true
                readonly property bool isCut: root.app.board.cut && root.app.board.paths.includes(modelData.path)

                width: grid.cellWidth
                height: grid.cellHeight
                opacity: isCut ? 0.45 : 1

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Theme.control
                    color: tile.isPicked ? Qt.alpha(Theme.accent, 0.13)
                        : tileArea.containsMouse || tileDrop.containsDrag ? Qt.alpha(Theme.fg, 0.04) : "transparent"
                    border.width: tile.index === root.cursor && root.activeFocus ? 1 : 0
                    border.color: Qt.alpha(Theme.accent, tile.isPicked ? 0.5 : 0.35)
                    Behavior on color { ColorAnimation { duration: Theme.quickMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Util.quick } }
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
                        source: tile.modelData.kind === "image" ? Util.fileUrl(tile.modelData.path) : ""
                        sourceSize: Qt.size(144, 128)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                    }

                    FileIcon {
                        anchors.centerIn: parent
                        visible: !thumb.visible
                        width: 48
                        height: 48
                        kind: tile.modelData.kind
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
                    onDropped: drop => root.app.dropInto(drop, tile.modelData.path)
                }
            }
        }

        ScrollHint { flick: grid }

        Column {
            anchors.centerIn: parent
            visible: root.shown.length === 0
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.error ? "Kein Zugriff" : filterField.text ? "Nichts passt zu „" + filterField.text + "“" : "Dieser Ordner ist leer"
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: 14
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: root.error
                color: Theme.fgMuted
                font.family: Theme.fontUi
                font.pixelSize: 12
            }
        }
    }

    Item {
        id: footer

        x: root.padding
        width: parent.width - 2 * root.padding
        height: 32
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.padding - 6

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
                if (root.isActive && root.app.message)
                    return root.app.message
                const count = root.pickedPaths.length
                if (count > 0) {
                    const bytes = root.shown.filter(entry => root.picked[entry.path] && !entry.dir)
                        .reduce((sum, entry) => sum + entry.size, 0)
                    return count + " ausgewählt" + (bytes ? "  ·  " + Util.size(bytes) : "")
                }
                const folders = root.shown.filter(entry => entry.dir).length
                const files = root.shown.length - folders
                return folders + " Ordner  ·  " + files + (files === 1 ? " Datei" : " Dateien")
            }
            color: root.isActive && root.app.message && root.app.failed ? Theme.danger : Theme.fgMuted
            font.family: Theme.fontUi
            font.pixelSize: 12
        }

        Text {
            id: space
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            text: root.path ? Files.space(root.path) : ""
            color: Theme.fgMuted
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
    }
}
