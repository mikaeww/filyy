.pragma library

// The keys of one pane: cursor movement, selection, the file actions and type-to-filter. A library has no QML
// context, so the Files singleton comes in as an argument. Marks the event accepted when a key did something.

function moveKey(pane, event, columns) {
    var shift = event.modifiers & Qt.ShiftModifier;
    var steps = {};
    steps[Qt.Key_Down] = columns;
    steps[Qt.Key_Up] = -columns;
    steps[Qt.Key_Home] = -pane.shown.length;
    steps[Qt.Key_End] = pane.shown.length;
    steps[Qt.Key_PageDown] = 10 * columns;
    steps[Qt.Key_PageUp] = -10 * columns;
    if (pane.view === "grid") {
        steps[Qt.Key_Right] = 1;
        steps[Qt.Key_Left] = -1;
    }
    if (steps[event.key] === undefined)
        return false;
    pane.moveCursor(steps[event.key], shift);
    return true;
}

// Ctrl+X, V, D and N, F2, F10 and Del change files; inside the trash or an archive they do nothing.
function changes(event) {
    var ctrl = event.modifiers & Qt.ControlModifier;
    return event.key === Qt.Key_Delete || event.key === Qt.Key_F2 || event.key === Qt.Key_F10
        || (ctrl && [Qt.Key_X, Qt.Key_V, Qt.Key_D, Qt.Key_N].indexOf(event.key) >= 0);
}

function actionKey(pane, event, files) {
    var app = pane.app;
    var ctrl = event.modifiers & Qt.ControlModifier;
    var shift = event.modifiers & Qt.ShiftModifier;
    var key = event.key;
    if (key === Qt.Key_Return || key === Qt.Key_Enter) pane.activate(pane.current);
    else if (key === Qt.Key_Space && pane.current && (!pane.inArchive || pane.current.dir)) app.quickLook.show(pane.shown, pane.cursor);
    else if (key === Qt.Key_Backspace) pane.up();
    else if (key === Qt.Key_Delete && !pane.inArchive) app.openSheet(pane.isTrash ? "purge" : shift ? "delete" : "trash");
    else if (pane.readOnly && changes(event)) return true;
    else if (key === Qt.Key_F2) app.openSheet("rename");
    else if ((key === Qt.Key_F10 && !shift) || (ctrl && shift && key === Qt.Key_N)) app.openSheet("mkdir");
    else if (shift && key === Qt.Key_F4) files.terminal(pane.path);
    else if (ctrl && shift && key === Qt.Key_C) files.copyPaths(pane.targets);
    else if (ctrl && key === Qt.Key_A) pane.selectRange(0, pane.shown.length - 1);
    else if (ctrl && key === Qt.Key_C) app.copy(pane.targets);
    else if (ctrl && key === Qt.Key_X) app.cut(pane.targets);
    else if (ctrl && key === Qt.Key_V) files.paste(pane.path);
    else if (ctrl && key === Qt.Key_D) files.duplicate(pane.targets);
    else return false;
    return true;
}

function handle(pane, event, files) {
    var ctrl = event.modifiers & Qt.ControlModifier;
    var shift = event.modifiers & Qt.ShiftModifier;
    var columns = pane.view === "grid" ? pane.activeView.columns : 1;
    if (moveKey(pane, event, columns) || actionKey(pane, event, files)) {
        event.accepted = true;
    } else if (event.key === Qt.Key_Menu || (shift && event.key === Qt.Key_F10)) {
        var at = pane.anchorOf(pane.cursor);
        pane.app.showMenu(pane.current, at.x, at.y);
        event.accepted = true;
    } else if (event.key === Qt.Key_Escape) {
        pane.clearFilterOrSelection();
        event.accepted = true;
    } else if (event.text.length === 1 && event.text > " " && !ctrl) {
        // Typing anywhere starts filtering, like Dolphin's type-ahead.
        pane.typeAhead(event.text);
        event.accepted = true;
    }
}
