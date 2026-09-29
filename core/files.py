"""Folder listing, places, clipboard and the quick file actions QML calls."""
import os
import shutil
import subprocess
import threading
from pathlib import Path

from PySide6.QtCore import (QFileSystemWatcher, QMimeData, QMimeDatabase, QObject, QStorageInfo, QTimer, QUrl,
                            Signal, Slot, QFile)
from PySide6.QtGui import QDesktopServices, QGuiApplication

from core.fs import checked_name, human, listing

HOME = str(Path.home())


def free_name(folder, name):
    """name, or 'name (Kopie N).ext' when it is taken in folder."""
    candidate = os.path.join(folder, name)
    stem, suffix = (name, "") if os.path.isdir(candidate) else os.path.splitext(name)
    number = 1
    while os.path.lexists(candidate):
        candidate = os.path.join(folder, f"{stem} (Kopie{'' if number == 1 else ' ' + str(number)}){suffix}")
        number += 1
    return candidate


def transfer(sources, folder, move):
    """Copies or moves sources into folder; returns the last destination."""
    last = ""
    for source in sources:
        source = os.path.abspath(source)
        if not os.path.lexists(source):
            raise FileNotFoundError(f"Nicht gefunden: {os.path.basename(source)}")
        real = os.path.realpath(source)
        if os.path.isdir(source) and not os.path.islink(source) and \
                os.path.commonpath((real, os.path.realpath(folder))) == real:
            raise ValueError("Ein Ordner kann nicht in sich selbst landen")
        if move and os.path.dirname(source) == os.path.abspath(folder):
            continue
        last = free_name(folder, os.path.basename(source))
        if move:
            shutil.move(source, last)
        elif os.path.islink(source):
            os.symlink(os.readlink(source), last)
        elif os.path.isdir(source):
            shutil.copytree(source, last, symlinks=True)
        else:
            shutil.copy2(source, last)
    return last


class Files(QObject):
    folderChanged = Signal(str)
    # ok, message, path to select afterwards ("" for none)
    done = Signal(bool, str, str)
    clipboardChanged = Signal()

    def __init__(self, theme):
        super().__init__()
        self._theme = theme
        self._watcher = QFileSystemWatcher(self)
        self._debounce = QTimer(self, singleShot=True, interval=150)
        self._debounce.timeout.connect(lambda: self.folderChanged.emit(self._watched))
        self._watcher.directoryChanged.connect(lambda _: self._debounce.start())
        self._watched = ""
        self._mime = QMimeDatabase()
        QGuiApplication.clipboard().dataChanged.connect(self.clipboardChanged)

    @Slot(str, bool, result="QVariantMap")
    def list(self, path, show_hidden):
        if self._watched:
            self._watcher.removePath(self._watched)
        self._watched = path
        self._watcher.addPath(path)
        return listing(path, show_hidden)

    @Slot(result=str)
    def home(self):
        return HOME

    @Slot(result="QVariantList")
    def places(self):
        wanted = [("Home", HOME, "home"), ("Desktop", HOME + "/Desktop", "desktop"),
                  ("Dokumente", HOME + "/Dokumente", "docs"), ("Downloads", HOME + "/Downloads", "download"),
                  ("Bilder", HOME + "/Bilder", "image"), ("Musik", HOME + "/Musik", "music"),
                  ("Videos", HOME + "/Videos", "video"), ("Projekte", HOME + "/Projekte", "code")]
        out = [{"name": n, "path": p, "icon": i, "group": "Orte"} for n, p, i in wanted if os.path.isdir(p)]
        for volume in QStorageInfo.mountedVolumes():
            root = volume.rootPath()
            if volume.isValid() and volume.isReady() and (root == "/" or root.startswith(("/run/media/", "/media/", "/mnt/"))):
                out.append({"name": "System" if root == "/" else (volume.displayName() or os.path.basename(root)),
                            "path": root, "icon": "drive", "group": "Geräte"})
        trash = HOME + "/.local/share/Trash/files"
        if os.path.isdir(trash):
            out.append({"name": "Papierkorb", "path": trash, "icon": "trash", "group": "Geräte"})
        return out

    @Slot(str, result=str)
    def space(self, path):
        info = QStorageInfo(path)
        return f"{human(info.bytesAvailable())} frei" if info.isValid() else ""

    @Slot(str, result=str)
    def mimeName(self, path):
        return self._mime.mimeTypeForFile(path).comment()

    @Slot(str)
    def open(self, path):
        QDesktopServices.openUrl(QUrl.fromLocalFile(path))

    @Slot(str)
    def terminal(self, folder):
        terminal = self._theme.terminal if shutil.which(self._theme.terminal) else "kitty"
        subprocess.Popen([terminal], cwd=folder, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def _run(self, work, message):
        """Runs work() off the UI thread; it returns the path to select."""
        def body():
            try:
                self.done.emit(True, message, work() or "")
            except (OSError, ValueError) as error:
                self.done.emit(False, str(error), "")
        threading.Thread(target=body, daemon=True).start()

    @Slot(str, str)
    def mkdir(self, folder, name):
        def work():
            target = os.path.join(folder, checked_name(name))
            os.mkdir(target)
            return target
        self._run(work, "Ordner erstellt")

    @Slot(str, str)
    def rename(self, path, name):
        def work():
            target = os.path.join(os.path.dirname(path), checked_name(name))
            if target != path:
                if os.path.lexists(target):
                    raise FileExistsError("Der Name ist schon vergeben")
                os.rename(path, target)
            return target
        self._run(work, "Umbenannt")

    @Slot("QVariantList")
    def trash(self, paths):
        def work():
            for path in paths:
                if not QFile.moveToTrash(path):
                    raise OSError(f"Konnte {os.path.basename(path)} nicht in den Papierkorb legen")
        self._run(work, f"{len(paths)} in den Papierkorb gelegt")

    @Slot("QVariantList")
    def remove(self, paths):
        def work():
            for path in paths:
                if os.path.isdir(path) and not os.path.islink(path):
                    shutil.rmtree(path)
                else:
                    os.remove(path)
        self._run(work, f"{len(paths)} endgültig gelöscht")

    @Slot("QVariantList")
    def duplicate(self, paths):
        def work():
            last = ""
            for path in paths:
                last = transfer([path], os.path.dirname(path), False)
            return last
        self._run(work, "Dupliziert")

    @Slot("QVariantList", str, bool)
    def transfer(self, paths, folder, move):
        self._run(lambda: transfer(paths, folder, move), "Verschoben" if move else "Kopiert")

    @Slot("QVariantList", bool)
    def setClipboard(self, paths, cut):
        data = QMimeData()
        data.setUrls([QUrl.fromLocalFile(p) for p in paths])
        # KDE and GNOME each read their own flag to tell cut from copy.
        data.setData("application/x-kde-cutselection", b"1" if cut else b"0")
        data.setData("x-special/gnome-copied-files",
                     ("cut" if cut else "copy").encode() + b"".join(b"\n" + QUrl.fromLocalFile(p).toEncoded().data() for p in paths))
        QGuiApplication.clipboard().setMimeData(data)

    @Slot("QVariantList")
    def copyPaths(self, paths):
        QGuiApplication.clipboard().setText("\n".join(paths))

    @Slot(result="QVariantMap")
    def clipboard(self):
        data = QGuiApplication.clipboard().mimeData()
        paths = [url.toLocalFile() for url in data.urls() if url.isLocalFile()] if data else []
        cut = bool(data) and (bytes(data.data("application/x-kde-cutselection").data()) == b"1"
                              or bytes(data.data("x-special/gnome-copied-files").data()).startswith(b"cut"))
        return {"paths": paths, "cut": cut}

    @Slot(str)
    def paste(self, folder):
        board = self.clipboard()
        if not board["paths"]:
            return
        self.transfer(board["paths"], folder, board["cut"])
        if board["cut"]:
            QGuiApplication.clipboard().clear()
