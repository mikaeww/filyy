#!/usr/bin/env python3
"""Filyy, a small file manager in the Ghostly QShell look.

  filyy [DIR]        open a window on DIR (default: home)
  filyy --selftest   check file actions and theme parsing
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

from PySide6.QtCore import (QFileSystemWatcher, QMimeData, QMimeDatabase, QObject, QSettings,
                            QStorageInfo, QTimer, QUrl, Property, Signal, Slot, QFile)
from PySide6.QtGui import QColor, QDesktopServices, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterSingletonInstance

HERE = Path(__file__).resolve().parent
HOME = str(Path.home())
SHELL = Path(os.environ.get("FILYY_SHELL", Path.home() / ".config/quickshell/ghostly-qshell"))
COLOR_KEYS = ["bg", "panelBg", "fg", "fgMuted", "accent", "accentSoft", "accentText", "warm",
              "warn", "danger", "surface", "surfaceSoft", "hairline"]
# Graphite-ish fallback when the shell is not installed; the shell's own presets win otherwise.
FALLBACK = dict(zip(COLOR_KEYS, ["#161616", "#1d1d1d", "#e6e6e6", "#a3a3a3", "#e6e6e6", "#3a3a3a",
                                 "#101010", "#c8c8c8", "#d1a565", "#c9624f", "#3c3c3c", "#2a2a2a",
                                 "#454545"]))
KINDS = [
    ("image", {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg", ".avif", ".heic"}),
    ("video", {".mp4", ".mkv", ".webm", ".mov", ".avi", ".m4v"}),
    ("audio", {".mp3", ".flac", ".ogg", ".opus", ".wav", ".m4a"}),
    ("archive", {".zip", ".tar", ".gz", ".xz", ".zst", ".7z", ".rar", ".bz2", ".jar"}),
    ("pdf", {".pdf"}),
    ("code", {".py", ".js", ".ts", ".qml", ".rs", ".go", ".java", ".c", ".cpp", ".h", ".sh",
              ".lua", ".json", ".toml", ".yaml", ".yml", ".html", ".css", ".kt"}),
    ("text", {".txt", ".md", ".log", ".ini", ".conf", ".csv", ".odt", ".docx", ".ods", ".xlsx"}),
]


def kind_of(name, is_dir):
    if is_dir:
        return "folder"
    suffix = os.path.splitext(name)[1].lower()
    return next((kind for kind, suffixes in KINDS if suffix in suffixes), "file")


def natural_key(name):
    return [int(part) if part.isdigit() else part.casefold() for part in re.split(r"(\d+)", name)]


def listing(path, show_hidden):
    entries = []
    try:
        with os.scandir(path) as it:
            for entry in it:
                if not show_hidden and entry.name.startswith("."):
                    continue
                try:
                    is_dir = entry.is_dir()
                    stat = entry.stat()
                except OSError:
                    # A dangling symlink still shows up, with the link's own data.
                    is_dir, stat = False, entry.stat(follow_symlinks=False)
                entries.append({"name": entry.name, "path": entry.path, "dir": is_dir,
                                "size": 0 if is_dir else stat.st_size, "mtime": stat.st_mtime * 1000,
                                "kind": kind_of(entry.name, is_dir), "link": entry.is_symlink()})
    except OSError as error:
        return {"path": path, "entries": [], "error": error.strerror or str(error)}
    entries.sort(key=lambda e: (not e["dir"], natural_key(e["name"])))
    return {"path": path, "entries": entries, "error": ""}


def checked_name(name):
    name = name.strip()
    if not name or name in (".", "..") or "/" in name or "\0" in name:
        raise ValueError("Ungültiger Name")
    return name


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


def human(size):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if size < 1024 or unit == "TB":
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1024


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


def selftest():
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "b10.txt").write_text("x")
        (Path(tmp) / "b9.txt").write_text("x")
        (Path(tmp) / "Zed").mkdir()
        (Path(tmp) / ".hidden").write_text("")
        names = [e["name"] for e in listing(tmp, False)["entries"]]
        assert names == ["Zed", "b9.txt", "b10.txt"], names
        assert len(listing(tmp, True)["entries"]) == 4
        assert listing(tmp + "/gone", False)["error"]
        copy = transfer([tmp + "/b9.txt"], tmp, False)
        assert copy.endswith("b9 (Kopie).txt"), copy
        assert transfer([tmp + "/b9.txt"], tmp, False).endswith("b9 (Kopie 2).txt")
        moved = transfer([tmp + "/b10.txt"], tmp + "/Zed", True)
        assert moved == tmp + "/Zed/b10.txt" and not os.path.exists(tmp + "/b10.txt")
        try:
            transfer([tmp + "/Zed"], tmp + "/Zed", True)
            raise AssertionError("moved a folder into itself")
        except ValueError:
            pass
        for bad in ("", "..", "a/b"):
            try:
                checked_name(bad)
                raise AssertionError(bad)
            except ValueError:
                pass
        qml = 'id: "rose"\n colors: {\n bg: "#2c2429",\n fg: "#f0e1e6"\n }\n id: "x" colors: { bg: "#000000" }'
        assert preset_colors(qml, "rose") == {"bg": "#2c2429", "fg": "#f0e1e6"}
        (Path(tmp) / "preferences.ini").write_text(
            '[Shell]\npresetId=rose\ncustomEnabled=true\ncornerStyle=square\n'
            'customJson="{\\"bg\\":\\"#000000\\",\\"nope\\":\\"#ffffff\\"}"\n')
        (Path(tmp) / "ThemePresets.qml").write_text(qml)
        theme = shell_theme(Path(tmp))
        assert theme["colors"]["bg"] == "#000000" and theme["colors"]["fg"] == "#f0e1e6", theme
        assert "nope" not in theme["colors"] and theme["square"] and theme["radius"] == 0
    assert human(512) == "512 B" and human(1536) == "1.5 KB"
    print("ok")


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
    if sys.argv[1:] == ["--selftest"]:
        selftest()
        return
    preload_nosuspend()
    QGuiApplication.setApplicationName("Filyy")
    QGuiApplication.setDesktopFileName("filyy")
    app = QGuiApplication(sys.argv)
    app.setWindowIcon(QIcon(str(HERE / "assets/filyy.svg")))
    theme = Theme()
    files = Files(theme)
    qmlRegisterSingletonInstance(Theme, "Filyy", 1, 0, "Theme", theme)
    qmlRegisterSingletonInstance(Files, "Filyy", 1, 0, "Files", files)
    arg = sys.argv[1] if len(sys.argv) > 1 else HOME
    # "Öffnen mit" hands over file:// URLs, a terminal a plain path.
    start = os.path.abspath(os.path.expanduser(QUrl(arg).toLocalFile() if arg.startswith("file://") else arg))
    engine = QQmlApplicationEngine()
    engine.setInitialProperties({"startPath": start if os.path.isdir(start) else HOME})
    engine.load(str(HERE / "qml/Main.qml"))
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
