#!/usr/bin/env python3
"""Draw the Sudoku launcher icon - a 3x3 grid with one square lit.

Rasterised from stdlib-only shape tests in a 60x60 design space with 4x
supersampling, at whatever pixel size a device's launcher slot needs. No
imaging library, so it runs anywhere the build runs and the icon is never a
binary blob nobody can regenerate.

The icon deliberately shows a 3x3 grid rather than a 9x9 one: at 36px, which
is what several launchers actually use, nine columns of lines turn into grey
mush, while three read as a Sudoku box at any size.

    python3 tools/make_icon.py resources/drawables/launcher_icon.png 96
"""
import struct
import sys
import zlib

DESIGN = 60.0
SS = 4

BG = (0x0D, 0x0D, 0x0F, 255)
RING = (0x00, 0x6C, 0xA8, 255)
LINE = (0xC8, 0xD2, 0xDC, 255)
LIT = (0x00, 0xAA, 0xFF, 255)
CLEAR = (0, 0, 0, 0)

CX = CY = 30.0
BOARD = 34.0                       # side of the grid
B0 = CX - BOARD / 2                # its left/top edge
STEP = BOARD / 3.0
HALF_LINE = 1.05


def in_disc(px, py, cx, cy, r):
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def in_ring(px, py, cx, cy, r0, r1):
    d2 = (px - cx) ** 2 + (py - cy) ** 2
    return r0 * r0 <= d2 <= r1 * r1


def in_box(px, py, x0, y0, x1, y1):
    return x0 <= px <= x1 and y0 <= py <= y1


def on_grid_line(px, py):
    """Any of the four verticals or four horizontals bounding the 3x3."""
    if not in_box(px, py, B0 - HALF_LINE, B0 - HALF_LINE,
                  B0 + BOARD + HALF_LINE, B0 + BOARD + HALF_LINE):
        return False
    for k in range(4):
        edge = B0 + k * STEP
        if abs(px - edge) <= HALF_LINE or abs(py - edge) <= HALF_LINE:
            return True
    return False


def sample(px, py):
    colour = CLEAR
    if in_disc(px, py, CX, CY, 29.0):
        colour = BG
    if in_ring(px, py, CX, CY, 26.5, 29.0):
        colour = RING

    # One square lit, middle row and right column - off-centre so the icon
    # has a direction to it instead of reading as a target.
    cell_x = B0 + 2 * STEP
    cell_y = B0 + STEP
    if in_box(px, py, cell_x + HALF_LINE, cell_y + HALF_LINE,
              cell_x + STEP - HALF_LINE, cell_y + STEP - HALF_LINE):
        colour = LIT

    if on_grid_line(px, py):
        colour = LINE

    return colour


def render(size):
    scale = DESIGN / size
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            r = g = b = a = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    px = (x + (sx + 0.5) / SS) * scale
                    py = (y + (sy + 0.5) / SS) * scale
                    sr, sg, sb, sa = sample(px, py)
                    weight = sa / 255.0
                    r += sr * weight
                    g += sg * weight
                    b += sb * weight
                    a += weight
            n = float(SS * SS)
            alpha = a / n
            if alpha > 0.0001:
                row += bytes((
                    min(255, int(round(r / n / alpha))),
                    min(255, int(round(g / n / alpha))),
                    min(255, int(round(b / n / alpha))),
                    int(round(alpha * 255)),
                ))
            else:
                row += bytes((0, 0, 0, 0))
        rows.append(bytes(row))
    return rows


def write_png(path, rows, size):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: make_icon.py <output.png> <size>")
    path = sys.argv[1]
    size = int(sys.argv[2])
    write_png(path, render(size), size)
    print("wrote %s (%dx%d)" % (path, size, size))


if __name__ == "__main__":
    main()
