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
(it gets lighter, and scaling would double its grain). Output keeps the source's exact format:
its BLP2 header is reused byte for byte (DXT1, no alpha, its own mip levels) and only the DXT1
blocks are replaced, each level the same size as before. A palettised BLP2 is NOT loaded by the
3.3.5 client for these: it draws them bright green. Needs Pillow 11+ (DXT1 encoding).
"""
import argparse
import io
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


HEADER = 148 + 1024  # BLP2 header, then the (unused for DXT) 256-entry palette


def dxt1_level(im, width, height):
    """One mip level as raw DXT1 blocks. Levels under 4x4 still take one 8-byte block."""
    level = im.resize((width, height), Image.BOX) if im.size != (width, height) else im
    if width < 4 or height < 4:
        level = level.resize((max(4, width), max(4, height)), Image.NEAREST)
    buf = io.BytesIO()
    level.save(buf, "DDS", pixel_format="DXT1")
    raw = buf.getvalue()[128:]  # DDS magic + 124-byte header
    want = max(1, (width + 3) // 4) * max(1, (height + 3) // 4) * 8
    return raw[:want]


def write_like(src, im, path):
    """Rewrite `src` with `im`'s pixels: same header, same levels, same byte sizes."""
    data = Path(src).read_bytes()
    if data[:4] != b"BLP2" or data[8] != 2 or data[9] != 0:
        sys.exit(f"{src}: expected a DXT1 BLP2 with no alpha")
    w, h = struct.unpack("<II", data[12:20])
    offsets = struct.unpack("<16I", data[20:84])
    sizes = struct.unpack("<16I", data[84:148])
    out = bytearray(data[:HEADER])
    for i, (off, size) in enumerate(zip(offsets, sizes)):
        if not size:
            break
        if off != len(out):
            sys.exit(f"{src}: level {i} is not packed after the one before it")
        blob = dxt1_level(im, max(1, w >> i), max(1, h >> i))
        if len(blob) != size:
            sys.exit(f"{src}: level {i} came out {len(blob)} bytes, source has {size}")
        out += blob
    Path(path).write_bytes(bytes(out))


def recolour(im, target, mode):
    mean = ImageStat.Stat(im).mean
    bands = im.split()
    if mode == "shift":
        out = [b.point(lambda v, t=t, m=m: max(0, min(255, round(t + v - m)))) for b, t, m in zip(bands, target, mean)]
    else:
        out = [b.point(lambda v, f=t / m: min(255, round(v * f))) for b, t, m in zip(bands, target, mean)]
    return Image.merge("RGB", out)


def check():
    ok = True
    for name, (target, _) in TARGETS.items():
        data = (UI / f"{name}.blp").read_bytes()
        if data[:4] != b"BLP2" or data[8] != 2:
            print(f"{name}: encoding {data[8]} is not DXT (the client draws other encodings green)")
            ok = False
            continue
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
        original = Image.open(src).convert("RGB")
        # DXT1 stores 5-6-5 endpoints, which pulls these dark browns off target (blue most): encode,
        # read back, and re-aim by the drift until the decoded mean lands.
        aim = target
        for _ in range(6):
            write_like(src, recolour(original, aim, mode), UI / f"{name}.blp")
            got = ImageStat.Stat(Image.open(UI / f"{name}.blp").convert("RGB")).mean
            drift = [t - g for t, g in zip(target, got)]
            if all(abs(d) < 0.75 for d in drift):
                break
            aim = tuple(a + d for a, d in zip(aim, drift))
        print(f"wrote {name}.blp ({mode} to {target}, DXT1, source header and levels)")
    check()


if __name__ == "__main__":
    main()
