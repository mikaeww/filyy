# Motion

`qml/motion/curves.js` solves a damped spring analytically; `Spring.qml` drives it from the render loop.

## Claims

1. At t = 0 the solution returns exactly the position and velocity it was started with.
2. The velocity is the time derivative of the position.
3. From rest, glide and settle swing through their target by less than 2 % of the travel.
4. The path depends on time only: 60, 120 and 144 Hz sample the same values at shared instants.
5. A retarget continues from the sampled position and velocity, without a jump or a velocity reset.
6. A 36 px travel settles (rest and next-frame move below 0.1 px) within 0.2 to 0.55 s, and then lands exactly on
   the target.

## Oracle and method

The closed-form solution of `ÿ + 2ζω·ẏ + ω²·y = 0` for ζ < 1 and ζ = 1; claims 1 to 6 are checked in
`tests/motion.test.js` for glide (0.34, 0.82), settle (0.30, 0.86) and the critical case, claim 2 by central
differences over 100 samples. Claim 6's exact landing is `Spring.qml` writing the target once it counts as settled.

## Known gaps

Frame pacing on the real display is not measured; reduced motion is checked by reading the code paths only.
