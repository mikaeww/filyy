"""Runnable checks for the backend: python3 tests/test_core.py"""
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.files import transfer
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
        copy = transfer([tmp + "/b9.txt"], tmp, False)
        assert copy.endswith("b9 (Kopie).txt"), copy
        assert transfer([tmp + "/b9.txt"], tmp, False).endswith("b9 (Kopie 2).txt")
        moved = transfer([tmp + "/b10.txt"], tmp + "/Zed", True)
        assert moved == tmp + "/Zed/b10.txt" and not os.path.exists(tmp + "/b10.txt")
        try:
            transfer([tmp + "/Zed"], tmp + "/Zed", True)
            raise AssertionError("moved a folder into itself")
        except ValueError:
            pass
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
    print("ok")


if __name__ == "__main__":
    main()
