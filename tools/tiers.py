#!/usr/bin/env python3
"""The tier table, mirrored from source/Difficulty.mc.

`tools/check_constants.py` parses the Monkey C and compares it against this,
so the two cannot drift apart without `tools/verify.sh` failing.
"""

NAMES = ["BEGINNER", "EASY", "MEDIUM", "HARD", "EXPERT"]

# How many givens the player starts with. 0 means "leave the puzzle minimal".
TARGET_CLUES = [44, 34, 28, 30, 0]

# Whether the finished puzzle must defeat naked and hidden singles.
NEEDS_ADVANCED = [False, False, False, True, True]


def tier(index):
    return {
        "name": NAMES[index],
        "target_clues": TARGET_CLUES[index],
        "needs_advanced": NEEDS_ADVANCED[index],
    }


def all_tiers():
    return [tier(i) for i in range(len(NAMES))]
