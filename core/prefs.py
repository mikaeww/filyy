"""What Filyy remembers between runs: view, hidden files, window size and the open tabs.

Values are JSON in $XDG_CONFIG_HOME/filyy/filyy.ini and are written the moment they change, so a crash or a
killed window loses nothing.
"""
import json
import os

from PySide6.QtCore import QObject, QSettings, Slot
from PySide6.QtQml import QJSValue

CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "filyy", "filyy.ini")


class Prefs(QObject):
    def __init__(self, path=CONFIG):
        super().__init__()
        self._settings = QSettings(path, QSettings.IniFormat)

    @Slot(str, "QVariant", result="QVariant")
    def get(self, key, default=None):
        raw = self._settings.value(key)
        if raw is None:
            return default
        try:
            return json.loads(raw)
        except (TypeError, ValueError):
            return default

    @Slot(str, "QVariant")
    def set(self, key, value):
        # Nested JS objects arrive as QJSValue; plain Python values are what json understands.
        if isinstance(value, QJSValue):
            value = value.toVariant()
        encoded = json.dumps(value)
        if self._settings.value(key) != encoded:
            self._settings.setValue(key, encoded)
            self._settings.sync()
