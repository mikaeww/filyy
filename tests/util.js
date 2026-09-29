const fs = require("fs")
eval(fs.readFileSync(__dirname + "/../qml/Util.js", "utf8").replace(".pragma library", ""))
const assert = require("assert")

let h = { list: ["/a"], index: 0 }
h = visit(visit(h, "/b"), "/c")
assert.deepStrictEqual(h, { list: ["/a", "/b", "/c"], index: 2 })
// Revisiting the current folder is a no-op, a visit after going back cuts the forward part.
assert.strictEqual(visit(h, "/c"), h)
assert.deepStrictEqual(visit({ list: h.list, index: 0 }, "/d"), { list: ["/a", "/d"], index: 1 })

assert.deepStrictEqual(crumbs("/home/m/Bilder/x", "/home/m").map(c => c.name), ["Home", "Bilder", "x"])
assert.deepStrictEqual(crumbs("/home/mika2", "/home/m").map(c => c.path), ["/", "/home", "/home/mika2"])
assert.deepStrictEqual(crumbs("/", "/home/m").map(c => c.name), ["/"])

assert.strictEqual(size(512), "512 B")
assert.strictEqual(size(1536), "1.5 KB")
assert.strictEqual(spring(0.34, 0.82).at(1), 1)
console.log("ok")
