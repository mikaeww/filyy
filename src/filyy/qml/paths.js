.pragma library

// Paths as the browser walks them: file URLs, back/forward history and the breadcrumb.

function fileUrl(p) {
    return "file://" + p.split("/").map(encodeURIComponent).join("/");
}

function baseName(p) {
    return p.slice(p.lastIndexOf("/") + 1);
}

function parentOf(p) {
    return p.slice(0, p.lastIndexOf("/")) || "/";
}

// Browser-style history: visiting a folder drops everything forward of the current entry.
function visit(state, path) {
    if (state.list[state.index] === path)
        return state;
    var list = state.list.slice(0, state.index + 1).concat([path]);
    return { list: list, index: list.length - 1 };
}

// Every folder from / down to path, for the breadcrumb; home shows as one "Home" step.
function crumbs(path, home) {
    var out = [];
    var start = path === home || path.indexOf(home + "/") === 0 ? home : "";
    if (start)
        out.push({ name: "Home", path: home });
    else
        out.push({ name: "/", path: "/" });
    var rest = path.slice(start.length).split("/").filter(function (part) {
        return part;
    });
    var at = start;
    for (var i = 0; i < rest.length; i++) {
        at += "/" + rest[i];
        out.push({ name: rest[i], path: at });
    }
    return out;
}
