"""Shared helpers for the C64 asset converters: a dependency-free PNG
reader/writer and nearest-colour matching against the C64 palette.

Only the Python standard library is used, so the converters run anywhere
python3 runs (no Pillow needed).
"""

import struct
import sys
import zlib

# Pepto's PAL palette (the de facto reference used by VICE and most editors).
PALETTE = [
    (0x00, 0x00, 0x00),  # 0 black
    (0xFF, 0xFF, 0xFF),  # 1 white
    (0x68, 0x37, 0x2B),  # 2 red
    (0x70, 0xA4, 0xB2),  # 3 cyan
    (0x6F, 0x3D, 0x86),  # 4 purple
    (0x58, 0x8D, 0x43),  # 5 green
    (0x35, 0x28, 0x79),  # 6 blue
    (0xB8, 0xC7, 0x6F),  # 7 yellow
    (0x6F, 0x4F, 0x25),  # 8 orange
    (0x43, 0x39, 0x00),  # 9 brown
    (0x9A, 0x67, 0x59),  # 10 light red
    (0x44, 0x44, 0x44),  # 11 dark grey
    (0x6C, 0x6C, 0x6C),  # 12 grey
    (0x9A, 0xD2, 0x84),  # 13 light green
    (0x6C, 0x5E, 0xB5),  # 14 light blue
    (0x95, 0x95, 0x95),  # 15 light grey
]

COLOR_NAMES = [
    "black", "white", "red", "cyan", "purple", "green", "blue", "yellow",
    "orange", "brown", "lightred", "darkgrey", "grey", "lightgreen",
    "lightblue", "lightgrey",
]


def parse_color(value):
    """Accept a palette index (0-15) or a colour name."""
    v = str(value).strip().lower().replace("_", "").replace(" ", "")
    if v.isdigit() and 0 <= int(v) <= 15:
        return int(v)
    aliases = {"gray": "grey", "lightgray": "lightgrey", "darkgray": "darkgrey"}
    v = aliases.get(v, v)
    if v in COLOR_NAMES:
        return COLOR_NAMES.index(v)
    raise ValueError(f"unknown C64 colour: {value!r}")


_nearest_cache = {}


def nearest(rgb):
    """Nearest C64 palette index for an (r, g, b) tuple."""
    hit = _nearest_cache.get(rgb)
    if hit is not None:
        return hit
    r, g, b = rgb
    best, best_d = 0, None
    for i, (pr, pg, pb) in enumerate(PALETTE):
        d = (r - pr) ** 2 * 3 + (g - pg) ** 2 * 4 + (b - pb) ** 2 * 2
        if best_d is None or d < best_d:
            best, best_d = i, d
    _nearest_cache[rgb] = best
    return best


class Image:
    """Width, height and rows of (r, g, b, a) tuples."""

    def __init__(self, width, height, rows):
        self.width = width
        self.height = height
        self.rows = rows

    def pixel(self, x, y):
        return self.rows[y][x]

    def c64(self, x, y, transparent=None):
        """Palette index at (x, y); None if transparent (alpha < 128 or the
        given transparent palette index)."""
        r, g, b, a = self.rows[y][x]
        if a < 128:
            return None
        idx = nearest((r, g, b))
        if transparent is not None and idx == transparent:
            return None
        return idx


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG file")
    pos = 8
    ihdr = None
    palette = []
    trns = b""
    idat = []
    while pos < len(data):
        length, ctype = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", body)
        elif ctype == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif ctype == b"tRNS":
            trns = body
        elif ctype == b"IDAT":
            idat.append(body)
        elif ctype == b"IEND":
            break
    width, height, depth, ctype, _, _, interlace = ihdr
    if interlace:
        raise ValueError(f"{path}: interlaced PNGs are not supported, re-save without interlace")
    if ctype in (2, 4, 6) and depth != 8:
        raise ValueError(f"{path}: only 8-bit RGB/RGBA/grey+alpha PNGs are supported")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    bits_pp = channels * depth
    stride = (width * bits_pp + 7) // 8
    bpp = max(1, bits_pp // 8)
    raw = zlib.decompress(b"".join(idat))

    rows = []
    prev = bytearray(stride)
    i = 0
    for _ in range(height):
        ftype = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if ftype == 1:
                line[x] = (line[x] + a) & 0xFF
            elif ftype == 2:
                line[x] = (line[x] + b) & 0xFF
            elif ftype == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 0xFF
            elif ftype == 4:
                line[x] = (line[x] + _paeth(a, b, c)) & 0xFF
        prev = line

        px = []
        if ctype == 3 or (ctype == 0 and depth < 8):
            mask = (1 << depth) - 1
            for x in range(width):
                bit = x * depth
                v = (line[bit // 8] >> (8 - depth - bit % 8)) & mask
                if ctype == 3:
                    r, g, b = palette[v]
                    a = trns[v] if v < len(trns) else 255
                else:
                    g = v * 255 // mask
                    r, b, a = g, g, 255
                px.append((r, g, b, a))
        elif ctype == 0:
            px = [(v, v, v, 255) for v in line]
        elif ctype == 2:
            px = [(line[j], line[j + 1], line[j + 2], 255) for j in range(0, len(line), 3)]
        elif ctype == 4:
            px = [(line[j], line[j], line[j], line[j + 1]) for j in range(0, len(line), 2)]
        elif ctype == 6:
            px = [tuple(line[j:j + 4]) for j in range(0, len(line), 4)]
        rows.append(px)
    return Image(width, height, rows)


def write_png(path, width, height, rows):
    """rows: list of lists of (r, g, b) or (r, g, b, a)."""
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for p in row:
            raw.extend(p[:3])
            raw.append(p[3] if len(p) > 3 else 255)

    def chunk(tag, body):
        out = struct.pack(">I", len(body)) + tag + body
        return out + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        f.write(chunk(b"IEND", b""))


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def warn(msg):
    print(f"warning: {msg}", file=sys.stderr)
