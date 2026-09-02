#!/usr/bin/env python3
"""A reference implementation of the generator that ships in source/.

This is the Python mirror of `Solver.mc`, `Rater.mc` and `Generator.mc`. It
exists so the difficulty tiers are *checkable*: the claim "a Medium puzzle
needs locked candidates but never a guess" is otherwise just a comment. The
tier table itself is mirrored from `source/Difficulty.mc` and compared against
it by `tools/check_constants.py`, so the two cannot drift apart silently.

The algorithms here are deliberately written the same shape as the Monkey C -
same masks, same MRV search, same dig loop - so that a fix in one is an
obvious fix in the other. It is not seeded identically, and does not need to
be: `tools/check_generator.py` asserts properties of the output, not equality
with a golden puzzle.
"""
import random

ALL = 0x1FF  # bits 0..8 stand for digits 1..9

# --- geometry ---------------------------------------------------------------

ROW = [i // 9 for i in range(81)]
COL = [i % 9 for i in range(81)]
BOX = [(i // 9 // 3) * 3 + (i % 9) // 3 for i in range(81)]

PEERS = []
for i in range(81):
    p = set()
    for j in range(81):
        if j != i and (ROW[j] == ROW[i] or COL[j] == COL[i] or BOX[j] == BOX[i]):
            p.add(j)
    PEERS.append(sorted(p))

UNITS = []
for r in range(9):
    UNITS.append([i for i in range(81) if ROW[i] == r])
for c in range(9):
    UNITS.append([i for i in range(81) if COL[i] == c])
for b in range(9):
    UNITS.append([i for i in range(81) if BOX[i] == b])


def bit(d):
    return 1 << (d - 1)


def popcount(m):
    n = 0
    while m:
        m &= m - 1
        n += 1
    return n


def lowest_digit(m):
    """The digit of the lowest set bit, or 0 for an empty mask."""
    for d in range(1, 10):
        if m & bit(d):
            return d
    return 0


# --- solver -----------------------------------------------------------------

class Solver(object):
    """Counting solver: MRV backtracking over row/column/box masks.

    `count(grid, limit)` stops as soon as `limit` solutions have been found,
    which is what makes the uniqueness test in the generator affordable - it
    only ever asks for two.
    """

    def __init__(self):
        self.nodes = 0
        self.solution = None

    def count(self, grid, limit=2):
        rows = [0] * 9
        cols = [0] * 9
        boxes = [0] * 9
        for i, v in enumerate(grid):
            if v:
                b = bit(v)
                if rows[ROW[i]] & b or cols[COL[i]] & b or boxes[BOX[i]] & b:
                    return 0  # the givens already contradict each other
                rows[ROW[i]] |= b
                cols[COL[i]] |= b
                boxes[BOX[i]] |= b
        self.nodes = 0
        self.solution = None
        work = list(grid)
        return self._search(work, rows, cols, boxes, limit, 0)

    def _search(self, grid, rows, cols, boxes, limit, found):
        best, best_mask, best_size = -1, 0, 10
        for i in range(81):
            if grid[i]:
                continue
            mask = ALL & ~(rows[ROW[i]] | cols[COL[i]] | boxes[BOX[i]])
            size = popcount(mask)
            if size == 0:
                return found  # dead end
            if size < best_size:
                best, best_mask, best_size = i, mask, size
                if size == 1:
                    break
        if best < 0:
            if self.solution is None:
                self.solution = list(grid)
            return found + 1

        i = best
        for d in range(1, 10):
            b = bit(d)
            if not (best_mask & b):
                continue
            self.nodes += 1
            grid[i] = d
            rows[ROW[i]] |= b
            cols[COL[i]] |= b
            boxes[BOX[i]] |= b
            found = self._search(grid, rows, cols, boxes, limit, found)
            grid[i] = 0
            rows[ROW[i]] &= ~b
            cols[COL[i]] &= ~b
            boxes[BOX[i]] &= ~b
            if found >= limit:
                return found
        return found

    def solve(self, grid):
        """The first solution, or None."""
        self.count(grid, 1)
        return self.solution


# --- human-technique rater --------------------------------------------------

# Rating levels. A puzzle's rating is the cheapest level that solves it
# outright; anything a pencil-and-paper player cannot crack without a guess
# lands in GUESS.
SINGLES = 1   # naked single, hidden single
LOCKED = 2    # + pointing / claiming (locked candidates)
SUBSETS = 3   # + naked pairs and triples, hidden pairs
GUESS = 4     # needs search


class Rater(object):
    """Solves by constraint propagation only, at a capped technique level.

    `ok` goes false the moment the puzzle contradicts itself, which is how a
    caller tells "this needs a harder technique" apart from "this is broken".
    """

    def __init__(self, grid):
        self.grid = list(grid)
        self.cand = [ALL if not v else 0 for v in grid]
        self.ok = True
        for i in range(81):
            if grid[i] and not self._assign(i, grid[i]):
                self.ok = False
                return

    def _eliminate(self, i, d):
        b = bit(d)
        if not (self.cand[i] & b):
            return True
        self.cand[i] &= ~b
        if self.cand[i] == 0 and not self.grid[i]:
            self.ok = False
            return False
        return True

    def _assign(self, i, d):
        if self.grid[i] and self.grid[i] != d:
            self.ok = False
            return False
        self.grid[i] = d
        self.cand[i] = 0
        for p in PEERS[i]:
            if self.grid[p] == d:
                self.ok = False
                return False
            if not self._eliminate(p, d):
                return False
        return True

    def solved(self):
        return all(self.grid)

    # -- techniques; each returns True if it changed something --------------

    def naked_singles(self):
        for i in range(81):
            if not self.grid[i] and popcount(self.cand[i]) == 1:
                self._assign(i, lowest_digit(self.cand[i]))
                return True
        return False

    def hidden_singles(self):
        for unit in UNITS:
            for d in range(1, 10):
                b = bit(d)
                spot = -1
                seen = 0
                for i in unit:
                    if self.grid[i] == d:
                        seen = 99
                        break
                    if self.cand[i] & b:
                        seen += 1
                        spot = i
                if seen == 1:
                    self._assign(spot, d)
                    return True
                if seen == 0:
                    self.ok = False
                    return False
        return False

    def locked_candidates(self):
        """Pointing and claiming: a digit confined to the intersection of two
        units can be struck from the rest of both."""
        changed = False
        for unit in UNITS:
            for d in range(1, 10):
                b = bit(d)
                if any(self.grid[i] == d for i in unit):
                    continue
                spots = [i for i in unit if self.cand[i] & b]
                if len(spots) < 2:
                    continue
                for other in (ROW, COL, BOX):
                    key = other[spots[0]]
                    if any(other[i] != key for i in spots):
                        continue
                    for i in range(81):
                        if other[i] == key and i not in spots and (self.cand[i] & b):
                            if not self._eliminate(i, d):
                                return changed
                            changed = True
        return changed

    def subsets(self):
        """Naked pairs and triples, and hidden pairs, within one unit."""
        changed = False
        for unit in UNITS:
            open_cells = [i for i in unit if not self.grid[i]]
            for size in (2, 3):
                for group in _combos(open_cells, size):
                    merged = 0
                    for i in group:
                        merged |= self.cand[i]
                    if popcount(merged) != size:
                        continue
                    for k in open_cells:
                        if k in group:
                            continue
                        for d in range(1, 10):
                            if (merged & bit(d)) and (self.cand[k] & bit(d)):
                                if not self._eliminate(k, d):
                                    return changed
                                changed = True
            for d1 in range(1, 10):
                for d2 in range(d1 + 1, 10):
                    b1, b2 = bit(d1), bit(d2)
                    s1 = [i for i in open_cells if self.cand[i] & b1]
                    s2 = [i for i in open_cells if self.cand[i] & b2]
                    if len(s1) != 2 or s1 != s2:
                        continue
                    for i in s1:
                        extra = self.cand[i] & ~(b1 | b2)
                        for d in range(1, 10):
                            if extra & bit(d):
                                if not self._eliminate(i, d):
                                    return changed
                                changed = True
        return changed

    def run(self, level):
        while self.ok:
            if self.naked_singles() or self.hidden_singles():
                continue
            if not self.ok:
                break
            if level >= LOCKED and self.locked_candidates():
                continue
            if level >= SUBSETS and self.subsets():
                continue
            break
        return self.ok and self.solved()


def _combos(items, size, start=0, acc=None):
    acc = acc or []
    if len(acc) == size:
        yield list(acc)
        return
    for n in range(start, len(items)):
        acc.append(items[n])
        for c in _combos(items, size, n + 1, acc):
            yield c
        acc.pop()


def rate(grid):
    """The cheapest technique level that cracks this puzzle."""
    for level in (SINGLES, LOCKED, SUBSETS):
        r = Rater(grid)
        if r.ok and r.run(level):
            return level
    return GUESS


# --- generator ---------------------------------------------------------------
#
# This mirrors source/Generator.mc step for step. The watch runs it as a state
# machine so a progress bar can move between slices; here it is a plain
# function, but the phases, the order of the tests and the acceptance rules
# are the same, so a difficulty claim proved here is a claim about the app.

def solvable_by_singles(grid):
    """The Python twin of Logic.solvableBySingles - naked and hidden singles
    only. This is the one difficulty question the watch itself can ask."""
    r = Rater(grid)
    return r.ok and r.run(SINGLES)


def solved_grid(rng):
    """A random completed grid. The three diagonal boxes share no row, column
    or box, so they can be filled independently and the solver finishes the
    rest with almost no backtracking."""
    grid = [0] * 81
    for b in (0, 4, 8):
        digits = list(range(1, 10))
        rng.shuffle(digits)
        cells = [i for i in range(81) if BOX[i] == b]
        for i, cell in enumerate(cells):
            grid[cell] = digits[i]
    return Solver().solve(grid)


def dig(full, rng, solver=None):
    """Remove clues for as long as the puzzle stays uniquely solvable.

    The uniqueness test is the cheap one Generator.stillUnique uses: the
    puzzle was unique a moment ago, so emptying one cell can only have added
    solutions through that cell. If no other digit fits there, none were
    added."""
    solver = solver or Solver()
    grid = list(full)
    order = list(range(81))
    rng.shuffle(order)
    for i in order:
        v = grid[i]
        if not v:
            continue
        grid[i] = 0
        unique = True
        for d in range(1, 10):
            if d == v:
                continue
            grid[i] = d
            found = solver.count(grid, 1)
            grid[i] = 0
            if found:
                unique = False
                break
        if not unique:
            grid[i] = v
    return grid


def add_back(grid, full, rng, target, advanced):
    """Put clues back until the tier's clue target is met.

    A given can only make a puzzle easier and can never break uniqueness, so
    this walks difficulty *down* onto the tier rather than hunting for it -
    which is what makes the easy tiers deterministic instead of a rejection
    lottery."""
    clues = sum(1 for v in grid if v)
    empties = [i for i in range(81) if not grid[i]]
    rng.shuffle(empties)
    for i in empties:
        if clues >= target and (advanced or solvable_by_singles(grid)):
            break
        grid[i] = full[i]
        if advanced and solvable_by_singles(grid):
            # This given hands the puzzle to plain scanning, which is exactly
            # what this tier promises not to do.
            grid[i] = 0
            continue
        clues += 1
    return grid, clues


def generate(tier, rng=None, max_attempts=12):
    """A puzzle for `tier`, as (puzzle, solution, clues, attempts).

    `max_attempts` mirrors Generator.MAX_ATTEMPTS and is the same trade-off:
    past it the generator ships what it has, which for a tier that needs real
    deduction means a board that is easier than its label.
    """
    rng = rng or random.Random()
    solver = Solver()
    target = tier["target_clues"]
    advanced = tier["needs_advanced"]

    for attempt in range(1, max_attempts + 1):
        full = solved_grid(rng)
        puzzle = dig(full, rng, solver)
        if advanced and solvable_by_singles(puzzle):
            # Minimal but still crackable by scanning; no clue removal can
            # fix that, so start over.
            if attempt < max_attempts:
                continue
        if target:
            puzzle, clues = add_back(puzzle, full, rng, target, advanced)
        else:
            clues = sum(1 for v in puzzle if v)
        return puzzle, full, clues, attempt
    raise AssertionError("unreachable")
