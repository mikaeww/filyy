# Conventions

Binding rules for Filyy, derived from the `clean-project` skill and kept in line with Calendary and Fold, whose
design and tooling Filyy shares. Deviations need an ADR in `decisions/`.

## Layout

- `src/filyy/` holds the Python package: `filesystem` (listing, the QML file actions, jobs, trash, archives, undo,
  rename), `lookup` (jump, search, storage map, git), `preview` (quick look text, thumbnails, apps), `platform`
  (the Hyprland preload), plus `app.py` (wiring), `preferences.py`, `desktop.py` and `i18n.py`.
- `src/filyy/qml/` holds the interface. `Main.qml` is the window; everything else lives in a named directory:
  `theme`, `motion`, `controls`, `window` (sidebar, tabs, panes, menu, jobs, shortcuts), `browser` (one pane) with
  `browser/views`, `sheets`, `quicklook`. `format.js` and `paths.js` are the shared pure functions.
- `tests/` checks the public operations of the package, the real window offscreen, and the pure QML logic
  (`*.test.js`).
- `tools/` holds dev commands: `check.py`, `structure.py`, `qmltypes.py` (describes the Python singletons to
  qmllint), `render.py` (offscreen screenshots of a sample folder), `pixelart.py` (builds the file icons).

## Hard limits

Enforced by `tools/structure.py`, which runs in `tools/check.py`.

| Limit | Value |
|---|---|
| Lines per handwritten file (code, docs, scripts) | 500 |
| Code files per directory (entry files and tests excluded) | 8 |
| Markdown files per docs directory, index included | 8 |
| Lines per Python function | 60 |
| Parameters per Python function (`self`/`cls` excluded) | 5 |
| Directory depth below `src/` | 4 |

Forbidden module names: `utils`, `util`, `helpers`, `helper`, `misc`, `common`, `stuff`, `shared`.

## Code

- Entry files (`__init__.py`, `__main__.py`) document and wire; logic lives in named modules.
- No bare `except:`, no `assert` in library code unless its message starts with `invariant:`.
- Every module starts with a docstring saying what it is for and what not.
- Errors are never swallowed silently; a deliberate ignore carries a comment saying why.
- User data first: file actions go through jobs with undo steps, deletes go to the trash unless asked otherwise,
  and a conflict is asked about, never decided silently.
- Tests touch only files they created. The real trash, jump history and preferences are never used in tests.
- Dependencies: Python 3 stdlib and PySide6; `ripgrep`, `ffmpeg` and `git` are optional tools. Nothing else
  without an ADR.

## Interface

- Colours, radii, spacing, font sizes and motion come only from `qml/theme/Theme.qml`, which uses Calendary's
  values (ADR 0002).
- Neutral grey only (R = G = B). The one exception is content: the pixel file icons, the tombstones and
  thumbnails, which tell file types and files apart (ADR 0002).
- No borders, lines or shadows as structure; depth is a brightness step. Radii come in two steps: surfaces and
  controls. No pill shapes.
- Dark and light palettes both exist; the default follows the system, the choice is saved.
- Motion follows `qml/motion/`: Leech's two springs, glide (0.34 s, damping 0.82) for things that travel (the
  sidebar and tab selection, the view switch) and settle (0.30 s, 0.86) for things that appear (sheets, menu,
  cards, a folder's entrance). They run on the render loop, keep position and velocity on retarget and land
  exactly on their target. Hover and colour changes use a short native transition. Reduced motion removes travel
  and keeps fades.
- Every QML file declares `pragma ComponentBehavior: Bound`; delegates reach model data only through required
  properties.
- UI text is written in German as the key and translated in `i18n.py`; English is the default. Code and docs are
  English.

## Workflow

1. Plan in the commit message, or in `docs/` for larger changes.
2. Implement in steps that keep the tree working.
3. `python3 tools/check.py` must pass.
4. Real check: `python3 tools/render.py` for the interface in both themes, the real program on a scratch folder
   for anything else.
5. Commit one logical step at a time with the docs it changes, naming how it was checked. Commits happen only when
   the owner asks for them.
