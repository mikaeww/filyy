pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../controls"
import "../format.js" as Format

// A copy or move found a file that is already there: skip, replace or keep both, for this one or all that follow.
Sheet {
    id: root

    // The first job waiting for an answer about an existing file, if any.
    readonly property var conflict: Array.from(Jobs.items || []).find(job => job.state === "conflict") ?? null
    readonly property var source: conflict ? Files.info(conflict.conflict.source) : ({})
    readonly property var target: conflict ? Files.info(conflict.conflict.target) : ({})
    property bool forAll: false

    function answer(choice) {
        Jobs.resolve(conflict.id, choice, forAll);
        forAll = false;
    }

    open: conflict !== null
    cardWidth: 480
    onDismissed: answer("skip")
    onAccepted: answer("keep")

    Title {
        width: parent.width
        text: Format.tr(I18n.strings, "„{name}“ gibt es dort schon", {
            name: root.target.name ?? ""
        })
    }

    Repeater {
        model: [
            {
                label: Format.tr(I18n.strings, "Neu"),
                info: root.source
            },
            {
                label: Format.tr(I18n.strings, "Vorhanden"),
                info: root.target
            }
        ]

        Row {
            id: side

            required property var modelData

            spacing: Theme.space3

            SectionLabel {
                width: 90
                anchors.verticalCenter: parent.verticalCenter
                text: side.modelData.label
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (side.modelData.info.dir ? Format.tr(I18n.strings, "Ordner") : Format.size(side.modelData.info.size ?? 0)) + "  ·  " + Qt.formatDateTime(new Date(side.modelData.info.mtime ?? 0), "dd.MM.yyyy  HH:mm")
                color: Theme.sub
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBody
                font.features: {
                    "tnum": 1
                }
            }
        }
    }

    Chip {
        label: Format.tr(I18n.strings, "Für alle weiteren Konflikte")
        active: root.forAll
        onClicked: root.forAll = !root.forAll
    }

    Row {
        anchors.right: parent.right
        spacing: Theme.space2

        Button {
            label: Format.tr(I18n.strings, "Überspringen")
            onClicked: root.answer("skip")
        }

        Button {
            label: Format.tr(I18n.strings, "Ersetzen")
            onClicked: root.answer("replace")
        }

        Button {
            label: Format.tr(I18n.strings, "Beide behalten")
            primary: true
            onClicked: root.answer("keep")
        }
    }
}
