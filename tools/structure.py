#!/usr/bin/env python3
"""Structure check: the hard limits of docs/conventions.md over every handwritten file.

Covers Python, QML, JavaScript, C, shell scripts and Markdown; skips `.git`, caches and build output and never
follows symlinks. Python functions are measured with `ast`; QML and JavaScript only by file size, which the report
states as its coverage. Not a formatter and not a type checker.

  python3 tools/structure.py [ROOT]      prints violations and coverage, exits 1 on any violation
"""
import ast
import os
import sys
from pathlib import Path

MAX_FILE_LINES = 500
MAX_CODE_FILES = 8
MAX_DOC_FILES = 8
MAX_FUNCTION_LINES = 60
MAX_PARAMETERS = 5
MAX_SRC_DEPTH = 4
CODE = {".py", ".qml", ".js", ".c", ".sh"}
SKIP = {".git", "__pycache__", "build"}
ENTRY = {"__init__.py", "__main__.py", "Main.qml"}
FORBIDDEN = {"utils", "util", "helpers", "helper", "misc", "common", "stuff", "shared"}


def is_script(path):
    try:
        with open(path, "rb") as f:
            return f.read(2) == b"#!"
    except OSError:
        return False


def kind(path):
    if path.suffix in CODE or (not path.suffix and is_script(path)):
        return "code"
    return "doc" if path.suffix == ".md" else None


def walk(root):
    """Yields (directory, [files]) below root without entering skipped directories or symlinks."""
    for current, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in SKIP and not os.path.islink(os.path.join(current, d)))
        yield Path(current), [Path(current, f) for f in sorted(files) if not os.path.islink(os.path.join(current, f))]


def check_python(path, label, in_library):
    """Function size, parameters, bare excepts, stray asserts and the module docstring, in source order."""
    tree = ast.parse(path.read_text(), label)
    found = [] if ast.get_docstring(tree) else [(0, f"{label}: module docstring missing")]
    for node in ast.walk(tree):
        found += [(node.lineno, f"{label}:{node.lineno}: {text}") for text in python_findings(node, in_library)]
    return [text for _, text in sorted(found)]


def python_findings(node, in_library):
    findings = []
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        length = node.end_lineno - node.lineno + 1
        if length > MAX_FUNCTION_LINES:
            findings.append(f"function {node.name} has {length} lines")
        names = [a.arg for a in node.args.posonlyargs + node.args.args + node.args.kwonlyargs]
        names += [a.arg for a in (node.args.vararg, node.args.kwarg) if a]
        count = len([n for n in names if n not in ("self", "cls")])
        if count > MAX_PARAMETERS:
            findings.append(f"function {node.name} has {count} parameters")
    elif isinstance(node, ast.ExceptHandler) and node.type is None:
        findings.append("bare except")
    elif in_library and isinstance(node, ast.Assert):
        message = node.msg.value if isinstance(node.msg, ast.Constant) else ""
        if not str(message).startswith("invariant:"):
            findings.append("assert without 'invariant:' message")
    return findings


def check_directory(root, directory, files):
    problems = []
    relative = directory.relative_to(root)
    if directory.name in FORBIDDEN:
        problems.append(f"{relative}: forbidden directory name")
    code = [f for f in files if kind(f) == "code" and f.name not in ENTRY and not f.name.endswith(".test.js")]
    if relative.parts[:1] != ("tests",) and len(code) > MAX_CODE_FILES:
        problems.append(f"{relative}: {len(code)} code files (max {MAX_CODE_FILES})")
    docs = [f for f in files if kind(f) == "doc"]
    if relative.parts[:1] == ("docs",) and len(docs) > MAX_DOC_FILES:
        problems.append(f"{relative}: {len(docs)} markdown files (max {MAX_DOC_FILES})")
    if relative.parts[:1] == ("src",) and len(relative.parts) - 1 > MAX_SRC_DEPTH:
        problems.append(f"{relative}: deeper than {MAX_SRC_DEPTH} below src/")
    return problems


def check_file(root, path, coverage):
    problems = []
    found = kind(path)
    if not found:
        return problems
    relative = path.relative_to(root)
    coverage[path.suffix or "script"] = coverage.get(path.suffix or "script", 0) + 1
    lines = len(path.read_text(errors="replace").splitlines())
    if lines > MAX_FILE_LINES:
        problems.append(f"{relative}: {lines} lines (max {MAX_FILE_LINES})")
    if found == "code" and path.stem.split(".")[0] in FORBIDDEN:
        problems.append(f"{relative}: forbidden module name")
    if path.suffix == ".py":
        problems += check_python(path, str(relative), relative.parts[:1] == ("src",))
    return problems


def scan(root):
    """All violations below root plus a count of checked files per kind."""
    root = Path(root).resolve()
    problems, coverage = [], {}
    for directory, files in walk(root):
        problems += check_directory(root, directory, files)
        for path in files:
            problems += check_file(root, path, coverage)
    return problems, coverage


def main():
    problems, coverage = scan(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent)
    for problem in problems:
        print(problem)
    covered = ", ".join(f"{count} {suffix}" for suffix, count in sorted(coverage.items()))
    print(f"structure: {len(problems)} violations in {covered}; function limits checked for .py only")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
