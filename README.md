<p align="center"><img src="assets/filyy.svg" width="96" alt="Filyy ghost holding a folder"></p>

# Filyy

A small file manager for Hyprland in the look of Ghostly QShell, my Quickshell desktop.
PySide6 + QML, a real window with its own app id (`filyy`), no shell integration needed.

![Filyy in the Cocoa theme](assets/screenshot.png)

- **Follows your shell theme live.** Colours, corner radius, fonts, terminal and "reduce motion" are read
  from Ghostly QShell's `preferences.ini`; change the theme there and Filyy follows without a restart.
  Without the shell it falls back to a neutral grey theme.
- **Motion from the shell's settings panel:** 220 ms fade with a hint of scale, pages settle 8 px upward,
  the places rail selection glides on a spring.
- **Everyday file work:** list and grid view with image thumbnails, breadcrumb and typed paths, type-to-filter,
  multi-select, context menu, copy/cut/paste through the system clipboard (interoperable with Dolphin and
  Nautilus), drag and drop in and out, trash with confirmation, open in terminal.
- **Tiling friendly:** the layout folds down when Hyprland tiles it narrow.

The UI is in German.

## Install

Needs `pyside6` (system Qt 6), a C compiler with the Wayland client headers, and a Nerd Font
(Monofur Nerd Font) for the icons.

```sh
./install.sh      # builds nosuspend.c, links ~/.local/bin/filyy, the desktop entry and the icon
filyy [folder]
```

Bind it in Hyprland, e.g. `hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("filyy"))`.
Point it at another shell config with `FILYY_SHELL=<dir>`.

## Keys

| Key | Action |
| --- | --- |
| ↑ ↓ (← → in grid), Home/End, PgUp/PgDn | move, with Shift to extend the selection |
| Enter, double click | open (files with their default app) |
| Backspace, Alt+↑ / Alt+← → | up / history |
| typing, Ctrl+F | filter |
| Ctrl+L, click the path bar | type a path (`~` works) |
| Ctrl+C / X / V | copy / cut / paste |
| Ctrl+D, F2 | duplicate, rename |
| Del, Shift+Del | move to trash, delete permanently (both ask first) |
| Ctrl+Shift+N, F10 | new folder |
| Ctrl+H, Ctrl+1/2, F5 | hidden files, list/grid, reload |
| Shift+F4 | terminal here |
| right click, Menu key | context menu |

## Why there is a C file

Hyprland 0.56 sometimes sends `xdg_toplevel.suspended` to a window that is visible and active, for
example after dragging it from a large tile into a smaller one. Qt obeys and stops drawing, so Hyprland
stretches the last frame into the new size. `nosuspend.c` is preloaded into Filyy only and advertises
`xdg_wm_base` as version 5, where `suspended` does not exist yet. Filyy drops it from its environment right
after start, so apps opened from Filyy do not inherit it.

## Checks

```sh
python3 filyy.py --selftest   # listing, copy/move, name validation, theme parsing
node tests/util.js            # history, breadcrumbs, sizes
```

## Not yet

Tabs, split view, restoring from trash, undo, progress for large copies, video thumbnails, "open with".
