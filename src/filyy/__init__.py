"""Filyy, a keyboard-friendly file manager for tiling Wayland desktops.

`python3 -m filyy [DIR]` opens a window; `app.build_engine` wires the backend singletons into the QML window.
The backend lives in `filesystem` (listing, jobs, trash, archives, undo, rename), `lookup` (jump, search, storage
map, git) and `preview` (quick look text, thumbnails, apps). No logic in this file.
"""
