#!/usr/bin/env python3
"""Check that tools/tiers.py still says what source/Difficulty.mc says.

The difficulty claims this project makes - "a Medium puzzle can be finished by
scanning", "a Hard one cannot" - are proved by tools/check_generator.py, which
runs against the Python mirror. That proof is worth exactly nothing if the
mirror and the shipped table have drifted apart, and they drift the moment
somebody tunes one file and forgets the other.

    python3 tools/check_constants.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tiers

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "source", "Difficulty.mc")


def array_of(text, name):
    """The contents of `const NAME = [ ... ];` as a list of tokens."""
    m = re.search(r"const\s+%s\s*=\s*\[(.*?)\]\s*;" % name, text, re.S)
    if not m:
        sys.exit("could not find %s in %s" % (name, SOURCE))
    return [t.strip() for t in m.group(1).split(",") if t.strip()]


def main():
    with open(SOURCE) as fh:
        text = fh.read()

    problems = []

    names = [t.strip('"') for t in array_of(text, "NAMES")]
    if names != tiers.NAMES:
        problems.append("NAMES: %s in Monkey C, %s in tiers.py" % (names, tiers.NAMES))

    clues = [int(t) for t in array_of(text, "TARGET_CLUES")]
    if clues != tiers.TARGET_CLUES:
        problems.append("TARGET_CLUES: %s in Monkey C, %s in tiers.py"
                        % (clues, tiers.TARGET_CLUES))

    advanced = [t == "true" for t in array_of(text, "NEEDS_ADVANCED")]
    if advanced != tiers.NEEDS_ADVANCED:
        problems.append("NEEDS_ADVANCED: %s in Monkey C, %s in tiers.py"
                        % (advanced, tiers.NEEDS_ADVANCED))

    count = re.search(r"const\s+COUNT\s*=\s*(\d+)\s*;", text)
    if count and int(count.group(1)) != len(tiers.NAMES):
        problems.append("COUNT is %s but there are %d tiers"
                        % (count.group(1), len(tiers.NAMES)))

    lengths = {len(names), len(clues), len(advanced)}
    if len(lengths) != 1:
        problems.append("the three tier arrays are different lengths: %s" % sorted(lengths))

    # The ladder only means something if it descends. Beginner through Medium
    # hold the technique and take clues away; Hard and Expert do the same one
    # rung down. A table that breaks this would compile and would quietly ship
    # an "Easy" harder than its "Medium".
    scanning = [c for c, adv in zip(clues, advanced) if not adv]
    if scanning != sorted(scanning, reverse=True):
        problems.append("the scanning-only tiers do not lose clues in order: %s" % scanning)

    if problems:
        for p in problems:
            print("  " + p)
        sys.exit("%d constant(s) out of sync" % len(problems))

    for i, name in enumerate(names):
        print("%-9s %s clues, %s" % (
            name,
            clues[i] or "minimal",
            "needs deduction" if advanced[i] else "scanning only"))
    print("\nDifficulty.mc and tiers.py agree")


if __name__ == "__main__":
    main()
