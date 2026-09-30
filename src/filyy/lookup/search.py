"""Content search through ripgrep: streamed, grouped by file, cancelled when the query changes."""
import json
import os
import shutil
import subprocess
import threading

from PySide6.QtCore import QObject, Signal, Slot

MAX_MATCHES = 500


def command(folder, query, regex, hidden):
    args = ["rg", "--json", "--smart-case", "--max-columns", "300", "--max-columns-preview", "--max-count", "5"]
    if not regex:
        args.append("--fixed-strings")
    if hidden:
        args.append("--hidden")
    return args + ["--", query, folder]


def parse(line, folder):
    """One rg --json line to a match dict, or None for anything that is not a match."""
    try:
        event = json.loads(line)
    except ValueError:
        return None
    if event.get("type") != "match":
        return None
    data = event["data"]
    path = data["path"].get("text", "")
    text = data["lines"].get("text", "").rstrip("\n")
    spans = [(m["start"], m["end"]) for m in data.get("submatches", [])]
    # rg gives byte offsets; the UI needs character offsets.
    raw = text.encode()
    spans = [(len(raw[:s].decode(errors="ignore")), len(raw[:e].decode(errors="ignore"))) for s, e in spans]
    return {"path": path, "relative": os.path.relpath(path, folder), "line": data.get("line_number", 0),
            "text": text, "start": spans[0][0] if spans else 0, "end": spans[0][1] if spans else 0}


class Search(QObject):
    # search id, matches found since the last batch
    found = Signal(int, "QVariantList")
    # search id, total matches, whether it stopped at the limit
    finished = Signal(int, int, bool)

    def __init__(self):
        super().__init__()
        self._current = 0
        self._process = None
        self.available = bool(shutil.which("rg"))

    @Slot(result=bool)
    def ready(self):
        return self.available

    @Slot()
    def cancel(self):
        self._current += 1
        if self._process and self._process.poll() is None:
            self._process.kill()

    @Slot(str, str, bool, bool, result=int)
    def start(self, folder, query, regex, hidden):
        self.cancel()
        search_id = self._current
        if not query.strip() or not self.available:
            self.finished.emit(search_id, 0, False)
            return search_id
        process = subprocess.Popen(command(folder, query, regex, hidden), stdout=subprocess.PIPE,
                                   stderr=subprocess.DEVNULL, text=True, bufsize=1)
        self._process = process

        def work():
            batch, total = [], 0
            for line in process.stdout:
                if search_id != self._current:
                    return
                match = parse(line, folder)
                if not match:
                    continue
                batch.append(match)
                total += 1
                if len(batch) >= 25:
                    self.found.emit(search_id, batch)
                    batch = []
                if total >= MAX_MATCHES:
                    process.kill()
                    break
            if search_id == self._current:
                if batch:
                    self.found.emit(search_id, batch)
                self.finished.emit(search_id, total, total >= MAX_MATCHES)
        threading.Thread(target=work, daemon=True).start()
        return search_id
