#!/usr/bin/env python3
"""Prove the difficulty ladder is real.

The app advertises five tiers. Two of those claims are substantive and neither
is obvious from reading the code:

  * Beginner, Easy and Medium can be finished by scanning alone - naked and
    hidden singles, no guessing, no pencil-and-paper technique beyond what a
    newspaper solver uses.
  * Hard and Expert cannot. Scanning provably stalls, and finishing needs
    locked candidates, subsets, or more.

The watch can only ask the first question: `Logic.solvableBySingles` is all
that ships, because that is all the generator needs. The *second* claim - that
what is left over genuinely requires stronger technique - is checked here,
where the full rater from sudoku_ref.py can run the locked-candidate and
subset solvers over a real sample without costing a player any battery.

Every puzzle is also checked for the thing that would make it not a puzzle at
all: exactly one solution, and clues that agree with it.

    python3 tools/check_generator.py            # the fast sample used by CI
    python3 tools/check_generator.py -n 25      # a deeper run
"""
import argparse
import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sudoku_ref as S
import tiers

# The lowest clue count any uniquely-solvable Sudoku can have. Proved
# exhaustively by McGuire, Tugemann and Civario in 2012; a generator that
# claims to have beaten it has a bug in its uniqueness test.
MIN_POSSIBLE_CLUES = 17


def check_puzzle(puzzle, solution, problems, label):
    clues = sum(1 for v in puzzle if v)

    if clues < MIN_POSSIBLE_CLUES:
        problems.append("%s: %d clues, below the 17 minimum" % (label, clues))

    for i, v in enumerate(puzzle):
        if v and v != solution[i]:
            problems.append("%s: clue at %d contradicts the solution" % (label, i))
            break

    for unit in S.UNITS:
        if sorted(solution[i] for i in unit) != list(range(1, 10)):
            problems.append("%s: the solution is not a valid grid" % label)
            break

    n = S.Solver().count(puzzle, 2)
    if n != 1:
        problems.append("%s: %s solution(s), not exactly one"
                        % (label, "no" if n == 0 else "several"))
    return clues


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-n", "--samples", type=int, default=6,
                    help="puzzles to generate per tier (default 6)")
    ap.add_argument("--seed", type=int, default=20240901,
                    help="fix the RNG so a failure can be reproduced")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    problems = []

    print("%-9s %-7s %-9s %-22s %s"
          % ("TIER", "CLUES", "ATTEMPTS", "HARDEST TECHNIQUE", "TIME"))

    summary = []
    for index, tier in enumerate(tiers.all_tiers()):
        clue_counts = []
        ratings = []
        attempts = []
        started = time.time()

        for k in range(args.samples):
            puzzle, solution, clues, attempt = S.generate(tier, rng)
            label = "%s #%d" % (tier["name"], k + 1)
            clue_counts.append(check_puzzle(puzzle, solution, problems, label))
            attempts.append(attempt)

            rating = S.rate(puzzle)
            ratings.append(rating)

            # The tier's own promise.
            by_scanning = (rating == S.SINGLES)
            if tier["needs_advanced"] and by_scanning:
                problems.append(
                    "%s: promises real deduction but singles finish it" % label)
            if not tier["needs_advanced"] and not by_scanning:
                problems.append(
                    "%s: promises scanning only but needs %s"
                    % (label, technique(rating)))

            if clues < tier["target_clues"]:
                problems.append("%s: %d clues, under the tier's target of %d"
                                % (label, clues, tier["target_clues"]))

        elapsed = time.time() - started
        summary.append((tier, clue_counts, ratings))
        print("%-9s %-7s %-9s %-22s %.2fs/puzzle"
              % (tier["name"],
                 "%d-%d" % (min(clue_counts), max(clue_counts)),
                 "%.1f avg" % (sum(attempts) / float(len(attempts))),
                 technique(max(ratings)),
                 elapsed / args.samples))

    # The ladder has to descend. Comparing the *sparsest* board each tier can
    # produce against the next rung catches a table where two tiers overlap so
    # far that they are the same puzzle with different names.
    scanning = [(t, c) for t, c, _ in summary if not t["needs_advanced"]]
    for (a, ca), (b, cb) in zip(scanning, scanning[1:]):
        if min(ca) <= min(cb):
            problems.append("%s is not denser than %s (%d vs %d clues)"
                            % (a["name"], b["name"], min(ca), min(cb)))

    if problems:
        print()
        for p in problems:
            print("  " + p)
        sys.exit("%d problem(s) across %d puzzles"
                 % (len(problems), args.samples * len(tiers.NAMES)))

    print("\n%d puzzles: all uniquely solvable, all matching their tier"
          % (args.samples * len(tiers.NAMES)))


def technique(rating):
    return {
        S.SINGLES: "singles",
        S.LOCKED: "locked candidates",
        S.SUBSETS: "subsets",
        S.GUESS: "beyond subsets",
    }[rating]


if __name__ == "__main__":
    main()
