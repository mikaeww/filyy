"""Runnable checks for the backend: python3 tests/test_core.py"""
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core import trash as trashcan
from core.jobs import CHUNK, KEEP_BOTH, REPLACE, SKIP, Job
from core import archive
from core.apps import all_apps, handlers
from core.gitinfo import info as git_info
from core.jump import fuzzy, rank
from core.rename import apply as apply_rename, kebab, plan
from core.prefs import Prefs
from core.search import parse as parse_match
from core.thumbs import cache_path, fresh, generate
from core.undo import revert
from core.usage import disk_usage
from core.fs import checked_name, human, kind_of, listing, natural_key
from core.theme import preset_colors, shell_theme


def main():
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "b10.txt").write_text("x")
        (Path(tmp) / "b9.txt").write_text("x")
        (Path(tmp) / "Zed").mkdir()
        (Path(tmp) / ".hidden").write_text("")
        names = [e["name"] for e in listing(tmp, False)["entries"]]
        assert names == ["Zed", "b9.txt", "b10.txt"], names
        assert len(listing(tmp, True)["entries"]) == 4
        assert listing(tmp + "/gone", False)["error"]
        jobs(Path(tmp))
        for bad in ("", "..", "a/b"):
            try:
                checked_name(bad)
                raise AssertionError(bad)
            except ValueError:
                pass
        qml = 'id: "rose"\n colors: {\n bg: "#2c2429",\n fg: "#f0e1e6"\n }\n id: "x" colors: { bg: "#000000" }'
        assert preset_colors(qml, "rose") == {"bg": "#2c2429", "fg": "#f0e1e6"}
        (Path(tmp) / "preferences.ini").write_text(
            '[Shell]\npresetId=rose\ncustomEnabled=true\ncornerStyle=square\n'
            'customJson="{\\"bg\\":\\"#000000\\",\\"nope\\":\\"#ffffff\\"}"\n')
        (Path(tmp) / "ThemePresets.qml").write_text(qml)
        theme = shell_theme(Path(tmp))
        assert theme["colors"]["bg"] == "#000000" and theme["colors"]["fg"] == "#f0e1e6", theme
        assert "nope" not in theme["colors"] and theme["square"] and theme["radius"] == 0
    assert human(512) == "512 B" and human(1536) == "1.5 KB"
    with tempfile.TemporaryDirectory() as tmp:
        trash(Path(tmp))
    with tempfile.TemporaryDirectory() as tmp:
        undo(Path(tmp))
    jump()
    with tempfile.TemporaryDirectory() as tmp:
        rename(Path(tmp))
    with tempfile.TemporaryDirectory() as tmp:
        git(Path(tmp))
    with tempfile.TemporaryDirectory() as tmp:
        apps(Path(tmp))
    with tempfile.TemporaryDirectory() as tmp:
        thumbs(Path(tmp))
    search()
    with tempfile.TemporaryDirectory() as tmp:
        usage(Path(tmp))
    with tempfile.TemporaryDirectory() as tmp:
        archives(Path(tmp))
    with tempfile.TemporaryDirectory() as tmp:
        prefs(Path(tmp))
    print("ok")


def run(kind, sources, folder, bin_dir, policy=None):
    job = Job(kind, [str(s) for s in sources], str(folder), lambda p: trashcan.trash(p, str(bin_dir)), policy=policy)
    job.run()
    return job


def jobs(root):
    src, dst, bin_dir = root / "src", root / "dst", root / "bin"
    for d in (src, dst, bin_dir):
        d.mkdir()
    (src / "a.txt").write_text("new")
    (src / "tree").mkdir()
    (src / "tree" / "inner.txt").write_text("inner")
    (dst / "a.txt").write_text("old")
    (dst / "tree").mkdir()
    (dst / "tree" / "keep.txt").write_text("keep")

    job = run("duplicate", [src / "a.txt"], src, bin_dir)
    assert job.state == "done" and job.last.endswith("a (Kopie).txt") and job.log == [("created", job.last)]
    assert run("copy", [src / "a.txt"], dst, bin_dir, policy=SKIP).state == "done"
    assert (dst / "a.txt").read_text() == "old"
    kept = run("copy", [src / "a.txt"], dst, bin_dir, policy=KEEP_BOTH)
    assert kept.last.endswith("a (Kopie).txt") and (dst / "a (Kopie).txt").read_text() == "new"
    replaced = run("copy", [src / "a.txt"], dst, bin_dir, policy=REPLACE)
    assert (dst / "a.txt").read_text() == "new", "replace writes the new file"
    trashed = [entry for entry in replaced.log if entry[0] == "trashed"]
    assert trashed and Path(trashed[0][2]).read_text() == "old", "the replaced file waits in the trash"
    # Folders onto folders merge; the moved source folder is gone afterwards.
    merged = run("move", [src / "tree"], dst, bin_dir, policy=REPLACE)
    assert merged.state == "done" and not (src / "tree").exists()
    assert sorted(os.listdir(dst / "tree")) == ["inner.txt", "keep.txt"]
    assert run("move", [dst], dst / "tree", bin_dir).state == "failed", "a folder cannot move into itself"
    assert not any(name.endswith(".filyy-part") for _, _, files in os.walk(root) for name in files)
    # A cancelled copy leaves no part file behind.
    (src / "big.bin").write_bytes(b"x" * (3 << 20))
    class StopMidway(Job):
        def _check(self):
            if self.done >= CHUNK:
                self.cancel()
            super()._check()

    job = StopMidway("copy", [str(src / "big.bin")], str(dst), lambda p: p)
    job.run()
    assert job.state == "cancelled" and job.done == CHUNK and not (dst / "big.bin").exists()
    (src / "many").mkdir()
    for i in range(3):
        (src / "many" / f"{i}.bin").write_bytes(b"y" * CHUNK)
    job = StopMidway("copy", [str(src / "many")], str(dst), lambda p: p)
    job.run()
    assert job.state == "cancelled" and not (dst / "many").exists(), "a cancelled folder copy leaves nothing"
    assert not any(name.endswith(".filyy-part") for name in os.listdir(dst))


def trash(root):
    bin_dir, home = root / "bin", root / "home"
    home.mkdir()
    (home / "note.txt").write_text("hi")
    (home / "dir").mkdir()
    where = trashcan.trash(str(home / "note.txt"), str(bin_dir))
    (home / "note.txt").write_text("again")
    second = trashcan.trash(str(home / "note.txt"), str(bin_dir))
    assert where != second and os.path.basename(second) == "note.2.txt", second
    listed = trashcan.entries(str(bin_dir))
    assert {e["original"] for e in listed} == {str(home / "note.txt")} and len(listed) == 2
    assert trashcan.restore(where, str(bin_dir)) == str(home / "note.txt")
    assert (home / "note.txt").read_text() == "hi"
    try:
        trashcan.restore(second, str(bin_dir))
        raise AssertionError("restore overwrote an existing file")
    except FileExistsError:
        pass
    trashcan.purge(second, str(bin_dir))
    assert trashcan.entries(str(bin_dir)) == []



def undo(root):
    bin_dir, a, b = root / "bin", root / "a", root / "b"
    a.mkdir()
    b.mkdir()
    (a / "one.txt").write_text("one")
    (a / "two.txt").write_text("two")
    (b / "two.txt").write_text("old two")
    to_bin = lambda p: trashcan.trash(p, str(bin_dir))
    from_bin = lambda p: trashcan.restore(p, str(bin_dir))
    before = {str(p.relative_to(root)): p.read_text() for p in root.rglob("*.txt")}

    copied = run("copy", [a / "one.txt"], b, bin_dir)
    replaced = run("copy", [a / "two.txt"], b, bin_dir, policy=REPLACE)
    moved = run("move", [a / "one.txt"], b / "..", bin_dir)
    os.rename(root / "one.txt", root / "uno.txt")
    renamed = [("renamed", str(root / "one.txt"), str(root / "uno.txt"))]
    assert (b / "two.txt").read_text() == "two" and not (a / "one.txt").exists()

    for steps in (renamed, moved.log, replaced.log, copied.log):
        revert(steps, to_bin, from_bin)
    after = {str(p.relative_to(root)): p.read_text() for p in root.rglob("*.txt") if bin_dir not in p.parents}
    assert after == before, (after, before)
    try:
        (a / "one.txt").write_text("blocker")
        revert([("moved", str(a / "one.txt"), str(a / "two.txt"))], to_bin, from_bin)
        raise AssertionError("undo overwrote a file")
    except FileExistsError:
        pass


def jump():
    assert fuzzy("prfil", "/home/m/Projekte/Apps/filyy") > 0
    assert fuzzy("xyz", "/home/m/Projekte") == 0
    assert fuzzy("bild", "/home/m/Bilder") > fuzzy("bild", "/home/m/Projekte/Apps/filyy/bild-tools")
    now = 1_000_000
    visits = {"/h/Projekte/filyy": {"visits": 20, "last": now - 60}, "/h/Projekte/fabric": {"visits": 1, "last": now - 10**7}}
    assert rank("f", visits, ["/h/Fotos"], now)[0] == "/h/Projekte/filyy", "frecency beats a fresh scan hit"
    assert rank("", visits, [], now) == ["/h/Projekte/filyy", "/h/Projekte/fabric"]


def rename(root):
    for name in ("IMG_001.JPG", "IMG_002.JPG", "a.txt", "b.txt"):
        (root / name).write_text(name)
    photos = [str(root / "IMG_001.JPG"), str(root / "IMG_002.JPG")]
    rows = plan(photos, find="IMG_", replace="", template="urlaub-{n}", case="kebab")
    assert [r["new"] for r in rows] == ["urlaub-1.jpg", "urlaub-2.jpg"], rows
    assert plan(photos * 1, template="gleich")[0]["error"] == "Doppelter Name"
    assert plan([str(root / "a.txt")], template="b")[0]["error"] == "Name ist schon vergeben"
    assert plan([str(root / "a.txt")], find="(", regex=True)[0]["error"].startswith("Regex")
    assert kebab("Mein Urlaub_2026 Bild") == "mein-urlaub-2026-bild" and kebab("fooBar") == "foo-bar"
    steps = apply_rename(rows)
    assert sorted(p.name for p in root.iterdir()) == ["a.txt", "b.txt", "urlaub-1.jpg", "urlaub-2.jpg"]
    revert(steps, None, None)
    assert (root / "IMG_001.JPG").read_text() == "IMG_001.JPG"
    # A swap needs the two-phase rename.
    swap = [dict(r, new=n) for r, n in zip(plan([str(root / "a.txt"), str(root / "b.txt")]), ("b.txt", "a.txt"))]
    apply_rename(swap)
    assert (root / "a.txt").read_text() == "b.txt" and (root / "b.txt").read_text() == "a.txt"


def git(root):
    import subprocess
    assert git_info(str(root)) == {}, "no card outside a repository"
    run_git = lambda *a: subprocess.run(["git", "-C", str(root), *a], check=True, capture_output=True)
    run_git("init", "-q", "-b", "main")
    assert git_info(str(root))["hash"] == "", "a fresh repository has no commit yet"
    (root / "a.txt").write_text("a")
    run_git("add", "a.txt")
    run_git("-c", "user.name=Test", "-c", "user.email=t@example.invalid", "commit", "-q", "-m", "Erster Commit")
    (root / "b.txt").write_text("b")
    got = git_info(str(root / ""))
    assert got["branch"] == "main" and got["subject"] == "Erster Commit" and got["author"] == "Test", got
    assert got["changes"] == 1 and got["time"] > 0


def apps(root):
    user, system = root / "user", root / "system"
    (system / "kde").mkdir(parents=True)
    user.mkdir()
    entry = "[Desktop Entry]\nType=Application\nName={name}\nExec=x %f\nMimeType={mime}\n"
    (system / "viewer.desktop").write_text(entry.format(name="System Viewer", mime="image/png;"))
    (user / "viewer.desktop").write_text(entry.format(name="Own Viewer", mime="image/png;"))
    (system / "kde" / "paint.desktop").write_text(entry.format(name="Paint", mime="image/png;image/jpeg;"))
    (system / "broken.desktop").write_text("not a desktop file")
    found = all_apps([str(user), str(system)])
    assert found["viewer.desktop"]["name"] == "Own Viewer", "the first XDG directory wins"
    assert "kde-paint.desktop" in found and "broken.desktop" not in found
    assert [a["name"] for a in handlers(["image/jpeg"], found)] == ["Paint"]


def thumbs(root):
    import shutil
    import subprocess
    if not shutil.which("ffmpeg"):
        print("skip thumbs: no ffmpeg")
        return
    from PySide6.QtGui import QGuiApplication
    app = QGuiApplication.instance() or QGuiApplication(["test", "-platform", "offscreen"])
    film, cache = root / "film.mp4", root / "cache"
    subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "testsrc=duration=1:size=320x180:rate=10", str(film)], check=True)
    made = generate(str(film), str(cache))
    assert made == cache_path(str(film), str(cache)) and fresh(str(film), made), made
    os.utime(film, (1, 1))
    assert not fresh(str(film), made), "a changed film invalidates its thumbnail"
    del app


def search():
    import json
    line = json.dumps({"type": "match", "data": {"path": {"text": "/p/a/notiz.md"}, "lines": {"text": "Grüße an Geist\n"},
                                                  "line_number": 7, "submatches": [{"start": 11, "end": 16}]}})
    match = parse_match(line, "/p")
    assert match["relative"] == "a/notiz.md" and match["line"] == 7
    assert match["text"][match["start"]:match["end"]] == "Geist", "rg byte offsets become character offsets"
    assert parse_match(json.dumps({"type": "begin", "data": {}}), "/p") is None


def usage(root):
    (root / "big").mkdir()
    (root / "big" / "data.bin").write_bytes(os.urandom(256 * 1024))
    (root / "big" / "inner").mkdir()
    (root / "big" / "inner" / "more.bin").write_bytes(os.urandom(128 * 1024))
    os.symlink(root / "big", root / "link")
    device = os.lstat(root).st_dev
    size = disk_usage(str(root / "big"), device, lambda: True)
    assert 384 * 1024 <= size < 512 * 1024, size
    assert disk_usage(str(root / "link"), device, lambda: True) < 4096, "symlinks are not followed"


def archives(root):
    import tarfile
    import zipfile
    pack = root / "pack.zip"
    with zipfile.ZipFile(pack, "w") as z:
        z.writestr("assets/logo.txt", "logo")
        z.writestr("assets/deep/x.txt", "x")
        z.writestr("readme.md", "hi")
        z.writestr("../evil.txt", "no")
        z.writestr("/abs.txt", "no")
    tgz = root / "src.tar.gz"
    with tarfile.open(tgz, "w:gz") as t:
        for name, text in (("src/a.py", "a"), ("src/b.py", "b")):
            data = text.encode()
            info = tarfile.TarInfo(name)
            info.size = len(data)
            import io
            t.addfile(info, io.BytesIO(data))
    assert archive.split(str(pack / "assets" / "logo.txt")) == (str(pack), "assets/logo.txt")
    assert archive.split(str(root)) is None
    top = archive.listing(str(pack), "", kind_of, natural_key)["entries"]
    assert [e["name"] for e in top] == ["assets", "readme.md"], "unsafe names never show up"
    inner = archive.listing(str(pack), "assets", kind_of, natural_key)["entries"]
    assert [e["name"] for e in inner] == ["deep", "logo.txt"]
    out = root / "out"
    job = run("extract", [str(pack / "assets")], out, root / "bin")
    assert job.state == "done", job.error
    assert (out / "assets" / "deep" / "x.txt").read_text() == "x" and not (root / "evil.txt").exists()
    assert job.log == [("created", str(out))], job.log
    job = run("extract", [str(tgz)], root / "src-out", root / "bin")
    assert job.state == "done" and (root / "src-out" / "src" / "b.py").read_text() == "b", job.error
    # Into an existing folder: one undo step per new top-level item.
    job = run("extract", [str(pack / "readme.md")], out, root / "bin")
    assert job.log == [("created", str(out / "readme.md"))], job.log


def prefs(root):
    path = str(root / "filyy.ini")
    first = Prefs(path)
    assert first.get("view", "list") == "list", "defaults before anything is saved"
    session = {"index": 1, "tabs": [{"path": "/a", "split": False}, {"path": "/b", "split": True, "second": "/c"}]}
    first.set("view", "grid")
    first.set("hidden", True)
    first.set("session", session)
    again = Prefs(path)
    assert again.get("view") == "grid" and again.get("hidden") is True and again.get("session") == session


if __name__ == "__main__":
    main()
