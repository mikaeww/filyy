.pragma library

// Words and numbers as the interface shows them: translation, relative time, sizes, escaped rich text.

// Translated text for a German key; {name} placeholders come from values, "one|many" picks by values.n.
function tr(strings, text, values) {
    if (text === undefined || text === null)
        return "";
    var out = strings && strings[text] !== undefined ? strings[text] : text;
    if (values && out.indexOf("|") >= 0 && values.n !== undefined)
        out = out.split("|")[values.n === 1 ? 0 : 1];
    if (values)
        out = out.replace(/\{(\w+)\}/g, function (all, key) {
            return values[key] !== undefined ? values[key] : all;
        });
    return out;
}

// "vor 5 Min" style relative time for a unix timestamp in seconds.
function ago(strings, seconds) {
    if (!seconds)
        return "";
    var diff = Math.max(0, Date.now() / 1000 - seconds);
    var steps = [[60, "gerade eben", 1], [3600, "vor {n} Min", 60], [86400, "vor {n} Std", 3600],
                 [604800, "vor {n} Tagen", 86400], [2629800, "vor {n} Wochen", 604800],
                 [31557600, "vor {n} Monaten", 2629800], [Infinity, "vor {n} Jahren", 31557600]];
    for (var i = 0; i < steps.length; i++) {
        if (diff < steps[i][0])
            return tr(strings, steps[i][1], { n: Math.floor(diff / steps[i][2]) });
    }
    return "";
}

function escapeHtml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function size(bytes) {
    var units = ["B", "KB", "MB", "GB", "TB"];
    var unit = 0;
    while (bytes >= 1024 && unit < units.length - 1) {
        bytes /= 1024;
        unit++;
    }
    return (unit === 0 ? bytes : bytes.toFixed(1)) + " " + units[unit];
}
