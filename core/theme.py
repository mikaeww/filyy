"""The shell's live theme, read from Ghostly QShell's preferences.ini."""
import json
import os
import re
from pathlib import Path

from PySide6.QtCore import QFileSystemWatcher, QObject, QSettings, QTimer, Property, Signal
from PySide6.QtGui import QColor

SHELL = Path(os.environ.get("FILYY_SHELL", Path.home() / ".config/quickshell/ghostly-qshell"))
COLOR_KEYS = ["bg", "panelBg", "fg", "fgMuted", "accent", "accentSoft", "accentText", "warm",
              "warn", "danger", "surface", "surfaceSoft", "hairline"]
# Graphite-ish fallback when the shell is not installed; the shell's own presets win otherwise.
FALLBACK = dict(zip(COLOR_KEYS, ["#161616", "#1d1d1d", "#e6e6e6", "#a3a3a3", "#e6e6e6", "#3a3a3a",
                                 "#101010", "#c8c8c8", "#d1a565", "#c9624f", "#3c3c3c", "#2a2a2a",
                                 "#454545"]))


def preset_colors(presets_qml, preset_id):
    # ponytail: regex over ThemePresets.qml, breaks if the literal layout changes; a JSON export from the shell would be sturdier.
    match = re.search(r'id:\s*"%s".*?colors:\s*\{(.*?)\}' % re.escape(preset_id), presets_qml, re.S)
    return dict(re.findall(r'(\w+):\s*"(#[0-9a-fA-F]{6})"', match.group(1))) if match else {}


def shell_theme(shell_dir):
    """Palette and shape of the running shell, derived the same way Preferences.qml does."""
    ini = shell_dir / "preferences.ini"
    settings = QSettings(str(ini), QSettings.IniFormat)
    settings.beginGroup("Shell")
    value = lambda key, default: settings.value(key, default)
    try:
        presets = (shell_dir / "ThemePresets.qml").read_text()
    except OSError:
        presets = ""
    colors = dict(FALLBACK)
    colors.update(preset_colors(presets, str(value("presetId", "cocoa"))) or preset_colors(presets, "cocoa"))
    if str(value("customEnabled", "false")).lower() == "true":
        try:
            custom = json.loads(str(value("customJson", "{}")))
            colors.update({k: v for k, v in custom.items() if k in colors and re.fullmatch(r"#[0-9a-fA-F]{6}", str(v))})
        except ValueError:
            pass
    square = value("cornerStyle", "round") == "square"
    try:
        radius = max(8, min(40, int(value("panelRadius", 20))))
    except (TypeError, ValueError):
        radius = 20
    return {"colors": colors, "square": square, "radius": 0 if square else radius,
            "fontUi": str(value("fontUi", "Monofur Nerd Font")),
            "fontMono": str(value("fontMono", "Monofur Nerd Font")),
            "terminal": str(value("terminal", "kitty")),
            "reducedMotion": str(value("reducedMotion", "false")).lower() == "true"}


class Theme(QObject):
    changed = Signal()
    # PySide only registers properties that exist when the class body runs.
    for _key in COLOR_KEYS:
        locals()[_key] = Property(QColor, lambda self, key=_key: QColor(self._theme["colors"][key]), notify=changed)
    del _key

    def __init__(self):
        super().__init__()
        self._theme = shell_theme(SHELL)
        self._watcher = QFileSystemWatcher(self)
        self._reload = QTimer(self, singleShot=True, interval=120, timeout=self.reload)
        self._watcher.fileChanged.connect(self._reload.start)
        self._watcher.directoryChanged.connect(self._reload.start)
        self._watch()

    def _watch(self):
        # QSettings replaces the ini by rename, which drops the file watch, so re-add it every time.
        paths = [str(p) for p in (SHELL, SHELL / "preferences.ini") if p.exists()]
        missing = [p for p in paths if p not in self._watcher.files() + self._watcher.directories()]
        if missing:
            self._watcher.addPaths(missing)

    def reload(self):
        self._watch()
        fresh = shell_theme(SHELL)
        if fresh != self._theme:
            self._theme = fresh
            self.changed.emit()

    square = Property(bool, lambda self: self._theme["square"], notify=changed)
    radius = Property(int, lambda self: self._theme["radius"], notify=changed)
    fontUi = Property(str, lambda self: self._theme["fontUi"], notify=changed)
    fontMono = Property(str, lambda self: self._theme["fontMono"], notify=changed)
    reducedMotion = Property(bool, lambda self: self._theme["reducedMotion"], notify=changed)
    terminal = Property(str, lambda self: self._theme["terminal"], notify=changed)
    # Shared shape and motion, so every QML file agrees with the shell's settings panel.
    control = Property(int, lambda self: 0 if self._theme["square"] else round(self._theme["radius"] / 2), notify=changed)
    enterMs = Property(int, lambda self: 0 if self._theme["reducedMotion"] else 220, notify=changed)
    exitMs = Property(int, lambda self: 0 if self._theme["reducedMotion"] else 150, notify=changed)
    quickMs = Property(int, lambda self: 0 if self._theme["reducedMotion"] else 140, notify=changed)
    iconFont = Property(str, lambda self: "Monofur Nerd Font", constant=True)
