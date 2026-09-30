# 0003: Checks with the standard library, qmlformat and qmllint

**Status:** accepted
**Date:** 2026-09-30

## Context
The clean-project rules want a formatter and a linter in the check command. `ruff` is not installed and would need
root to install; Calendary and Fold decided the same.

## Options
- Install ruff system-wide.
- Enforce the limits with an own `ast`-based structure check, format and lint QML with Qt's own tools.

## Decision
No new tool: `tools/structure.py` (copied from Calendary), `qmlformat` and `qmllint` with a qmltypes file generated
from the Python singletons, Python compiled and tested but not formatted.

## Consequences
Python formatting is by hand. Adding ruff later needs one step in `tools/check.py` and a superseding ADR.
