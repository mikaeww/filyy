pragma Singleton
import QtQuick
import Filyy

// Every colour, radius, size and duration of the interface; Calendary's values (ADR 0002). Components use these
// tokens and nothing else.
QtObject {
    id: theme

    // "system", "dark" or "light"; saved in the preferences.
    property string mode: Prefs.get("theme", "system")
    // The linter types Qt.styleHints as QObject; QStyleHints.colorScheme exists at runtime since Qt 6.5.
    readonly property bool dark: mode === "dark" || (mode === "system" && Qt.styleHints.colorScheme !== Qt.ColorScheme.Light) // qmllint disable missing-property

    // Neutral grey only, R = G = B. raise1..3 are equal brightness steps away from bg.
    readonly property color bg: dark ? "#111111" : "#f6f6f6"
    readonly property color raise1: dark ? "#1b1b1b" : "#ececec"
    readonly property color raise2: dark ? "#262626" : "#e1e1e1"
    readonly property color raise3: dark ? "#313131" : "#d5d5d5"
    readonly property color fg: dark ? "#ececec" : "#161616"
    readonly property color sub: dark ? "#a3a3a3" : "#575757"
    readonly property color faint: dark ? "#6f6f6f" : "#8b8b8b"
    readonly property color chipOn: fg
    readonly property color chipOnFg: bg
    readonly property color scrim: Qt.rgba(bg.r, bg.g, bg.b, 0.72)

    readonly property int radius: 12
    readonly property int radiusSmall: 8
    // Thin bars (storage map, job progress) get a hint of rounding; half their height would make them pills.
    readonly property int radiusBar: 2

    readonly property int fsMicro: 10
    readonly property int fsSmall: 11
    readonly property int fsBody: 12
    readonly property int fsTitle: 14
    readonly property int fsHead: 17
    readonly property int fsDisplay: 24

    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 16
    readonly property int space5: 24
    readonly property int pad: space3
    readonly property int ctlH: 26

    // File icons are pixel art on a 16 px grid and only stay crisp at whole multiples of it.
    readonly property int iconSmall: 16
    readonly property int iconLarge: 48
    readonly property int rowH: iconSmall + 2 * space2
    readonly property int sidebarWidth: 248
    // Hyprland tiles and groups ignore minimumWidth, so the layout folds below this instead.
    readonly property int compactWidth: 980

    readonly property string fontUi: Prefs.fontUi
    readonly property string fontMono: Prefs.fontMono
    readonly property string iconFont: "Monofur Nerd Font"
    // Material Design Icons code points from the Nerd Font.
    readonly property var glyph: ({
            folder: "\u{F024B}",
            home: "\u{F02DC}",
            desktop: "\u{F01C4}",
            docs: "\u{F0219}",
            download: "\u{F01DA}",
            image: "\u{F02E9}",
            music: "\u{F075A}",
            video: "\u{F0381}",
            code: "\u{F0169}",
            drive: "\u{F02CA}",
            trash: "\u{F0A7A}",
            back: "\u{F0141}",
            forward: "\u{F0142}",
            chevron: "\u{F0142}",
            list: "\u{F0572}",
            grid: "\u{F0570}",
            usage: "\u{F0E94}",
            eye: "\u{F0208}",
            eyeOff: "\u{F0209}",
            newFolder: "\u{F0257}",
            search: "\u{F0349}",
            terminal: "\u{F018D}",
            copy: "\u{F018F}",
            cut: "\u{F0190}",
            paste: "\u{F0192}",
            rename: "\u{F0455}",
            duplicate: "\u{F0191}",
            open: "\u{F03CC}",
            link: "\u{F0337}",
            close: "\u{F0156}",
            refresh: "\u{F0450}",
            split: "\u{F0BCC}",
            tab: "\u{F04E9}",
            undo: "\u{F054C}",
            jump: "\u{F0968}",
            git: "\u{F02A2}",
            branch: "\u{F062C}",
            pause: "\u{F03E4}",
            play: "\u{F040A}",
            cancel: "\u{F073A}",
            restore: "\u{F099B}",
            apps: "\u{F003B}",
            textSearch: "\u{F13B8}",
            extract: "\u{F03D4}",
            preview: "\u{F06D0}",
            batch: "\u{F060E}",
            settings: "\u{F08BB}"
        })

    readonly property bool reducedMotion: Prefs.reducedMotion
    readonly property int motionFast: reducedMotion ? 0 : 140
    // Leech's two springs: glide for things that travel (pills, pages), settle for things that appear.
    readonly property var glide: ({
            response: 0.34,
            damping: 0.82
        })
    readonly property var settle: ({
            response: 0.30,
            damping: 0.86
        })

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // Rows and tiles: picked is the third step, hover or the keyboard cursor the second.
    function tint(picked, hot) {
        return picked ? raise3 : hot ? raise2 : "transparent";
    }

    function setMode(next) {
        mode = next;
        Prefs.set("theme", next);
    }
}
