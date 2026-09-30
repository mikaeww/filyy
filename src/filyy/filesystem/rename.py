"""Batch rename: build a plan from a few options, preview it, then apply it in one undoable step.

Template tokens: {name} (name without extension), {ext} (with the dot), {n} (a counter padded to the width of the
largest number), {date} (YYYY-MM-DD from EXIF for photos, else the file's modification date).
"""
import datetime
import os
import re
import threading
import uuid

from PySide6.QtCore import QObject, Signal, Slot

from filyy.filesystem.listing import checked_name
from filyy.i18n import tr


def photo_date(path):
    """EXIF DateTimeOriginal when Pillow is installed and the file has one."""
    try:
        from PIL import Image
        with Image.open(path) as image:
            raw = image.getexif().get_ifd(0x8769).get(0x9003) or image.getexif().get(0x0132)
        if raw:
            return datetime.datetime.strptime(str(raw)[:19], "%Y:%m:%d %H:%M:%S").date()
    except Exception:
        # ponytail: any unreadable or non-image file just falls back to its mtime.
        pass
    return None


def file_date(path):
    date = photo_date(path)
    if date is None:
        try:
            date = datetime.date.fromtimestamp(os.stat(path).st_mtime)
        except OSError:
            date = datetime.date.today()
    return date.isoformat()


def kebab(text):
    text = re.sub(r"[\s_]+", "-", text.strip())
    text = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "-", text)
    return re.sub(r"-{2,}", "-", text).strip("-").lower()


CASES = {"": lambda t: t, "lower": str.lower, "upper": str.upper, "kebab": kebab}


def plan(paths, options=None):
    """One row per path: {path, old, new, error}. Rows only change what the options change.

    options: find, replace, regex, template ("{name}" by default), start (1), case ("", lower, upper, kebab).
    """
    options = options or {}
    find, replace, regex = options.get("find", ""), options.get("replace", ""), bool(options.get("regex"))
    template, start, case = options.get("template") or "{name}", int(options.get("start") or 1), options.get("case", "")
    width = len(str(start + max(len(paths) - 1, 0)))
    pattern = None
    if find and regex:
        try:
            pattern = re.compile(find)
        except re.error as error:
            return [{"path": p, "old": os.path.basename(p), "new": os.path.basename(p), "error": tr("Regex: {error}", error=error)} for p in paths]
    rows = []
    for index, path in enumerate(paths):
        old = os.path.basename(path)
        is_dir = os.path.isdir(path)
        stem, ext = (old, "") if is_dir else os.path.splitext(old)
        if find:
            stem = pattern.sub(replace, stem) if pattern else stem.replace(find, replace)
        values = {"name": stem, "ext": ext, "n": str(start + index).zfill(width)}
        if "{date}" in template:
            values["date"] = file_date(path)
        try:
            base = re.sub(r"\{(name|ext|n|date)\}", lambda m: values[m.group(1)], template)
        except KeyError:
            base = template
        new = CASES.get(case, CASES[""])(base) + ("" if "{ext}" in template else ext.lower() if case in ("lower", "kebab") else ext)
        rows.append({"path": path, "old": old, "new": new, "error": ""})
    seen = {}
    for row in rows:
        try:
            checked_name(row["new"])
        except ValueError as error:
            row["error"] = str(error)
            continue
        folder = os.path.dirname(row["path"])
        key = (folder, row["new"])
        if key in seen:
            row["error"] = tr("Doppelter Name")
            seen[key]["error"] = tr("Doppelter Name")
        seen[key] = row
    renamed = {row["path"] for row in rows}
    for row in rows:
        target = os.path.join(os.path.dirname(row["path"]), row["new"])
        if not row["error"] and row["new"] != row["old"] and os.path.lexists(target) and target not in renamed:
            row["error"] = tr("Name ist schon vergeben")
    return rows


def apply(rows):
    """Renames through temporary names first, so swaps like a↔b work; returns undo steps."""
    moves = [(row["path"], os.path.join(os.path.dirname(row["path"]), row["new"])) for row in rows
             if row["new"] != row["old"] and not row["error"]]
    if any(row["error"] for row in rows):
        raise ValueError(tr("Der Plan hat noch Fehler"))
    parked = []
    try:
        for source, target in moves:
            temp = os.path.join(os.path.dirname(source), f".filyy-rename-{uuid.uuid4().hex}")
            os.rename(source, temp)
            parked.append((source, temp, target))
        steps = []
        for source, temp, target in parked:
            os.rename(temp, target)
            steps.append(("renamed", source, target))
        return steps
    except OSError:
        # Put everything that is still parked back under its old name.
        for source, temp, _ in parked:
            if os.path.lexists(temp):
                os.rename(temp, source)
        raise


class Rename(QObject):
    # ok, message, undo steps
    done = Signal(bool, str, "QVariantList")

    @Slot("QVariantList", "QVariantMap", result="QVariantList")
    def preview(self, paths, options):
        return plan(list(paths), dict(options))

    @Slot("QVariantList")
    def run(self, rows):
        def work():
            try:
                steps = apply([dict(row) for row in rows])
                self.done.emit(True, tr("{n} umbenannt", n=len(steps)), [list(s) for s in steps])
            except (OSError, ValueError) as error:
                self.done.emit(False, str(error), [])
        threading.Thread(target=work, daemon=True).start()
