#!/usr/bin/env python3
"""Check the board screen's geometry against a round display.

`Layout.mc` derives every coordinate from the screen size, so one layout has
to serve every round watch in the manifest - a 416px Venu 2 down to a 260px
Venu Sq 2. On a round screen the corners do not exist, and a 9x9 grid is all
corner: its four corners are the furthest points from the centre, and they are
what decides how large a cell can be.

This replays that arithmetic and asserts that

  * the grid's corners stay inside the glass,
  * the action bar - a pill, because a rectangle's corners would not - does
    too, including its rounded ends,
  * the bar and the grid do not overlap,
  * the two status rows above the grid have room for real fonts, at the width
    the circle actually offers at their height.

    python3 tools/check_layout.py
"""
import math
import sys

# The round sizes named in manifest.xml: the largest and smallest, plus the
# two common ones in between.
SIZES = [416, 390, 360, 260]

MARGIN = 3          # px of glass to leave unused at the rim

# Font line heights are device metrics, so the app measures them with
# dc.getFontHeight() and never hard-codes an offset. These are only used here,
# to prove the header band is big enough for fonts of a plausible size - they
# are scaled from the Venu 2's actual metrics.
FONT_XTINY_416 = 21
FONT_TINY_416 = 25

# The longest strings the two header rows ever have to show.
LONGEST_LABEL = "BEGINNER"
LONGEST_CLOCK = "1:04:37"
# Rough advance width per character at each font, again only for this check.
CHAR_W_XTINY_416 = 11.0
CHAR_W_TINY_416 = 13.0


def layout(size):
    """The Python mirror of Layout.initialize(). Integer division throughout,
    to match Monkey C's Number arithmetic exactly."""
    cx = cy = size // 2
    radius = size // 2
    cell = size * 13 // 180
    board = cell * 9
    board_cy = size * 191 // 416
    board_x = cx - board // 2
    board_y = board_cy - board // 2
    ring_r = radius - size * 6 // 416
    bar_h = size * 46 // 416
    bar_w = size * 236 // 416
    bar_x = cx - bar_w // 2
    bar_y = cy + size * 152 // 416 - bar_h // 2
    return {
        "size": size, "cx": cx, "cy": cy, "radius": radius,
        "cell": cell, "board": board, "board_x": board_x, "board_y": board_y,
        "ring_r": ring_r,
        "bar_x": bar_x, "bar_y": bar_y, "bar_w": bar_w, "bar_h": bar_h,
        "zone_w": bar_w // 4,
    }


def dist(L, x, y):
    return math.hypot(x - L["cx"], y - L["cy"])


def chord_half_width(radius, dy):
    d = abs(dy)
    return 0.0 if d >= radius else math.sqrt(radius * radius - d * d)


def check(L, problems):
    size = L["size"]
    limit = L["radius"] - MARGIN

    # --- the grid: a square, so check its four corners ---
    for x in (L["board_x"], L["board_x"] + L["board"]):
        for y in (L["board_y"], L["board_y"] + L["board"]):
            d = dist(L, x, y)
            if d > limit:
                problems.append(
                    "%dpx: grid corner (%d,%d) is %.1fpx outside the glass"
                    % (size, x, y, d - limit))

    # --- the action bar: a pill. Its extreme points are on the end caps, so
    #     the thing to measure is each cap's centre plus its radius. ---
    r = L["bar_h"] / 2.0
    for cxp in (L["bar_x"] + r, L["bar_x"] + L["bar_w"] - r):
        for cyp in (L["bar_y"] + r, L["bar_y"] + L["bar_h"] - r):
            d = dist(L, cxp, cyp) + r
            if d > limit:
                problems.append(
                    "%dpx: action bar cap (%.0f,%.0f) reaches %.1fpx outside the glass"
                    % (size, cxp, cyp, d - limit))

    # --- the ring has to clear the bar and the grid ---
    if L["ring_r"] > limit + MARGIN:
        problems.append("%dpx: completion ring r=%d is off the glass" % (size, L["ring_r"]))

    # --- nothing may overlap ---
    board_bottom = L["board_y"] + L["board"]
    if L["bar_y"] < board_bottom:
        problems.append("%dpx: action bar (y=%d) overlaps the grid (ends y=%d)"
                        % (size, L["bar_y"], board_bottom))

    # --- the header band above the grid ---
    scale = size / 416.0
    label_h = FONT_XTINY_416 * scale
    clock_h = FONT_TINY_416 * scale
    needed = label_h + clock_h + 4 * scale
    if L["board_y"] < needed:
        problems.append("%dpx: only %dpx above the grid, two status rows need %.0fpx"
                        % (size, L["board_y"], needed))
    else:
        # Place the rows the way BoardView does - the block centred in the
        # band - and check each against the chord at its own height.
        top = (L["board_y"] - (label_h + clock_h)) / 2.0
        rows = [
            ("difficulty label", top + label_h / 2.0,
             len(LONGEST_LABEL) * CHAR_W_XTINY_416 * scale),
            ("clock", top + label_h + clock_h / 2.0,
             len(LONGEST_CLOCK) * CHAR_W_TINY_416 * scale),
        ]
        for name, y, need_w in rows:
            have = 2.0 * chord_half_width(L["radius"] - MARGIN, y - L["cy"])
            if have < need_w:
                problems.append(
                    "%dpx: %s at y=%.0f has %.0fpx of width, needs %.0f"
                    % (size, name, y, have, need_w))

    # --- touch targets ---
    if L["zone_w"] < 34 * scale:
        problems.append("%dpx: action-bar zone is only %dpx wide" % (size, L["zone_w"]))
    if L["cell"] < 17 * scale:
        problems.append("%dpx: cells are only %dpx" % (size, L["cell"]))


def main():
    problems = []
    for size in SIZES:
        L = layout(size)
        check(L, problems)
        print("%3dpx: cell %2d  grid %3d at y=%3d..%3d  bar %3dx%2d at y=%3d  zone %2d"
              % (size, L["cell"], L["board"], L["board_y"],
                 L["board_y"] + L["board"], L["bar_w"], L["bar_h"], L["bar_y"],
                 L["zone_w"]))
    if problems:
        print()
        for p in problems:
            print("  " + p)
        sys.exit("%d layout problem(s)" % len(problems))
    print("\nevery screen fits the circle")


if __name__ == "__main__":
    main()
