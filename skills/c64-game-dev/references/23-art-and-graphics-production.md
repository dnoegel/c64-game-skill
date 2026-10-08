# 23 - Art and Graphics Production

The C64's visual identity comes from a fixed 16-colour palette and strict per-cell colour
rules. Understanding those rules is what separates art that looks like a C64 game from art
that looks like a bad photo conversion.

---

## 1. The palette

16 fixed colours. No palette registers, no shading beyond what's there.

| # | Name | | # | Name |
|---|---|---|---|---|
| 0 | Black | | 8 | Orange |
| 1 | White | | 9 | Brown |
| 2 | Red | | 10 | Light red |
| 3 | Cyan | | 11 | Dark grey |
| 4 | Purple | | 12 | Grey |
| 5 | Green | | 13 | Light green |
| 6 | Blue | | 14 | Light blue |
| 7 | Yellow | | 15 | Light grey |

### Luminance ordering (the artist's most important tool)

Sorted dark → light:
```
0 Black · 6 Blue · 9 Brown · 11 Dark grey · 2 Red · 4 Purple · 8 Orange ·
12 Grey · 14 Light blue · 5 Green · 10 Light red · 15 Light grey ·
3 Cyan · 13 Light green · 7 Yellow · 1 White
```

Useful ramps:
- **Greys:** 0 → 11 → 12 → 15 → 1 (five clean steps - the backbone of most C64 art)
- **Blues:** 0 → 6 → 14 → 3 → 1
- **Warm:** 0 → 9 → 2 → 8 → 7 → 1
- **Greens:** 0 → 5 → 13 → 7 → 1

Anything that reads as a smooth gradient must be built from a luminance ramp. Two colours
of similar luminance (e.g. 4 purple and 8 orange) will fight rather than blend.

---

## 2. Colour rules by mode

### Multicolour character mode (the workhorse)
- **4 colours per 8×8 cell**, but the pixels are **4×8 fat pixels** (2 pixels wide).
- Bit pairs: `00` → `$D021` (global background), `01` → `$D022` (global), `10` → `$D023`
  (global), `11` → **colour RAM for that cell** (0–7 only).
- So: **three globally shared colours + one free colour per cell**, and that free colour is
  limited to the first 8 palette entries.
- **The mixed-mode trick:** a colour RAM value of 0–7 renders that cell as **hires** with
  that foreground colour. So you can drop sharp, full-resolution detail into a multicolour
  screen on a per-cell basis at zero extra cost. Use it for text, thin lines, and edges.

### Standard (hires) character mode
- 8×8 full-resolution pixels, **2 colours per cell**: foreground from colour RAM (any of
  16), background from `$D021` (global).
- Sharp but flat. Good for text, UI, and stylised line-art games.

### Multicolour bitmap
- 160×200 fat pixels. Per cell: `00` → `$D021` (global), `01` → screen RAM hi nibble,
  `10` → screen RAM lo nibble, `11` → colour RAM.
- **Three free per-cell colours + one global** - the best colour fidelity available.
- 8 KB + 1 KB. For title screens and cutscenes only.

### Sprites
- Hires: 24×21, **1 colour** + transparent.
- Multicolour: 12×21 fat pixels - `01` and `11` are **globally shared** (`$D025`/`$D026`),
  `10` is the sprite's own colour.
- **Overlay is how you escape this.** See below.

---

## 3. The sprite overlay convention

The defining look of modern C64 sprites, used throughout *Sam's Journey*:

```
Sprite n     (lower number = on top): HIRES, black - outlines, eyes, sharp detail
Sprite n+1   (higher number = behind): MULTICOLOUR - body, shading
```

This gives you:
- Full 24-pixel horizontal resolution for outlines and detail
- 3 colours + transparency for the body
- A crisp silhouette that reads against any background

Two multicolour sprites stacked instead gives **5 colours** (2 own + 2 shared +
transparent) at 12×21 chunky resolution.

**Cost:** 2 hardware sprites per character. With a 24-sprite multiplexer that's 12 logical
actors - usually plenty.

### The shared-colour problem and its fix
`$D025`/`$D026` are shared by *all* sprites. If your hero needs skin tones and your enemy
needs metal tones, they collide. Fixes:
1. **Design a shared palette** - pick two shared colours that work for everything
   (a mid-grey and a dark tone are common choices).
2. **Raster-split the shared colours** - change `$D025`/`$D026` at a raster line so the
   top half of the screen uses one pair and the bottom another. Costs one IRQ.
   ([`07-scrolling.md`](07-scrolling.md) §8.)
3. Put unique colour in the per-sprite register (`$D027+n`), which *is* free per sprite.

---

## 4. Dithering

With a fixed palette and no blending, **dithering is how you get intermediate tones**.

- **Checkerboard (50 %)** between two adjacent luminance steps is the workhorse.
- **Sparse dithering** (1-in-4, 1-in-8) for subtle gradients.
- On the C64 the pixels are **non-square** (especially in multicolour, where they're 2:1),
  which gives C64 dithering its distinctive horizontal-streak character. Embrace it - it's
  part of the platform's look.
- Dither *between adjacent luminance steps only*. Dithering red against cyan produces
  noise, not a colour.

### Practical workflow
A technique used by modern C64 artists: dither a source image to three greyscale levels
first (ImageMagick or any raster tool), *then* map those levels onto a C64 luminance ramp.
The structure survives the conversion far better than a direct colour quantisation.

---

## 5. Charset design

You have **256 characters** (fewer if you reserve some for softsprites or UI). That's the
real constraint on visual variety.

### Budgeting characters

```
 0- 15   UI / status bar / font digits
16- 47   Font (A-Z, punctuation)  [or use a separate charset via $D018 split]
48-199   Level tiles
200-255  Dynamic / animated / softsprite pool
```

Two charsets via a `$D018` raster split gives you **512 characters** - one for the
playfield, one for UI and text. This is cheap (one IRQ) and very commonly done.

### Getting more from 256 chars
- **Tiles of 2×2 or 4×4 chars.** A 4×4 tile is 16 chars but is reused across the whole
  map; you might have 40 tiles built from 150 chars.
- **Reuse aggressively.** Solid fills, edges, and corners recur constantly. A disciplined
  artist gets 3–4× more visual variety from the same char count.
- **Mirror in art, not in data.** Design tiles that read the same flipped, so one char
  serves both sides of a symmetric object.
- **Colour variation.** The same char in a different colour RAM value reads as a different
  material. Free variety.
- **Animate rather than duplicate.** Redefining 8 bytes animates every instance - see
  [`06-charmode-graphics.md`](06-charmode-graphics.md) §5.

### Char-locked colour
If your engine derives colour RAM from the character code (a 256-byte lookup), the artist
must accept that **each character has exactly one colour everywhere it appears**. This is a
significant art constraint but a huge engine win for scrolling games. **Decide this before
art production starts** - retrofitting it means redrawing everything.

---

## 6. Tools

| Tool | Purpose | Notes |
|---|---|---|
| **CharPad C64 Pro** | Charsets, tiles, tile colours, maps, char attributes | The standard. ~$15, actively maintained (3.8.x, 2025). Exports binary/asm/PNG. Also reads/writes SEUCK format |
| **SpritePad C64 Pro** | Sprite sets, animation, overlays | Companion tool, same vendor |
| **Spritemate** | Browser sprite editor, free | Multicolour, overlays, SpritePad import, **assembly source export**, can extract sprites from a VICE snapshot. <https://www.spritemate.com> |
| **Multipaint** | Bitmap art (multicolour/hires) across 8-bit formats | For title screens |
| **Aseprite** | General pixel art | Used by modern C64 devs (e.g. *Cab Hustle*) for the drawing, then converted with a script. Better animation tooling than C64-native editors |
| **C64 Studio** | IDE with built-in charset/sprite/media editors | Georg Rottensteiner's; one integrated environment |
| **Lospec** | Tutorials + palette reference | <https://lospec.com/pixel-art-tutorials/tags/c64> |

### The Aseprite route
Draw in Aseprite with the C64 palette loaded and a constraint-aware grid, then convert with
a script. You get modern animation tools (onion skinning, timelines, tags) at the cost of
having to enforce the colour rules yourself. Several shipping games used this. **The risk
is drawing something the hardware can't display** - build the validator into your converter
so it errors loudly.

---

## 7. Art pipeline

```
assets/
  charset.ctm       CharPad source     ─┐
  sprites.spd       SpritePad source   ─┼─> tools/convert_assets.py ─> build/*.bin
  title.kla         Multipaint source  ─┘                              (engine layout)
```

Rules:
1. **Keep the editor source files in version control.** Export binaries in the build.
2. **Write a converter** that turns the tool's export into your engine's exact layout
   (de-interleaving, reordering, appending colour tables, generating tile property tables).
   Never hand-edit exported binaries.
3. **Validate in the converter.** Assert: no cell uses more colours than the mode allows;
   colour RAM values are in range; char count is within budget; sprite count fits the
   allocated region. Fail the build, don't ship a glitch.
4. **Print an asset budget report** each build: chars used, sprites used, bytes consumed.

---

## 8. Art direction advice

- **Commit to a limited palette per area.** Two or three colours plus black and white reads
  far better than using all 16. The strongest-looking C64 games are colour-disciplined.
- **Silhouette first.** At 24×21 with fat pixels, shape is everything. If the silhouette
  doesn't read, no amount of internal detail will save it.
- **Black outlines.** The overlay technique exists for this reason. Black separates
  everything from everything and is free (it's usually `$D021`/transparent).
- **Contrast the player against everything.** The player should be the brightest or most
  saturated thing on screen, always.
- **Design the background to recede.** Low contrast, mid-luminance colours, less detail.
  Foreground and hazards get contrast.
- **Fewer, better animation frames.** *International Karate +* is the reference: 4 great
  frames beat 8 mediocre ones, and cost half the RAM.
- **Test on a real display.** Composite output on a CRT blurs adjacent pixels and makes
  dithering blend; an HDMI-upscaled FPGA machine shows every pixel sharply. Your art will
  look different on the two. The Ultimate II+ in a real C64 with real video output is the
  honest test.

---

## 9. Common art mistakes

| Mistake | Consequence |
|---|---|
| Designing sprites without the overlay in mind | Flat, 80s-looking characters |
| Ignoring the fat-pixel aspect ratio | Everything looks horizontally squashed in-game |
| Using all 16 colours | Visual noise; nothing reads |
| Dithering across luminance jumps | Noise instead of gradient |
| Forgetting `$D025`/`$D026` are shared | Sprites that can't coexist |
| Drawing tiles without a char budget | Running out of characters at level 3 |
| Not deciding char-locked colour up front | A full art redo mid-project |
| Detail that disappears at 160×200 | Wasted effort |
| Testing only in an upscaled emulator | Art that looks wrong on real hardware |
