pragma ComponentBehavior: Bound

import QtQuick
import Filyy

// The window-wide shortcuts. Keys that belong to the file list live in browser/keyboard.js.
Item {
    id: root

    required property var app

    Shortcut {
        sequence: "Ctrl+L"
        onActivated: root.app.pane.editPath()
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: root.app.pane.focusFilter()
    }

    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: root.app.close()
    }

    Shortcut {
        sequence: "Ctrl+Z"
        onActivated: Undo.undo()
    }

    Shortcut {
        sequences: ["Ctrl+K", "Ctrl+P"]
        onActivated: root.app.openJump()
    }

    Shortcut {
        sequence: "Ctrl+Shift+F"
        onActivated: root.app.openSearch()
    }

    Shortcut {
        sequence: "Ctrl+T"
        onActivated: root.app.newTab(root.app.pane.path)
    }

    Shortcut {
        sequence: "Ctrl+W"
        onActivated: root.app.closeTab(root.app.tabIndex)
    }

    Shortcut {
        sequences: ["Ctrl+Tab", "Ctrl+PgDown"]
        onActivated: root.app.switchTab((root.app.tabIndex + 1) % root.app.tabCount)
    }

    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab", "Ctrl+PgUp"]
        onActivated: root.app.switchTab((root.app.tabIndex + root.app.tabCount - 1) % root.app.tabCount)
    }

    Shortcut {
        sequence: "F3"
        onActivated: root.app.toggleSplit()
    }

    Shortcut {
        sequence: "F6"
        onActivated: root.app.otherPane()
    }

    Shortcut {
        sequence: "F5"
        onActivated: root.app.pane.reload()
    }

    Shortcut {
        sequence: "Ctrl+H"
        onActivated: root.app.pane.toggleHidden()
    }

    Shortcut {
        sequence: "Alt+Left"
        onActivated: root.app.pane.stepHistory(-1)
    }

    Shortcut {
        sequence: "Alt+Right"
        onActivated: root.app.pane.stepHistory(1)
    }

    Shortcut {
        sequence: "Alt+Up"
        onActivated: root.app.pane.up()
    }

    Shortcut {
        sequence: "Ctrl+1"
        onActivated: root.app.pane.view = "list"
    }

    Shortcut {
        sequence: "Ctrl+2"
        onActivated: root.app.pane.view = "grid"
    }

    Shortcut {
        sequence: "Ctrl+3"
        onActivated: root.app.pane.view = "usage"
    }
}
