"""Listing folders and the small helpers every file action shares."""
import os
import re

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


def human(size):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if size < 1024 or unit == "TB":
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1024
