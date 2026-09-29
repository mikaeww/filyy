"""Quick look: loads text for the preview and colours code with a small regex highlighter in theme colours."""
import os
import re

from PySide6.QtCore import QObject, QRegularExpression, Slot
from PySide6.QtGui import QColor, QFont, QSyntaxHighlighter, QTextCharFormat
from PySide6.QtQuick import QQuickTextDocument

MAX_BYTES = 256 * 1024

KEYWORDS = {
    "python": "and as assert async await break class continue def del elif else except False finally for from global "
              "if import in is lambda None nonlocal not or pass raise return self True try while with yield",
    "js": "async await break case catch class const continue default delete do else export extends false finally for "
          "function if import in instanceof let new null of property readonly required return signal super switch "
          "this throw true try typeof undefined var void while yield",
    "c": "auto bool break case char class const continue default delete do double else enum extern false float for "
         "if int long namespace new nullptr private protected public return short signed sizeof static struct switch "
         "template this true typedef union unsigned using virtual void volatile while",
    "rust": "as async await break const continue crate else enum false fn for if impl in let loop match mod move mut "
            "pub ref return self Self static struct super trait true type unsafe use where while",
    "go": "break case chan const continue default defer else fallthrough for func go goto if import interface map "
          "package range return select struct switch type var nil true false",
    "java": "abstract boolean break case catch class const continue default do double else enum extends final finally "
            "float for fun if implements import instanceof int interface long new null package private protected "
            "public return static super switch this throw try val var void while true false",
    "shell": "case do done elif else esac export fi for function if in local return then until while",
    "lua": "and break do else elseif end false for function goto if in local nil not or repeat return then true until while",
}
LANGUAGES = {
    ".py": "python", ".js": "js", ".ts": "js", ".qml": "js", ".mjs": "js", ".c": "c", ".h": "c", ".cpp": "c",
    ".hpp": "c", ".cc": "c", ".rs": "rust", ".go": "go", ".java": "java", ".kt": "java", ".sh": "shell",
    ".bash": "shell", ".fish": "shell", ".zsh": "shell", ".lua": "lua", ".json": "json", ".toml": "conf",
    ".ini": "conf", ".conf": "conf", ".yaml": "conf", ".yml": "conf", ".md": "markdown", ".css": "c",
}
HASH_COMMENTS = {"python", "shell", "conf"}


def load_text(path):
    """{text, truncated, binary, language} for a file, reading at most MAX_BYTES."""
    try:
        with open(path, "rb") as handle:
            raw = handle.read(MAX_BYTES + 1)
    except OSError as error:
        return {"text": "", "binary": True, "truncated": False, "language": "", "error": error.strerror or str(error)}
    # NUL bytes mean binary; everything else is decoded leniently.
    if b"\0" in raw[:8192]:
        return {"text": "", "binary": True, "truncated": False, "language": "", "error": ""}
    return {"text": raw[:MAX_BYTES].decode("utf-8", "replace"), "binary": False, "truncated": len(raw) > MAX_BYTES,
            "language": LANGUAGES.get(os.path.splitext(path)[1].lower(), ""), "error": ""}


def fmt(color, bold=False, italic=False):
    out = QTextCharFormat()
    out.setForeground(QColor(color))
    if bold:
        out.setFontWeight(QFont.Bold)
    out.setFontItalic(italic)
    return out


class Highlighter(QSyntaxHighlighter):
    def __init__(self, document, language, theme):
        super().__init__(document)
        c = theme._theme["colors"]
        self.rules = []
        words = KEYWORDS.get(language)
        if words:
            self.rules.append((QRegularExpression(r"\b(" + "|".join(map(re.escape, words.split())) + r")\b"), fmt(c["accent"], bold=True)))
        if language == "json":
            self.rules.append((QRegularExpression(r'"[^"\\]*(\\.[^"\\]*)*"(?=\s*:)'), fmt(c["accent"])))
        if language == "markdown":
            self.rules.append((QRegularExpression(r"^#{1,6} .*$"), fmt(c["accent"], bold=True)))
            self.rules.append((QRegularExpression(r"`[^`]+`"), fmt(c["warm"])))
        else:
            self.rules.append((QRegularExpression(r"\b\d+(\.\d+)?\b"), fmt(c["warn"])))
            self.rules.append((QRegularExpression(r'"[^"\\\n]*(\\.[^"\\\n]*)*"|\'[^\'\\\n]*(\\.[^\'\\\n]*)*\''), fmt(c["warm"])))
        if language in HASH_COMMENTS:
            self.rules.append((QRegularExpression(r"#[^\n]*"), fmt(c["fgMuted"], italic=True)))
        elif language and language not in ("json", "markdown"):
            self.rules.append((QRegularExpression(r"//[^\n]*" if language != "lua" else r"--[^\n]*"), fmt(c["fgMuted"], italic=True)))
        self.block = fmt(c["fgMuted"], italic=True) if language in ("js", "c", "rust", "go", "java") else None

    def highlightBlock(self, text):
        for pattern, style in self.rules:
            it = pattern.globalMatch(text)
            while it.hasNext():
                match = it.next()
                self.setFormat(match.capturedStart(), match.capturedLength(), style)
        if not self.block:
            return
        # /* block */ comments that may span lines.
        start = 0 if self.previousBlockState() == 1 else text.find("/*")
        self.setCurrentBlockState(0)
        while start >= 0:
            end = text.find("*/", start + 2)
            if end < 0:
                self.setFormat(start, len(text) - start, self.block)
                self.setCurrentBlockState(1)
                return
            self.setFormat(start, end + 2 - start, self.block)
            start = text.find("/*", end + 2)


class Preview(QObject):
    def __init__(self, theme):
        super().__init__()
        self._theme = theme
        self._highlighter = None

    @Slot(str, result="QVariantMap")
    def text(self, path):
        return load_text(path)

    @Slot(QObject, str)
    def highlight(self, document, language):
        """Colours the QML TextEdit's document; a new call replaces the previous highlighter."""
        if self._highlighter:
            self._highlighter.setDocument(None)
        doc = document.textDocument() if isinstance(document, QQuickTextDocument) else None
        self._highlighter = Highlighter(doc, language, self._theme) if doc and language else None
