# 0002: Calendary's grey tokens, Leech's springs, colour only in file icons

**Status:** accepted
**Date:** 2026-09-30

## Context
Filyy took colours, radii and hairlines live from the Ghostly QShell. The owner's other apps (Calendary, Fold,
Rewa) moved to one calm grey look with Leech's motion, and asked Filyy to match.

## Options
- Keep the live shell theme.
- Calendary's tokens in `qml/theme/Theme.qml`, the shell only for fonts, terminal and reduced motion.

## Decision
Calendary's tokens, dark and light, default from the system, choice saved in the settings. The shell still names
the UI and mono font, the terminal and reduced motion (`desktop.py`), read once at start. Motion uses Leech's two
springs: glide (response 0.34 s, damping 0.82) and settle (0.30 s, 0.86), plus a 140 ms colour transition. Hue is
allowed only in content: the pixel file icons, tombstones and thumbnails tell file types and files apart, the way
thumbnails do. They stay at whole multiples of their 16 px grid, which makes a list icon (16 px) larger than its
12 px label.

## Consequences
- Changing the shell's theme no longer recolours Filyy; changing its font does after a restart.
- Code in quick look is highlighted by weight and brightness only; destructive actions are bold, not red.
- The ghostly-qshell look and its accent colour are gone from Filyy, including the git card's warning colour.
