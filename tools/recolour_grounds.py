#!/usr/bin/env python3
"""Recolour DragonUI's window grounds to the professions window's browns.

This fork ships ui-background-rock (window ground) and ui-background-marble (inset floor)
recoloured in place, so every window and every addon that borrows these paths matches the
professions window. An upstream merge that touches either file brings the grey back without any
code change, so after merging upstream run:

    python3 tools/recolour_grounds.py --check

and if it fails, regenerate from upstream's new originals:

    git show upstream/main:DragonUI/Textures/UI/ui-background-rock.blp > /tmp/rock.blp
    git show upstream/main:DragonUI/Textures/UI/ui-background-marble.blp > /tmp/marble.blp
    python3 tools/recolour_grounds.py --rock /tmp/rock.blp --marble /tmp/marble.blp

Rock is scaled to its target (it gets darker, so its grain shrinks with it); marble is shifted
(it gets lighter, and scaling would double its grain). Output is palettised BLP2, keeping the
source's mipmap setting. Needs Pillow.
"""
import argparse
import struct
import sys
from pathlib import Path

from PIL import Image, ImageStat

UI = Path(__file__).resolve().parent.parent / "DragonUI" / "Textures" / "UI"
TARGETS = {
    # name: (target mean RGB, mode)
    "ui-background-rock": ((34, 29, 24), "scale"),
    "ui-background-marble": ((25, 21, 17), "shift"),
}
TOLERANCE = 2


def has_mips(path):
    data = Path(path).read_bytes()
    return data[:4] == b"BLP2" and data[11] != 0


def recolour(im, target, mode):
    mean = ImageStat.Stat(im).mean
    bands = im.split()
    if mode == "shift":
        out = [b.point(lambda v, t=t, m=m: max(0, min(255, round(t + v - m)))) for b, t, m in zip(bands, target, mean)]
    else:
        out = [b.point(lambda v, f=t / m: min(255, round(v * f))) for b, t, m in zip(bands, target, mean)]
    return Image.merge("RGB", out)


def write_blp2(im, path, mips):
    """Palettised BLP2 (encoding 1, no alpha); every mip level shares the top level's palette."""
    top = im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    levels = [top]
    if mips:
        w, h = im.size
        while (w, h) != (1, 1):
            w, h = max(1, w // 2), max(1, h // 2)
            levels.append(im.resize((w, h), Image.BOX).quantize(palette=top, dither=Image.Dither.NONE))
    pal = (top.getpalette() or [])[:768]
    pal += [0] * (768 - len(pal))
    blobs = [lvl.tobytes() for lvl in levels]
    offsets, sizes, at = [], [], 148 + 1024
    for blob in blobs:
        offsets.append(at)
        sizes.append(len(blob))
        at += len(blob)
    offsets += [0] * (16 - len(offsets))
    sizes += [0] * (16 - len(sizes))
    w, h = im.size
    header = b"BLP2" + struct.pack("<I", 1) + bytes([1, 0, 0, 1 if mips else 0]) + struct.pack("<II", w, h)
    header += struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes)
    palette = b"".join(bytes([pal[i * 3 + 2], pal[i * 3 + 1], pal[i * 3], 255]) for i in range(256))
    Path(path).write_bytes(header + palette + b"".join(blobs))


def check():
    ok = True
    for name, (target, _) in TARGETS.items():
        mean = ImageStat.Stat(Image.open(UI / f"{name}.blp").convert("RGB")).mean
        good = all(abs(m - t) <= TOLERANCE for m, t in zip(mean, target))
        ok &= good
        print(f"{name}: mean {tuple(round(m) for m in mean)} target {target} {'ok' if good else 'NOT RECOLOURED'}")
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="verify the shipped files carry the target colours")
    ap.add_argument("--rock", help="upstream's original ui-background-rock.blp")
    ap.add_argument("--marble", help="upstream's original ui-background-marble.blp")
    args = ap.parse_args()
    if args.check:
        sys.exit(0 if check() else 1)
    sources = {"ui-background-rock": args.rock, "ui-background-marble": args.marble}
    if not all(sources.values()):
        ap.error("--rock and --marble are both required (or --check)")
    for name, src in sources.items():
        target, mode = TARGETS[name]
        out = recolour(Image.open(src).convert("RGB"), target, mode)
        write_blp2(out, UI / f"{name}.blp", has_mips(src))
        print(f"wrote {name}.blp ({mode} to {target}, mips={'yes' if has_mips(src) else 'no'})")
    check()


if __name__ == "__main__":
    main()
