.pragma library

// Damped spring, solved analytically for the error x = value - target from absolute local time, so the path is the
// same at any refresh rate. response is the undamped period in seconds; damping is the ratio: below 1 it swings
// through the target a little (Leech's springs), 1 and above use the critically damped solution.
function spring(x0, v0, response, damping, t) {
    var omega = 2 * Math.PI / response;
    if (damping >= 1) {
        var decay1 = Math.exp(-omega * t);
        var slope = v0 + omega * x0;
        return { x: (x0 + slope * t) * decay1, v: (v0 - omega * t * slope) * decay1 };
    }
    var rate = damping * omega;
    var wd = omega * Math.sqrt(1 - damping * damping);
    var decay = Math.exp(-rate * t);
    var c = Math.cos(wd * t), s = Math.sin(wd * t);
    var b = (v0 + rate * x0) / wd;
    return { x: decay * (x0 * c + b * s), v: decay * (v0 * c - (x0 * wd + rate * b) * s) };
}

// Settled when the rest and the next frame's predicted move are both below the visible precision.
function settled(state, precision) {
    return Math.abs(state.x) < precision && Math.abs(state.v) / 60 < precision;
}
