"""Ctrl+Z for file actions.

Every undoable action records what it did as a list of steps; undo walks them backwards. Undoing a copy puts
the copy into the trash rather than deleting it, so undo itself can never lose data.
"""
import os
import threading

from PySide6.QtCore import QObject, Property, Signal, Slot

from filyy.i18n import tr

LIMIT = 50


def revert(steps, trash, restore):
    """Undoes steps, newest first; raises on the first one that cannot be undone safely."""
    for step in reversed(steps):
        kind = step[0]
        if kind == "created":
            if os.path.lexists(step[1]):
                trash(step[1])
        elif kind in ("moved", "renamed"):
            source, target = step[1], step[2]
            if os.path.lexists(source):
                raise FileExistsError(tr("Am alten Ort liegt schon {name}", name=os.path.basename(source)))
            os.makedirs(os.path.dirname(source), exist_ok=True)
            os.rename(target, source)
        elif kind == "trashed":
            if not step[2]:
                raise OSError(tr("{name} liegt in einem fremden Papierkorb", name=os.path.basename(step[1])))
            restore(step[2])
        else:
            raise ValueError(f"Unbekannter Schritt {kind}")


class Undo(QObject):
    changed = Signal()
    # ok, message
    done = Signal(bool, str)

    def __init__(self, trash, restore):
        super().__init__()
        self._trash = trash
        self._restore = restore
        self._stack = []

    @Slot(str, "QVariantList")
    def push(self, label, steps):
        steps = [tuple(step) for step in steps]
        if not steps:
            return
        self._stack.append((label, steps))
        del self._stack[:-LIMIT]
        self.changed.emit()

    @Slot()
    def undo(self):
        if not self._stack:
            return
        label, steps = self._stack.pop()
        self.changed.emit()

        def work():
            try:
                revert(steps, self._trash, self._restore)
                self.done.emit(True, tr("Rückgängig: {label}", label=tr(label)))
            except (OSError, ValueError) as error:
                self.done.emit(False, tr("{label} lässt sich nicht rückgängig machen: {error}", label=tr(label), error=error))
        threading.Thread(target=work, daemon=True).start()

    label = Property(str, lambda self: self._stack[-1][0] if self._stack else "", notify=changed)
