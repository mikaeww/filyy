# Verification

Claims are backed by the strongest method that is practical; a check that did not run is not a pass.

| Component | Plan | Main evidence |
|---|---|---|
| Motion | [verification/motion.md](verification/motion.md) | `tests/motion.test.js` against the analytic solution |
| Backend | `tests/test_core.py` | Example tests on folders built per test: listing, jobs with conflicts, trash, undo, rename, archives, search, jump, usage, git, preferences, translations |
| Window | `tests/test_interface.py` | The real window offscreen: new folder through the sheet, views, split, menu |
| Structure | `tests/test_structure.py` | Every limit trips on a tree built to break it |

Known gap: the interface is checked offscreen and by screenshots from `tools/render.py`; motion on a real display
at different refresh rates is checked by maths only.
