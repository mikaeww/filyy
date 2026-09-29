#!/usr/bin/env python3
"""Filyy, a small file manager in the Ghostly QShell look.

  filyy [DIR]        open a window on DIR (default: home)
"""
import os
import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterSingletonInstance

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from core import archive, trash  # noqa: E402
from core.files import HOME, Files  # noqa: E402
from core.jobs import Jobs  # noqa: E402
from core.apps import AppIcons, Apps  # noqa: E402
from core.gitinfo import Git  # noqa: E402
from core.i18n import I18n  # noqa: E402
from core.jump import Jump  # noqa: E402
from core.prefs import Prefs  # noqa: E402
from core.preview import Preview  # noqa: E402
from core.rename import Rename  # noqa: E402
from core.search import Search  # noqa: E402
from core.thumbs import Thumbs  # noqa: E402
from core.usage import Usage  # noqa: E402
from core.undo import Undo  # noqa: E402
from core.theme import Theme  # noqa: E402


def preload_nosuspend():
    """Restarts once with nosuspend.c preloaded, then drops it so opened apps don't inherit it."""
    lib = str(HERE / "build/libnosuspend.so")
    if os.environ.pop("FILYY_NOSUSPEND", "") == "1":
        rest = [p for p in os.environ.get("LD_PRELOAD", "").split(":") if p and p != lib]
        if rest:
            os.environ["LD_PRELOAD"] = ":".join(rest)
        else:
            os.environ.pop("LD_PRELOAD", None)
        return
    if os.environ.get("WAYLAND_DISPLAY") and os.path.exists(lib):
        env = dict(os.environ, FILYY_NOSUSPEND="1",
                   LD_PRELOAD=":".join(filter(None, [lib, os.environ.get("LD_PRELOAD")])))
        os.execve(sys.executable, [sys.executable, str(HERE / "filyy.py"), *sys.argv[1:]], env)


def main():
    preload_nosuspend()
    QGuiApplication.setApplicationName("Filyy")
    QGuiApplication.setDesktopFileName("filyy")
    app = QGuiApplication(sys.argv)
    app.setWindowIcon(QIcon(str(HERE / "assets/filyy.svg")))
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    # "Öffnen mit" hands over file:// URLs, a terminal a plain path.
    start = os.path.abspath(os.path.expanduser(QUrl(arg).toLocalFile() if arg.startswith("file://") else arg)) if arg else HOME
    # Started plain (SUPER+E), Filyy comes back as it was left; asked for a folder, it opens just that.
    engine = build_engine(start, restore=not arg)
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())


def backend():
    """Creates and registers the QML singletons; kept module-level so Python keeps them alive."""
    global _backend
    # First, so everything created after it already speaks the saved language.
    prefs = Prefs()
    i18n = I18n(prefs)
    theme = Theme()
    jobs = Jobs(trash.trash)
    QGuiApplication.instance().aboutToQuit.connect(jobs.shutdown)
    files = Files(theme, jobs)
    undo = Undo(trash.trash, trash.restore)
    files.recorded.connect(undo.push)
    jobs.finished.connect(lambda _ok, _text, _last, label, steps: undo.push(label, steps))
    rename = Rename()
    rename.done.connect(lambda ok, _text, steps: undo.push("Umbenennen", steps) if ok else None)
    _backend = [theme, jobs, files, undo, Jump(HOME), rename, Preview(theme), Git(), Apps(), Thumbs(), Search(), Usage(), prefs, i18n]
    for obj in _backend:
        qmlRegisterSingletonInstance(type(obj), "Filyy", 1, 0, type(obj).__name__, obj)
    return _backend


def build_engine(start, restore=False):
    """Loads the window; the offscreen render check uses this too."""
    backend()
    engine = QQmlApplicationEngine()
    engine.addImageProvider("appicon", AppIcons())
    openable = os.path.isdir(start) or (archive.supported(start) and os.path.isfile(start))
    engine.setInitialProperties({"startPath": start if openable else HOME, "restore": restore})
    engine.load(str(HERE / "qml/Main.qml"))
    return engine


if __name__ == "__main__":
    main()
