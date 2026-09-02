#!/usr/bin/env bash
#
# Build and run the unit tests.
#
#   tools/test.sh              # compile them
#   tools/test.sh --run        # compile, then run them in the simulator
#
# Compiling is the part CI can do anywhere. *Running* needs the Connect IQ
# simulator, which is a GTK/WebKit application: it wants a display, and on
# Linux it links against libsoup-2.4 and webkit2gtk-4.0, which recent
# distributions no longer package. If --run cannot start the simulator it says
# so and stops rather than reporting a pass it did not observe.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
SDK="${CIQ_SDK:-$DIST/sdk}"
KEY="${CIQ_KEY:-$DIST/developer_key.der}"
DEVICE="${CIQ_DEVICE:-venu2}"

run=0
for arg in "$@"; do
    case "$arg" in
        --run) run=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

if [ ! -f "$SDK/bin/monkeybrains.jar" ]; then
    echo "no Connect IQ SDK at $SDK" >&2
    echo "run 'tools/build.sh --fetch-sdk' first, or set CIQ_SDK" >&2
    exit 1
fi
if [ ! -d "$DIST/devices/$DEVICE" ] || [ ! -f "$KEY" ]; then
    echo "==> priming the device config and developer key"
    "$ROOT/tools/build.sh" "$DEVICE" >/dev/null
fi

echo "==> compiling the tests for $DEVICE"
java -jar "$SDK/bin/monkeybrains.jar" \
    --jungles "$ROOT/tests.jungle" \
    --output "$DIST/tests.prg" \
    --apidb "$SDK/bin/api.db" \
    --apimir "$SDK/bin/api.mir" \
    --override-devices-json "$DIST/devices" \
    --device "$DEVICE" \
    --private-key "$KEY" \
    --unit-test \
    --warn
echo "    $DIST/tests.prg"

if [ "$run" = 0 ]; then
    echo
    echo "compiled only; pass --run to execute them in the simulator"
    exit 0
fi

if ! command -v "$SDK/bin/simulator" >/dev/null 2>&1; then
    echo "no simulator in $SDK/bin" >&2
    exit 1
fi
missing="$(ldd "$SDK/bin/simulator" 2>/dev/null | awk '/not found/ {print $1}' || true)"
if [ -n "$missing" ]; then
    echo "the simulator cannot start; these libraries are missing:" >&2
    echo "$missing" | sed 's/^/    /' >&2
    exit 1
fi

echo "==> starting the simulator"
"$SDK/bin/simulator" >"$DIST/simulator.log" 2>&1 &
sim=$!
trap 'kill $sim 2>/dev/null || true' EXIT
sleep 8

echo "==> running the tests"
"$SDK/bin/monkeydo" "$DIST/tests.prg" "$DEVICE" -t
