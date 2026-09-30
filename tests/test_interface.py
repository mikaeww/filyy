"""The real window, offscreen, on a folder made for the test: a new folder through the sheet, the views, the split
and the menu. Trash and jump history point into the test folder; nothing goes to a desktop session.
"""
import tempfile
import time
import unittest
from pathlib import Path

import shiboken6
from PySide6.QtCore import Q_ARG, QMetaObject, QObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickWindow

from filyy.app import build_engine
from filyy.filesystem import trash
from filyy.lookup import jump
from filyy.preferences import Prefs


def plain(value):
    return value.toVariant() if hasattr(value, "toVariant") else value


def call(target, method, *values):
    QMetaObject.invokeMethod(target, method, *[Q_ARG("QVariant", v) for v in values])


class InterfaceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QGuiApplication.instance() or QGuiApplication([])
        cls.tmp = tempfile.TemporaryDirectory()
        root = Path(cls.tmp.name)
        cls.folder = root / "work"
        (cls.folder / "sub").mkdir(parents=True)
        (cls.folder / "a.txt").write_text("a")
        cls._defaults = [(f, f.__defaults__) for f in (trash.trash, trash.entries, trash.restore, trash.purge)]
        for function, _ in cls._defaults:
            function.__defaults__ = (str(root / "Trash"),)
        cls._jump = jump.DATA
        jump.DATA = str(root / "jump")
        cls.engine = build_engine(str(cls.folder), prefs=Prefs(str(root / "filyy.ini"), shell=root))
        cls.window = shiboken6.wrapInstance(shiboken6.getCppPointer(cls.engine.rootObjects()[0])[0], QQuickWindow)
        cls.spin(0.8)

    @classmethod
    def tearDownClass(cls):
        cls.window.close()
        del cls.engine
        for function, defaults in cls._defaults:
            function.__defaults__ = defaults
        jump.DATA = cls._jump
        cls.tmp.cleanup()

    @classmethod
    def spin(cls, seconds=0.5):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            cls.app.processEvents()
            time.sleep(0.005)

    def pane(self):
        return self.window.property("pane")

    def names(self):
        return [entry["name"] for entry in plain(self.pane().property("shown"))]

    def item(self, prefix):
        found = []

        def walk(item):
            for child in item.childItems():
                if child.metaObject().className().startswith(prefix):
                    found.append(child)
                walk(child)
        walk(self.window.contentItem())
        return found[0]

    def test_1_listing_and_new_folder(self):
        self.assertEqual(self.pane().property("path"), str(self.folder))
        self.assertEqual(self.names(), ["sub", "a.txt"])
        call(self.window, "openSheet", "mkdir")
        sheet = self.item("NameSheet")
        self.assertEqual(sheet.property("kind"), "mkdir")
        field = [c for c in sheet.findChildren(QObject) if c.metaObject().className() == "QQuickTextInput"][0]
        field.setProperty("text", "neu")
        QMetaObject.invokeMethod(sheet, "confirm")
        self.spin(0.8)
        self.assertTrue((self.folder / "neu").is_dir())
        self.assertIn("neu", self.names())
        self.assertEqual(sheet.property("kind"), "")

    def test_2_views_split_and_menu(self):
        for view in ("grid", "usage", "list"):
            self.pane().setProperty("view", view)
            self.spin(0.3)
            self.assertEqual(self.pane().property("view"), view)
        call(self.window, "toggleSplit")
        self.spin(0.6)
        self.assertTrue(self.window.property("split"))
        call(self.window, "showMenu", None, 200, 200)
        self.spin(0.6)
        menu = self.item("ContextMenu")
        self.assertTrue(menu.property("open"))
        labels = [item["label"] for item in plain(menu.property("items")) if "label" in item]
        self.assertIn("New folder", labels)
        QMetaObject.invokeMethod(menu, "hide")
        self.spin(0.6)
        self.assertFalse(menu.property("visible"))


if __name__ == "__main__":
    unittest.main()
