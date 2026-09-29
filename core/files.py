"""Folder listing, places, clipboard and the quick file actions QML calls."""
import os
import shutil
import subprocess
import threading
from pathlib import Path

from PySide6.QtCore import (QFileSystemWatcher, QMimeData, QMimeDatabase, QObject, QStandardPaths, QStorageInfo, QTimer, QUrl,
                            Signal, Slot)
from PySide6.QtGui import QDesktopServices, QGuiApplication

import hashlib

from core import archive
from core import trash as trashcan
from core.fs import checked_name, human, kind_of, listing, natural_key
from core.i18n import tr
from core.jobs import free_name

HOME = str(Path.home())


class Files(QObject):
    folderChanged = Signal(str)
    # ok, message, path to select afterwards ("" for none)
    done = Signal(bool, str, str)
    # undo label, steps (see core/undo.py)
    recorded = Signal(str, "QVariantList")
    # Worker threads hand files to open to the GUI thread through this.
    extracted = Signal(str)
    clipboardChanged = Signal()

    def __init__(self, theme, jobs):
        super().__init__()
        self._theme = theme
        self._jobs = jobs
        jobs.finished.connect(lambda ok, text, last, _label, _steps: self.done.emit(ok, text, last))
        self._watcher = QFileSystemWatcher(self)
        self._debounce = QTimer(self, singleShot=True, interval=150)
        self._debounce.timeout.connect(lambda: self.folderChanged.emit(self._watched))
        self._watcher.directoryChanged.connect(lambda _: self._debounce.start())
        self._watched = ""
        self._mime = QMimeDatabase()
        QGuiApplication.clipboard().dataChanged.connect(self.clipboardChanged)
        self.extracted.connect(self.open)

    @Slot(str, bool, result="QVariantMap")
    def list(self, path, show_hidden):
        inside = archive.split(path)
        if self._watched:
            self._watcher.removePath(self._watched)
        # Inside an archive the archive's own folder is watched, so a rewritten archive refreshes too.
        self._watched = os.path.dirname(inside[0]) if inside else path
        self._watcher.addPath(self._watched)
        if inside:
            try:
                return archive.listing(inside[0], inside[1], kind_of, natural_key)
            except (OSError, ValueError, archive.zipfile.BadZipFile, archive.tarfile.TarError) as error:
                return {"path": path, "entries": [], "error": tr("Archiv nicht lesbar: {error}", error=error)}
        return listing(path, show_hidden)

    @Slot(str, result=bool)
    def exists(self, path):
        """A folder or an archive Filyy can open, for restoring tabs from last time."""
        return os.path.isdir(path) or archive.split(path) is not None

    @Slot(str, result=bool)
    def inArchive(self, path):
        return archive.split(path) is not None

    @Slot(str, result=bool)
    def isArchive(self, path):
        return archive.supported(path) and os.path.isfile(path)

    @Slot(str, result=str)
    def archiveFolder(self, path):
        inside = archive.split(path)
        return os.path.dirname(inside[0]) if inside else os.path.dirname(path)

    @Slot("QVariantList", str)
    def extract(self, paths, folder):
        if paths:
            self._jobs.start("extract", paths, folder)

    @Slot(str)
    def extractAll(self, path):
        """Unpacks the whole archive into a new folder next to it, named like the archive."""
        base = os.path.basename(path)
        stem = next((base[:-len(s)] for s in archive.ZIP + archive.TAR if base.lower().endswith(s)), base)
        self._jobs.start("extract", [path], free_name(os.path.dirname(path), stem))

    @Slot(str)
    def openArchived(self, path):
        """Extracts one member into ~/.cache/filyy/open and opens it with its default app."""
        def work(steps):
            source, inner = archive.split(path)
            folder = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "filyy", "open",
                                  hashlib.md5(path.encode()).hexdigest())
            os.makedirs(folder, exist_ok=True)
            target = os.path.join(folder, os.path.basename(inner))
            for _, handle in archive.each_member(source, [inner]):
                with open(target, "wb") as out:
                    shutil.copyfileobj(handle, out)
            self.extracted.emit(target)
        self._run(work, tr("Aus dem Archiv geöffnet"))

    @Slot(result=str)
    def home(self):
        return HOME

    @Slot(result="QVariantList")
    def places(self):
        # The user's own XDG folders, named as they are on disk, so they match any language.
        wanted = [(tr("Home"), HOME, "home")]
        for kind, icon in ((QStandardPaths.DesktopLocation, "desktop"), (QStandardPaths.DocumentsLocation, "docs"),
                           (QStandardPaths.DownloadLocation, "download"), (QStandardPaths.PicturesLocation, "image"),
                           (QStandardPaths.MusicLocation, "music"), (QStandardPaths.MoviesLocation, "video")):
            folder = QStandardPaths.writableLocation(kind)
            if folder and folder != HOME:
                wanted.append((os.path.basename(folder), folder, icon))
        wanted += [(name, os.path.join(HOME, name), "code") for name in ("Projects", "Projekte")]
        out = [{"name": n, "path": p, "icon": i, "group": tr("Orte")} for n, p, i in wanted if os.path.isdir(p)]
        for volume in QStorageInfo.mountedVolumes():
            root = volume.rootPath()
            if volume.isValid() and volume.isReady() and (root == "/" or root.startswith(("/run/media/", "/media/", "/mnt/"))):
                out.append({"name": tr("System") if root == "/" else (volume.displayName() or os.path.basename(root)),
                            "path": root, "icon": "drive", "group": tr("Geräte")})
        out.append({"name": tr("Papierkorb"), "path": self.trashPath(), "icon": "trash", "group": tr("Geräte")})
        return out

    @Slot(result=str)
    def trashPath(self):
        path = os.path.join(trashcan.HOME_TRASH, "files")
        os.makedirs(path, exist_ok=True)
        return path

    @Slot(result="QVariantList")
    def trashEntries(self):
        out = []
        for entry in trashcan.entries():
            try:
                st = os.lstat(entry["path"])
            except OSError:
                continue
            out.append(dict(entry, size=0 if entry["dir"] else st.st_size, mtime=st.st_mtime * 1000,
                            kind=kind_of(entry["name"], entry["dir"]), link=False))
        return out

    @Slot("QVariantList")
    def restore(self, paths):
        def work(steps):
            last = ""
            for path in paths:
                last = trashcan.restore(path)
                # Undoing a restore puts the item back into the trash.
                steps.append(("created", last))
            return last
        self._run(work, tr("{n} wiederhergestellt", n=len(paths)), "Wiederherstellen")

    @Slot("QVariantList")
    def purge(self, paths):
        def work(steps):
            for path in paths:
                trashcan.purge(path)
        self._run(work, tr("{n} endgültig gelöscht", n=len(paths)))

    @Slot(str, result=str)
    def space(self, path):
        info = QStorageInfo(path)
        return tr("{size} frei", size=human(info.bytesAvailable())) if info.isValid() else ""

    @Slot(str, result=int)
    def count(self, path):
        try:
            return sum(1 for entry in os.scandir(path) if not entry.name.startswith("."))
        except OSError:
            return 0

    @Slot(str, result="QVariantMap")
    def info(self, path):
        try:
            st = os.stat(path)
        except OSError:
            return {"name": os.path.basename(path)}
        return {"name": os.path.basename(path), "size": st.st_size, "mtime": st.st_mtime * 1000,
                "dir": os.path.isdir(path)}

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

    def _run(self, work, message, label=""):
        """Runs work(steps) off the UI thread; it returns the path to select and appends undo steps."""
        def body():
            steps = []
            try:
                select = work(steps)
                self.done.emit(True, message, select or "")
            except (OSError, ValueError) as error:
                self.done.emit(False, str(error), "")
            if label and steps:
                self.recorded.emit(label, [list(step) for step in steps])
        threading.Thread(target=body, daemon=True).start()

    @Slot(str, str)
    def mkdir(self, folder, name):
        def work(steps):
            target = os.path.join(folder, checked_name(name))
            os.mkdir(target)
            steps.append(("created", target))
            return target
        self._run(work, tr("Ordner erstellt"), "Neuer Ordner")

    @Slot(str, str)
    def rename(self, path, name):
        def work(steps):
            target = os.path.join(os.path.dirname(path), checked_name(name))
            if target != path:
                if os.path.lexists(target):
                    raise FileExistsError(tr("Der Name ist schon vergeben"))
                os.rename(path, target)
                steps.append(("renamed", path, target))
            return target
        self._run(work, tr("Umbenannt"), "Umbenennen")

    @Slot("QVariantList")
    def trash(self, paths):
        def work(steps):
            for path in paths:
                steps.append(("trashed", path, trashcan.trash(path)))
        self._run(work, tr("{n} in den Papierkorb gelegt", n=len(paths)), "Papierkorb")

    @Slot("QVariantList")
    def remove(self, paths):
        def work(steps):
            for path in paths:
                if os.path.isdir(path) and not os.path.islink(path):
                    shutil.rmtree(path)
                else:
                    os.remove(path)
        self._run(work, tr("{n} endgültig gelöscht", n=len(paths)))

    @Slot("QVariantList")
    def duplicate(self, paths):
        if paths:
            self._jobs.start("duplicate", paths, os.path.dirname(paths[0]))

    @Slot("QVariantList", str, bool)
    def transfer(self, paths, folder, move):
        if paths:
            self._jobs.start("move" if move else "copy", paths, folder)

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
