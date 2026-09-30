<p align="center"><img src="assets/filyy.png" width="96" alt="Filyy icon"></p>

# Filyy

A keyboard-friendly file manager for Linux, made for tiling Wayland desktops like Hyprland.
Written in Python with Qt Quick (PySide6).

![Filyy](assets/screenshot.png)

## Features

- Tabs and a split view, restored the next time you open it
- List, grid and a storage map that shows what takes up space
- Quick look on the space bar for images, PDFs, video, audio and code
- Jump to any folder with a few letters, and search inside files
- Copy and move with progress, pause, cancel and a conflict dialog
- Undo for file actions
- Batch rename with a live preview
- Open zip, jar and tar archives like folders
- A trash you can browse and restore from
- Git status for the folder you are in
- Open with any installed app, video thumbnails, drag and drop
- Pixel icons for file types
- Dark and light, following the system unless you pick one
- English and German, switchable in the settings (gear, bottom left)

## Install

Needs Python 3 with PySide6 (Qt 6), a C compiler and the Wayland headers. `ripgrep`, `ffmpeg` and `git`
are optional and enable content search, video thumbnails and the git status.

```sh
git clone https://github.com/mikaeww/filyy
cd filyy
./install.sh
filyy
```

## Development

```sh
python3 tools/check.py              # structure limits, QML format and lint, all tests
python3 tools/render.py out.png     # offscreen screenshot of a sample folder, see --help in the file
```

The code lives in `src/filyy` (Python backend) and `src/filyy/qml` (interface). Rules and decisions are in
[docs/](docs/README.md).

## Shortcuts

| Key | Action |
| --- | --- |
| Enter / Backspace | open / go up |
| Space | quick look |
| Ctrl+K | jump to a folder |
| Ctrl+Shift+F | search in files |
| Ctrl+T, F3 | new tab, split view |
| Ctrl+C / X / V, Ctrl+Z | copy, cut, paste, undo |
| F2 | rename |
| Del | move to trash |
| Ctrl+1 / 2 / 3 | list, grid, storage map |

## License

MIT
