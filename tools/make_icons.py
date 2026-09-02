#!/usr/bin/env python3
"""Draw one launcher icon per device, at that device's exact size.

The launcher slot is a different size on nearly every watch - 70px on a Venu
2, 61px on a Venu 2S, 35px on a vivoactive 4 - and a single icon scaled to fit
looks scaled. Connect IQ's answer is a per-device resource path, so this
writes one small resource folder per device and `monkey.jungle` points each
product at its own.

The sizes come from the compiler.json files `make_device_json.py` generates,
so adding a product to the manifest is all it takes; nothing here has a device
list of its own to fall out of date.

    python3 tools/make_icons.py --devices dist/devices --out resources-icon \\
        venu2 venu2s venu2plus

Everything it writes is a build artefact and is gitignored.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_icon

DRAWABLES = """<drawables>
    <bitmap id="LauncherIcon" filename="launcher_icon.png" />
</drawables>
"""


def icon_size(devices_dir, device, fallback=96):
    path = os.path.join(devices_dir, device, "compiler.json")
    try:
        with open(path) as fh:
            return int(json.load(fh)["launcherIcon"]["width"])
    except (IOError, OSError, KeyError, ValueError):
        return fallback


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--devices", required=True,
                    help="folder of per-device compiler.json files")
    ap.add_argument("--out", required=True,
                    help="folder to write the per-device resource trees into")
    ap.add_argument("products", nargs="+", help="device ids")
    args = ap.parse_args()

    for device in args.products:
        size = icon_size(args.devices, device)
        folder = os.path.join(args.out, device, "drawables")
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, "drawables.xml"), "w") as fh:
            fh.write(DRAWABLES)
        png = os.path.join(folder, "launcher_icon.png")
        make_icon.write_png(png, make_icon.render(size), size)
        print("%s: %dx%d" % (device, size, size))


if __name__ == "__main__":
    main()
