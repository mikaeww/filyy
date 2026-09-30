// History, breadcrumb and size formatting from qml/paths.js and qml/format.js. node tests/paths.test.js
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const load = (name, names) => new Function(fs.readFileSync(path.join(__dirname, "../src/filyy/qml", name), "utf8")
    .replace(".pragma library", "") + "; return {" + names + "};")();
const { visit, crumbs, parentOf } = load("paths.js", "visit, crumbs, parentOf");
const { tr, size } = load("format.js", "tr, size");

let h = { list: ["/a"], index: 0 };
h = visit(visit(h, "/b"), "/c");
assert.deepStrictEqual(h, { list: ["/a", "/b", "/c"], index: 2 });
// Revisiting the current folder is a no-op, a visit after going back cuts the forward part.
assert.strictEqual(visit(h, "/c"), h);
assert.deepStrictEqual(visit({ list: h.list, index: 0 }, "/d"), { list: ["/a", "/d"], index: 1 });

assert.deepStrictEqual(crumbs("/home/m/Bilder/x", "/home/m").map(c => c.name), ["Home", "Bilder", "x"]);
assert.deepStrictEqual(crumbs("/home/mika2", "/home/m").map(c => c.path), ["/", "/home", "/home/mika2"]);
assert.deepStrictEqual(crumbs("/", "/home/m").map(c => c.name), ["/"]);
assert.strictEqual(parentOf("/a"), "/");
assert.strictEqual(parentOf("/a/b"), "/a");

assert.strictEqual(size(512), "512 B");
assert.strictEqual(size(1536), "1.5 KB");
assert.strictEqual(tr({ "{n} Ordner": "{n} folder|{n} folders" }, "{n} Ordner", { n: 3 }), "3 folders");
assert.strictEqual(tr({}, "{n} Ordner", { n: 1 }), "1 Ordner");
console.log("paths: ok");
