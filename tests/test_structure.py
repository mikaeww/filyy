"""Tests for tools/structure.py: every limit trips on a file built to break it, and nothing else does."""
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

import structure  # noqa: E402


def write(root, relative, text):
    path = Path(root, relative)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


class StructureTest(unittest.TestCase):
    def scan(self, files):
        with tempfile.TemporaryDirectory() as root:
            for relative, text in files.items():
                write(root, relative, text)
            return structure.scan(root)

    def test_clean_tree_passes(self):
        problems, coverage = self.scan({"src/app/model.py": '"""Doc."""\n', "docs/README.md": "# Docs\n"})
        self.assertEqual(problems, [])
        self.assertEqual(coverage, {".py": 1, ".md": 1})

    def test_file_length(self):
        problems, _ = self.scan({"tools/long.js": "x\n" * 501})
        self.assertEqual(problems, ["tools/long.js: 501 lines (max 500)"])

    def test_function_length_and_parameters(self):
        body = "\n".join("    x = %d" % i for i in range(60))
        source = '"""Doc."""\n\ndef long():\n%s\n\ndef wide(self, a, b, c, d, e, f):\n    pass\n' % body
        problems, _ = self.scan({"src/app/model.py": source})
        self.assertEqual(problems, ["src/app/model.py:3: function long has 61 lines",
                                    "src/app/model.py:65: function wide has 6 parameters"])

    def test_bare_except_assert_and_docstring(self):
        source = "try:\n    pass\nexcept:\n    pass\nassert True, 'nope'\nassert True, 'invariant: fine'\n"
        problems, _ = self.scan({"src/app/model.py": source})
        self.assertEqual(problems, ["src/app/model.py: module docstring missing", "src/app/model.py:3: bare except",
                                    "src/app/model.py:5: assert without 'invariant:' message"])

    def test_asserts_are_fine_outside_src(self):
        problems, _ = self.scan({"tests/test_x.py": '"""Doc."""\nassert 1 == 1\n'})
        self.assertEqual(problems, [])

    def test_directory_width_ignores_entry_files_and_tests(self):
        files = {"src/app/m%d.qml" % i: "" for i in range(8)}
        files.update({"src/app/Main.qml": "", "src/app/x.test.js": "", "src/app/__init__.py": '"""Doc."""\n'})
        self.assertEqual(self.scan(files)[0], [])
        files["src/app/m8.qml"] = ""
        self.assertEqual(self.scan(files)[0], ["src/app: 9 code files (max 8)"])

    def test_docs_width_depth_and_names(self):
        files = {"docs/d%d.md" % i: "" for i in range(9)}
        files["src/a/b/c/d/e/x.js"] = ""
        files["src/helpers/y.qml"] = ""
        files["src/misc.py"] = '"""Doc."""\n'
        problems, _ = self.scan(files)
        self.assertEqual(sorted(problems), sorted([
            "docs: 9 markdown files (max 8)", "src/a/b/c/d/e: deeper than 4 below src/",
            "src/helpers: forbidden directory name", "src/misc.py: forbidden module name"]))

    def test_symlinks_and_skipped_directories_are_not_followed(self):
        with tempfile.TemporaryDirectory() as root, tempfile.TemporaryDirectory() as outside:
            write(outside, "big.py", "x\n" * 900)
            os.symlink(outside, Path(root, "linked"))
            write(root, "build/huge.js", "x\n" * 900)
            write(root, ".git/hook.sh", "x\n" * 900)
            self.assertEqual(structure.scan(root), ([], {}))

    def test_scripts_without_suffix_count_as_code(self):
        problems, coverage = self.scan({"launcher": "#!/bin/sh\n" + "x\n" * 500, "notes": "plain\n"})
        self.assertEqual(problems, ["launcher: 501 lines (max 500)"])
        self.assertEqual(coverage, {"script": 1})


if __name__ == "__main__":
    unittest.main()
