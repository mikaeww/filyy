pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../motion"
import "../paths.js" as Paths
import "../format.js" as Format
import "views"
import "keyboard.js" as Keyboard

// One folder view with its own history, selection, filter and view mode: a toolbar on the window background and
// the folder on a raised surface below it. Tabs and the split view are just more of these.
FocusScope {
    id: root

    required property var app
    property string startPath: app.home
    // The second pane of a restored split starts in its own view; everything else takes the last one used.
    property string startView: Prefs.get("view", "list")

    readonly property bool isActive: app.pane === root
    readonly property bool listFocused: listKeys.activeFocus

    property string path: ""
    property var history: ({
            list: [],
            index: -1
        })
    property var entries: []
    property string error: ""
    property bool showHidden: Prefs.get("hidden", false)
    property string view: startView === "grid" ? "grid" : "list"
    // Picked entries as {path: true}; `cursor` is the keyboard position, `anchor` the start of a shift range.
    property var picked: ({})
    property int cursor: 0
    property int anchor: 0
    property string pendingSelect: ""
    property var git: ({})
    // Storage map: rows largest first, the folder's total, and whether measuring finished.
    property var usageRows: []
    property real usageTotal: 0
    property bool usageDone: false
    property int usageRun: -1
    readonly property bool isTrash: path === app.trashPath
    readonly property bool inArchive: path !== "" && Files.inArchive(path)
    // Trash and archives only allow what makes sense there; nothing inside an archive can change.
    readonly property bool readOnly: isTrash || inArchive

    readonly property var shown: {
        const needle = toolbar.filter.text.trim().toLowerCase();
        const base = view === "usage" && !isTrash ? usageRows : entries;
        return needle ? base.filter(entry => entry.name.toLowerCase().includes(needle)) : base;
    }
    readonly property var current: shown[cursor] ?? null
    readonly property string filterText: toolbar.filter.text
    readonly property var pickedPaths: Object.keys(picked)
    readonly property var targets: pickedPaths.length ? pickedPaths : (current ? [current.path] : [])
    // var, not Flickable: the list and grid views add positionViewAtIndex and itemAtIndex.
    readonly property var activeView: isTrash ? graves : view === "grid" ? grid : view === "usage" ? usage : list
    readonly property string title: isTrash ? Format.tr(I18n.strings, "Papierkorb") : path === app.home ? Format.tr(I18n.strings, "Home") : Paths.baseName(path) || "/"

    Component.onCompleted: navigate(startPath)

    // The storage map is a tool, not a layout, so only list and grid are remembered.
    onViewChanged: {
        if (view === "usage") {
            measure();
        } else {
            Usage.cancel();
            Prefs.set("view", view);
        }
    }
    onPathChanged: app.saveSession()

    function measure() {
        usageRows = [];
        usageTotal = 0;
        usageDone = false;
        usageRun = Usage.start(path);
    }

    function navigate(target) {
        const clean = target.trim().replace(/^~(?=\/|$)/, app.home).replace(/(.)\/+$/, "$1");
        if (!clean.startsWith("/"))
            return;
        history = Paths.visit(history, clean);
        open(clean);
    }

    function stepHistory(delta) {
        const index = history.index + delta;
        if (index < 0 || index >= history.list.length)
            return;
        history = {
            list: history.list,
            index: index
        };
        open(history.list[index]);
    }

    function up() {
        if (path === "/")
            return;
        pendingSelect = path;
        navigate(Paths.parentOf(path));
    }

    // A folder change comes in with the page entrance; reload() is the quiet variant.
    function open(target) {
        path = target;
        git = ({});
        if (target !== app.trashPath) {
            Jump.record(target);
            Git.request(target);
        }
        toolbar.filter.text = "";
        toolbar.editingPath = false;
        picked = {};
        cursor = 0;
        anchor = 0;
        reload();
        activeView.contentY = activeView.originY;
        entrance.jump(0);
        entrance.target = 1;
    }

    function reload() {
        const result = Files.list(path, showHidden || isTrash);
        entries = isTrash ? Files.trashEntries() : result.entries;
        error = result.error;
        if (view === "usage" && !isTrash)
            measure();
        const kept = {};
        for (const entry of entries)
            if (picked[entry.path])
                kept[entry.path] = true;
        const wanted = pendingSelect || (current ? current.path : "");
        const index = shown.findIndex(entry => entry.path === wanted);
        if (pendingSelect && index >= 0) {
            kept[pendingSelect] = true;
            pendingSelect = "";
        }
        picked = kept;
        cursor = Math.max(0, Math.min(index >= 0 ? index : cursor, shown.length - 1));
        if (index >= 0)
            Qt.callLater(() => activeView.positionViewAtIndex(cursor, ListView.Contain));
    }

    function activate(entry) {
        if (!entry)
            return;
        // In the trash, opening only looks: restoring is a deliberate menu action.
        if (isTrash)
            // By path: QML hands out a new wrapper object per access, so indexOf never finds the entry.
            app.quickLook.show(shown, Math.max(0, shown.findIndex(e => e.path === entry.path)));
        else if (inArchive && !entry.dir)
            Files.openArchived(entry.path);
        else if (entry.dir || Files.isArchive(entry.path))
            navigate(entry.path);
        else
            Files.open(entry.path);
    }

    function select(index, modifiers) {
        const entry = shown[index];
        if (!entry)
            return;
        if (modifiers & Qt.ShiftModifier) {
            selectRange(anchor, index);
        } else if (modifiers & Qt.ControlModifier) {
            const next = Object.assign({}, picked);
            if (next[entry.path])
                delete next[entry.path];
            else
                next[entry.path] = true;
            picked = next;
            anchor = index;
        } else {
            picked = {
                [entry.path]: true
            };
            anchor = index;
        }
        cursor = index;
    }

    function selectRange(from, to) {
        const next = {};
        for (let i = Math.min(from, to); i <= Math.max(from, to); i++)
            next[shown[i].path] = true;
        picked = next;
    }

    function moveCursor(delta, extend) {
        if (shown.length === 0)
            return;
        const next = Math.max(0, Math.min(shown.length - 1, cursor + delta));
        if (extend) {
            cursor = next;
            selectRange(anchor, next);
        } else {
            select(next, 0);
        }
        activeView.positionViewAtIndex(next, ListView.Contain);
    }

    function toggleHidden() {
        showHidden = !showHidden;
        Prefs.set("hidden", showHidden);
        reload();
    }

    function focusFilter() {
        toolbar.filter.input.forceActiveFocus();
    }

    function typeAhead(text) {
        toolbar.filter.text += text;
        focusFilter();
    }

    function editPath() {
        toolbar.editPath();
    }

    // Focus goes to a plain item, not to the scope: a FocusScope hands its focus back to the last focused
    // child, which kept the filter field grabbing every key after one click into it.
    function focusList() {
        listKeys.forceActiveFocus();
    }

    // Left edge of an entry in window coordinates, for menus opened from the keyboard.
    function anchorOf(index) {
        const item = activeView.itemAtIndex ? activeView.itemAtIndex(index) : null;
        return item ? item.mapToItem(app.contentItem, Theme.space5, item.height / 2) : Qt.point(app.width / 2, app.height / 2);
    }

    function clearFilterOrSelection() {
        if (pickedPaths.length)
            picked = {};
        else
            toolbar.filter.text = "";
    }

    Connections {
        function onProgress(run, rows, total, done) {
            if (run !== root.usageRun)
                return;
            root.usageRows = rows;
            root.usageTotal = total;
            root.usageDone = done;
        }

        target: Usage
    }

    Connections {
        function onReady(folder, info) {
            if (folder === root.path)
                root.git = info;
        }

        target: Git
    }

    Connections {
        function onFolderChanged(changed) {
            if (changed === root.path) {
                root.reload();
                Git.request(root.path);
            }
        }

        function onDone(ok, text, select) {
            if (ok && select && Paths.parentOf(select) === root.path)
                root.pendingSelect = select;
            root.reload();
        }

        target: Files
    }

    // Any press inside makes this the pane that the sidebar, shortcuts and menus act on.
    MouseArea {
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            root.app.focusPane(root);
            mouse.accepted = false;
        }
    }

    Item {
        id: listKeys

        focus: true
    }

    Keys.onPressed: event => Keyboard.handle(root, event, Files)

    Spring {
        id: entrance

        motion: Theme.settle
        // The fade stays with reduced motion; only the rise goes.
        instant: false
        precision: 0.002
    }

    Toolbar {
        id: toolbar

        width: parent.width
        pane: root
        opacity: root.isActive || !root.app.split ? 1 : 0.55

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionFast
            }
        }
    }

    Rectangle {
        id: stage

        y: toolbar.height + Theme.space3
        width: parent.width
        height: parent.height - y
        radius: Theme.radius
        color: Theme.raise1
        clip: true

        DropArea {
            anchors.fill: parent
            onDropped: drop => root.app.dropInto(drop, root.path)
        }

        Item {
            id: body

            x: Theme.space1
            y: Theme.space1 + (Theme.reducedMotion ? 0 : (1 - entrance.value) * Theme.space2)
            width: parent.width - 2 * Theme.space1
            height: footer.y - Theme.space1
            opacity: Math.min(1, entrance.value)

            FileList {
                id: list

                anchors.fill: parent
                visible: root.view === "list" && !root.isTrash
                pane: root
                bottomMargin: gitCard.shown ? gitCard.height + Theme.space3 : 0
            }

            FileGrid {
                id: grid

                anchors.fill: parent
                visible: root.view === "grid" && !root.isTrash
                pane: root
                bottomMargin: gitCard.shown ? gitCard.height + Theme.space3 : 0
            }

            UsageMap {
                id: usage

                anchors.fill: parent
                visible: root.view === "usage" && !root.isTrash
                pane: root
            }

            Graveyard {
                id: graves

                anchors.fill: parent
                visible: root.isTrash
                pane: root
            }

            EmptyState {
                anchors.centerIn: parent
                visible: root.shown.length === 0 && !(root.view === "usage" && !root.usageDone)
                pane: root
            }
        }

        GitCard {
            id: gitCard

            x: Theme.space2
            y: footer.y - height - Theme.space1
            z: 3
            width: Math.min(300, parent.width - 2 * Theme.space2)
            // A half-height split pane has no room for it.
            info: root.height >= 480 ? root.git : ({})
        }

        Footer {
            id: footer

            x: Theme.space1
            y: parent.height - height - Theme.space1
            width: parent.width - 2 * Theme.space1
            pane: root
        }
    }
}
