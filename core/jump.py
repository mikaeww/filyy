"""Ctrl+K: jump to any folder by a few letters, ranked by how often and how recently it was visited.

Visits live in $XDG_DATA_HOME/filyy/frecency.json. Folders never visited still show up from a shallow scan of
home, just ranked below the ones in use.
"""
import json
import os
import time

from PySide6.QtCore import QObject, Slot

DATA = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "filyy")
LIMIT = 12


def fuzzy(query, path):
    """Score of query as an in-order subsequence of path, 0 when it does not match.

    Hits in the last component, at word starts and in runs count more, so "prfil" finds Projekte/filyy.
    """
    query = query.lower().replace(" ", "")
    if not query:
        return 1.0
    text = path.lower()
    base_start = text.rfind("/") + 1
    score, at, run = 0.0, 0, 0
    for ch in query:
        found = text.find(ch, at)
        if found < 0:
            return 0.0
        run = run + 1 if found == at else 0
        score += 1 + run * 2
        if found >= base_start:
            score += 2
        if found == 0 or text[found - 1] in "/-_. ":
            score += 3
        at = found + 1
    # Shorter paths win ties: a match in ~/Bilder beats one deep in a project.
    return score / (1 + len(text) / 80)


def frecency(entry, now):
    age = now - entry["last"]
    weight = 4 if age < 3600 else 2 if age < 86400 else 0.5 if age < 604800 else 0.25
    return entry["visits"] * weight


# Build output and dependency trees are never where anyone wants to jump.
SKIP = {"node_modules", "target", "build", "dist", "__pycache__", "venv", "site-packages"}


def scan(root, depth=4):
    """Folders under root; follows symlinks, and the depth limit keeps link loops finite."""
    out = []
    try:
        for entry in os.scandir(root):
            if entry.name.startswith(".") or entry.name in SKIP or not entry.is_dir():
                continue
            out.append(entry.path)
            if depth > 1:
                out += scan(entry.path, depth - 1)
    except OSError:
        pass
    return out


def rank(query, visits, extra, now=None):
    now = now or time.time()
    scored = {}
    for path, entry in visits.items():
        match = fuzzy(query, path)
        if match:
            scored[path] = match * (1 + frecency(entry, now))
    for path in extra:
        if path not in scored:
            match = fuzzy(query, path)
            if match:
                scored[path] = match * 0.5
    return sorted(scored, key=lambda p: (-scored[p], p))[:LIMIT]


class Jump(QObject):
    def __init__(self, home):
        super().__init__()
        self._home = home
        self._file = os.path.join(DATA, "frecency.json")
        try:
            with open(self._file) as handle:
                self._visits = json.load(handle)
        except (OSError, ValueError):
            self._visits = {}
        self._scan = None

    @Slot(str)
    def record(self, path):
        entry = self._visits.setdefault(path, {"visits": 0, "last": 0})
        entry["visits"] += 1
        entry["last"] = time.time()
        # ponytail: rewrites the whole file per visit; fine for a few thousand folders.
        os.makedirs(DATA, exist_ok=True)
        tmp = self._file + ".tmp"
        try:
            with open(tmp, "w") as handle:
                json.dump(self._visits, handle)
            os.replace(tmp, self._file)
        except OSError:
            pass

    @Slot(str, result="QVariantList")
    def search(self, query):
        if self._scan is None:
            self._scan = scan(self._home)
        alive = {p: e for p, e in self._visits.items() if os.path.isdir(p)}
        return [{"path": p, "name": os.path.basename(p) or "/", "parent": os.path.dirname(p).replace(self._home, "~", 1)}
                for p in rank(query, alive, self._scan)]
