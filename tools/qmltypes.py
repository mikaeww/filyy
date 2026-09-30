#!/usr/bin/env python3
"""Describes the Python singletons (`Files`, `Jobs`, `Prefs`, ...) to qmllint, generated from their QMetaObjects.

qmllint cannot see types registered at runtime from Python. Generating the module description at check time
keeps it identical to the real API, so a typo in QML fails the check instead of the running app.

  python3 tools/qmltypes.py DIR      writes DIR/Filyy/{qmldir,filyy.qmltypes}
"""
import sys
from pathlib import Path

from PySide6.QtCore import QMetaMethod

SIMPLE = {"QString": "QString", "bool": "bool", "int": "int", "double": "double", "float": "double",
          "QVariant": "QVariant", "QVariantList": "QVariantList", "QVariantMap": "QVariantMap"}


def type_name(name):
    name = bytes(name).decode() if not isinstance(name, str) else name
    return SIMPLE.get(name, "QVariant")


def parameters(method):
    names = [bytes(n).decode() for n in method.parameterNames()]
    return "".join('        Parameter { name: "%s"; type: "%s" }\n'
                   % (names[i] or "arg%d" % i, type_name(method.parameterTypeName(i)))
                   for i in range(method.parameterCount()))


def component(name, meta):
    lines = ["    Component {", '        name: "%s"' % name, '        accessSemantics: "reference"',
             '        prototype: "QObject"', '        exports: ["Filyy/%s 1.0"]' % name,
             "        isCreatable: false", "        isSingleton: true", "        exportMetaObjectRevisions: [256]"]
    for i in range(meta.propertyOffset(), meta.propertyCount()):
        prop = meta.property(i)
        notify = prop.notifySignal()
        lines.append('        Property { name: "%s"; type: "%s"; read: "%s"; isReadonly: %s%s }' % (
            prop.name(), type_name(prop.typeName()), prop.name(), "false" if prop.isWritable() else "true",
            '; notify: "%s"' % bytes(notify.name()).decode() if notify.isValid() else ""))
    for i in range(meta.methodOffset(), meta.methodCount()):
        method = meta.method(i)
        method_name = bytes(method.name()).decode()
        if method_name.startswith("_"):
            continue
        kind = "Signal" if method.methodType() == QMetaMethod.Signal else "Method"
        returns = type_name(method.typeName()) if kind == "Method" and method.typeName() != "void" else ""
        lines.append("        %s {" % kind)
        lines.append('            name: "%s"' % method_name + ('; type: "%s"' % returns if returns else ""))
        if method.parameterCount():
            lines.append(parameters(method).rstrip("\n").replace("        Parameter", "            Parameter"))
        lines.append("        }")
    lines.append("    }")
    return "\n".join(lines)


def singletons():
    """(QML name, class) of everything app.backend registers, imported the way the app imports them."""
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
    from filyy import app
    names = ["Files", "Jobs", "Rename", "Undo", "I18n", "Git", "Jump", "Search", "Usage", "Prefs", "Apps",
             "Preview", "Thumbs"]
    return [(name, getattr(app, name)) for name in names]


def write(directory):
    module = Path(directory, "Filyy")
    module.mkdir(parents=True, exist_ok=True)
    (module / "qmldir").write_text("module Filyy\ntypeinfo filyy.qmltypes\n")
    body = "\n".join(component(name, cls.staticMetaObject) for name, cls in singletons())
    (module / "filyy.qmltypes").write_text("import QtQuick.tooling 1.2\n\nModule {\n%s\n}\n" % body)
    return module


if __name__ == "__main__":
    print(write(sys.argv[1] if len(sys.argv) > 1 else "."))
