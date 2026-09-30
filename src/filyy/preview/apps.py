"""Open with: the installed .desktop apps that handle a file's type, and launching one of them."""
import configparser
import os
import shutil
import subprocess

from PySide6.QtCore import QMimeDatabase, QObject, QSize, Slot
from PySide6.QtGui import QIcon, QPixmap
from PySide6.QtQuick import QQuickImageProvider


def application_dirs():
    home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    dirs = [home] + (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    return [os.path.join(d, "applications") for d in dirs if d]


def read_entry(path):
    parser = configparser.RawConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        parser.read(path, encoding="utf-8")
        section = parser["Desktop Entry"]
    except (configparser.Error, KeyError, UnicodeDecodeError, OSError):
        return None
    if section.get("Type", "Application") != "Application" or section.get("Hidden") == "true" or not section.get("Exec"):
        return None
    return {"id": os.path.basename(path), "path": path, "name": section.get("Name", os.path.basename(path)),
            "icon": section.get("Icon", ""), "mimes": [m for m in section.get("MimeType", "").split(";") if m],
            "shown": section.get("NoDisplay") != "true"}


def all_apps(dirs=None):
    """Every desktop app, the first directory in XDG order winning per id, like the spec asks."""
    apps = {}
    for folder in dirs or application_dirs():
        for root, _, files in os.walk(folder):
            for name in files:
                if not name.endswith(".desktop"):
                    continue
                # Desktop ids of apps in subfolders use - instead of / (kde/foo.desktop -> kde-foo.desktop).
                app_id = os.path.relpath(os.path.join(root, name), folder).replace("/", "-")
                if app_id in apps:
                    continue
                entry = read_entry(os.path.join(root, name))
                if entry:
                    entry["id"] = app_id
                    apps[app_id] = entry
    return apps


def handlers(mime_names, apps):
    wanted = set(mime_names)
    return sorted((a for a in apps.values() if wanted & set(a["mimes"])), key=lambda a: a["name"].lower())


class AppIcons(QQuickImageProvider):
    """image://appicon/<name or path> for app icons from the icon theme."""

    def __init__(self):
        super().__init__(QQuickImageProvider.Pixmap)

    def requestPixmap(self, icon_id, size, requested):
        icon = QIcon(icon_id) if icon_id.startswith("/") else QIcon.fromTheme(icon_id)
        side = requested.width() if requested.width() > 0 else 32
        pixmap = icon.pixmap(QSize(side, side)) if not icon.isNull() else QPixmap(side, side)
        if icon.isNull():
            pixmap.fill()
        return pixmap


class Apps(QObject):
    def __init__(self):
        super().__init__()
        self._apps = None
        self._mime = QMimeDatabase()

    def _load(self):
        if self._apps is None:
            self._apps = all_apps()
        return self._apps

    def _mimes(self, path):
        mime = self._mime.mimeTypeForFile(path)
        return mime.name(), [mime.name()] + mime.allAncestors()

    @Slot(str, result="QVariantList")
    def forFile(self, path):
        """Apps for the file, the default one first and flagged."""
        name, family = self._mimes(path)
        default = ""
        if shutil.which("xdg-mime"):
            try:
                default = subprocess.run(["xdg-mime", "query", "default", name], capture_output=True, text=True,
                                         timeout=2).stdout.strip()
            except subprocess.TimeoutExpired:
                pass
        out = [dict(app, default=app["id"] == default) for app in handlers(family, self._load())]
        out.sort(key=lambda a: not a["default"])
        return out

    @Slot(result="QVariantList")
    def everything(self):
        return sorted((dict(a, default=False) for a in self._load().values() if a["shown"]), key=lambda a: a["name"].lower())

    @Slot(str, str, str, bool)
    def launch(self, app_id, app_path, file_path, make_default):
        if make_default and shutil.which("xdg-mime"):
            subprocess.run(["xdg-mime", "default", app_id, self._mimes(file_path)[0]], timeout=3)
        subprocess.Popen(["gio", "launch", app_path, file_path], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
