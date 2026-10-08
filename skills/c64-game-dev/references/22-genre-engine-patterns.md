# 22 - Engine Patterns by Genre

Concrete architectural recipes. Each section gives the memory model, the frame budget, and
the specific techniques from files 03–08 that apply.

---

## 1. Single-screen arcade

*Bubble Bobble*, *Boulder Dash*, *Pac-Man*-likes.

```
Screen:      one static screen, redrawn on level change
Scroll:      none
Sprites:     full 8 available, multiplexer optional
Budget:      ~17,000 cycles for gameplay (no scroll cost)
```

**Architecture**
- Level = a 40×25 char map (1000 bytes) or a compact tile map, decompressed on level start.
- Entities move in pixel space over a static background.
- Collision against the **char map**, not sprite registers: convert entity position to a
  cell index and look up the tile's properties in a 256-byte attribute table.

```asm
; entity (x,y) -> screen cell -> tile property
    lda ent_y,x
    lsr
    lsr
    lsr                 ; y/8 = row
    tay
    lda rowlo,y
    sta ptr
    lda rowhi,y
    sta ptr+1
    lda ent_xhi,x
    lsr
    lsr
    lsr                 ; x/8 = column
    tay
    lda (ptr),y         ; char code at that cell
    tax
    lda char_props,x    ; solid / hazard / collectible / empty
```

**Why start here:** almost the entire frame budget goes to gameplay. You can afford
softsprites, particle effects, physics, and complex AI. It's also the genre where good
design is most visible.

**Techniques:** charset animation for background life; colour cycling; sprite overlays for
a detailed player; raster splits for a status bar.

---

## 2. Flip-screen exploration (platformer / adventure)

*Soulless*, *Joe Gunn*, *Nixy*, *Jet Set Willy* lineage.

```
Screen:      one screen at a time, transition on edge exit
Scroll:      none (or a short wipe/fade transition)
Sprites:     8 + multiplexer for enemies
Budget:      ~15,000 cycles gameplay; a burst on transition
```

**Architecture**
- World = grid of rooms; each room = a compressed screen or a tile-map region.
- Room data stored compressed; decompress on entry with the screen blanked
  (`$D011` bit 4 = 0) - a 1–2 frame black flash that reads as a deliberate transition.
- Entity state per room: either persistent (an array of room states) or respawn-on-entry.
- Player position carries across; entities are re-spawned from a per-room spawn table.

**Room data budget**
```
100 rooms x 1000 bytes raw           = 100 KB   -> impossible
100 rooms x 250 bytes (tile map)     =  25 KB   -> tight but possible
100 rooms x ~100 bytes (compressed)  =  10 KB   -> comfortable
```
This is why tile maps + compression is the standard.
See [`06-charmode-graphics.md`](06-charmode-graphics.md) §4 and
[`12-compression.md`](12-compression.md).

**Why this is the best fit for a first serious project:** big-feeling worlds, zero scroll
cost, natural chunking for loading, and a content pipeline (draw rooms in CharPad) that a
dedicated artist can drive independently.

---

## 3. Horizontal scrolling shooter

*Armalyte*, *Katakis*, *Uridium*.

```
Scroll:      horizontal only, 1-4 px/frame
Sprites:     multiplexer essential (16-24)
Budget:      ~10,000 cycles gameplay after scroll cost
```

**Architecture**
- **Banded playfield.** Scroll only 16–20 rows; put a status panel in the rest via a
  raster split. Shifting 16×40 = 640 screen bytes + 640 colour bytes is affordable when
  amortised; shifting 25 rows usually isn't.
- **XSCROLL + amortised char shift.** Decrement `$D016` bits 2–0 each frame; when it
  wraps, shift the screen one column. Spread the shift across the 8 frames between wraps
  by moving 2–3 rows per frame.
- **Colour RAM is the bottleneck.** Use char-locked colour (colour = f(char code)) so the
  colour write happens in the same loop as the screen write from a 256-byte table.
- **Attack waves as data.** A scroll-position-indexed table of `(spawn_x, type, y, path)`.
  A wave table plus a set of movement-pattern tables is how every shooter does this - it's
  what SEUCK's "Attack Waves" designer produced, and it's still the right structure.

```asm
; movement patterns as delta tables, indexed by entity's pattern + phase
pattern_dx:  .byte  2, 2, 2, 1, 0,-1,-2,-2 ...
pattern_dy:  .byte  0, 1, 2, 2, 2, 1, 0,-1 ...
```

**Techniques:** sprite multiplexing; opened top/bottom border for the status area; raster
splits for a sky gradient; charset animation for scrolling starfields and parallax bands.

**Parallax cheaply:** a second scroll layer via **colour splits** or by animating a
charset (shifting the pixels within characters) rather than moving data. Full data-moving
parallax is usually unaffordable.

---

## 4. Multidirectional scrolling action

*Turrican*, *Steel Ranger*, *Sam's Journey*.

**This is the expensive one.** The colour RAM problem is unavoidable: scrolling vertically
means writing 40 screen + 40 colour bytes per row, and diagonally means both axes.

**The reference implementation is `c64gameframework`** - read it before building your own.
Its answers:
- 22 visible scrolling rows (not 25) - reduces per-row cost and leaves border room
- 24-sprite multiplexer
- **Actor logic at 25 Hz** (every second frame), with **sprite positions interpolated at
  50 Hz**. Halves logic cost while looking smooth. This is the key trick
- **Realtime sprite depacking into a sprite cache** - decouples total animation data from
  the 16 KB VIC bank
- Dynamic memory allocation for sprites, level data, and code

**If you build your own:** budget realistically. A full 8-way scroller leaves perhaps
6,000–8,000 cycles for gameplay. Everything else must be lean.

**Alternative:** AGSP (VSP + linecrunch) makes the scroll nearly free but carries the
VSP crash risk and costs the top 12 % of the screen. See
[`07-scrolling.md`](07-scrolling.md) §4–5.

---

## 5. Vertical scrolling shooter

Cheaper than horizontal, because `$D018` moves the screen base in 1 KB steps.

**Architecture**
- Two 1 KB screen buffers. Scroll YSCROLL (`$D011` bits 2–0) down; when it wraps, flip
  `$D018` to the other buffer and fill the newly exposed row off-screen.
- Or: use a taller-than-screen buffer and step `$D018` - but the 1 KB granularity means
  you need the double-buffer flip anyway.
- Row updates are 40 screen + 40 colour bytes, once every 8 frames at 1 px/frame.

**Techniques:** linecrunch/FLD for start-position adjustment; colour splits for depth
bands.

---

## 6. Isometric / pseudo-3D adventure

*Last Ninja*, *Knight Lore* lineage.

**The hard parts:** depth sorting, masking (things in front of and behind the player), and
the sheer volume of graphics.

**Architecture**
- Room = a static bitmap or char screen, drawn once on entry.
- Movable objects = sprites, depth-sorted by their position along the depth axis, mapped
  onto hardware sprite priority (sprite 0 = frontmost).
- Sprite-vs-background occlusion via `$D01B` (sprite behind foreground) plus careful art:
  make "in front" scenery use foreground bit patterns and "behind" scenery use background
  patterns.
- Where hardware priority isn't enough, **softsprites** with AND/OR masks
  ([`06-charmode-graphics.md`](06-charmode-graphics.md) §6).

**The Last Ninja's key idea: real-time sprite decompression.** The graphics volume exceeds
memory, so store compressed and depack on demand. This is the same pattern as Cadaver's
sprite cache - see [`19-case-studies.md`](19-case-studies.md) §4.

---

## 7. Turn-based / RPG / dungeon crawler

*Eye of the Beholder*.

**CPU is not the constraint. Data volume is.**

**Architecture**
- Everything is a table: monsters, items, spells, rooms, text.
- **Text is expensive.** 40×25 chars, and dialogue adds up fast. Compress strings (a
  dictionary of common words plus byte codes is very effective and cheap to decode).
- **Cartridge is strongly indicated.** *Eye of the Beholder* stalled for 12 years on
  memory and only shipped once it targeted a 1 MB EasyFlash.
- With a cartridge, treat ROM banks as a random-access asset store: room graphics,
  monster sprites, text blocks paged in on demand.
- Custom build tooling for bank assignment is near-mandatory at scale (JackAsser wrote a
  pre-linker for exactly this).

**Techniques:** raster splits for a permanent UI panel; `$D018` charset switching so the
UI has its own font; sprite multiplexing barely needed.

---

## 8. Puzzle

Cheapest genre to implement, highest design leverage.

- Board = a small 2D array; render is a direct map to screen cells.
- No scrolling, minimal sprites (or none - use charset animation for pieces).
- Almost the entire frame budget is free, so you can afford elaborate transitions,
  particle effects, and a rich UI.
- Content is generated or hand-authored levels - tiny data.

**Very strong candidate for a first project or a 16 KB compo entry.**

---

## 9. Racing / pseudo-3D road

- Road drawn as horizontal bands; per-band `$D021`/`$D022` colour changes via raster IRQ
  create the road edges without drawing anything.
- Curvature = per-line X offset, driven by a table - a raster IRQ writing `$D016` XSCROLL
  per band, or per-line char shifts.
- Roadside objects = sprites, scaled with `$D017`/`$D01D` expansion (2 sizes) or with
  **sprite stretching** for continuous scaling
  ([`05-sprites.md`](05-sprites.md) §5).
- Horizon = a raster split.

Very raster-IRQ-heavy; needs a stable raster.

---

## 10. Choosing: a decision table

| If you want… | Build… |
|---|---|
| To ship something in 6 months | Single-screen arcade or puzzle |
| A big world with modest engine cost | Flip-screen exploration |
| The classic C64 feel | Horizontal shooter |
| To push the platform | Multidirectional scroller (start from `c64gameframework`) |
| A content-heavy game | Cartridge + flip-screen or dungeon crawler |
| To enter the RGCD 16 KB compo | Single-screen arcade or puzzle |

**Default recommendation for a first game:** flip-screen exploration or a banded horizontal
scroller. Both are genuinely achievable, both look impressive, both leave enough budget
that the game can be *good* rather than merely technically interesting.
