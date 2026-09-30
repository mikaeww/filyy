"""Storage map: what takes the space under a folder, measured like du (blocks on disk) in the background.

Symlinks are not followed and other filesystems are not entered, so a mounted drive under home does not count.
"""
import os
import stat
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

from PySide6.QtCore import QObject, Signal, Slot

from filyy.filesystem.listing import kind_of


class Stopped(Exception):
    pass


def disk_usage(path, device, alive):
    """Bytes on disk under path; alive() returning False aborts."""
    try:
        st = os.lstat(path)
    except OSError:
        return 0
    total = st.st_blocks * 512
    if not stat.S_ISDIR(st.st_mode) or st.st_dev != device:
        return total
    stack = [path]
    while stack:
        if not alive():
            raise Stopped()
        folder = stack.pop()
        try:
            with os.scandir(folder) as it:
                for entry in it:
                    try:
                        info = entry.stat(follow_symlinks=False)
                    except OSError:
                        continue
                    if info.st_dev != device:
                        continue
                    total += info.st_blocks * 512
                    if stat.S_ISDIR(info.st_mode):
                        stack.append(entry.path)
        except OSError:
            pass
    return total


class Usage(QObject):
    # run id, rows so far (largest first), folder total so far, done
    progress = Signal(int, "QVariantList", float, bool)

    def __init__(self):
        super().__init__()
        self._run = 0

    @Slot()
    def cancel(self):
        self._run += 1

    @Slot(str, result=int)
    def start(self, folder):
        self._run += 1
        run = self._run
        alive = lambda: run == self._run

        def work():
            try:
                device = os.lstat(folder).st_dev
                children = sorted(os.scandir(folder), key=lambda e: e.name.lower())
            except OSError:
                self.progress.emit(run, [], 0, True)
                return
            rows = []
            for entry in children:
                is_dir = entry.is_dir(follow_symlinks=False)
                rows.append({"name": entry.name, "path": entry.path, "dir": is_dir, "link": entry.is_symlink(),
                             "kind": kind_of(entry.name, is_dir), "size": 0, "mtime": 0, "pending": True})
            ordered = lambda: sorted(rows, key=lambda r: (r["pending"], -r["size"]))
            # Every row shows at once; sizes fill in, a few updates per second, so one huge folder does not
            # hide all the others while it is being measured.
            self.progress.emit(run, ordered(), 0, False)
            last = time.monotonic()
            # Four at a time: small folders finish while a huge one is still being walked.
            with ThreadPoolExecutor(max_workers=4) as pool:
                futures = {pool.submit(disk_usage, row["path"], device, alive): row for row in rows}
                for future in as_completed(futures):
                    try:
                        futures[future]["size"] = future.result()
                    except Stopped:
                        return
                    futures[future]["pending"] = False
                    if time.monotonic() - last > 0.25:
                        last = time.monotonic()
                        self.progress.emit(run, ordered(), sum(r["size"] for r in rows), False)
            self.progress.emit(run, ordered(), sum(r["size"] for r in rows), True)
        threading.Thread(target=work, daemon=True).start()
        return run
