#!/usr/bin/env python3
"""Static checks for the Monkey C traps that cost real debugging time here.

The compiler catches type errors. It does not catch a numeric font quietly
rendering a letter as nothing, and its message for a visibility keyword at
module scope is actively misleading. Both of those have already happened in
this codebase; this is the check that stops them happening twice.

    python3 tools/check_source.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = ["source", "tests"]

# FONT_NUMBER_* faces carry 0-9, a colon and a decimal point, and essentially
# nothing else. A letter drawn in one renders as nothing at all - no error, no
# fallback, just a gap - so any string handed to one has to be provably
# digits. These are the only expressions allowed to reach a numeric font.
DIGIT_SAFE = re.compile(
    r"""^(
          [\w.]*\.toString\(\)          # a Number
        | [\w.]*\.format\("[^"]*"\)     # a formatted Number
        | Fmt\.clock\(.*\)              # digits and colons by construction
        | "8"                           # the width probe in BoardView
        | \(index \+ 1\)\.toString\(\)  # the picker's own digits
        )$""",
    re.X)

CLASS_RE = re.compile(r'class\s+(\w+)\s+extends\s+([\w.]+)\s*\{')
ONSELECT_RE = re.compile(r'\bfunction\s+onSelect\s*\(')


def source_files():
    for d in DIRS:
        folder = os.path.join(ROOT, d)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            if name.endswith(".mc"):
                yield os.path.join(d, name), os.path.join(folder, name)


def check_module_scope_visibility(rel, text, problems):
    """`hidden` and `private` are class modifiers. At module scope the parser
    rejects them with "extraneous input", which says nothing about
    visibility and sends you looking in the wrong place entirely."""
    depth = 0
    in_module = []
    for n, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        opens_module = re.match(r"module\s+\w+", stripped)
        opens_class = re.match(r"class\s+\w+", stripped)

        if re.match(r"(hidden|private)\s", stripped) and in_module and in_module[-1]:
            problems.append(
                "%s:%d: `%s` at module scope - it is a class modifier, and the "
                "compiler's error will not tell you that"
                % (rel, n, stripped.split()[0]))

        if opens_module or opens_class:
            in_module.append(bool(opens_module))
        depth += line.count("{") - line.count("}")
        if in_module and depth <= len(in_module) - 1:
            in_module.pop()


def check_numeric_fonts(rel, text, problems):
    """Every drawText that uses a FONT_NUMBER_* face, and what it draws."""
    for n, line in enumerate(text.splitlines(), 1):
        if "FONT_NUMBER" not in line or "Graphics.FONT_NUMBER" not in line:
            continue
        # Declaring a candidate list is fine; the check is on what gets drawn.
        if re.search(r"\[\s*Graphics\.FONT_NUMBER", line):
            continue
        m = re.search(r"drawText\([^,]+,[^,]+,\s*Graphics\.FONT_NUMBER_\w+\s*,\s*([^,]+),", line)
        if m and not DIGIT_SAFE.match(m.group(1).strip()):
            problems.append(
                "%s:%d: %s drawn in a numeric font; letters render as nothing"
                % (rel, n, m.group(1).strip()))


def check_font_metrics(rel, text, problems):
    """Text rows have to be positioned from measured font heights. A guessed
    pixel offset works on the watch it was guessed on and clips on the rest."""
    for n, line in enumerate(text.splitlines(), 1):
        m = re.search(r"drawText\(\s*[^,]+,\s*(\d{2,})\s*,", line)
        if m:
            problems.append("%s:%d: drawText at a hard-coded y of %s - use "
                            "dc.getFontHeight()" % (rel, n, m.group(1)))


def find_class_bodies(text):
    """Yield (name, base, body) for every top-level `class X extends Y { ... }`."""
    for m in CLASS_RE.finditer(text):
        name, base = m.group(1), m.group(2)
        start = m.end()
        depth = 1
        i = start
        while i < len(text) and depth > 0:
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                depth -= 1
            i += 1
        yield name, base, text[start:i]


def check_onselect_ontap_trap(rel, text, problems):
    """On real Venu 2 hardware a screen tap arrives as *two* separate events:
    onTap, with real coordinates, and the physical select behaviour,
    onSelect, with none. A WatchUi.BehaviorDelegate that overrides onSelect
    to do anything target-dependent runs that logic a second time,
    unconditionally, right after every real tap - which is how a tap
    anywhere on the board turned into "open the picker for whatever cell was
    already selected" in BoardDelegate, and the same mistake independently
    shipped in the sibling foundry, deep-shaft and garmin-survival projects.

    The fix is always the same: hang the physical-button-only action off
    onKey(WatchUi.KEY_ENTER) instead, which only the physical START/select
    button actually produces, and drop onSelect entirely. onSelect itself
    belongs to Menu2InputDelegate and ConfirmationDelegate, which react to a
    chosen item rather than a raw screen event, and are unaffected."""
    for name, base, body in find_class_bodies(text):
        if base != "WatchUi.BehaviorDelegate":
            continue
        if ONSELECT_RE.search(body):
            problems.append(
                "%s: %s extends WatchUi.BehaviorDelegate and defines onSelect() - "
                "a real screen tap also fires onSelect with no coordinates, so this "
                "will re-run after every onTap. Move the physical-button action to "
                "onKey(WatchUi.KEY_ENTER) instead." % (rel, name))


def main():
    problems = []
    files = 0
    for rel, path in source_files():
        with open(path) as fh:
            text = fh.read()
        files += 1
        check_module_scope_visibility(rel, text, problems)
        check_numeric_fonts(rel, text, problems)
        check_font_metrics(rel, text, problems)
        check_onselect_ontap_trap(rel, text, problems)

    if problems:
        for p in problems:
            print("  " + p)
        sys.exit("%d problem(s)" % len(problems))
    print("%d source files: no known Monkey C traps" % files)


if __name__ == "__main__":
    main()
