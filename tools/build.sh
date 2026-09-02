#!/usr/bin/env bash
#
# Build Sudoku for sideloading.
#
#   tools/build.sh                    # build the default device set
#   tools/build.sh venu2               # just one
#   tools/build.sh --fetch-sdk         # download the SDK first, then build
#   CIQ_SDK=~/my-sdk tools/build.sh    # point at an existing SDK install
#
# Needs java and python3. If you already use the graphical SDK Manager, set
# CIQ_SDK to your SDK folder; otherwise --fetch-sdk pulls the current Linux
# SDK into dist/sdk. Device configurations are generated straight from the
# SDK's own device table (tools/make_device_json.py), so the SDK Manager's
# per-device downloads are never required - this can target any device the
# SDK knows about, including ones you've never opened the Manager for.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
SDK="${CIQ_SDK:-$DIST/sdk}"
KEY="${CIQ_KEY:-$DIST/developer_key.der}"
DEVICES_DIR="$DIST/devices"
TYPECHECK="${CIQ_TYPECHECK:-1}"   # gradual: the codebase isn't fully type-annotated yet
SDK_INDEX="https://developer.garmin.com/downloads/connect-iq/sdks"
APP_NAME="Sudoku"

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

fetch_sdk=0
targets=()
for arg in "$@"; do
    case "$arg" in
        --fetch-sdk) fetch_sdk=1 ;;
        -*) echo "unknown option: $arg" >&2; exit 2 ;;
        *) targets+=("$arg") ;;
    esac
done
if [ ${#targets[@]} -eq 0 ]; then
    targets=(venu2 venu2s venu2plus)
fi

mkdir -p "$DIST"

if [ "$fetch_sdk" = 1 ] && [ ! -d "$SDK/bin" ]; then
    echo "==> fetching the Connect IQ SDK"
    curl -fsSL "$SDK_INDEX/sdks.json" -o "$DIST/sdks.json"
    name="$("$PYTHON" -c "
import json
entries = json.load(open('$DIST/sdks.json'))
print(sorted(entries, key=lambda e: [int(p) for p in e['version'].split('.')])[-1]['linux'])
")"
    echo "    $name"
    curl -fsSL "$SDK_INDEX/$name" -o "$DIST/sdk.zip"
    mkdir -p "$SDK"
    unzip -q -o "$DIST/sdk.zip" -d "$SDK"
    chmod +x "$SDK"/bin/* 2>/dev/null || true
fi

if [ ! -f "$SDK/bin/monkeybrains.jar" ]; then
    echo "no Connect IQ SDK at $SDK" >&2
    echo "run 'tools/build.sh --fetch-sdk', or set CIQ_SDK to your SDK folder" >&2
    exit 1
fi

# A developer key signs the build. It is personal and never committed; any RSA
# key works for sideloading, and the store wants the one you registered with.
if [ ! -f "$KEY" ]; then
    echo "==> generating a developer key at $KEY"
    openssl genrsa -out "$DIST/developer_key.pem" 4096 2>/dev/null
    openssl pkcs8 -topk8 -inform PEM -outform DER \
        -in "$DIST/developer_key.pem" -out "$KEY" -nocrypt
fi

# Configure every product the manifest claims, not just the ones being built.
# The compiler validates the whole manifest against this folder, so building
# one device with configs for one device means eight "invalid device id"
# warnings that are not telling you anything.
mapfile -t products < <("$PYTHON" - "$ROOT/manifest.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ns = {"iq": "http://www.garmin.com/xml/connectiq"}
for p in ET.parse(sys.argv[1]).getroot().iter("{%s}product" % ns["iq"]):
    print(p.get("id"))
PY
)

echo "==> generating device configurations"
"$PYTHON" "$ROOT/tools/make_device_json.py" --sdk "$SDK" --out "$DEVICES_DIR" \
    "${products[@]}" >/dev/null

status=0
echo "==> drawing the launcher icons"
"$PYTHON" "$ROOT/tools/make_icons.py" --devices "$DEVICES_DIR" \
    --out "$ROOT/resources-icon" "${products[@]}" >/dev/null

for device in "${targets[@]}"; do
    out="$DIST/$APP_NAME-$device.prg"
    echo "==> building $device"
    if java -jar "$SDK/bin/monkeybrains.jar" \
        --jungles "$ROOT/monkey.jungle" \
        --output "$out" \
        --apidb "$SDK/bin/api.db" \
        --apimir "$SDK/bin/api.mir" \
        --override-devices-json "$DEVICES_DIR" \
        --device "$device" \
        --private-key "$KEY" \
        --typecheck "$TYPECHECK" \
        --warn; then
        echo "    $out ($(wc -c <"$out") bytes)"
    else
        status=1
    fi
done

exit $status
