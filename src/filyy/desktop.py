"""What Filyy takes from the Ghostly QShell: UI and mono font, the terminal and the reduced-motion switch (ADR 0002).

Read once from the shell's preferences.ini; without the shell the system fonts, kitty and full motion apply. Not for
colours: those are Filyy's own tokens in qml/theme/Theme.qml.
"""
import os
from pathlib import Path

from PySide6.QtCore import QSettings

SHELL = Path(os.environ.get("FILYY_SHELL", Path.home() / ".config/quickshell/ghostly-qshell"))
FALLBACK = {"fontUi": "sans-serif", "fontMono": "monospace", "terminal": "kitty", "reducedMotion": False}


def read(shell=SHELL):
    ini = Path(shell) / "preferences.ini"
    if not ini.exists():
        return dict(FALLBACK)
    settings = QSettings(str(ini), QSettings.IniFormat)
    settings.beginGroup("Shell")
    text = lambda key: str(settings.value(key, FALLBACK[key])) or FALLBACK[key]
    return {"fontUi": text("fontUi"), "fontMono": text("fontMono"), "terminal": text("terminal"),
            "reducedMotion": str(settings.value("reducedMotion", "false")).lower() == "true"}
