#!/usr/bin/env bash
#
# Package Sudoku for the Connect IQ store.
#
#   tools/package.sh                     # -> dist/Sudoku.iq
#   tools/package.sh --fetch-sdk         # download the SDK first
#   CIQ_KEY=~/keys/makeitrain.der tools/package.sh
#
# The store takes one signed .iq holding every product declared in the
# manifest, not the per-device .prg files tools/build.sh emits for
# sideloading. Run tools/verify.sh and tools/build.sh first: this compiles in
# release mode, which is not a substitute for the strict type check.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
SDK="${CIQ_SDK:-$DIST/sdk}"
KEY="${CIQ_KEY:-$DIST/developer_key.der}"
DEVICES_DIR="$DIST/devices"
OUT="${CIQ_OUT:-$DIST/Sudoku.iq}"

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

for arg in "$@"; do
    case "$arg" in
        --fetch-sdk) "$ROOT/tools/build.sh" --fetch-sdk venu2 >/dev/null ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

if [ ! -f "$SDK/bin/monkeybrains.jar" ]; then
    echo "no Connect IQ SDK at $SDK; set CIQ_SDK or pass --fetch-sdk" >&2
    exit 1
fi

# Unlike tools/build.sh this never generates a key. A sideload signed with a
# throwaway key is merely a sideload; a *store* package signed with one is a
# different publisher identity, and the store binds the app to whichever key
# first uploaded it. Silently inventing one here would either be rejected or,
# worse, publish under an identity whose private half is about to be deleted
# with the dist directory.
if [ ! -f "$KEY" ]; then
    echo "no developer key at $KEY" >&2
    echo "set CIQ_KEY to the key this app is published under - the store will" >&2
    echo "not accept updates signed with any other one." >&2
    exit 1
fi

mkdir -p "$DIST"

# The product list comes from the manifest rather than being repeated here.
# A store package has to cover exactly what the manifest declares, and a
# second hand-maintained list is a second thing to forget to update.
mapfile -t PACKAGE_TARGETS < <("$PYTHON" - "$ROOT/manifest.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
NS = "http://www.garmin.com/xml/connectiq"
for p in ET.parse(sys.argv[1]).getroot().iter("{%s}product" % NS):
    print(p.get("id"))
PY
)
echo "==> ${#PACKAGE_TARGETS[@]} products declared in the manifest"

echo "==> generating device configurations"
"$PYTHON" "$ROOT/tools/make_device_json.py" --sdk "$SDK" --out "$DEVICES_DIR" \
    "${PACKAGE_TARGETS[@]}" >/dev/null

# One icon per product, each at that device's own launcher size. A store
# package covers every product at once, so a single icon here would be a
# scaled icon on all but one watch.
echo "==> drawing the launcher icons"
"$PYTHON" "$ROOT/tools/make_icons.py" --devices "$DEVICES_DIR" \
    --out "$ROOT/resources-icon" "${PACKAGE_TARGETS[@]}" >/dev/null

# --package-app replaces --device: it builds every product in the manifest,
# once per firmware part number, into a single archive.
echo "==> packaging every product for the store"
java -jar "$SDK/bin/monkeybrains.jar" \
    --jungles "$ROOT/monkey.jungle" \
    --output "$OUT" \
    --apidb "$SDK/bin/api.db" \
    --apimir "$SDK/bin/api.mir" \
    --override-devices-json "$DEVICES_DIR" \
    --private-key "$KEY" \
    --package-app \
    --release \
    --warn

echo "    $OUT ($(wc -c <"$OUT") bytes)"
