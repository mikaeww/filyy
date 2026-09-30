pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../controls"
import "../format.js" as Format

// Batch rename with a live preview: find and replace (optionally as regex), a name template with numbers and
// dates, and the letter case. Conflicts are named per row and block the run.
Sheet {
    id: root

    required property var app
    property bool active: false
    property var targets: []
    property var rows: []
    property var options: ({})
    readonly property int errors: rows.filter(row => row.error).length
    readonly property int changes: rows.filter(row => row.new !== row.old && !row.error).length

    function start(paths) {
        targets = paths;
        options = {
            find: "",
            replace: "",
            regex: false,
            template: "{name}",
            start: 1,
            case: ""
        };
        findField.text = "";
        replaceField.text = "";
        templateField.text = "{name}";
        startField.text = "1";
        rows = Rename.preview(paths, options);
        active = true;
        findField.input.forceActiveFocus();
    }

    function setOption(key, value) {
        if (!active)
            return;
        const next = Object.assign({}, options);
        next[key] = value;
        options = next;
        rows = Rename.preview(targets, next);
    }

    function close() {
        active = false;
        if (app.pane)
            app.pane.focusList();
    }

    function apply() {
        if (errors || !changes)
            return;
        Rename.run(rows);
        close();
    }

    open: active
    cardWidth: 760
    onDismissed: close()
    onAccepted: apply()

    Title {
        text: Format.tr(I18n.strings, "{n} Elemente umbenennen", {
            n: root.targets.length
        })
    }

    Row {
        width: parent.width
        spacing: Theme.space2

        Field {
            id: findField

            width: (parent.width - regexChip.width - 2 * Theme.space2) / 2
            placeholder: Format.tr(I18n.strings, "Suchen")
            onTextChanged: root.setOption("find", text)
        }

        Field {
            id: replaceField

            width: findField.width
            placeholder: Format.tr(I18n.strings, "Ersetzen durch")
            onTextChanged: root.setOption("replace", text)
        }

        Chip {
            id: regexChip

            label: "Regex"
            active: root.options.regex === true
            onClicked: root.setOption("regex", !root.options.regex)
        }
    }

    Row {
        width: parent.width
        spacing: Theme.space2

        Field {
            id: templateField

            width: parent.width - startField.width - Theme.space2
            mono: true
            placeholder: Format.tr(I18n.strings, "Vorlage, z. B. {date}-{name}-{n}")
            onTextChanged: root.setOption("template", text)
        }

        Field {
            id: startField

            width: 110
            mono: true
            placeholder: Format.tr(I18n.strings, "Nummer ab")
            input.validator: IntValidator {
                bottom: 0
                top: 99999
            }
            onTextChanged: root.setOption("start", parseInt(text) || 1)
        }
    }

    Row {
        spacing: Theme.space2

        SectionLabel {
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: Theme.space1
            text: Format.tr(I18n.strings, "Schreibweise")
        }

        Repeater {
            model: [
                {
                    key: "",
                    label: Format.tr(I18n.strings, "unverändert")
                },
                {
                    key: "lower",
                    label: Format.tr(I18n.strings, "klein")
                },
                {
                    key: "upper",
                    label: Format.tr(I18n.strings, "GROSS")
                },
                {
                    key: "kebab",
                    label: "kebab-case"
                }
            ]

            Chip {
                required property var modelData

                label: modelData.label
                active: root.options.case === modelData.key
                onClicked: root.setOption("case", modelData.key)
            }
        }
    }

    Text {
        width: parent.width
        text: Format.tr(I18n.strings, "{name} Name  ·  {n} Nummer  ·  {date} Aufnahme- oder Änderungsdatum  ·  {ext} Endung")
        color: Theme.faint
        font.family: Theme.fontMono
        font.pixelSize: Theme.fsSmall
        elide: Text.ElideRight
    }

    Rectangle {
        width: parent.width
        height: Math.min(260, preview.contentHeight + 2 * Theme.space1)
        radius: Theme.radiusSmall
        color: Theme.raise2

        ListView {
            id: preview

            anchors.fill: parent
            anchors.margins: Theme.space1
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows

            delegate: Item {
                id: line

                required property var modelData
                readonly property bool changed: modelData.new !== modelData.old

                width: preview.width
                height: Theme.ctlH

                Text {
                    id: oldName

                    x: Theme.space2
                    width: (parent.width - 5 * Theme.space2) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: line.modelData.old
                    elide: Text.ElideMiddle
                    color: Theme.sub
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSmall
                }

                Text {
                    x: oldName.x + oldName.width + Theme.space2
                    anchors.verticalCenter: parent.verticalCenter
                    text: "→"
                    color: Theme.faint
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSmall
                }

                Text {
                    x: oldName.x + oldName.width + 3 * Theme.space2
                    width: parent.width - x - Theme.space2
                    anchors.verticalCenter: parent.verticalCenter
                    text: line.modelData.error ? line.modelData.new + "  ·  " + line.modelData.error : line.modelData.new
                    elide: Text.ElideMiddle
                    color: line.changed || line.modelData.error ? Theme.fg : Theme.sub
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSmall
                    font.bold: line.changed || line.modelData.error !== ""
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        spacing: Theme.space2

        Button {
            label: Format.tr(I18n.strings, "Abbrechen")
            onClicked: root.close()
        }

        Button {
            label: root.errors ? Format.tr(I18n.strings, root.errors === 1 ? "{n} Konflikt" : "{n} Konflikte", {
                n: root.errors
            }) : Format.tr(I18n.strings, "{n} umbenennen", {
                n: root.changes
            })
            primary: true
            enabled: !root.errors && root.changes > 0
            onClicked: root.apply()
        }
    }
}
