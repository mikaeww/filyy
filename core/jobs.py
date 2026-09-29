"""Copy and move jobs with progress, pause, cancel and conflict questions.

A job runs in its own thread. It never leaves half files behind: data goes to a hidden part file that is
renamed into place once complete, and "replace" moves the old item to the trash instead of deleting it.
"""
import os
import shutil
import stat
import threading
import time

from PySide6.QtCore import QObject, QTimer, Property, Signal, Slot

CHUNK = 1 << 20

# Conflict answers
REPLACE, KEEP_BOTH, SKIP = "replace", "keep", "skip"


def free_name(folder, name):
    """name, or 'name (Kopie N).ext' when it is taken in folder."""
    candidate = os.path.join(folder, name)
    stem, suffix = (name, "") if os.path.isdir(candidate) else os.path.splitext(name)
    number = 1
    while os.path.lexists(candidate):
        candidate = os.path.join(folder, f"{stem} (Kopie{'' if number == 1 else ' ' + str(number)}){suffix}")
        number += 1
    return candidate


def tree_size(path):
    try:
        st = os.lstat(path)
    except OSError:
        return 0
    if not stat.S_ISDIR(st.st_mode):
        return st.st_size
    total = 0
    for root, dirs, files in os.walk(path):
        for name in files:
            try:
                total += os.lstat(os.path.join(root, name)).st_size
            except OSError:
                pass
    return total


class Cancelled(Exception):
    pass


class Job:
    """One copy/move/duplicate run; `trash(path) -> str` moves a replaced item away and returns where."""

    def __init__(self, kind, sources, folder, trash, ask=None, policy=None):
        self.kind = kind
        self.sources = [os.path.abspath(s) for s in sources]
        self.folder = os.path.abspath(folder)
        self.trash = trash
        self.ask = ask
        self.policy = policy
        self.total = 0
        self.done = 0
        self.current = ""
        self.state = "running"
        self.error = ""
        self.conflict = None
        # What happened, for undo: ("created", dst) | ("moved", src, dst) | ("trashed", original, where)
        self.log = []
        self.last = ""
        self._resume = threading.Event()
        self._resume.set()
        self._cancel = False
        self.started = time.monotonic()

    def pause(self, paused):
        if paused:
            self._resume.clear()
            self.state = "paused"
        else:
            self.state = "running"
            self._resume.set()

    def cancel(self):
        self._cancel = True
        self._resume.set()

    def _check(self):
        self._resume.wait()
        if self._cancel:
            raise Cancelled()

    def _resolve(self, src, dst):
        if self.policy:
            return self.policy
        if not self.ask:
            return KEEP_BOTH
        self.conflict = {"source": src, "target": dst}
        self.state = "conflict"
        answer, for_all = self.ask(self)
        self.conflict = None
        self.state = "running"
        if for_all:
            self.policy = answer
        return answer

    def run(self):
        try:
            self.total = sum(tree_size(s) for s in self.sources)
            for source in self.sources:
                self._check()
                if not os.path.lexists(source):
                    raise FileNotFoundError(f"Nicht gefunden: {os.path.basename(source)}")
                real = os.path.realpath(source)
                if os.path.isdir(source) and not os.path.islink(source) and \
                        os.path.commonpath((real, os.path.realpath(self.folder))) == real:
                    raise ValueError("Ein Ordner kann nicht in sich selbst landen")
                if self.kind == "duplicate":
                    target = free_name(os.path.dirname(source), os.path.basename(source))
                    self._fresh_copy(source, target)
                    self.log.append(("created", target))
                    self.last = target
                    continue
                if self.kind == "move" and os.path.dirname(source) == self.folder:
                    self.done += tree_size(source)
                    continue
                self._place(source, os.path.join(self.folder, os.path.basename(source)))
            self.state = "done"
        except Cancelled:
            self.state = "cancelled"
        except (OSError, ValueError) as error:
            self.error = str(error)
            self.state = "failed"

    def _place(self, source, target):
        """Copies or moves source to target, asking when target exists; folders onto folders merge."""
        if os.path.lexists(target):
            both_dirs = os.path.isdir(source) and not os.path.islink(source) and os.path.isdir(target) and not os.path.islink(target)
            answer = self._resolve(source, target)
            if answer == SKIP:
                self.done += tree_size(source)
                return
            if answer == KEEP_BOTH:
                target = free_name(os.path.dirname(target), os.path.basename(target))
            elif both_dirs:
                for name in sorted(os.listdir(source)):
                    self._check()
                    self._place(os.path.join(source, name), os.path.join(target, name))
                if self.kind == "move":
                    try:
                        os.rmdir(source)
                    except OSError:
                        pass
                return
            else:
                self.log.append(("trashed", target, self.trash(target)))
        if self.kind == "move":
            self._move(source, target)
            self.log.append(("moved", source, target))
        else:
            self._fresh_copy(source, target)
            self.log.append(("created", target))
        self.last = target

    def _move(self, source, target):
        try:
            os.rename(source, target)
            self.done += tree_size(target)
            return
        except OSError as error:
            if error.errno != 18:  # EXDEV: other filesystem, fall back to copy + delete
                raise
        self._fresh_copy(source, target)
        if os.path.isdir(source) and not os.path.islink(source):
            shutil.rmtree(source)
        else:
            os.remove(source)

    def _fresh_copy(self, source, target):
        """Copies to a target this job creates; on cancel or error the half-built target goes away again."""
        try:
            self._copy(source, target)
        except BaseException:
            if os.path.isdir(target) and not os.path.islink(target):
                shutil.rmtree(target, ignore_errors=True)
            raise

    def _copy(self, source, target):
        self.current = os.path.basename(source)
        if os.path.islink(source):
            os.symlink(os.readlink(source), target)
        elif os.path.isdir(source):
            os.mkdir(target)
            for name in sorted(os.listdir(source)):
                self._check()
                self._copy(os.path.join(source, name), os.path.join(target, name))
            shutil.copystat(source, target, follow_symlinks=False)
        else:
            part = os.path.join(os.path.dirname(target), f".{os.path.basename(target)}.filyy-part")
            try:
                with open(source, "rb") as src, open(part, "wb") as dst:
                    while chunk := src.read(CHUNK):
                        self._check()
                        dst.write(chunk)
                        self.done += len(chunk)
                shutil.copystat(source, part)
                os.replace(part, target)
            except BaseException:
                try:
                    os.remove(part)
                except OSError:
                    pass
                raise


class Jobs(QObject):
    """The running jobs as a list QML can bind to, refreshed ten times a second while any exist."""

    changed = Signal()
    # ok, message, path to select, undo log
    finished = Signal(bool, str, str, "QVariantList")

    def __init__(self, trash):
        super().__init__()
        self._trash = trash
        self._jobs = {}
        self._answers = {}
        self._next = 1
        self._items = []
        self._timer = QTimer(self, interval=100)
        self._timer.timeout.connect(self._refresh)

    def start(self, kind, sources, folder):
        job_id = self._next
        self._next += 1
        job = Job(kind, sources, folder, self._trash, ask=lambda j, i=job_id: self._wait_answer(i))
        self._jobs[job_id] = job
        job.thread = threading.Thread(target=job.run, daemon=True)
        job.thread.start()
        self._timer.start()
        self._refresh()
        return job_id

    def _wait_answer(self, job_id):
        event = threading.Event()
        self._answers[job_id] = [event, None]
        event.wait()
        return self._answers.pop(job_id)[1]

    @Slot(int, str, bool)
    def resolve(self, job_id, answer, for_all):
        slot = self._answers.get(job_id)
        if slot and answer in (REPLACE, KEEP_BOTH, SKIP):
            slot[1] = (answer, for_all)
            slot[0].set()

    @Slot(int, bool)
    def pause(self, job_id, paused):
        if job_id in self._jobs:
            self._jobs[job_id].pause(paused)

    @Slot(int)
    def cancel(self, job_id):
        job = self._jobs.get(job_id)
        if job:
            job.cancel()
            self.resolve(job_id, SKIP, True)

    @Slot()
    def shutdown(self):
        """Cancels every job on quit and waits for them, so no part file outlives the app."""
        for job_id, job in list(self._jobs.items()):
            job.cancel()
            self.resolve(job_id, SKIP, True)
        for job in list(self._jobs.values()):
            job.thread.join(timeout=5)

    def _refresh(self):
        items = []
        for job_id, job in list(self._jobs.items()):
            if job.state in ("done", "failed", "cancelled"):
                del self._jobs[job_id]
                verb = {"copy": "Kopiert", "move": "Verschoben", "duplicate": "Dupliziert"}[job.kind]
                ok = job.state == "done"
                text = job.error if job.state == "failed" else "Abgebrochen" if job.state == "cancelled" else \
                    f"{verb}: {len(job.sources)} Element{'e' if len(job.sources) != 1 else ''}"
                self.finished.emit(ok, text, job.last, [list(entry) for entry in job.log])
                continue
            elapsed = max(0.1, time.monotonic() - job.started)
            items.append({"id": job_id, "kind": job.kind, "state": job.state, "count": len(job.sources),
                          "folder": job.folder, "current": job.current, "done": job.done, "total": job.total,
                          "rate": job.done / elapsed, "conflict": job.conflict or {}})
        if not self._jobs:
            self._timer.stop()
        if items != self._items:
            self._items = items
            self.changed.emit()

    items = Property("QVariantList", lambda self: self._items, notify=changed)
    busy = Property(bool, lambda self: bool(self._items), notify=changed)
