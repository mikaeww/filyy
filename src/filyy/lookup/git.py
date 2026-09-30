"""The small git card: repository, branch, last commit and whether there are uncommitted changes."""
import os
import subprocess
import threading
import time

from PySide6.QtCore import QObject, Signal, Slot

CACHE_SECONDS = 5


def git(folder, *args):
    result = subprocess.run(["git", "-C", folder, *args], capture_output=True, text=True, timeout=3)
    if result.returncode != 0:
        raise OSError(result.stderr.strip())
    return result.stdout


def info(folder):
    """{} outside a repository, else repo, branch, last commit and change count."""
    try:
        top = git(folder, "rev-parse", "--show-toplevel").strip()
    except (OSError, subprocess.TimeoutExpired):
        return {}
    out = {"repo": os.path.basename(top), "top": top, "branch": "", "hash": "", "subject": "", "author": "",
           "time": 0, "changes": -1}
    try:
        out["branch"] = git(folder, "rev-parse", "--abbrev-ref", "HEAD").strip()
        head = git(folder, "log", "-1", "--format=%h%x00%s%x00%an%x00%ct").strip().split("\0")
        if len(head) == 4:
            out.update(hash=head[0], subject=head[1], author=head[2], time=int(head[3]))
    except (OSError, subprocess.TimeoutExpired, ValueError):
        pass  # a fresh repository without commits
    try:
        out["changes"] = sum(1 for line in git(folder, "status", "--porcelain").splitlines() if line.strip())
    except (OSError, subprocess.TimeoutExpired):
        pass
    return out


class Git(QObject):
    ready = Signal(str, "QVariantMap")

    def __init__(self):
        super().__init__()
        self._cache = {}

    @Slot(str)
    def request(self, folder):
        cached = self._cache.get(folder)
        if cached and time.monotonic() - cached[0] < CACHE_SECONDS:
            self.ready.emit(folder, cached[1])
            return

        def work():
            result = info(folder)
            self._cache[folder] = (time.monotonic(), result)
            self.ready.emit(folder, result)
        threading.Thread(target=work, daemon=True).start()
