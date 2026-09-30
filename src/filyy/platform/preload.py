"""Restarts the process once with nosuspend.c preloaded (Hyprland sends xdg_toplevel.suspended to visible windows).

The library is built by install.sh into build/. The preload is removed from the environment after the restart, so
apps opened from Filyy do not inherit it.
"""
import os
import sys
from pathlib import Path

LIBRARY = Path(__file__).resolve().parents[3] / "build/libnosuspend.so"
MARKER = "FILYY_NOSUSPEND"


def preload_nosuspend():
    library = str(LIBRARY)
    if os.environ.pop(MARKER, "") == "1":
        rest = [p for p in os.environ.get("LD_PRELOAD", "").split(":") if p and p != library]
        if rest:
            os.environ["LD_PRELOAD"] = ":".join(rest)
        else:
            os.environ.pop("LD_PRELOAD", None)
        return
    if os.environ.get("WAYLAND_DISPLAY") and LIBRARY.exists():
        env = dict(os.environ, **{MARKER: "1"})
        env["LD_PRELOAD"] = ":".join(filter(None, [library, os.environ.get("LD_PRELOAD")]))
        os.execve(sys.executable, [sys.executable, "-m", "filyy", *sys.argv[1:]], env)
