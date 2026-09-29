#!/usr/bin/env python3
"""Draws every pixel graphic Filyy ships: the ghost app icon and the file type icons.

  python3 tools/pixelart.py      writes assets/filyy.svg and assets/icons/*.svg
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


def ghost():
    """32×32 ghost holding a folder."""
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
    for x0 in (11, 19):
        paint(g, [(x, y) for x in range(x0, x0 + 2) for y in range(8, 12)], "O")
        g[8][x0] = "W"
    paint(g, [(9, 12), (10, 12), (21, 12), (22, 12)], "K")
    paint(g, [(15, 13), (16, 13)], "O")
    paint(g, [(15, 14), (16, 14)], "T")
    # the folder, its tab on the left, the shaded bottom row
    paint(g, [(x, y) for x in range(9, 23) for y in range(17, 26)], "Y")
    paint(g, [(x, 16) for x in range(9, 15)], "O")
    paint(g, [(x, 17) for x in range(15, 23)] + [(9, 17), (14, 17)], "O")
    paint(g, [(x, 17) for x in range(10, 14)], "y")
    paint(g, [(9, y) for y in range(18, 26)] + [(22, y) for y in range(18, 26)], "O")
    paint(g, [(x, 18) for x in range(10, 22)], "L")
    paint(g, [(x, 24) for x in range(10, 22)], "y")
    paint(g, [(x, 25) for x in range(9, 23)], "O")
    # hands gripping both sides
    for x0 in (7, 21):
        paint(g, [(x0 + 1, 20), (x0 + 2, 20), (x0 + 1, 23), (x0 + 2, 23), (x0, 21), (x0, 22), (x0 + 3, 21), (x0 + 3, 22)], "O")
        paint(g, [(x0 + 1, 21), (x0 + 2, 21), (x0 + 1, 22), (x0 + 2, 22)], "G")
    return g


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
    out = ROOT / "assets/icons"
    out.mkdir(parents=True, exist_ok=True)
    for name, grid in ICONS.items():
        assert all(len(row) == 16 for row in grid) and len(grid) == 16, name
        (out / f"{name}.svg").write_text(svg(grid))
    print(f"wrote filyy.svg and {len(ICONS)} icons")


if __name__ == "__main__":
    main()
