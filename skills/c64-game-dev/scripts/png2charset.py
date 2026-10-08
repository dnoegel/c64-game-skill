#!/usr/bin/env python3
"""Convert a PNG (a level, a screen, a title picture in character mode) into
a C64 charset, a screen map and colour data, enforcing the mode's colour
rules and the 256-character limit.

Modes
  hires (default)  per 8x8 cell: background (--bg, $d021) + one colour
  mc               per 8x8 cell, read as 4x8 double-wide pixels:
                     00 = --bg ($d021)   01 = --mc1 ($d022)
                     10 = --mc2 ($d023)  11 = cell colour, 0-7 only
                   colour RAM gets cell colour | 8 (multicolour flag)

Outputs
  -o charset.bin        unique characters, 8 bytes each (char 0 = empty cell)
  --map map.bin         one char code per cell, row-major
  --colours col.bin     one colour RAM value per cell
  --char-colours a.bin  one colour per character ("char-locked" colour: the
                        game writes colour RAM from this table whenever it
                        writes a char, so colour never has to be stored per
                        map cell). Same bitmap with different colours becomes
                        different characters.
  --tiles WxH           also build meta-tiles: --tile-data tiles.bin
                        (W*H char codes per tile, row-major) and
                        --tile-map tilemap.bin (one tile index per block)
  --asm file.asm        constants: char count, map size, tile count

Colour rule violations are reported per cell with coordinates and the
conversion continues with the most frequent colour, so the artist gets a
full list in one run. --strict turns violations into an error.

Example:
  png2charset.py assets/level1.png --mode mc --bg black --mc1 darkgrey \\
      --mc2 grey -o build/chars.bin --map build/level1.map \\
      --char-colours build/chars.col --tiles 2x2 \\
      --tile-data build/tiles.bin --tile-map build/level1.tmap
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64img import COLOR_NAMES, die, parse_color, read_png, warn  # noqa: E402


def write(path, data):
    if not path:
        return
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as f:
        f.write(bytes(data))


def convert_cell(img, cx, cy, args, problems):
    """Return (bitmap bytes, colour RAM value) for one 8x8 cell."""
    ox, oy = cx * 8, cy * 8
    counts = {}
    if args.mode == "hires":
        pix = [[img.c64(ox + x, oy + y) for x in range(8)] for y in range(8)]
        for row in pix:
            for c in row:
                if c is not None and c != args.bg:
                    counts[c] = counts.get(c, 0) + 1
        colour = max(counts, key=counts.get) if counts else 1
        if len(counts) > 1:
            problems.append((cx, cy, "hires cell uses " + ", ".join(COLOR_NAMES[c] for c in sorted(counts))
                             + " besides the background (max 1)"))
        data = bytearray()
        for row in pix:
            byte = 0
            for x, c in enumerate(row):
                if c is not None and c != args.bg:
                    byte |= 0x80 >> x
            data.append(byte)
        return data, colour

    shared = {args.bg: 0b00, args.mc1: 0b01, args.mc2: 0b10}
    pix = []
    for y in range(8):
        row = []
        for p in range(4):
            a = img.c64(ox + p * 2, oy + y)
            b = img.c64(ox + p * 2 + 1, oy + y)
            if a != b:
                problems.append((cx, cy, f"pixel pair at ({p * 2},{y}) differs (multicolour pixels are 2 wide)"))
            a = args.bg if a is None else a
            row.append(a)
            if a not in shared:
                counts[a] = counts.get(a, 0) + 1
        pix.append(row)
    colour = max(counts, key=counts.get) if counts else 0
    if len(counts) > 1:
        problems.append((cx, cy, "cell uses " + ", ".join(COLOR_NAMES[c] for c in sorted(counts))
                         + " besides the 3 shared colours (max 1)"))
    if colour > 7:
        problems.append((cx, cy, f"cell colour {COLOR_NAMES[colour]} ({colour}) is not 0-7; "
                         "multicolour chars can only use colours 0-7 for bit pair 11"))
        colour &= 7
    data = bytearray()
    for row in pix:
        byte = 0
        for p, c in enumerate(row):
            byte |= shared.get(c, 0b11) << (6 - p * 2)
        data.append(byte)
    return data, colour | 8


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("png")
    ap.add_argument("-o", "--output", required=True, help="charset binary")
    ap.add_argument("--mode", choices=("hires", "mc"), default="hires")
    ap.add_argument("--bg", default="black", help="background colour ($d021)")
    ap.add_argument("--mc1", help="multicolour 1 ($d022)")
    ap.add_argument("--mc2", help="multicolour 2 ($d023)")
    ap.add_argument("--map", help="screen map output, one byte per cell")
    ap.add_argument("--colours", help="per-cell colour RAM output")
    ap.add_argument("--char-colours", help="per-character colour output (char-locked colour)")
    ap.add_argument("--first-char", type=int, default=0, help="code of the first emitted char (default 0)")
    ap.add_argument("--max-chars", type=int, default=256)
    ap.add_argument("--tiles", help="meta-tile size, e.g. 2x2 or 4x4")
    ap.add_argument("--tile-data", help="meta-tile definitions output")
    ap.add_argument("--tile-map", help="meta-tile map output")
    ap.add_argument("--asm", help="write size constants as assembler source")
    ap.add_argument("--strict", action="store_true", help="fail on any colour rule violation")
    args = ap.parse_args()

    args.bg = parse_color(args.bg)
    if args.mode == "mc":
        if args.mc1 is None or args.mc2 is None:
            die("--mode mc needs --mc1 and --mc2")
        args.mc1, args.mc2 = parse_color(args.mc1), parse_color(args.mc2)

    img = read_png(args.png)
    if img.width % 8 or img.height % 8:
        warn(f"{args.png}: {img.width}x{img.height} is not a multiple of 8; partial cells are ignored")
    cw, ch = img.width // 8, img.height // 8

    per_char_colour = args.char_colours is not None
    problems = []
    chars = []          # bitmaps
    char_cols = []      # colour per char (char-locked mode)
    index = {}
    cell_map = []
    cell_cols = []

    empty = bytes(8)
    empty_key = (empty, 0 if args.mode == "hires" else 8) if per_char_colour else empty
    index[empty_key] = 0
    chars.append(empty)
    char_cols.append(empty_key[1] if per_char_colour else 0)

    for cy in range(ch):
        for cx in range(cw):
            data, colour = convert_cell(img, cx, cy, args, problems)
            data = bytes(data)
            if data == empty:
                key = empty_key
            else:
                key = (data, colour) if per_char_colour else data
            if key not in index:
                index[key] = len(chars)
                chars.append(data)
                char_cols.append(colour)
            cell_map.append(index[key] + args.first_char)
            cell_cols.append(colour)

    shown = {}
    for cx, cy, msg in problems:
        if shown.get((cx, cy), 0) >= 2:
            continue
        shown[(cx, cy)] = shown.get((cx, cy), 0) + 1
        warn(f"cell ({cx},{cy}) at pixel ({cx * 8},{cy * 8}): {msg}")
    if problems and args.strict:
        die(f"{len(problems)} colour rule violation(s)")

    total = len(chars) + args.first_char
    if total > args.max_chars:
        die(f"{len(chars)} unique characters (+{args.first_char} reserved) exceed the limit of {args.max_chars}; "
            "reuse more tiles, simplify detail, or split the screen across two charsets with a raster split")

    write(args.output, b"".join(chars))
    write(args.map, cell_map)
    write(args.colours, cell_cols)
    write(args.char_colours, char_cols)

    tile_count = 0
    if args.tiles:
        tw, th = (int(v) for v in args.tiles.lower().split("x"))
        if cw % tw or ch % th:
            die(f"map of {cw}x{ch} cells is not a multiple of the {tw}x{th} tile size")
        tiles, tindex, tmap = [], {}, []
        for by in range(ch // th):
            for bx in range(cw // tw):
                key = tuple(cell_map[(by * th + y) * cw + bx * tw + x] for y in range(th) for x in range(tw))
                if key not in tindex:
                    tindex[key] = len(tiles)
                    tiles.append(key)
                tmap.append(tindex[key])
        if len(tiles) > 256:
            die(f"{len(tiles)} unique {tw}x{th} tiles exceed 256")
        tile_count = len(tiles)
        write(args.tile_data, [c for t in tiles for c in t])
        write(args.tile_map, tmap)
        print(f"  {tile_count} unique {tw}x{th} meta-tiles, tile map {cw // tw}x{ch // th}")

    if args.asm:
        os.makedirs(os.path.dirname(os.path.abspath(args.asm)), exist_ok=True)
        stem = os.path.splitext(os.path.basename(args.png))[0].upper().replace("-", "_")
        with open(args.asm, "w") as f:
            f.write(f"; generated by png2charset.py from {os.path.basename(args.png)}, do not edit\n")
            f.write(f"{stem}_CHARS = {len(chars)}\n{stem}_MAP_W = {cw}\n{stem}_MAP_H = {ch}\n")
            if args.tiles:
                f.write(f"{stem}_TILES = {tile_count}\n")

    print(f"{args.png}: {cw}x{ch} cells, {len(chars)} unique chars ({total}/{args.max_chars} codes used), "
          f"{len(problems)} colour problem(s) -> {args.output}")


if __name__ == "__main__":
    main()
