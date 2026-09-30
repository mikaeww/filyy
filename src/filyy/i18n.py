"""English and German. The German strings in the code are the keys; EN holds their English text.

QML calls Util.tr(I18n.strings, key, values); Python calls tr(key, **values). {name}-style placeholders are
filled in both, and "one|many" picks by {n} where only English needs a plural. English is the default; the
choice is saved in the prefs.
"""
from PySide6.QtCore import QObject, Property, Signal, Slot

LANGUAGES = ("en", "de")
current = "en"

EN = {
    # navigation and views
    "Zurück": "Back", "Vor": "Forward", "Hoch": "Up", "Liste": "List", "Raster": "Grid",
    "Speicher-Karte": "Storage map", "Versteckte Dateien": "Hidden files", "Pfad": "Path", "Filtern …": "Filter …",
    "Größe": "Size", "Geändert": "Modified", "Ordner": "Folder", "Papierkorb": "Trash", "Orte": "Places",
    "Geräte": "Devices", "Einstellungen": "Settings", "Sprache": "Language", "Home": "Home", "System": "System",
    "Darstellung": "Appearance", "Dunkel": "Dark", "Hell": "Light", "Tab schließen": "Close tab", "OK": "OK",
    "Kein Zugriff": "No access", "Nichts passt zu „{filter}“": "Nothing matches “{filter}”",
    "Der Papierkorb ist leer": "The trash is empty", "Dieser Ordner ist leer": "This folder is empty",
    "{n} ausgewählt": "{n} selected", "{n} Ordner": "{n} folder|{n} folders", "{n} Datei": "{n} file", "{n} Dateien": "{n} files",
    "{size} belegt": "{size} used", "misst …": "measuring …", "{size} frei": "{size} free",
    # menus
    "Öffnen": "Open", "Durchsuchen": "Browse", "Vorschau": "Quick look", "Öffnen mit …": "Open with …",
    "In neuem Tab": "Open in new tab", "Im Terminal öffnen": "Open in terminal", "Terminal hier": "Terminal here",
    "Ausschneiden": "Cut", "Kopieren": "Copy", "Einfügen": "Paste", "Hier hinein einfügen": "Paste into folder",
    "Duplizieren": "Duplicate", "Umbenennen": "Rename", "Mehrere umbenennen …": "Rename several …",
    "Pfad kopieren": "Copy path", "In den Papierkorb": "Move to trash", "Neuer Ordner": "New folder",
    "Rückgängig": "Undo", "Rückgängig: {label}": "Undo: {label}", "Versteckte zeigen": "Show hidden files",
    "Versteckte ausblenden": "Hide hidden files", "Als Raster": "Show as grid", "Als Liste": "Show as list",
    "Geteilte Ansicht": "Split view", "Teilung schließen": "Close split view", "Neu laden": "Reload",
    "Wiederherstellen": "Restore", "Herkunft öffnen": "Open original folder", "Endgültig löschen": "Delete permanently",
    "Papierkorb leeren": "Empty trash", "Alles entpacken": "Extract all", "Hier entpacken": "Extract here",
    "Neben das Archiv entpacken": "Extract next to archive", "In andere Seite entpacken": "Extract to other side",
    "Entf": "Del", "Leertaste": "Space", "Mittelklick": "Middle click", "Strg+X": "Ctrl+X", "Strg+C": "Ctrl+C",
    "Strg+V": "Ctrl+V", "Strg+D": "Ctrl+D", "Strg+Z": "Ctrl+Z", "Strg+H": "Ctrl+H", "Strg+Shift+N": "Ctrl+Shift+N",
    "Strg+Shift+C": "Ctrl+Shift+C", "Strg+1": "Ctrl+1", "Strg+2": "Ctrl+2",
    # dialogs
    "In den Papierkorb legen?": "Move to trash?", "Endgültig löschen?": "Delete permanently?",
    "Papierkorb leeren?": "Empty the trash?", "Erstellen": "Create", "Löschen": "Delete", "Leeren": "Empty",
    "Abbrechen": "Cancel", "Name …": "Name …", "und {n} weitere": "and {n} more",
    "Alle {n} Elemente im Papierkorb werden gelöscht. Das lässt sich nicht rückgängig machen.":
        "All {n} items in the trash will be deleted. This cannot be undone.",
    "{names} wird sofort gelöscht, ohne Papierkorb. Das lässt sich nicht rückgängig machen.":
        "{names} will be deleted right away, without the trash. This cannot be undone.",
    "{names} landet im Papierkorb und lässt sich von dort zurückholen.":
        "{names} goes to the trash and can be restored from there.",
    "„{name}“ gibt es dort schon": "“{name}” already exists there", "Neu": "New", "Vorhanden": "Existing",
    "Für alle weiteren Konflikte": "Apply to all remaining conflicts", "Überspringen": "Skip", "Ersetzen": "Replace",
    "Beide behalten": "Keep both",
    # batch rename
    "{n} Elemente umbenennen": "Rename {n} items", "Suchen": "Find", "Ersetzen durch": "Replace with",
    "Vorlage, z. B. {date}-{name}-{n}": "Template, e.g. {date}-{name}-{n}", "Nummer ab": "Start at",
    "Schreibweise": "Case", "unverändert": "unchanged", "klein": "lower", "GROSS": "UPPER",
    "{name} Name  ·  {n} Nummer  ·  {date} Aufnahme- oder Änderungsdatum  ·  {ext} Endung":
        "{name} name  ·  {n} number  ·  {date} date taken or modified  ·  {ext} extension",
    "{n} Konflikt": "{n} conflict", "{n} Konflikte": "{n} conflicts", "{n} umbenennen": "Rename {n}",
    # open with, search, jump
    "„{file}“ öffnen mit": "Open “{file}” with", "App suchen …": "Search apps …", "Standard": "Default",
    "Keine passende App gefunden": "No matching app", "Als Standard für diesen Dateityp merken": "Always use for this file type",
    "In Dateien suchen …": "Search in files …", "Versteckte": "Hidden", "in {folder}": "in {folder}",
    "Suche …": "Searching …", "Nichts gefunden": "Nothing found", "{n} Treffer": "{n} match|{n} matches",
    "{n} Treffer, bei {n} abgebrochen": "{n} matches, stopped at {n}",
    "ripgrep (rg) ist nicht installiert": "ripgrep (rg) is not installed",
    "↑ ↓  Treffer     Enter  Datei zeigen     Strg+Enter  Öffnen": "↑ ↓  matches     Enter  show file     Ctrl+Enter  open",
    "Zu Ordner springen …": "Jump to folder …", "Kein passender Ordner": "No matching folder",
    "↑ ↓  Auswählen     Enter  Springen     Strg+Enter  Neuer Tab": "↑ ↓  select     Enter  jump     Ctrl+Enter  new tab",
    # jobs
    "Kopiere {items} nach {folder}": "Copying {items} to {folder}", "Verschiebe {items} nach {folder}": "Moving {items} to {folder}",
    "Dupliziere {items}": "Duplicating {items}", "Entpacke {items} nach {folder}": "Extracting {items} to {folder}",
    "Pausiert: {what}": "Paused: {what}", "{n} Element": "{n} item", "{n} Elemente": "{n} items",
    "{done} von {total}": "{done} of {total}", "Fortsetzen": "Resume", "Pausieren": "Pause",
    "Kopiert: {items}": "Copied: {items}", "Verschoben: {items}": "Moved: {items}",
    "Dupliziert: {items}": "Duplicated: {items}", "Entpackt: {items}": "Extracted: {items}", "Abgebrochen": "Cancelled",
    "Verschieben": "Move", "Entpacken": "Extract",
    # git, quick look, media
    "Noch kein Commit": "No commit yet", "Alles committet": "Everything committed",
    "{n} offene Änderung": "{n} uncommitted change", "{n} offene Änderungen": "{n} uncommitted changes",
    "gerade eben": "just now", "vor {n} Min": "{n} min ago", "vor {n} Std": "{n} h ago", "vor {n} Tagen": "{n} days ago",
    "vor {n} Wochen": "{n} weeks ago", "vor {n} Monaten": "{n} months ago", "vor {n} Jahren": "{n} years ago",
    "Seite {page} / {count}": "Page {page} / {count}", "… gekürzt, nur die ersten 256 KB": "… cut off after the first 256 KB",
    "Keine Vorschau für diesen Dateityp": "No preview for this file type", "Geändert {date}": "Modified {date}",
    "Abspielen": "Play",
    # messages from the backend
    "{n} ausgeschnitten": "{n} cut", "{n} kopiert": "{n} copied", "Ordner erstellt": "Folder created",
    "Umbenannt": "Renamed", "{n} in den Papierkorb gelegt": "{n} moved to trash", "{n} endgültig gelöscht": "{n} deleted",
    "{n} wiederhergestellt": "{n} restored", "{n} umbenannt": "{n} renamed", "Aus dem Archiv geöffnet": "Opened from archive",
    "Ungültiger Name": "Invalid name", "Der Name ist schon vergeben": "That name is taken",
    "Nicht gefunden: {name}": "Not found: {name}", "Ein Ordner kann nicht in sich selbst landen": "A folder cannot go into itself",
    "Kopie": "copy", "Doppelter Name": "Duplicate name", "Name ist schon vergeben": "Name is taken",
    "Regex: {error}": "Regex: {error}", "Der Plan hat noch Fehler": "The plan still has errors",
    "Am alten Ort liegt schon {name}": "{name} already exists at its old place",
    "{name} liegt in einem fremden Papierkorb": "{name} is in another drive's trash",
    "{label} lässt sich nicht rückgängig machen: {error}": "Cannot undo {label}: {error}",
    "Konnte {name} nicht in den Papierkorb legen": "Could not move {name} to the trash",
    "Keine Herkunft für {name}": "No original location for {name}", "Nicht im Archiv": "Not in the archive",
    "Archiv nicht lesbar: {error}": "Cannot read archive: {error}", "{name} liegt in keinem Archiv": "{name} is not in an archive",
    "Nur aus einem Archiv auf einmal": "Only one archive at a time",
}


def tr(text, **values):
    out = EN.get(text, text) if current == "en" else text
    if "|" in out and "n" in values:
        out = out.split("|")[0 if values["n"] == 1 else 1]
    return out.format(**values) if values else out


class I18n(QObject):
    changed = Signal()

    def __init__(self, prefs):
        super().__init__()
        global current
        self._prefs = prefs
        saved = prefs.get("lang", "en")
        current = saved if saved in LANGUAGES else "en"

    @Slot(str)
    def setLang(self, lang):
        global current
        if lang in LANGUAGES and lang != current:
            current = lang
            self._prefs.set("lang", lang)
            self.changed.emit()

    lang = Property(str, lambda self: current, notify=changed)
    strings = Property("QVariantMap", lambda self: EN if current == "en" else {}, notify=changed)
