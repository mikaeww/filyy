"""`python3 -m filyy [DIR]`: the Hyprland workaround, the application object and the window.

Started plain (SUPER+E), Filyy comes back as it was left; asked for a folder, it opens just that.
"""
import os
import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication, QIcon

from filyy.app import build_engine
from filyy.filesystem.files import HOME
from filyy.platform import preload_nosuspend

ICON = Path(__file__).resolve().parents[2] / "assets/filyy.png"


def start_path(arg):
    # "Öffnen mit" hands over file:// URLs, a terminal a plain path.
    if not arg:
        return HOME
    return os.path.abspath(os.path.expanduser(QUrl(arg).toLocalFile() if arg.startswith("file://") else arg))


def main():
    preload_nosuspend()
    QGuiApplication.setApplicationName("Filyy")
    QGuiApplication.setDesktopFileName("filyy")
    app = QGuiApplication(sys.argv)
    app.setWindowIcon(QIcon(str(ICON)))
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    engine = build_engine(start_path(arg), restore=not arg)
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
