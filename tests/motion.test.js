// The spring in qml/motion/curves.js against the checks of the clean-project motion contract. node tests/motion.test.js
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const source = fs.readFileSync(path.join(__dirname, "../src/filyy/qml/motion/curves.js"), "utf8");
const { spring, settled } = new Function(source.replace(".pragma library", "") + "; return { spring, settled };")();
const close = (a, b, tolerance, what) => assert.ok(Math.abs(a - b) <= tolerance, `${what}: ${a} vs ${b}`);
// Leech's glide and settle, and the critically damped case.
const curves = [[0.34, 0.82], [0.30, 0.86], [0.34, 1]];

for (const [response, damping] of curves) {
    const at = (x0, v0, t) => spring(x0, v0, response, damping, t);
    const name = `${response}/${damping}`;

    // Start is exact: position and velocity at t = 0 are the ones handed in.
    for (const [x0, v0] of [[36, 0], [-36, 0], [0.5, -400], [0, 250]]) {
        close(at(x0, v0, 0).x, x0, 1e-12, `${name} start x`);
        close(at(x0, v0, 0).v, v0, 1e-9, `${name} start v`);
    }

    // v is the derivative of x (central differences); from rest it swings through at most 2 % of the travel.
    for (let t = 0.001; t < 1; t += 0.01) {
        const h = 1e-6;
        close(at(36, 0, t).v, (at(36, 0, t + h).x - at(36, 0, t - h).x) / (2 * h), 1e-3, `${name} derivative at ${t}`);
        assert.ok(at(36, 0, t).x > -0.02 * 36, `${name} overshoot at ${t}`);
    }

    // The path depends on time only: 60, 120 and 144 Hz land on the same values at the instants they share
    // (every 1/12 s), with frame times derived as exact fractions, never by summing rounded frame durations.
    for (let m = 0; m <= 12; m++) {
        const at60 = at(36, 0, (5 * m) / 60).x;
        assert.strictEqual(at(36, 0, (10 * m) / 120).x, at60);
        assert.strictEqual(at(36, 0, (12 * m) / 144).x, at60);
    }

    // A retarget mid-flight continues from the sampled position and velocity: no jump, no velocity reset.
    const before = at(36, 0, 0.12);
    const oldTarget = 0, newTarget = -20;
    const shown = oldTarget + before.x;
    const after = at(shown - newTarget, before.v, 0);
    close(newTarget + after.x, shown, 1e-12, `${name} retarget position`);
    close(after.v, before.v, 1e-9, `${name} retarget velocity`);

    // A page-sized travel settles within about 1.5 response periods, and the settle test is strict about speed.
    let settle = 0;
    while (!settled(at(36, 0, settle), 0.1))
        settle += 1 / 240;
    assert.ok(settle > 0.2 && settle < 0.55, `${name} settles after ${settle}s`);
    console.log(`motion ${name}: ok, settles after ${settle.toFixed(3)} s`);
}
assert.ok(!settled({ x: 0.01, v: 30 }, 0.1), "a fast crossing is not settled");
