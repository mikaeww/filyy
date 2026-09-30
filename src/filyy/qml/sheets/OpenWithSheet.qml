pragma ComponentBehavior: Bound

import QtQuick
import Filyy
import "../theme"
import "../controls"
import "../paths.js" as Paths
import "../format.js" as Format

// Pick an app for one file: its own handlers first, every installed app once you type; optionally remembered as
// the default for the file type.
Sheet {
    id: root

    required property var app
    property string file: ""
    property var handlers: []
    property var apps: []
    property int index: 0
    property bool remember: false

    function start(path) {
        file = path;
        handlers = Apps.forFile(path);
        field.text = "";
        apps = handlers;
        index = 0;
        remember = false;
        field.input.forceActiveFocus();
    }

    function filter(query) {
        const needle = query.trim().toLowerCase();
        if (!needle) {
            apps = handlers;
        } else {
            const own = handlers.filter(app => app.name.toLowerCase().includes(needle));
            const ids = own.map(app => app.id);
            apps = own.concat(Apps.everything().filter(app => !ids.includes(app.id) && app.name.toLowerCase().includes(needle)));
        }
        index = 0;
    }

    function launch(at) {
        const chosen = apps[at];
        if (chosen)
            Apps.launch(chosen.id, chosen.path, file, remember);
        close();
    }

    function close() {
        file = "";
        if (app.pane)
            app.pane.focusList();
    }

    open: file !== ""
    cardWidth: 520
    onDismissed: close()
    onAccepted: launch(index)
    onKeyPressed: event => {
        const count = apps.length;
        if (event.key === Qt.Key_Down)
            index = count ? (index + 1) % count : 0;
        else if (event.key === Qt.Key_Up)
            index = count ? (index + count - 1) % count : 0;
        else
            return;
        event.accepted = true;
    }

    Title {
        width: parent.width
        elide: Text.ElideMiddle
        wrapMode: Text.NoWrap
        text: Format.tr(I18n.strings, "„{file}“ öffnen mit", {
            file: Paths.baseName(root.file)
        })
    }

    Field {
        id: field

        width: parent.width
        glyph: Theme.glyph.search
        placeholder: Format.tr(I18n.strings, "App suchen …")
        onTextChanged: root.filter(text)
    }

    ListView {
        id: list

        width: parent.width
        height: Math.min(8, Math.max(1, count)) * Theme.rowH
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.apps
        currentIndex: root.index
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index

            width: list.width
            height: Theme.rowH
            radius: Theme.radiusSmall
            color: Theme.tint(index === root.index, pointer.containsMouse)

            Image {
                id: icon

                x: Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSmall
                height: Theme.iconSmall
                source: row.modelData.icon ? "image://appicon/" + row.modelData.icon : ""
                sourceSize: Qt.size(2 * width, 2 * height)
            }

            Text {
                anchors.left: icon.right
                anchors.leftMargin: Theme.space2
                anchors.right: badge.left
                anchors.rightMargin: Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.name
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBody
            }

            Text {
                id: badge

                anchors.right: parent.right
                anchors.rightMargin: Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.default ? Format.tr(I18n.strings, "Standard") : ""
                color: Theme.faint
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
            }

            MouseArea {
                id: pointer

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launch(row.index)
            }
        }
    }

    Text {
        visible: root.apps.length === 0
        text: Format.tr(I18n.strings, "Keine passende App gefunden")
        color: Theme.sub
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBody
    }

    Chip {
        label: Format.tr(I18n.strings, "Als Standard für diesen Dateityp merken")
        active: root.remember
        onClicked: root.remember = !root.remember
    }
}
