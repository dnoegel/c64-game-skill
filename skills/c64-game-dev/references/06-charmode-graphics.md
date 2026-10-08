# 06 - Character Graphics, Tiles and Softsprites

Character mode is where C64 games live. This document covers the graphics modes, tile
engines, charset animation, colour RAM handling, and software sprites.

---

## 1. Why character mode

| | Character mode | Bitmap mode |
|---|---|---|
| Memory | 2 KB charset + 1 KB screen | 8 KB bitmap + 1 KB screen |
| Draw a 8×8 block | 1 byte write | 8 byte writes |
| Full screen redraw | 1000 bytes | 8000 bytes |
| Animation | Redefine 1 char → all instances animate free | Redraw every instance |
| Hardware scroll | Yes ($D011/$D016 + row/column shift) | Yes, but the shift costs 8× |
| Colour resolution | 1 colour per 8×8 cell (+ shared) | 2 colours per 8×8 cell (from screen RAM) + 1 shared |
| Distinct tiles | 256 | unlimited |

The 8× data-volume difference is decisive. **Use character mode for gameplay screens;
reserve bitmap for title screens, cutscenes, and end pictures.**

---

## 2. The character modes in detail

### Standard (hires) text - `ECM=0, BMM=0, MCM=0`
- 8×8 pixels, 1 bit per pixel.
- Colour: foreground from colour RAM (`$D800+offset`, 16 colours), background from `$D021`
  (global).
- Crisp, but only two colours per cell.

### Multicolour text - `MCM=1`
- 4×8 "fat pixels", 2 bits per pixel.
- Per-cell colour RAM value determines the mode:
  - Colour RAM value **0–7**: the cell renders as **hires** with that foreground colour.
    (Bit 3 of the colour nibble is the multicolour flag.)
  - Colour RAM value **8–15**: the cell renders as multicolour, using colour `value − 8`
    for bit-pair `11`.
- Bit pairs: `00` → `$D021`, `01` → `$D022`, `10` → `$D023`, `11` → colour RAM `& 7`.
- **This mixed-mode capability is a huge deal**: you can put hires detail (text, thin
  lines, sharp edges) into a multicolour screen on a per-cell basis at no extra cost.

### Extended background colour mode (ECM) - `ECM=1`
- Only **64 characters** usable (top 2 bits of the screen code select one of 4
  backgrounds `$D021`–`$D024`).
- Rarely used in games - losing 192 chars usually isn't worth 3 extra background colours.
- Combining ECM with sprites: note that ECM makes the VIC read from `$3FFF` for certain
  addresses, which interacts with border tricks.

### Invalid modes
Setting `ECM=1` together with `BMM` and/or `MCM` produces a black screen. Demos use this
deliberately (fast screen blanking that still generates bad lines). For a game, the
useful blanking is `DEN=0` in `$D011` bit 4.

---

## 3. Colour RAM - the recurring problem

```
$D800-$DBFF   1000 nibbles, 4 bits each
```

- **Cannot be relocated.** Not affected by the VIC bank.
- **Cannot be double-buffered** in hardware.
- The upper 4 bits are undefined - always mask with `and #$0f` when reading.
- Writing it is as expensive as writing screen RAM, so a full-screen colour update is
  another 1000 bytes of work.

### Consequences
- **8-way scrolling is expensive** primarily because of colour RAM: when a new column
  scrolls in you must write 25 screen bytes *and* 25 colour bytes; a new row is 40 + 40.
- The classic mitigation: **use a single global colour scheme per screen region** so
  colour RAM only changes when the whole screen changes. Many scrolling games colour the
  entire playfield with one or two colours and rely on multicolour bit patterns for
  variety.
- Second mitigation: **char-locked colour**. Reserve colour by character index - e.g.
  chars 0–63 are always colour 5, 64–127 always colour 12. Then colour RAM is a pure
  function of the screen code, and you can write it from a 256-byte lookup table in the
  same loop that writes screen RAM (adds ~4 cycles/cell).
- Third mitigation: **don't scroll vertically**. Horizontal-only scrolling touches 25
  colour cells per column instead of 40 per row.
- Fourth: some engines only refresh colour RAM every other frame, accepting a one-frame
  colour lag at the scroll-in edge. Usually invisible.

---

## 4. Tile / map engines

The universal structure:

```
charset       256 chars x 8 bytes                              = 2048 bytes
tileset       N tiles, each 2x2 or 4x4 chars                   = N*4 or N*16 bytes
tile colours  N bytes (one colour per tile)                    = N bytes
map           W x H tile indices                               = W*H bytes
```

A 4×4-char tile means one map byte covers 32×32 pixels - a 100×100 tile world is 10 KB
and covers 3200×3200 pixels. This is how large C64 worlds fit in memory.

**CharPad C64 Pro** produces exactly this data structure (charset, tiles, tile colours,
map, char attributes) and exports binary or assembler source. It is the de-facto standard
tool and worth the ~$15.

### Screen composition
Two approaches:

1. **Draw from the map every time the view moves** - decode tile → 4 or 16 chars, write
   to screen RAM. Cheap if you only redraw the incoming row/column.
2. **Keep a "virtual screen"** of chars (e.g. 41×26 bytes) and copy the visible window.
   Simpler logic, but the copy is expensive. Only worth it if the copy is unrolled
   speedcode.

For scrolling, always use approach 1 with an incremental column/row update - see
[`07-scrolling.md`](07-scrolling.md).

---

## 5. Charset animation - the cheapest visual effect on the platform

Because every screen cell using character N renders whatever the 8 bytes at
`charbase + N*8` currently contain, **rewriting 8 bytes animates every instance of that
character simultaneously**.

```asm
; animate 4 water chars, 4 frames, 8 bytes each
anim_water:
    ldx anim_frame
    lda frame_lo,x
    sta src+1
    lda frame_hi,x
    sta src+2
    ldy #32-1           ; 4 chars x 8 bytes
src:lda $ffff,y
    sta charbase + WATER_CHAR*8,y
    dey
    bpl src
```

32 bytes copied = ~350 cycles for animated water across the entire screen. Compare with
redrawing sprites or bitmap.

**Uses:** water, lava, conveyor belts, sparkles, flickering torches, rotating machinery,
scrolling starfields, energy bars, animated backgrounds, "pulsing" UI.

**Colour cycling** is the sibling trick: rotate the values in `$D021`–`$D024` or in
`$D025/$D026` for animated shading at zero data cost.

### Char-based counters and bars
An HP/energy bar made of 9 chars (empty → full) is one screen byte write per update, and
looks like smooth pixel-level animation.

---

## 6. Software sprites ("softsprites")

Drawing movable objects directly into the charset instead of using hardware sprites.

### When to use them
- You've run out of hardware sprites *on a raster line*.
- Objects that are static-ish or move on a grid (bubbles, blocks, bullets in a
  single-screen game).
- Ports of Spectrum games where the original was all software sprites anyway.
- Backgrounds that must interact pixel-precisely with the object.

Real examples: *Heartland* (hardware sprite player, softsprite enemies), *Underwurlde*
(softsprite bubbles/rope), *Bubble Bobble* (softsprites, made feasible by simple
non-scrolling backgrounds), *Fairlight* and *Rogue Trooper* (all-softsprite ports).

### How it works

1. Reserve a pool of "dynamic" characters (e.g. chars 200–255 = 56 chars = 7×8 cells).
2. When an object occupies screen cells, allocate dynamic chars for those cells.
3. Copy the background tile's char data into the dynamic char, then OR/mask the object's
   pre-shifted bitmap into it.
4. Write the dynamic char indices into screen RAM.
5. Next frame, restore (or just reallocate) and repeat.

### Cost
A 16×16 object straddles up to 3×3 = 9 cells → 9 chars × 8 bytes = 72 bytes of background
copy + 72 bytes of mask/OR = roughly **1,000–1,500 cycles per object per frame**. That's
~8% of the frame for one object. Ten softsprites is not happening at full speed.

### Pre-shifting
The expensive part is bit-shifting the object to a sub-character X position. Solution:
**store 8 pre-shifted copies** (or 4 for multicolour, where the granularity is 2 pixels).
Costs 8× the data but turns the draw into a straight `lda / ora / sta` sequence.

Multicolour softsprites only need **4** pre-shift positions (x mod 4, since pixels are
2 wide) - that's the usual arrangement, e.g. 8×16 multicolour sprites with 4 shift
variants.

### Masking
For proper occlusion you need both an AND mask (clear the object's footprint) and an OR
mask (draw the object):
```asm
    lda screen_char_data,y
    and mask,y
    ora sprite,y
    sta dynamic_char,y
```
3 extra cycles per byte. Store mask and data interleaved to avoid two index registers.

### Verdict
Use hardware sprites plus multiplexing for actors. Use softsprites for a **small, bounded
number** of special objects, or for a game deliberately designed around a static screen.
Do not build a scrolling action game on softsprites.

---

## 7. Bitmap mode (when you do need it)

- **Standard bitmap** (`BMM=1`): 320×200, 8 KB. Per 8×8 cell, 2 colours taken from screen
  RAM (`hi nibble` = foreground, `lo nibble` = background). Colour RAM unused.
- **Multicolour bitmap** (`BMM=1, MCM=1`): 160×200 fat pixels, 8 KB. Per cell, bit pairs
  select: `00` → `$D021` (global), `01` → screen RAM hi nibble, `10` → screen RAM lo
  nibble, `11` → colour RAM. **Three per-cell colours + one global** - the best colour
  fidelity the C64 offers without tricks.

Row addressing in bitmap mode is awkward: byte address =
`base + (row * 320) + (col * 8) + pixel_row`. Precompute a 25-entry table of
`row * 320` lo/hi.

### FLI (Flexible Line Interpretation)
By changing `$D018` (and forcing a bad line) on **every** raster line, you make the VIC
re-fetch colour data every line instead of every 8 - giving per-line colour resolution
(effectively 8× the colour detail). Cost: it consumes essentially the entire CPU, needs a
stable raster, uses 8 screen RAMs (8 KB), and leaves the leftmost 3 pixels of each cell
undefined (the "FLI bug").

**Not usable for gameplay.** Excellent for title screens and cutscenes where nothing else
happens. Also degrades badly on NTSC.

---

## 8. Practical layout recommendations

For a typical character-mode game:

```
Charset          2 KB   (one 256-char set; consider 2 sets for split screens)
Screen RAM       1 KB   (2 KB if double-buffering the screen)
Sprite data      2-8 KB (inside the same VIC bank)
```

All of the above must fit in **one 16 KB VIC bank**, minus $1000–$1FFF if you're in bank
0 or 2 (char ROM shadow). A common layout in bank 1 ($4000–$7FFF):

```
$4000-$47FF   charset (2 KB)
$4800-$4BFF   screen 0 (1 KB, sprite pointers at $4BF8)
$4C00-$4FFF   screen 1 (1 KB, for double-buffering / status split)
$5000-$5FFF   sprite data (4 KB = 64 sprites)
$6000-$7FFF   free for map data / code
```

See [`08-memory-layout.md`](08-memory-layout.md) for full-system planning.

---

## 9. Split screens: two graphics modes in one frame

A raster IRQ can change `$D011`, `$D016`, and `$D018` mid-frame. This gives you:

- **Status bar in hires text, playfield in multicolour** - change `$D016` bit 4 at the
  boundary line.
- **Different charsets top and bottom** - change `$D018` bits 3–1. Effectively **512
  distinct characters** on one screen.
- **Different screen RAM** - change `$D018` bits 7–4, useful for a fixed status panel
  that isn't disturbed by scrolling.
- **Bitmap panel + character playfield** - change `$D011` bit 5.

Rules:
- Write `$D018` in the **border between text rows** or accept a glitched line. The safest
  point is during the last raster line of a character row (when the VIC has already
  fetched that row's data), or in the border.
- Changing `$D011` YSCROLL at a boundary can create/destroy a bad line - account for it.
- The IRQ doesn't need to be cycle-stable for `$D018`/`$D016` changes if the boundary is
  in a horizontal border region or the change is visually forgiving. It **does** need
  stability if the change is visible mid-row.

This is one of the highest-value/lowest-cost tricks available: a status bar with its own
charset and colour scheme costs one IRQ.
