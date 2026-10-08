#!/usr/bin/env python3
"""Convert a PNG sprite sheet into C64 sprite data.

The sheet is cut into 24x21 cells, left to right, top to bottom. Each frame
becomes 64 bytes: 63 bytes of bitmap plus one attribute byte (SpritePad
convention: bit 7 = multicolour, bits 0-3 = the sprite's own colour), so
frames can be copied to a 64-byte aligned address as-is.

Hires (default):   transparent -> 0, any other colour -> 1
Multicolour (--mc): pixels are read in horizontal pairs (draw art at 24 px
                    with doubled pixels). transparent -> 00, --mc0 -> 01,
                    own colour -> 10, --mc1 -> 11.

Transparency is alpha < 128, or the palette colour given with --transparent.

Examples:
  png2sprites.py assets/sprites.png -o build/sprites.bin --transparent black
  png2sprites.py hero.png -o build/hero.bin --mc --mc0 black --mc1 lightred \\
                 --transparent cyan --asm build/hero.asm
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64img import COLOR_NAMES, die, parse_color, read_png, warn  # noqa: E402

W, H = 24, 21


def convert_frame(img, ox, oy, args, frame_no):
    data = bytearray()
    own = {}
    split_pairs = []
    for y in range(H):
        for xb in range(3):
            byte = 0
            if args.mc:
                for pair in range(4):
                    x = ox + xb * 8 + pair * 2
                    c = img.c64(x, oy + y, args.transparent)
                    c2 = img.c64(x + 1, oy + y, args.transparent)
                    if c != c2:
                        split_pairs.append((x - ox, y))
                    if c is None:
                        bits = 0b00
                    elif c == args.mc0:
                        bits = 0b01
                    elif c == args.mc1:
                        bits = 0b11
                    else:
                        bits = 0b10
                        own[c] = own.get(c, 0) + 1
                    byte |= bits << (6 - pair * 2)
            else:
                for bit in range(8):
                    c = img.c64(ox + xb * 8 + bit, oy + y, args.transparent)
                    if c is not None:
                        byte |= 0x80 >> bit
                        own[c] = own.get(c, 0) + 1
            data.append(byte)
    if split_pairs:
        where = ", ".join(f"({x},{y})" for x, y in split_pairs[:6])
        more = f" and {len(split_pairs) - 6} more" if len(split_pairs) > 6 else ""
        warn(f"frame {frame_no}: {len(split_pairs)} multicolour pixel pair(s) with two different colours, "
             f"at {where}{more}; draw multicolour art with 2-pixel-wide pixels (the left pixel was used)")
    colour = max(own, key=own.get) if own else 1
    if len(own) > 1:
        names = ", ".join(COLOR_NAMES[c] for c in sorted(own))
        warn(f"frame {frame_no}: {len(own)} colours in the sprite's own-colour slot ({names}); "
             f"one sprite has one own colour, using {COLOR_NAMES[colour]}")
    data.append((0x80 if args.mc else 0) | colour)
    return data, colour


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("png")
    ap.add_argument("-o", "--output", required=True, help="binary output, 64 bytes per frame")
    ap.add_argument("--asm", help="also write a .byte listing (64tass/ACME/KickAss compatible)")
    ap.add_argument("--mc", action="store_true", help="multicolour sprites")
    ap.add_argument("--mc0", default=None, help="colour for bit pair 01 ($d025)")
    ap.add_argument("--mc1", default=None, help="colour for bit pair 11 ($d026)")
    ap.add_argument("--transparent", default=None, help="palette colour treated as transparent")
    ap.add_argument("--frames", type=int, default=None, help="convert at most N frames")
    args = ap.parse_args()

    args.transparent = parse_color(args.transparent) if args.transparent is not None else None
    if args.mc:
        if args.mc0 is None or args.mc1 is None:
            die("--mc needs --mc0 and --mc1")
        args.mc0 = parse_color(args.mc0)
        args.mc1 = parse_color(args.mc1)

    img = read_png(args.png)
    if img.width % W or img.height % H:
        warn(f"{args.png} is {img.width}x{img.height}, not a multiple of {W}x{H}; extra pixels are ignored")
    cols, rows = img.width // W, img.height // H
    if cols * rows == 0:
        die(f"{args.png} is smaller than one {W}x{H} sprite")

    out = bytearray()
    colours = []
    n = 0
    for r in range(rows):
        for c in range(cols):
            if args.frames is not None and n >= args.frames:
                break
            frame, colour = convert_frame(img, c * W, r * H, args, n)
            out += frame
            colours.append(colour)
            n += 1

    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "wb") as f:
        f.write(out)

    if args.asm:
        with open(args.asm, "w") as f:
            f.write(f"; generated by png2sprites.py from {os.path.basename(args.png)}, do not edit\n")
            for i in range(n):
                f.write(f"; frame {i}, colour {colours[i]} ({COLOR_NAMES[colours[i]]})\n")
                chunk = out[i * 64:(i + 1) * 64]
                for j in range(0, 64, 16):
                    f.write("        .byte " + ", ".join(f"${b:02x}" for b in chunk[j:j + 16]) + "\n")

    print(f"{args.png}: {n} sprite frame(s), {len(out)} bytes -> {args.output}")


if __name__ == "__main__":
    main()
