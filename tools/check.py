#!/usr/bin/env python3
"""The one check command: structure, Python compile, QML format and lint, tests. Stops at the first failure.

Runs at the lowest CPU and I/O priority so it never competes with the desktop. A missing tool fails the check
instead of being skipped.

  python3 tools/check.py          check everything
  python3 tools/check.py --fix    rewrite QML with qmlformat first
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML = ROOT / "src/filyy/qml"
QT_BIN = Path("/usr/lib/qt6/bin")


def tool(name):
    found = shutil.which(name) or (str(QT_BIN / name) if (QT_BIN / name).exists() else None)
    if not found:
        raise SystemExit(f"check: {name} is not installed")
    return found


def qml_files():
    return sorted(QML.rglob("*.qml"))


def run(title, command, **kwargs):
    print(f"== {title}", flush=True)
    done = subprocess.run(command, cwd=ROOT, **kwargs)
    if done.returncode != 0:
        raise SystemExit(f"check: {title} failed")
    return done


def qml_format(fix):
    qmlformat = tool("qmlformat")
    if fix:
        run("qmlformat --fix", [qmlformat, "-i", *map(str, qml_files())])
        return
    print("== qmlformat", flush=True)
    unformatted = []
    for path in qml_files():
        done = subprocess.run([qmlformat, str(path)], capture_output=True, text=True)
        if done.returncode != 0 or done.stdout != path.read_text():
            unformatted.append(str(path.relative_to(ROOT)))
    if unformatted:
        raise SystemExit("check: not qmlformat-clean (run with --fix): " + ", ".join(unformatted))


def qml_lint():
    """qmllint against the real Qt modules plus a description of the Python singletons generated right now."""
    with tempfile.TemporaryDirectory(prefix="filyy-lint-") as types:
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
        run("qmltypes", [sys.executable, "tools/qmltypes.py", types], env=env, stdout=subprocess.DEVNULL)
        run("qmllint", [tool("qmllint"), "--max-warnings", "0", "-I", types, "-I", str(QML), *map(str, qml_files())])


def main():
    os.nice(19)
    subprocess.run(["ionice", "-c3", "-p", str(os.getpid())], check=False)
    run("structure", [sys.executable, "tools/structure.py"])
    run("compile", [sys.executable, "-m", "compileall", "-q", "src", "tools", "tests"])
    if qml_files():
        qml_format("--fix" in sys.argv)
        qml_lint()
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", PYTHONPATH=str(ROOT / "src"))
    run("python tests", [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-t", "."], env=env)
    for test in sorted((ROOT / "tests").glob("*.test.js")):
        run(test.name, [tool("node"), str(test)])
    print("check: ok")


if __name__ == "__main__":
    main()
