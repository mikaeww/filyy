"""Runnable checks for the backend: python3 tests/test_core.py"""
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core import trash as trashcan
from core.jobs import CHUNK, KEEP_BOTH, REPLACE, SKIP, Job
from core.jump import fuzzy, rank
from core.undo import revert
from core.fs import checked_name, human, listing
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


if __name__ == "__main__":
    main()
