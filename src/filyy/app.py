"""Wiring: creates the backend singletons, registers them for QML and loads the window.

The offscreen checks and the local file picker use `build_engine` too; the picker swaps `Files` for a subclass
before calling it.
"""
import os
from pathlib import Path

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterSingletonInstance

from filyy.filesystem import archive, trash
from filyy.filesystem.files import HOME, Files
from filyy.filesystem.jobs import Jobs
from filyy.filesystem.rename import Rename
from filyy.filesystem.undo import Undo
from filyy.i18n import I18n
from filyy.lookup.git import Git
from filyy.lookup.jump import Jump
from filyy.lookup.search import Search
from filyy.lookup.usage import Usage
from filyy.preferences import Prefs
from filyy.preview.apps import AppIcons, Apps
from filyy.preview.preview import Preview
from filyy.preview.thumbs import Thumbs

QML = Path(__file__).resolve().parent / "qml"
_alive = []


def backend(prefs=None):
    """Creates and registers the QML singletons; `_alive` keeps them from being collected."""
    # First, so everything created after it already speaks the saved language.
    prefs = prefs or Prefs()
    i18n = I18n(prefs)
    jobs = Jobs(trash.trash)
    QGuiApplication.instance().aboutToQuit.connect(jobs.shutdown)
    files = Files(jobs, prefs.terminal)
    undo = Undo(trash.trash, trash.restore)
    files.recorded.connect(undo.push)
    jobs.finished.connect(lambda _ok, _text, _last, label, steps: undo.push(label, steps))
    rename = Rename()
    rename.done.connect(lambda ok, _text, steps: undo.push("Umbenennen", steps) if ok else None)
    _alive[:] = [jobs, files, undo, Jump(HOME), rename, Preview(), Git(), Apps(), Thumbs(), Search(), Usage(),
                 prefs, i18n]
    for obj in _alive:
        qmlRegisterSingletonInstance(type(obj), "Filyy", 1, 0, type(obj).__name__, obj)
    return _alive


def build_engine(start, restore=False, prefs=None):
    """Loads Main.qml on `start`; with `restore` the tabs from last time come back instead."""
    backend(prefs)
    engine = QQmlApplicationEngine()
    engine.addImageProvider("appicon", AppIcons())
    openable = os.path.isdir(start) or (archive.supported(start) and os.path.isfile(start))
    engine.setInitialProperties({"startPath": start if openable else HOME, "restore": restore})
    engine.load(str(QML / "Main.qml"))
    return engine
