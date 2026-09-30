"""Video thumbnails through ffmpeg, stored in the shared freedesktop.org thumbnail cache.

Other file managers read the same ~/.cache/thumbnails/large entries, and Filyy reuses theirs.
"""
import hashlib
import os
import shutil
import subprocess
import tempfile
import threading

from PySide6.QtCore import QObject, QUrl, Signal, Slot
from PySide6.QtGui import QImage

CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "thumbnails", "large")
SIZE = 256
# Two ffmpeg processes at a time, so a folder full of films does not flood the machine.
WORKERS = threading.Semaphore(2)


def uri(path):
    return QUrl.fromLocalFile(path).toEncoded().data().decode()


def cache_path(path, cache=CACHE):
    return os.path.join(cache, hashlib.md5(uri(path).encode()).hexdigest() + ".png")


def fresh(path, thumb):
    """A cached thumbnail counts only if it was made from this exact modification time."""
    image = QImage(thumb)
    if image.isNull():
        return False
    try:
        return image.text("Thumb::MTime") == str(int(os.stat(path).st_mtime))
    except OSError:
        return False


def duration(path):
    try:
        out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                             capture_output=True, text=True, timeout=10).stdout
        return float(out.strip() or 0)
    except (subprocess.TimeoutExpired, ValueError, OSError):
        return 0


def generate(path, cache=CACHE):
    """Renders a frame at 10 % of the film into the cache and returns the thumbnail path ("" on failure)."""
    os.makedirs(cache, mode=0o700, exist_ok=True)
    at = max(0.0, min(duration(path) * 0.1, 30.0))
    with tempfile.TemporaryDirectory() as tmp:
        frame = os.path.join(tmp, "frame.png")
        try:
            subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{at:.2f}", "-i", path, "-frames:v", "1",
                            "-vf", f"scale={SIZE}:{SIZE}:force_original_aspect_ratio=decrease", "-y", frame],
                           capture_output=True, timeout=30, check=True)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
            return ""
        image = QImage(frame)
        if image.isNull():
            return ""
        image.setText("Thumb::URI", uri(path))
        image.setText("Thumb::MTime", str(int(os.stat(path).st_mtime)))
        image.setText("Software", "Filyy")
        target = cache_path(path, cache)
        part = target + ".filyy-part.png"
        if not image.save(part, "PNG"):
            return ""
        os.chmod(part, 0o600)
        os.replace(part, target)
        return target


class Thumbs(QObject):
    ready = Signal(str, str)

    def __init__(self):
        super().__init__()
        self._pending = set()
        self._failed = set()
        self._ffmpeg = bool(shutil.which("ffmpeg"))

    @Slot(str, result=str)
    def video(self, path):
        """The thumbnail URL when cached, else "" and one is made in the background (then `ready` fires)."""
        thumb = cache_path(path)
        if os.path.exists(thumb) and fresh(path, thumb):
            return QUrl.fromLocalFile(thumb).toString()
        if not self._ffmpeg or path in self._pending or path in self._failed:
            return ""
        self._pending.add(path)

        def work():
            with WORKERS:
                made = generate(path)
            self._pending.discard(path)
            if made:
                self.ready.emit(path, QUrl.fromLocalFile(made).toString())
            else:
                self._failed.add(path)
        threading.Thread(target=work, daemon=True).start()
        return ""
