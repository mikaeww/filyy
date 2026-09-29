.pragma library

// SwiftUI-style springs as {at(phase), ms}, the same maths as the shell's Theme.spring.
function spring(response, damping) {
    var omega = 2 * Math.PI / response
    var decay = damping * omega
    var wd = omega * Math.sqrt(1 - damping * damping)
    var x = function (t) { return 1 - Math.exp(-decay * t) * (Math.cos(wd * t) + (decay / wd) * Math.sin(wd * t)) }
    var duration = 0.05
    while (duration < 3 && Math.abs(1 - x(duration)) + Math.exp(-decay * duration) > 0.002)
        duration += 0.01
    return { at: function (phase) { return phase >= 1 ? 1 : x(phase * duration) }, ms: Math.round(duration * 1000) }
}

var glide = spring(0.34, 0.82)
// The settings' entrance curve and the shell's quick curve for colour feedback.
var enter = [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
var quick = [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]

function fileUrl(p) {
    return "file://" + p.split("/").map(encodeURIComponent).join("/")
}

// Browser-style history: visiting a folder drops everything forward of the current entry.
function visit(state, path) {
    if (state.list[state.index] === path)
        return state
    var list = state.list.slice(0, state.index + 1).concat([path])
    return { list: list, index: list.length - 1 }
}

// Translated text for a German key; {name} placeholders come from values, "one|many" picks by values.n.
function tr(strings, text, values) {
    var out = strings && strings[text] !== undefined ? strings[text] : text
    if (values && out.indexOf("|") >= 0 && values.n !== undefined)
        out = out.split("|")[values.n === 1 ? 0 : 1]
    if (values)
        out = out.replace(/\{(\w+)\}/g, function (all, key) { return values[key] !== undefined ? values[key] : all })
    return out
}

// "vor 5 Min" style relative time for a unix timestamp in seconds.
function ago(strings, seconds) {
    if (!seconds)
        return ""
    var diff = Math.max(0, Date.now() / 1000 - seconds)
    var steps = [[60, "gerade eben", 1], [3600, "vor {n} Min", 60], [86400, "vor {n} Std", 3600],
                 [604800, "vor {n} Tagen", 86400], [2629800, "vor {n} Wochen", 604800],
                 [31557600, "vor {n} Monaten", 2629800], [Infinity, "vor {n} Jahren", 31557600]]
    for (var i = 0; i < steps.length; i++) {
        if (diff < steps[i][0])
            return tr(strings, steps[i][1], { n: Math.floor(diff / steps[i][2]) })
    }
    return ""
}

function escapeHtml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

function size(bytes) {
    var units = ["B", "KB", "MB", "GB", "TB"]
    var unit = 0
    while (bytes >= 1024 && unit < units.length - 1) {
        bytes /= 1024
        unit++
    }
    return (unit === 0 ? bytes : bytes.toFixed(1)) + " " + units[unit]
}

// Every folder from / down to path, for the breadcrumb; home shows as one "Home" step.
function crumbs(path, home) {
    var out = []
    var start = path === home || path.indexOf(home + "/") === 0 ? home : ""
    if (start)
        out.push({ name: "Home", path: home })
    else
        out.push({ name: "/", path: "/" })
    var rest = path.slice(start.length).split("/").filter(function (part) { return part })
    var at = start
    for (var i = 0; i < rest.length; i++) {
        at += "/" + rest[i]
        out.push({ name: rest[i], path: at })
    }
    return out
}

var glyphs = {
    folder: "\u{F024B}", file: "\u{F0214}", image: "\u{F021F}", video: "\u{F022B}", audio: "\u{F0223}",
    archive: "\u{F05C4}", pdf: "\u{F0226}", code: "\u{F022E}", text: "\u{F09EE}",
    home: "\u{F02DC}", desktop: "\u{F01C4}", docs: "\u{F0219}", download: "\u{F01DA}", music: "\u{F075A}",
    movie: "\u{F0381}", braces: "\u{F0169}", drive: "\u{F02CA}", trash: "\u{F0A7A}",
    back: "\u{F004D}", forward: "\u{F0054}", up: "\u{F005D}", chevron: "\u{F0142}",
    list: "\u{F0572}", grid: "\u{F0570}", eye: "\u{F0208}", eyeOff: "\u{F0209}", newFolder: "\u{F0257}",
    search: "\u{F0349}", terminal: "\u{F018D}", copy: "\u{F018F}", cut: "\u{F0190}", paste: "\u{F0192}",
    rename: "\u{F0455}", duplicate: "\u{F0191}", open: "\u{F03CC}", link: "\u{F0337}", close: "\u{F0156}",
    refresh: "\u{F0450}", split: "\u{F0BCC}", tab: "\u{F04E9}", undo: "\u{F054C}", jump: "\u{F0968}",
    git: "\u{F02A2}", branch: "\u{F062C}", commit: "\u{F0718}", usage: "\u{F0E94}", pause: "\u{F03E4}",
    play: "\u{F040A}", cancel: "\u{F073A}", restore: "\u{F099B}", grave: "\u{F0BA2}", apps: "\u{F003B}",
    textSearch: "\u{F13B8}", extract: "\u{F03D4}", preview: "\u{F06D0}", batch: "\u{F060E}", settings: "\u{F08BB}"
}

// Place icons use their own names so "image" can differ between a file and the Bilder folder.
var placeGlyphs = {
    home: glyphs.home, desktop: glyphs.desktop, docs: glyphs.docs, download: glyphs.download,
    image: "\u{F02E9}", music: glyphs.music, video: glyphs.movie, code: glyphs.braces,
    drive: glyphs.drive, trash: glyphs.trash
}
