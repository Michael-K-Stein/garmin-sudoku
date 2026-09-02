#!/usr/bin/env bash
#
# Every check that does not need the Connect IQ SDK. This is the fast gate:
# run it before compiling, and after any change to the tier table.
#
#   tools/verify.sh
#   tools/verify.sh --deep     # a much larger generator sample
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The Windows Store ships a `python3` stub that only prints an advert, so the
# interpreter is probed rather than just located.
if [ -z "${PYTHON:-}" ]; then
    for candidate in python3 python py; do
        if command -v "$candidate" >/dev/null 2>&1 &&
           "$candidate" -c "import sys" >/dev/null 2>&1; then
            PYTHON="$candidate"
            break
        fi
    done
fi
if [ -z "${PYTHON:-}" ]; then
    echo "no working python interpreter found; set PYTHON to one" >&2
    exit 1
fi

samples=6
for arg in "$@"; do
    case "$arg" in
        --deep) samples=30 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

echo "==> the Monkey C traps that have bitten this codebase"
"$PYTHON" "$ROOT/tools/check_source.py"

echo
echo "==> the tier table agrees between Difficulty.mc and tiers.py"
"$PYTHON" "$ROOT/tools/check_constants.py"

echo
echo "==> the round-screen layout"
"$PYTHON" "$ROOT/tools/check_layout.py"

echo
echo "==> every tier still generates the puzzle it advertises"
"$PYTHON" "$ROOT/tools/check_generator.py" -n "$samples"
