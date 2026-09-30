# Overview

```text
filyy (launcher) -> python3 -m filyy -> platform.preload_nosuspend -> app.build_engine -> qml/Main.qml
```

## Backend (Python)

`app.backend()` creates one object per concept and registers each as a QML singleton under `import Filyy`:

| Singleton | Module | Does |
|---|---|---|
| `Files` | `filesystem/files.py` | Listing, places, clipboard, quick file actions (mkdir, rename, trash, paste, extract), folder watching |
| `Jobs` | `filesystem/jobs.py` | Copy, move, duplicate and extract on worker threads, with progress, pause, cancel and conflict questions |
| `Undo` | `filesystem/undo.py` | Reverts the last recorded file action from its steps |
| `Rename` | `filesystem/rename.py` | Batch rename plan and run through temporary names |
| `Jump`, `Search`, `Usage`, `Git` | `lookup/` | Fuzzy folder jump, ripgrep search, storage map, git card |
| `Preview`, `Thumbs`, `Apps` | `preview/` | Quick look text and grey highlighting, video thumbnails, apps per file type |
| `Prefs`, `I18n` | `preferences.py`, `i18n.py` | Saved settings plus the shell's font, terminal and reduced motion; English and German |

Long work runs on threads and reports back through signals; only the GUI thread touches QML.

## Interface (QML)

- `Main.qml`: window state (tabs, split, the active pane, messages) and the functions every part calls
  (`openSheet`, `showMenu`, `dropInto`, `newTab`, ...).
- `window/`: `Rail` (sidebar), `TabStrip`, `Panes` (the tabs' Browsers), `ContextMenu`, `JobStack` and
  `JobCard`, `Shortcuts`.
- `browser/`: `Browser` is one pane (history, selection, filter, view); `Toolbar`, `Footer`, `GitCard`,
  `EmptyState`, `FileIcon`, and `keyboard.js` for its keys; `views/` holds the list, grid, storage map and
  graveyard plus the shared press and drag areas.
- `sheets/`: one file per dialog, each owning its own state. `quicklook/`: the preview sheet and its PDF and media
  loaders.
- `theme/Theme.qml` holds every token, `motion/` the spring, `controls/` the shared controls.

## Outside the repository

The local file picker (`~/.local/share/filyy-picker/`) is a FileChooser portal backend that loads `Main.qml` with a
`Files` subclass and adds a pick bar. It relies on `app.Files`, `build_engine`, the window's `pane` and the item
named `layout`; its `check.py` runs it offscreen.
