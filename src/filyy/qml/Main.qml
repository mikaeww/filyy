pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Filyy
import "theme"
import "window"
import "sheets"
import "quicklook"
import "format.js" as Format

// The window: sidebar left, tabs and one or two panes right, menus, jobs and sheets on top.
Window {
    id: win

    required property string startPath
    // True when started without a folder: the tabs from last time come back.
    property bool restore: false
    property bool restoring: true

    readonly property string home: Files.home()
    readonly property string trashPath: Files.trashPath()
    readonly property alias quickLook: quickLook
    // Hyprland tiles and groups ignore minimumWidth, so the layout has to fold instead.
    readonly property bool compact: width < Theme.compactWidth
    readonly property var tab: tabAt(tabIndex)
    readonly property bool split: tab ? tab.split : false
    readonly property int tabCount: tabModel.count

    // The pane the sidebar, the shortcuts and the menus act on.
    property var pane: null
    property int tabIndex: 0
    property string message: ""
    property bool failed: false
    property bool settingsOpen: false
    property var places: Files.places()
    property var board: Files.clipboard()
    // A tab chip dragged over the panes: {index, x, y, title} in window coordinates, or null.
    property var tabDrag: null
    readonly property string tabDropZone: tabDrag ? dropZoneAt(tabDrag.x, tabDrag.y) : ""

    width: Prefs.get("width", 1180)
    height: Prefs.get("height", 720)
    minimumWidth: 480
    minimumHeight: 460
    visible: true
    color: Theme.bg
    title: "Filyy – " + (pane ? pane.title : "")

    Component.onCompleted: {
        const session = restore ? Prefs.get("session", null) : null;
        // Lists from Python arrive as Qt sequences, not real arrays.
        const saved = session && session.tabs ? Array.from(session.tabs).filter(t => t && Files.exists(t.path)) : [];
        for (const t of saved)
            tabModel.append({
                start: t.path,
                split: !!t.split,
                vertical: !!t.vertical,
                second: t.second && Files.exists(t.second) ? t.second : t.path
            });
        if (!saved.length)
            tabModel.append({
                start: startPath,
                split: false,
                vertical: false,
                second: startPath
            });
        Qt.callLater(() => {
            switchTab(Math.min(Math.max(0, saved.length ? session.index ?? 0 : 0), tabModel.count - 1));
            restoring = false;
            saveSession();
        });
    }

    onClosing: saveSession()
    onWidthChanged: sizeSave.restart()
    onHeightChanged: sizeSave.restart()
    onActiveChanged: if (active)
        places = Files.places()

    // Tabs, split and folders, written whenever any of them changes.
    function saveSession() {
        // A window opened on one folder by another app must not replace the tabs you left.
        if (restoring || !restore)
            return;
        const tabsNow = [];
        for (let i = 0; i < tabModel.count; i++) {
            const owner = tabAt(i);
            if (!owner || !owner.first.path)
                continue;
            tabsNow.push({
                path: owner.first.path,
                split: owner.split,
                vertical: owner.vertical,
                second: owner.secondPane ? owner.secondPane.path : owner.first.path
            });
        }
        if (tabsNow.length)
            Prefs.set("session", {
                tabs: tabsNow,
                index: tabIndex
            });
    }

    function tabAt(index) {
        return panes.tabAt(index);
    }

    function focusPane(browser) {
        pane = browser;
        const owner = tabAt(tabIndex);
        if (owner && (owner.first === browser || owner.secondPane === browser))
            owner.lastPane = browser;
    }

    function newTab(path) {
        tabModel.append({
            start: path,
            split: false,
            vertical: false,
            second: path
        });
        Qt.callLater(() => switchTab(tabModel.count - 1));
    }

    function switchTab(index) {
        if (index < 0 || index >= tabModel.count)
            return;
        tabIndex = index;
        saveSession();
        const owner = tabAt(index);
        if (owner && owner.lastPane) {
            pane = owner.lastPane;
            pane.focusList();
        }
    }

    function closeTab(index) {
        if (tabModel.count === 1)
            return win.close();
        tabModel.remove(index);
        switchTab(Math.min(index <= tabIndex ? Math.max(0, tabIndex - 1) : tabIndex, tabModel.count - 1));
        saveSession();
    }

    function toggleSplit() {
        const owner = tabAt(tabIndex);
        if (!owner)
            return;
        if (!owner.split)
            tabModel.setProperty(tabIndex, "second", owner.first.path);
        tabModel.setProperty(tabIndex, "split", !owner.split);
        Qt.callLater(() => {
            focusPane(owner.split ? owner.secondPane : owner.first);
            pane.focusList();
            saveSession();
        });
    }

    // "right" or "bottom" when a dragged tab would become the other half of the current tab.
    function dropZoneAt(x, y) {
        if (!tabDrag || tabDrag.index === tabIndex)
            return "";
        const at = panes.mapFromItem(win.contentItem, x, y);
        if (at.x < 0 || at.y < 0 || at.x > panes.width || at.y > panes.height)
            return "";
        return at.x > panes.width * 0.55 ? "right" : at.y > panes.height * 0.55 ? "bottom" : "";
    }

    // Dropping tab `index` beside or under the current one makes it that tab's second pane.
    function dropTab(index, x, y) {
        const zone = dropZoneAt(x, y);
        tabDrag = null;
        const owner = tabAt(tabIndex);
        const dragged = tabAt(index);
        if (!zone || !owner || !dragged)
            return;
        const path = dragged.first.path;
        tabModel.setProperty(tabIndex, "vertical", zone === "bottom");
        if (owner.split) {
            owner.secondPane.navigate(path);
        } else {
            tabModel.setProperty(tabIndex, "second", path);
            tabModel.setProperty(tabIndex, "split", true);
        }
        const keep = index < tabIndex ? tabIndex - 1 : tabIndex;
        tabModel.remove(index);
        switchTab(keep);
        Qt.callLater(() => {
            if (owner.secondPane) {
                focusPane(owner.secondPane);
                pane.focusList();
            }
            saveSession();
        });
    }

    function otherPaneOf(browser) {
        if (!split || !tab)
            return null;
        return browser === tab.first ? tab.secondPane : tab.first;
    }

    function otherPane() {
        const other = otherPaneOf(pane);
        if (other) {
            focusPane(other);
            pane.focusList();
        }
    }

    function say(text, bad) {
        message = text;
        failed = bad;
        messageTimer.restart();
    }

    function openSheet(kind) {
        const targets = !pane ? [] : kind === "empty" ? pane.entries.map(entry => entry.path) : pane.targets;
        if (kind !== "mkdir" && targets.length === 0)
            return;
        if (kind === "rename" && targets.length > 1)
            return renameSheet.start(targets);
        nameSheet.ask(kind, targets, pane.path);
    }

    function openWith(path) {
        openWithSheet.start(path);
    }

    // Starts with whatever the pane's filter holds, so filtering can turn into a content search.
    function openSearch(query) {
        searchSheet.start(pane.path, query ?? pane.filterText);
    }

    function openJump() {
        jumpSheet.start();
    }

    function cut(paths) {
        if (!paths.length)
            return;
        Files.setClipboard(paths, true);
        say(Format.tr(I18n.strings, "{n} ausgeschnitten", {
            n: paths.length
        }), false);
    }

    function copy(paths) {
        if (!paths.length)
            return;
        Files.setClipboard(paths, false);
        say(Format.tr(I18n.strings, "{n} kopiert", {
            n: paths.length
        }), false);
    }

    function dropInto(drop, folder) {
        const paths = drop.urls.map(url => String(url)).filter(url => url.startsWith("file://")).map(url => decodeURIComponent(url.slice(7)));
        if (paths.length === 0)
            return;
        if (Files.inArchive(paths[0])) {
            Files.extract(paths, folder);
            drop.accept(Qt.CopyAction);
            return;
        }
        // ponytail: drags from inside Filyy move, drags from other apps copy; Dolphin asks instead.
        const move = drop.source !== null;
        Files.transfer(paths, folder, move);
        drop.accept(move ? Qt.MoveAction : Qt.CopyAction);
    }

    // The archive file a virtual path like pack.zip/dir points into.
    function archiveOf(path) {
        const folder = Files.archiveFolder(path);
        return folder + "/" + path.slice(folder.length + 1).split("/")[0];
    }

    function showMenu(entry, x, y) {
        menu.show(entry, x, y);
    }

    Timer {
        id: sizeSave

        interval: 400
        onTriggered: {
            Prefs.set("width", win.width);
            Prefs.set("height", win.height);
        }
    }

    Timer {
        id: messageTimer

        interval: 4000
        onTriggered: win.message = ""
    }

    Connections {
        function onDone(ok, text, select) {
            win.say(text, !ok);
        }

        function onClipboardChanged() {
            win.board = Files.clipboard();
        }

        target: Files
    }

    Connections {
        function onChanged() {
            win.places = Files.places();
        }

        target: I18n
    }

    Connections {
        function onDone(ok, text, steps) {
            win.say(text, !ok);
        }

        target: Rename
    }

    Connections {
        function onDone(ok, text) {
            win.say(text, !ok);
        }

        target: Undo
    }

    Shortcuts {
        app: win
    }

    ListModel {
        id: tabModel
    }

    // Everything but the overlays; the file picker shortens it to make room for its bar.
    Item {
        id: layout

        objectName: "layout"
        width: parent.width
        height: parent.height

        Rail {
            id: rail

            x: Theme.space4
            y: Theme.space4
            width: win.compact ? Theme.rowH : Theme.sidebarWidth
            height: parent.height - 2 * Theme.space4
            app: win
        }

        TabStrip {
            id: tabStrip

            visible: tabModel.count > 1
            x: panes.x
            y: Theme.space4
            width: panes.width
            height: visible ? Theme.ctlH : 0
            app: win
            model: tabModel
        }

        Panes {
            id: panes

            x: rail.x + rail.width + (win.compact ? Theme.space4 : Theme.space5)
            y: tabStrip.visible ? tabStrip.y + tabStrip.height + Theme.space3 : Theme.space4
            width: parent.width - x - Theme.space4
            height: parent.height - y - Theme.space4
            app: win
            model: tabModel
        }
    }

    // The dragged tab following the pointer; where it would land is drawn inside the panes.
    Rectangle {
        visible: win.tabDrag !== null
        x: win.tabDrag ? win.tabDrag.x - width / 2 : 0
        y: win.tabDrag ? win.tabDrag.y - height / 2 : 0
        z: 4
        width: dragTitle.implicitWidth + 2 * Theme.space3
        height: Theme.ctlH
        radius: Theme.radiusSmall
        color: Theme.raise3

        Text {
            id: dragTitle

            anchors.centerIn: parent
            text: win.tabDrag ? win.tabDrag.title : ""
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBody
            font.bold: true
        }
    }

    ContextMenu {
        id: menu

        app: win
    }

    JobStack {
        anchors.right: parent.right
        anchors.rightMargin: Theme.space5 + Theme.space2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space5 + Theme.ctlH + Theme.space2
    }

    NameSheet {
        id: nameSheet

        app: win
    }

    SettingsSheet {
        app: win
    }

    QuickLook {
        id: quickLook

        app: win
    }

    RenameSheet {
        id: renameSheet

        app: win
    }

    OpenWithSheet {
        id: openWithSheet

        app: win
    }

    SearchSheet {
        id: searchSheet

        app: win
    }

    JumpSheet {
        id: jumpSheet

        app: win
    }

    ConflictSheet {}
}
