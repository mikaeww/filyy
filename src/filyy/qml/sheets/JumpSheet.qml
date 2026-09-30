pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../controls"
import "../browser"
import "../format.js" as Format

// Jump to any folder by a few letters, ranked by match and how often and recently it was visited.
Sheet {
    id: root

    required property var app
    property bool active: false
    property var results: []
    property int index: 0

    function start() {
        field.text = "";
        results = Jump.search("");
        index = 0;
        active = true;
        field.input.forceActiveFocus();
    }

    function close() {
        active = false;
        if (app.pane)
            app.pane.focusList();
    }

    function take(inNewTab) {
        const hit = results[index];
        close();
        if (!hit)
            return;
        if (inNewTab)
            app.newTab(hit.path);
        else
            app.pane.navigate(hit.path);
    }

    function step(delta) {
        const count = results.length;
        index = count ? (index + delta + count) % count : 0;
    }

    open: active
    cardWidth: 600
    cardTop: Math.round(height * 0.16)
    onDismissed: close()
    onKeyPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && ctrl))
            step(1);
        else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && ctrl))
            step(-1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            take(event.modifiers & (Qt.ControlModifier | Qt.ShiftModifier));
        else
            return;
        event.accepted = true;
    }

    Field {
        id: field

        width: parent.width
        size: Theme.fsTitle
        glyph: Theme.glyph.jump
        placeholder: Format.tr(I18n.strings, "Zu Ordner springen …")
        onTextChanged: {
            root.results = Jump.search(text);
            root.index = 0;
        }
    }

    Column {
        width: parent.width

        Repeater {
            // As many hits as fit below the field, so the card never runs off the window.
            model: root.results.slice(0, Math.max(3, Math.floor((root.height * 0.84 - 200) / Theme.rowH)))

            Rectangle {
                id: hit

                required property var modelData
                required property int index

                width: parent.width
                height: Theme.rowH
                radius: Theme.radiusSmall
                color: Theme.tint(index === root.index, pointer.containsMouse)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.motionFast
                    }
                }

                FileIcon {
                    id: icon

                    x: Theme.space2
                    width: Theme.iconSmall
                    height: Theme.iconSmall
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "folder"
                }

                Text {
                    id: name

                    anchors.left: icon.right
                    anchors.leftMargin: Theme.space2
                    anchors.verticalCenter: parent.verticalCenter
                    text: hit.modelData.name
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBody
                    font.bold: hit.index === root.index
                }

                Text {
                    anchors.left: name.right
                    anchors.leftMargin: Theme.space2
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space2
                    anchors.verticalCenter: parent.verticalCenter
                    text: hit.modelData.parent
                    elide: Text.ElideLeft
                    color: Theme.faint
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall
                }

                MouseArea {
                    id: pointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.index = hit.index;
                        root.take(false);
                    }
                }
            }
        }
    }

    Text {
        text: root.results.length ? Format.tr(I18n.strings, "↑ ↓  Auswählen     Enter  Springen     Strg+Enter  Neuer Tab") : Format.tr(I18n.strings, "Kein passender Ordner")
        color: Theme.faint
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSmall
    }
}
