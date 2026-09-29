#!/usr/bin/env python3
"""Draws every pixel graphic Filyy ships: the ghost app icon and the file type icons.

  python3 tools/pixelart.py      writes assets/filyy.svg, assets/ghost/*.svg and assets/icons/*.svg
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

PALETTE = {
    "O": "#2b2140",  # outline, eyes
    "G": "#f5f2ff",  # ghost / paper
    "g": "#d6ccf2",  # ghost / paper shade
    "W": "#ffffff",  # eye shine
    "K": "#ff9ec7",  # blush
    "T": "#ff7aa8",  # tongue, play button
    "Y": "#ffcf5c",  # folder
    "y": "#eea23a",  # folder shade and tab
    "L": "#ffe7a3",  # folder light
    "D": "#9d93b8",  # text lines
    "N": "#3b3355",  # screens
    "C": "#7bd88f",  # terminal green, hills
    "B": "#7ec8ff",  # sky
    "V": "#b79cff",  # music
    "R": "#ff6b6b",  # pdf band
    "Z": "#d9a46c",  # archive
}


def svg(grid):
    size = len(grid)
    rects = []
    for y, row in enumerate(grid):
        x = 0
        while x < len(row):
            ch = row[x]
            if ch == ".":
                x += 1
                continue
            start = x
            while x < len(row) and row[x] == ch:
                x += 1
            rects.append(f'<rect x="{start}" y="{y}" width="{x - start}" height="1" fill="{PALETTE[ch]}"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" shape-rendering="crispEdges">\n  '
            + "\n  ".join(rects) + "\n</svg>\n")


def paint(grid, cells, ch):
    for x, y in cells:
        grid[y][x] = ch


def ghost(eyes="open", look=0, mood="happy", lift=0):
    """32×32 ghost holding a folder; eyes open/closed/sad, look shifts them sideways, lift raises the folder."""
    size = 32
    g = [["."] * size for _ in range(size)]

    def body(x, y):
        if y <= 11:
            return (x - 15.5) ** 2 + (y - 11.5) ** 2 <= 9.6 ** 2
        return 6 <= x <= 25 and y <= 27 + [0, 1, 2, 1, 0][(x - 6) % 5]

    for y in range(size):
        for x in range(size):
            if body(x, y):
                edge = any(not body(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                g[y][x] = "O" if edge else "G"
    for y in range(size):
        for x in range(20, 26):
            if g[y][x] == "G" and "O" in (g[y][x + 1], g[y][x + 2]):
                g[y][x] = "g"
    for x0 in (11 + look, 19 + look):
        if eyes == "closed":
            paint(g, [(x0, 10), (x0 + 1, 10)], "O")
        elif eyes == "sad":
            paint(g, [(x, y) for x in range(x0, x0 + 2) for y in range(9, 12)], "O")
            g[9][x0] = "W"
        else:
            paint(g, [(x, y) for x in range(x0, x0 + 2) for y in range(8, 12)], "O")
            g[8][x0] = "W"
    if mood == "sad":
        paint(g, [(15, 13), (16, 13), (14, 14), (17, 14)], "O")
        paint(g, [(10, 12), (10, 13)], "B")
    else:
        paint(g, [(9, 12), (10, 12), (21, 12), (22, 12)], "K")
        paint(g, [(15, 13), (16, 13)], "O")
        paint(g, [(15, 14), (16, 14)], "T")
    # the folder, its tab on the left, the shaded bottom row; lift moves it and the hands up
    top = 16 - lift
    paint(g, [(x, y) for x in range(9, 23) for y in range(top + 1, top + 10)], "Y")
    paint(g, [(x, top) for x in range(9, 15)], "O")
    paint(g, [(x, top + 1) for x in range(15, 23)] + [(9, top + 1), (14, top + 1)], "O")
    paint(g, [(x, top + 1) for x in range(10, 14)], "y")
    paint(g, [(9, y) for y in range(top + 2, top + 10)] + [(22, y) for y in range(top + 2, top + 10)], "O")
    paint(g, [(x, top + 2) for x in range(10, 22)], "L")
    paint(g, [(x, top + 8) for x in range(10, 22)], "y")
    paint(g, [(x, top + 9) for x in range(9, 23)], "O")
    for x0 in (7, 21):
        hy = top + 4
        paint(g, [(x0 + 1, hy), (x0 + 2, hy), (x0 + 1, hy + 3), (x0 + 2, hy + 3), (x0, hy + 1), (x0, hy + 2), (x0 + 3, hy + 1), (x0 + 3, hy + 2)], "O")
        paint(g, [(x0 + 1, hy + 1), (x0 + 2, hy + 1), (x0 + 1, hy + 2), (x0 + 2, hy + 2)], "G")
    return g


GHOSTS = {
    "idle": ghost(),
    "blink": ghost(eyes="closed"),
    "look-left": ghost(look=-1),
    "look-right": ghost(look=1),
    "sad": ghost(eyes="sad", mood="sad"),
    "busy-left": ghost(look=-1, lift=2),
    "busy-right": ghost(look=1, lift=2),
}


DOC = [
    "................",
    "...OOOOOOOO.....",
    "...OGGGGGGOO....",
    "...OGGGGGGOGO...",
    "...OGGGGGGOOOO..",
    "...OGGGGGGGGGO..",
    "...OGGGGGGGGGO..",
    "...OGGGGGGGGGO..",
    "...OGGGGGGGGGO..",
    "...OGGGGGGGGGO..",
    "...OGGGGGGGGGO..",
    "...OGGGGGGGGGO..",
    "...OGGGGGGGGGO..",
    "...OgggggggggO..",
    "...OOOOOOOOOOO..",
    "................",
]

FOLDER = [
    "................",
    "................",
    ".OOOOO..........",
    "OyyyyyO.........",
    "OyyyyyyOOOOOOOO.",
    "OyyyyyyyyyyyyyyO",
    "OOOOOOOOOOOOOOOO",
    "OLLLLLLLLLLLLLLO",
    "OYYYYYYYYYYYYYYO",
    "OYYYYYYYYYYYYYYO",
    "OYYYYYYYYYYYYYYO",
    "OYYYYYYYYYYYYYYO",
    "OyyyyyyyyyyyyyyO",
    ".OOOOOOOOOOOOOO.",
    "................",
    "................",
]


def doc(overlay=None, fill=None):
    g = [list(row) for row in DOC]
    if fill:
        for y, row in enumerate(g):
            for x, ch in enumerate(row):
                if ch in "Gg":
                    g[y][x] = fill
    if overlay:
        overlay(g)
    return g


def text(g):
    for y, end in ((6, 12), (8, 11), (10, 12), (12, 10)):
        paint(g, [(x, y) for x in range(5, end)], "D")


def code(g):
    paint(g, [(x, y) for x in range(5, 12) for y in range(6, 12)], "N")
    paint(g, [(6, 7), (7, 8), (6, 9)], "C")
    paint(g, [(8, 10), (9, 10), (10, 10)], "C")


def image(g):
    paint(g, [(x, y) for x in range(5, 12) for y in range(6, 12)], "B")
    paint(g, [(10, 7), (9, 7), (10, 6)], "Y")
    paint(g, [(6, 9), (7, 9), (8, 9)] + [(x, y) for x in range(5, 12) for y in (10, 11)], "C")


def video(g):
    paint(g, [(x, y) for x in range(5, 12) for y in range(6, 13)], "N")
    paint(g, [(7, 7), (7, 8), (8, 8), (7, 9), (8, 9), (9, 9), (7, 10), (8, 10), (7, 11)], "T")
    paint(g, [(5, 6), (5, 8), (5, 10), (5, 12), (11, 6), (11, 8), (11, 10), (11, 12)], "g")


def audio(g):
    paint(g, [(9, y) for y in range(6, 11)] + [(10, 6), (10, 7), (11, 7)], "V")
    paint(g, [(7, 10), (8, 10), (7, 11), (8, 11), (6, 11), (9, 11)], "V")


def pdf(g):
    text(g)
    paint(g, [(x, y) for x in range(4, 13) for y in (9, 10, 11)], "R")


def archive(g):
    for y in range(1, 9):
        g[y][8] = "O" if y % 2 else "G"
    paint(g, [(7, 9), (8, 9), (9, 9), (7, 10), (9, 10), (7, 11), (8, 11), (9, 11)], "O")
    g[10][8] = "G"


ICONS = {
    "folder": [list(row) for row in FOLDER],
    "file": doc(),
    "text": doc(text),
    "code": doc(code),
    "image": doc(image),
    "video": doc(video),
    "audio": doc(audio),
    "pdf": doc(pdf),
    "archive": doc(archive, fill="Z"),
}


def main():
    (ROOT / "assets/filyy.svg").write_text(svg(ghost()))
    (ROOT / "assets/ghost").mkdir(parents=True, exist_ok=True)
    for name, grid in GHOSTS.items():
        (ROOT / f"assets/ghost/{name}.svg").write_text(svg(grid))
    out = ROOT / "assets/icons"
    out.mkdir(parents=True, exist_ok=True)
    for name, grid in ICONS.items():
        assert all(len(row) == 16 for row in grid) and len(grid) == 16, name
        (out / f"{name}.svg").write_text(svg(grid))
    print(f"wrote filyy.svg, {len(GHOSTS)} ghost frames and {len(ICONS)} icons")


if __name__ == "__main__":
    main()
