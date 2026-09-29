"""The freedesktop.org home trash: move in, list, restore, empty.

Filyy writes the trash itself (instead of QFile.moveToTrash) because undo and the graveyard view need to know
the name an item got inside the trash.
"""
import datetime
import os
import shutil
import urllib.parse

from PySide6.QtCore import QFile

from core.i18n import tr

HOME_TRASH = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "Trash")


def _dirs(trash):
    files, info = os.path.join(trash, "files"), os.path.join(trash, "info")
    os.makedirs(files, exist_ok=True)
    os.makedirs(info, exist_ok=True)
    return files, info


def trash(path, trash_dir=HOME_TRASH):
    """Moves path into the trash and returns its new location ("" when another filesystem's trash took it)."""
    path = os.path.abspath(path)
    files, info = _dirs(trash_dir)
    if os.lstat(path).st_dev != os.stat(files).st_dev:
        # ponytail: other filesystems use Qt's $topdir/.Trash; those items are not undoable from Filyy.
        if not QFile.moveToTrash(path):
            raise OSError(tr("Konnte {name} nicht in den Papierkorb legen", name=os.path.basename(path)))
        return ""
    base = os.path.basename(path)
    name, number = base, 1
    while True:
        try:
            # O_EXCL claims the name, so two Filyy windows never pick the same one.
            fd = os.open(os.path.join(info, name + ".trashinfo"), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            break
        except FileExistsError:
            number += 1
            stem, suffix = os.path.splitext(base)
            name = f"{stem}.{number}{suffix}"
    stamp = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    with os.fdopen(fd, "w") as handle:
        handle.write(f"[Trash Info]\nPath={urllib.parse.quote(path)}\nDeletionDate={stamp}\n")
    target = os.path.join(files, name)
    try:
        os.rename(path, target)
    except OSError:
        os.remove(os.path.join(info, name + ".trashinfo"))
        raise
    return target


def entries(trash_dir=HOME_TRASH):
    files, info = _dirs(trash_dir)
    out = []
    for name in sorted(os.listdir(files)):
        original, deleted = "", ""
        try:
            with open(os.path.join(info, name + ".trashinfo")) as handle:
                for line in handle:
                    key, _, value = line.strip().partition("=")
                    if key == "Path":
                        original = urllib.parse.unquote(value)
                    elif key == "DeletionDate":
                        deleted = value
        except OSError:
            pass
        path = os.path.join(files, name)
        out.append({"name": name, "path": path, "original": original, "deleted": deleted,
                    "dir": os.path.isdir(path) and not os.path.islink(path)})
    out.sort(key=lambda e: e["deleted"], reverse=True)
    return out


def restore(trashed, trash_dir=HOME_TRASH):
    """Moves a trashed item back to where it came from and returns that path."""
    files, info = _dirs(trash_dir)
    name = os.path.basename(trashed)
    record = next((e for e in entries(trash_dir) if e["name"] == name), None)
    if not record or not record["original"]:
        raise FileNotFoundError(tr("Keine Herkunft für {name}", name=name))
    target = record["original"]
    if os.path.lexists(target):
        raise FileExistsError(tr("Am alten Ort liegt schon {name}", name=os.path.basename(target)))
    os.makedirs(os.path.dirname(target), exist_ok=True)
    shutil.move(os.path.join(files, name), target)
    os.remove(os.path.join(info, name + ".trashinfo"))
    return target


def purge(trashed, trash_dir=HOME_TRASH):
    files, info = _dirs(trash_dir)
    name = os.path.basename(trashed)
    path = os.path.join(files, name)
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path)
    elif os.path.lexists(path):
        os.remove(path)
    try:
        os.remove(os.path.join(info, name + ".trashinfo"))
    except FileNotFoundError:
        pass
