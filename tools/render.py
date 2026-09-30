#!/usr/bin/env python3
"""Renders the window offscreen on a sample folder: no visible window, nothing outside a temporary directory.

  python3 tools/render.py OUT.png [dark|light] [WIDTHxHEIGHT] [list|grid|usage|trash] [EXTRA]

EXTRA is one of split, tabs, menu, settings, rename, jump, look (quick look on README.md).

Evidence for layout only, not for motion. The sample folder is built fresh with a git repository, pictures made
here, text files and folders; nothing is read from the real home except fonts.
"""
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TMP = Path(tempfile.mkdtemp(prefix="filyy-render-"))
# HOME moves into TMP so the breadcrumb, places and jump scan see only the sample. XDG_DATA_HOME and the shell stay
# pinned to the real ones first: fontconfig finds the user's fonts there, the shell names the UI font. Trash and
# jump history are pointed into TMP below instead.
os.environ["XDG_DATA_HOME"] = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
os.environ.setdefault("FILYY_SHELL", os.path.expanduser("~/.config/quickshell/ghostly-qshell"))
os.environ["HOME"] = str(TMP / "home")
for name in ("XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME"):
    os.environ[name] = str(TMP / name.lower())
os.environ["QT_QPA_PLATFORM"] = "offscreen"
sys.path.insert(0, str(ROOT / "src"))

import shiboken6  # noqa: E402
from PySide6.QtCore import Q_ARG, QMetaObject  # noqa: E402
from PySide6.QtGui import QColor, QGuiApplication, QImage  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402

from filyy.app import build_engine  # noqa: E402
from filyy.filesystem import trash  # noqa: E402
from filyy.lookup import jump  # noqa: E402
from filyy.preferences import Prefs  # noqa: E402

# Point the trash at TMP: its functions took the real path as their default when they were defined.
TRASH = str(TMP / "Trash")
trash.HOME_TRASH = TRASH
for function in (trash.trash, trash.entries, trash.restore, trash.purge):
    function.__defaults__ = (TRASH,)
jump.DATA = str(TMP / "jump")


def picture(path, shade):
    image = QImage(96, 64, QImage.Format_RGB32)
    image.fill(QColor(shade, shade, shade))
    image.save(str(path))


def sample():
    """A small project folder: sub folders, code, text, pictures, an archive, and a git repository with a commit."""
    for name in ("Desktop", "Documents", "Downloads", "Pictures"):
        (TMP / "home" / name).mkdir(parents=True)
    folder = TMP / "home" / "Projekte"
    for name in ("assets", "docs", "src", "tests"):
        (folder / name).mkdir(parents=True)
    (folder / "app.py").write_text("print('hallo')\n" * 40)
    (folder / "install.sh").write_text("#!/bin/sh\necho ok\n")
    (folder / "README.md").write_text("# Projekt\n" + "Text.\n" * 200)
    (folder / "notes.pdf").write_bytes(b"%PDF-1.4\n" + b"0" * 3000)
    (folder / "backup.zip").write_bytes(b"PK\x05\x06" + b"\0" * 18)
    picture(folder / "logo.png", 90)
    picture(folder / "banner.png", 160)
    env = dict(os.environ, GIT_AUTHOR_NAME="filyy", GIT_AUTHOR_EMAIL="f@x", GIT_COMMITTER_NAME="filyy",
               GIT_COMMITTER_EMAIL="f@x")
    for command in (["init", "-q", "-b", "main"], ["add", "."], ["commit", "-qm", "First sketch of the app"]):
        subprocess.run(["git", *command], cwd=folder, env=env, check=False, capture_output=True)
    (folder / "app.py").write_text("print('neu')\n")
    for name in ("alt.txt", "entwurf.md"):
        (folder / name).write_text("weg\n")
        trash.trash(str(folder / name))
    return folder


EXTRAS = ("split", "tabs", "menu", "settings", "rename", "jump", "look")


def arguments():
    args = sys.argv[1:]
    size = next((a for a in args if "x" in a and a.split("x")[0].isdigit()), "1240x780")
    return {"out": args[0] if args else "filyy.png", "theme": "light" if "light" in args else "dark",
            "size": [int(v) for v in size.split("x")],
            "view": next((a for a in args if a in ("list", "grid", "usage", "trash")), "list"),
            "extra": next((a for a in args if a in EXTRAS), "")}


def spin(app, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        app.processEvents()
        time.sleep(0.01)


def stage(window, options, folder):
    """Puts the window into the state asked for, through the same functions the interface calls."""
    pane = window.property("pane")
    if options["view"] == "trash":
        QMetaObject.invokeMethod(pane, "navigate", Q_ARG("QVariant", window.property("trashPath")))
    elif options["view"] != "list":
        pane.setProperty("view", options["view"])
    extra = options["extra"]
    if extra == "split":
        QMetaObject.invokeMethod(window, "toggleSplit")
    elif extra == "tabs":
        QMetaObject.invokeMethod(window, "newTab", Q_ARG("QVariant", str(folder / "docs")))
    elif extra == "settings":
        window.setProperty("settingsOpen", True)
    elif extra == "rename":
        pane.setProperty("picked", {str(folder / "logo.png"): True, str(folder / "banner.png"): True})
        QMetaObject.invokeMethod(window, "openSheet", Q_ARG("QVariant", "rename"))
    elif extra == "jump":
        QMetaObject.invokeMethod(window, "openJump")
    elif extra == "look":
        index = [e["name"] for e in pane.property("shown")].index("README.md")
        QMetaObject.invokeMethod(pane, "select", Q_ARG("QVariant", index), Q_ARG("QVariant", 0))
        look = next(o for o in window.contentItem().childItems() if o.metaObject().className().startswith("QuickLook"))
        QMetaObject.invokeMethod(look, "show", Q_ARG("QVariant", pane.property("shown")), Q_ARG("QVariant", index))
    elif extra == "menu":
        QMetaObject.invokeMethod(window, "showMenu", Q_ARG("QVariant", pane.property("current")), Q_ARG("QVariant", 640),
                                 Q_ARG("QVariant", 150))


def main():
    options = arguments()
    app = QGuiApplication(sys.argv)
    folder = sample()
    prefs = Prefs(str(TMP / "filyy.ini"))
    for key, value in (("theme", options["theme"]), ("width", options["size"][0]), ("height", options["size"][1])):
        prefs.set(key, value)
    engine = build_engine(str(folder), prefs=prefs)
    window = shiboken6.wrapInstance(shiboken6.getCppPointer(engine.rootObjects()[0])[0], QQuickWindow)
    spin(app, 0.6)
    stage(window, options, folder)
    spin(app, 1.2)
    window.grabWindow().save(options["out"])
    print(options["out"])


if __name__ == "__main__":
    main()
