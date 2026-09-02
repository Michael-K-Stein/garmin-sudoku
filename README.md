# Sudoku — Garmin Venu 2

A Sudoku app for the Garmin Venu 2 family. Puzzles are generated on the watch,
graded on the watch, and nothing is downloaded or bundled — there is no puzzle
list to run out of.

```sh
tools/verify.sh                    # fast checks, no SDK needed
tools/build.sh --fetch-sdk         # -> dist/Sudoku-<device>.prg (sideload)
tools/test.sh                      # compile the unit tests
tools/package.sh --fetch-sdk       # -> dist/Sudoku.iq (store-ready)
```

Sideload by copying a `.prg` into `GARMIN/APPS/` on a watch plugged in over USB.

## Playing

One screen: a two-row header, the grid, and a four-zone action bar.

| Gesture | What it does |
| --- | --- |
| Tap a square | Select it. Its row, column, box and every matching digit light up. |
| Tap it again | Open the digit picker |
| Swipe | Move the selection one square — for fixing a mis-tap without aiming again |
| Start button | Open the digit picker for the selected square |
| Menu (long press) | Erase all, settings, help, quit |
| Back | Leave; the puzzle is saved exactly as you left it |

The action bar, left to right: **pencil** toggles notes mode, **backspace**
clears the square, **undo** steps back, **bulb** gives a hint.

Digit entry uses Garmin's own picker (`WatchUi.PickerFactory`), and everything
destructive — a hint, erase-all, abandoning a puzzle, clearing the record —
asks first with the system's `WatchUi.Confirmation` screen. The menus are
`Menu2`. None of that is redrawn by hand, so the app scrolls and confirms the
way the rest of the watch does.

### Notes are dots, not numerals

Pencil marks show as a 3×3 lattice of dots inside the square, where the dot's
*position* is the digit: top-left is 1, bottom-right is 9.

Nine numerals will not fit legibly in a 30px cell. The smallest font on a Venu
2 is 21px tall, so a 3×3 block of them would need 63px in a square that has
30. Dots read at a glance, and after one puzzle the positions scan as fast as
numerals would have.

### Hints explain themselves

A hint does not just fill a square. It says *why* — "This row needs a 4",
"Only one digit fits" — and if you have already entered something wrong, it
points at that instead, because every deduction downstream of a wrong digit is
poisoned.

## Difficulty

Five tiers, on two axes. Clue count alone is a bad predictor: a published
newspaper "easy" with 30 clues and a 30-clue puzzle that needs chained
inference look identical on the board.

| Tier | Clues | Technique needed |
| --- | --- | --- |
| Beginner | 44 | scanning only |
| Easy | 34 | scanning only |
| Medium | 28 | scanning only |
| Hard | 30 | more than scanning |
| Expert | ~24 (minimal) | more than scanning |

"Scanning only" means naked and hidden singles finish the puzzle — the
technique a newspaper solver uses. The first three tiers hold that fixed and
take clues away; the last two hold the technique requirement and take clues
away again, so every rung is harder than the one below it for a reason you can
feel.

Both halves of that claim are checked, not asserted. `tools/check_generator.py`
generates a sample of every tier and runs a full technique solver over each
one — naked and hidden singles, locked candidates, naked pairs and triples,
hidden pairs — and fails the build if a tier's puzzles do not need what the
table says they need, or if any puzzle has anything other than exactly one
solution.

## How a puzzle is made

Generation is a state machine (`Generator.mc`) stepped from a timer behind
Garmin's `ProgressBar`, because the work is a few hundred solver runs and
doing it in one callback would freeze the watch.

1. **Build** a random complete grid. The three diagonal boxes share no row,
   column or box, so they are filled from three independent shuffles and the
   solver finishes the other 54 cells with almost no backtracking.
2. **Dig** clues out one at a time for as long as the puzzle stays uniquely
   solvable. This is the expensive phase and it runs with no difficulty checks
   at all — it just goes as far as it can, which lands around 24 clues.
3. **Judge**: a tier that needs real deduction rejects a minimal puzzle that
   scanning happens to crack, and starts over.
4. **Add back** clues from the solution until the tier's clue target is met.

Step 4 is the part worth explaining. Adding a given can only make a puzzle
easier and can never break uniqueness, so the generator walks difficulty
*down* onto the tier rather than hunting for it. That is what makes the easy
tiers deterministic — one dig, every time — instead of a rejection lottery.

The uniqueness test in step 2 is the cheap one: the puzzle was unique a moment
ago, so emptying one cell can only have added solutions *through that cell*.
If no other digit fits there, none were added.

## Verifying

There is no emulator in this loop — the Connect IQ simulator is a GTK/WebKit
application that needs a display and libraries recent Linux distributions no
longer package — so `tools/test.sh` compiles the unit tests and only runs them
where a simulator exists. What runs everywhere:

| Check | What it proves |
| --- | --- |
| `check_source.py` | The Monkey C traps below have not come back |
| `check_constants.py` | `Difficulty.mc` and `tools/tiers.py` still agree |
| `check_layout.py` | Nothing leaves the circle, at 416, 390, 360 and 260px |
| `check_generator.py` | Every tier generates the puzzle it advertises |

`tools/build.sh` compiles clean — no errors and no warnings — and that is the
other half. A change is "verified" when both pass.

## Traps

**`hidden` and `private` are class modifiers.** At module scope the compiler
rejects them with `extraneous input 'hidden'`, which says nothing about
visibility and sends you looking in entirely the wrong place.
`tools/check_source.py` catches it.

**`FONT_NUMBER_*` faces are digit-only.** They carry `0-9`, `:`, `.` and
little else, and a letter drawn in one renders as *nothing at all* — silently.
They are the right choice for a Sudoku cell, which is one digit, and for the
clock on the win screen; anywhere else they are a trap.
`tools/check_source.py` checks what reaches them.

**The screen is round, and a 9×9 grid is all corner.** Its four corners are
the furthest points from the centre and they decide how large a cell can be.
The action bar below the grid is a pill rather than a rectangle for the same
reason — a rectangle's corners would hang off the glass.
`tools/check_layout.py` replays the arithmetic on four screen sizes.

**Do not hard-code text offsets.** Row positions come from
`dc.getFontHeight()` and `dc.getTextWidthInPixels()`. A guessed offset works
on the watch it was guessed on and clips on the rest.

**A Timer with no live reference to its owner is a crash.** The generator run
is parked in a module variable for its whole life, and cancelling it stops the
timer rather than just dropping the reference.

## Shape of the code

`SudokuApp` owns one `Session`; views never write its fields, they call
`place` / `erase` / `toggleNote` / `undo`, so the rules that have to hold
together stay in one place.

| File | What it holds |
| --- | --- |
| `Difficulty.mc` | The tier table. Change the ladder here and nowhere else. |
| `Cells.mc` | Grid geometry and candidate bitmasks, as arithmetic not tables |
| `Solver.mc` | Counting solver; iterative, because the search goes 60+ deep |
| `Logic.mc` | Singles, conflicts, and the hint that explains itself |
| `Generator.mc` | The state machine above |
| `Session.mc` | The game in progress, its moves, and persistence |
| `Layout.mc` | Every coordinate on the board screen |
| `Theme.mc` / `Glyphs.mc` | Palette, primitives, and the vector icons |
| `*View.mc` / `*Delegate.mc` | One screen and its input, paired |

Icons are drawn as vectors rather than shipped as bitmaps: nine products
across four screen sizes would otherwise need a set of PNGs each, and every
one of them would be slightly the wrong size somewhere. The action-bar glyphs
are drawn by `Glyphs.mc` at whatever radius the bar gives them, and the
launcher icon by `tools/make_icons.py` into one resource folder per product,
at that device's exact launcher size - 70px on a Venu 2, 35px on a vivoactive
4. That is also why the icon shows a 3x3 grid rather than a 9x9 one: at 35px,
nine columns of lines are grey mush.
