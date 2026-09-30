# 0001: Restructure along the clean-project rules

**Status:** accepted
**Date:** 2026-09-30

## Context
Filyy grew feature by feature: `filyy.py` and `core/` next to one flat `qml/` folder, with a 1800-line `Main.qml`
and a 1160-line `Browser.qml`. The owner asked for the same design and structure as Calendary and Fold.

## Options
- Only restyle the existing files.
- Move to Calendary's layout: a `src/filyy` package, named QML directories, the same check tooling.

## Decision
Calendary's layout. The Python modules moved without changing their behaviour; `core/theme.py` gave way to
`desktop.py`. `Main.qml` and `Browser.qml` were split by concept: the window, the pane, its views, each sheet, the
menu, the jobs. `Util.js` became `format.js` and `paths.js`.

## Consequences
- `tools/check.py` enforces the limits, formats and lints QML with 0 warnings, and runs every test.
- `filyy.py` is gone; `./filyy` (and `~/.local/bin/filyy` after `install.sh`) starts `python3 -m filyy`.
- The local file picker had to follow the new paths.
