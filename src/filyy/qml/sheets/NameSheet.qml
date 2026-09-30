pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../controls"
import "../paths.js" as Paths
import "../format.js" as Format

// New folder and rename ask for a name; trash, delete, purge and empty ask for a confirmation that says what
// happens and whether it can be undone.
Sheet {
    id: root

    required property var app
    // "" | "mkdir" | "rename" | "trash" | "delete" | "purge" | "empty"
    property string kind: ""
    property var targets: []
    property string folder: ""
    readonly property bool asksName: kind === "mkdir" || kind === "rename"
    readonly property bool destroys: ["delete", "purge", "empty"].includes(kind)
    readonly property string names: targets.slice(0, 4).map(p => Paths.baseName(p)).join(", ") + (targets.length > 4 ? " " + Format.tr(I18n.strings, "und {n} weitere", {
            n: targets.length - 4
        }) : "")

    function ask(next, paths, inFolder) {
        targets = paths;
        folder = inFolder;
        kind = next;
        field.text = next === "rename" ? Paths.baseName(paths[0]) : "";
        if (asksName) {
            field.input.forceActiveFocus();
            // Select the name without its extension, like every other file manager.
            const dot = field.text.lastIndexOf(".");
            field.input.select(0, next === "rename" && dot > 0 ? dot : field.text.length);
        }
    }

    function close() {
        kind = "";
        if (app.pane)
            app.pane.focusList();
    }

    function confirm() {
        const name = field.text.trim();
        if (kind === "mkdir" && name)
            Files.mkdir(folder, name);
        else if (kind === "rename" && name)
            Files.rename(targets[0], name);
        else if (kind === "trash")
            Files.trash(targets);
        else if (kind === "delete")
            Files.remove(targets);
        else if (kind === "purge" || kind === "empty")
            Files.purge(targets);
        else
            return;
        close();
    }

    open: kind !== ""
    onDismissed: close()
    onAccepted: confirm()

    Title {
        width: parent.width
        text: Format.tr(I18n.strings, ({
                mkdir: "Neuer Ordner",
                rename: "Umbenennen",
                trash: "In den Papierkorb legen?",
                delete: "Endgültig löschen?",
                purge: "Endgültig löschen?",
                empty: "Papierkorb leeren?"
            })[root.kind] ?? "")
    }

    Text {
        width: parent.width
        visible: !root.asksName
        text: root.kind === "empty" ? Format.tr(I18n.strings, "Alle {n} Elemente im Papierkorb werden gelöscht. Das lässt sich nicht rückgängig machen.", {
            n: root.targets.length
        }) : root.destroys ? Format.tr(I18n.strings, "{names} wird sofort gelöscht, ohne Papierkorb. Das lässt sich nicht rückgängig machen.", {
            names: root.names
        }) : Format.tr(I18n.strings, "{names} landet im Papierkorb und lässt sich von dort zurückholen.", {
            names: root.names
        })
        wrapMode: Text.Wrap
        color: Theme.sub
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBody
        lineHeight: 1.3
    }

    Field {
        id: field

        visible: root.asksName
        width: parent.width
        placeholder: Format.tr(I18n.strings, "Name …")
    }

    Row {
        anchors.right: parent.right
        spacing: Theme.space2

        Button {
            label: Format.tr(I18n.strings, "Abbrechen")
            onClicked: root.close()
        }

        Button {
            label: Format.tr(I18n.strings, ({
                    mkdir: "Erstellen",
                    rename: "Umbenennen",
                    trash: "In den Papierkorb",
                    delete: "Löschen",
                    purge: "Löschen",
                    empty: "Leeren"
                })[root.kind] ?? "OK")
            primary: true
            onClicked: root.confirm()
        }
    }
}
