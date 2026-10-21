#!/usr/bin/env python3
"""Make the professions "link to chat" icon a plain chat bubble, without the gold arrow.

The icon is the "link-icon" cell of Textures/Professions/ProfessionsUI.tga (560..660 x 4..104, see
modules/professions/prof_atlas.lua), drawn on the professions window's link button and borrowed by
any addon that uses DragonUI's professions art. This fork ships the sheet edited in place, so an
upstream merge that touches the file brings the arrow back. After merging upstream run:

    python3 tools/link_icon_bubble.py --check

and if it fails, run it without --check to edit the sheet again.

The arrow covers the bubble's right edge, so that edge is rebuilt: the bubble's own pixels are kept
up to KEEP, past BLEND the left edge is mirrored left-right (top half) and that mirrored top-bottom
(bottom half, so the tail stays on the left only), with a crossfade in between. Nothing outside
the cell changes, and the sheet is written back as the same 32-bit RLE TGA. Needs Pillow.
"""
import argparse
import sys
from pathlib import Path

from PIL import Image

SHEET = Path(__file__).resolve().parent.parent / "DragonUI" / "Textures" / "Professions" / "ProfessionsUI.tga"
X0, Y0, SIZE = 560, 4, 100
CX, CY = 47, 44  # the bubble body's centre in the cell (top arc 36..58, body rows 18..70)
KEEP, BLEND = 52, 60  # the arrow, its rim highlight and shadow start at about 62


def is_arrow(pixel):
    r, g, b, a = pixel
    return a > 40 and r > 180 and g > 140 and b < 90


def has_arrow(cell):
    return any(is_arrow(cell.getpixel((x, y))) for y in range(SIZE) for x in range(SIZE))


def bubble_only(cell):
    def mirrored(x, y):
        sx = 2 * CX - x
        sy = y if y <= CY else 2 * CY - y
        return cell.getpixel((sx, sy)) if 0 <= sx < SIZE and 0 <= sy < SIZE else (0, 0, 0, 0)

    out = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    for y in range(SIZE):
        for x in range(SIZE):
            if x <= KEEP:
                out.putpixel((x, y), cell.getpixel((x, y)))
            elif x >= BLEND:
                out.putpixel((x, y), mirrored(x, y))
            else:
                t = (x - KEEP) / (BLEND - KEEP)
                a, b = cell.getpixel((x, y)), mirrored(x, y)
                out.putpixel((x, y), tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(4)))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="only say whether the arrow is gone")
    parser.add_argument("--sheet", type=Path, default=SHEET)
    args = parser.parse_args()

    sheet = Image.open(args.sheet).convert("RGBA")
    cell = sheet.crop((X0, Y0, X0 + SIZE, Y0 + SIZE))
    if args.check:
        if has_arrow(cell):
            print(f"{args.sheet.name}: the link icon still has its gold arrow; run tools/link_icon_bubble.py")
            return 1
        print(f"{args.sheet.name}: link icon is a plain bubble")
        return 0
    if not has_arrow(cell):
        print(f"{args.sheet.name}: already a plain bubble, nothing to do")
        return 0
    sheet.paste(Image.new("RGBA", cell.size, (0, 0, 0, 0)), (X0, Y0))
    sheet.paste(bubble_only(cell), (X0, Y0))
    sheet.save(args.sheet, compression="tga_rle")
    print(f"{args.sheet.name}: link icon is now a plain bubble")
    return 0


if __name__ == "__main__":
    sys.exit(main())
