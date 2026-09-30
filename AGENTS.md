# Agent instructions

Read `docs/conventions.md`, `docs/README.md` and the newest file in `docs/handoffs/` before changing anything.
`python3 tools/check.py` must pass before every commit. Tests and `tools/render.py` only touch folders they create;
never point them at the real trash, the real jump history or a real home folder. The local file picker in
`~/.local/share/filyy-picker/` loads `Main.qml`; run its `check.py` after changing the window.
