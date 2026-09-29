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

from core.files import HOME, Files  # noqa: E402
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
    arg = sys.argv[1] if len(sys.argv) > 1 else HOME
    # "Öffnen mit" hands over file:// URLs, a terminal a plain path.
    start = os.path.abspath(os.path.expanduser(QUrl(arg).toLocalFile() if arg.startswith("file://") else arg))
    engine = build_engine(start)
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())


def build_engine(start):
    """Registers the backend and loads the window; the offscreen render check uses this too."""
    # Module-level so Python keeps the singletons alive as long as QML uses them.
    global _backend
    theme = Theme()
    _backend = [theme, Files(theme)]
    for obj in _backend:
        qmlRegisterSingletonInstance(type(obj), "Filyy", 1, 0, type(obj).__name__, obj)
    engine = QQmlApplicationEngine()
    engine.setInitialProperties({"startPath": start if os.path.isdir(start) else HOME})
    engine.load(str(HERE / "qml/Main.qml"))
    return engine


if __name__ == "__main__":
    main()
