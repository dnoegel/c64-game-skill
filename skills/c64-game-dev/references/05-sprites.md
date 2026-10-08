# 05 - Sprites: Limits, Hacks and Tricks

The VIC-II gives you 8 sprites. This document is about how to make that feel like 24, 32,
or more - and how to work around every other sprite limitation.

---

## 1. The hard limits (and which ones are real)

| Limit | Real? | Workaround |
|---|---|---|
| 8 sprites total | **No** | Multiplexing - reuse each sprite several times per frame |
| 8 sprites per raster line | **Yes, absolute** | None. Design so ≤8 overlap vertically |
| 24×21 px | No | Overlays and grouping; sprite stretching for larger |
| 1 colour (hires) / 3 colours (multicolour) | No | Overlay sprites |
| $D025/$D026 shared by all sprites | Partly | Raster-split the shared colours mid-screen |
| Sprite data must be in the VIC bank | Yes | Bank switching, or copy into a "sprite window" |
| 63 bytes per frame of animation | Yes | Costs RAM: 64 bytes × frames × directions |

The **only** truly unbreakable rule is 8 sprites per raster line. Everything else is
negotiable.

---

## 2. Sprite basics recap

```
Data:      63 bytes (24x21 bits), padded to 64
Address:   vic_bank + (pointer * 64)     pointer at screen_base + $3F8 + n
Position:  $D000+2n (X low), $D001+2n (Y), $D010 bit n (X bit 8)
Screen:    X = 24, Y = 50 is the top-left of the display window
Visible X: roughly 0..343 with borders open; sprite disappears past ~344 (PAL wrap at 404)
```

Multicolour sprite bit pairs:

| Bits | Colour |
|---|---|
| `00` | transparent |
| `01` | `$D025` - shared multicolour 0 |
| `10` | `$D027+n` - this sprite's own colour |
| `11` | `$D026` - shared multicolour 1 |

Priority: **sprite 0 is on top, sprite 7 at the bottom.** `$D01B` bit n = 1 puts sprite n
*behind* the foreground graphics (non-background pixels). In multicolour text mode, only
bit-pairs `01` and `10` count as "background" for priority purposes, which is the classic
trick for making tiles that sprites walk behind.

---

## 3. Sprite overlays - more colours, more detail

The most common and cheapest trick in the book: stack two sprites at the same coordinates.

### Multicolour + hires black outline
A multicolour sprite (3 colours + transparency, chunky 12×21) overlaid with a **hires**
sprite drawn in black gives you sharp outlines and eye/detail pixels at full horizontal
resolution. This is what makes modern C64 sprites look so much better than 80s ones.
Used everywhere in *Sam's Journey*.

### Two multicolour sprites
Two multicolour sprites stacked give you up to **5 distinct colours** (2 individual
colours + 2 shared + transparency), still 12×21. Cost: 2 of your 8 sprites, and both must
be moved together.

### Practical grouping
Define a "logical sprite" as N hardware sprites with fixed offsets:

```asm
; logical sprite = 2 hardware sprites, same X/Y
;   sprite n   : multicolour body
;   sprite n+1 : hires black overlay (higher priority = lower number, so put
;                the overlay in the LOWER sprite number)
```

Since lower numbers win, the overlay must be the lower-numbered sprite.

### Larger characters
A 2×2 grid of sprites gives a 48×42 pixel actor (24×42 in multicolour) - standard for
bosses and big player characters. Cost: 4 sprites. With a multiplexer you can still have
several of these on screen if they don't share raster lines.

---

## 4. Sprite multiplexing - the essential technique

**Goal:** display more than 8 sprites per frame by reusing each hardware sprite several
times as the raster travels down the screen.

The rule: once a hardware sprite's 21 lines have been drawn, you can move it further down
the screen and give it new data/colour, and the VIC will draw it again.

### The algorithm

1. **Sort** all virtual sprites by Y coordinate, top to bottom.
2. **Assign** virtual sprites to hardware sprites cyclically: virtual 0→hw 0, 1→hw 1, …
   7→hw 7, 8→hw 0, 9→hw 1, …
3. **Schedule raster IRQs** so hardware sprite *k* is reprogrammed after its previous
   incarnation has finished drawing but **before** the raster reaches the new Y position.
4. **Park unused sprites** at Y = $FF (255) so leftovers from a busy frame don't reappear
   at the top of the next one.

### The 21-line rule

A hardware sprite cannot be reused until 21 raster lines after its previous Y position.
When sorting, reject any sprite that would violate this:

```
if (spry[next] - sortspry[count - 8]) < 21 then reject(next)
```

Sprites rejected this way simply don't display that frame. Good games hide this by
ensuring the *important* sprites (player, bullets) sort first or get reserved slots.

### Critical timing constraint

> **The Y coordinate must be written before the raster reaches it**, or the sprite won't
> appear at all that frame. (The VIC latches sprite DMA at the start of the line matching
> Y.)

Two scheduling strategies:

- **Pre-write:** set the registers a few lines *before* the new Y. Safe, but you must
  ensure the previous incarnation has already finished drawing.
- **Post-write:** set them immediately after the previous incarnation ends. Tighter
  packing, but riskier - if the IRQ is late, you lose the sprite.

Most engines use pre-write with a small margin (2–4 lines).

### Sorting algorithms

From the Codebase64 multiplexer article, ranked by practical usefulness for a game:

| Method | Cost | Notes |
|---|---|---|
| **Ocean sort** (incremental insertion) | Very low amortised | **Recommended.** Keeps last frame's order, fixes only what moved. Sprite positions change little between frames, so this is nearly free |
| Linear (selection) search | O(N²) but small constant | Fine up to ~16 sprites; supports easy rejection |
| Bubble sort | O(N²) | Simple, acceptable for small N |
| Radix / bucket sort | O(N), two passes | Correct and fast but more code and RAM |
| Y÷8 bucketing | O(N) | Fast but produces *incorrect* ordering within a bucket - causes flicker |

**Ocean sort** (named after Ocean Software, who used it) is the right default: on each
frame, walk the existing sorted list and do an insertion-sort pass. Because entities move
a few pixels per frame, this is almost always O(N) with a tiny constant.

### Reducing IRQ cost

The multiplexer IRQ is on the critical path. Standard optimisations:

1. **Batch.** Handle *all* sprites that start in the same region in one IRQ rather than
   one IRQ per sprite. Fewer IRQ entries (7+ cycles each) and fewer chain updates.
2. **Precalculate `$D010`.** The X-MSB register is per-frame global; computing it in the
   IRQ from 8 comparisons is expensive. Build the byte during the sort.
3. **Unroll per hardware sprite.** Write 8 separate code paths (`sta $d000`,
   `sta $d002`, …) rather than an indexed loop with `sta $d000,x` - saves the index
   arithmetic and lets you use absolute addressing.
4. **Self-modifying code / "fire" tables.** The fastest multiplexers precompute a block
   of `lda #imm / sta $d0xx` instructions during the sort, then the IRQ just `jsr`s into
   it. This is the same idea as speedcode.
5. **Skip unchanged registers.** Colour and pointer often don't change between
   incarnations.

### Double buffering

The sort runs in the main loop; the IRQs read the sorted tables. If they're the same
tables, you get tearing and flicker. **Allocate two copies and swap a pointer at the
frame boundary.**

```asm
sortspry_a:  .fill 32,0
sortspry_b:  .fill 32,0
; IRQ reads via self-modified absolute addresses, swapped once per frame
```

### Realistic capacity

| Sprites | Feasibility |
|---|---|
| 8 | Free, no multiplexer |
| 12–16 | Easy, ~1,000–1,500 cycles/frame |
| 20–24 | Standard for good games; needs Ocean sort + batched IRQs |
| 32 | Achievable; multiplexer starts dominating the budget |
| 48+ | Demo territory; requires very careful vertical distribution |

*Sam's Journey* and similar modern releases sit comfortably in the 16–24 range.

---

## 5. Sprite stretching (vertical repeat)

The Y-expand bit ($D017) is sampled per raster line via an internal **expansion
flip-flop**. If you clear the bit and then set it again *within the same line*, the VIC
does not advance the sprite's internal data pointer - so it redraws the **same 3 bytes of
sprite data** on the next line.

Do this repeatedly and one 21-line sprite covers an arbitrary number of raster lines.

### Uses in a game

- **Arbitrarily tall objects** from one sprite: pillars, laser beams, walls, energy bars,
  vertical scrollers' scenery.
- **Non-uniform scaling**: distribute the "advance" lines using a table for a smooth
  stretch (e.g. 20 advances spread over 100 lines gives a 5× stretch).
- **Full-height side panels** without spending sprites on each row.

### Implementation sketch

```asm
; per raster line, cycle-stable, main loop consumes exactly 63 cycles/line
stretch_loop:
    lda StretchTab,x    ; $ff = repeat this line, $00 = advance
    sta $d017
    lda #$00
    sta $d017           ; timing of these two writes is what matters
    ...                 ; padding to exactly one line
    inx
    ...
```

**Notes:**
- The write must land in a specific part of the line - the flip-flop update happens
  around **cycle 15**. Verify against a working reference.
- The routine must be **raster-stable** and consume exactly one line per iteration.
- With 8 sprites active, only ~44 cycles/line are yours; step `$D011`'s YSCROLL each line
  to suppress bad lines (see [`07-scrolling.md`](07-scrolling.md), FLD).
- Stretched sprites still count against the 8-per-line limit.

### The bug it's built on
Per the classic Ojala writeup: clearing the Y-expand bit *sets* the flip-flop regardless
of beam position; setting the bit again before the end of the line clears it, so the VIC
displays the same sprite line again.

---

## 6. Sprite crunch (MISC)

The inverse trick. Clearing the Y-expand register at **cycle 15** - the exact cycle the
VIC updates `MCBASE` (the sprite data counter) - makes the counter advance by *more* than
normal, so the sprite **skips** data lines and finishes early.

Why you'd want that: a sprite that finishes early frees its slot sooner, which means you
can pack more sprite reuses into the same vertical space. Linus Åkesson's **Massively
Interleaved Sprite Crunch (MISC)** uses this to get far more than 8 sprites'-worth of
imagery per line region.

**Verdict for a game project:** fascinating, very hard, extremely timing-sensitive, and
almost certainly not worth it. File under "know it exists". Read
<https://www.linusakesson.net/scene/lunatico/misc.php> if you're curious.

---

## 7. Sprites in the border

Sprites are the *only* thing that can be shown in the opened border - the character/bitmap
generator is off there. Opening the borders + sprites is how you get full-screen sprite
effects, wider playfields, and status displays outside the 40×25 area.

- **Top/bottom border:** easy (one register toggle per frame, no cycle-exactness).
- **Side borders:** hard (cycle-exact toggle every raster line).

See [`07-scrolling.md`](07-scrolling.md) §5.

---

## 8. Collisions

Hardware collision registers:
- `$D01E` - sprite ↔ sprite. Bit n set if sprite n was involved in *any* sprite-sprite
  collision.
- `$D01F` - sprite ↔ background. Bit n set if sprite n hit a foreground pixel.

**Both are cleared on read** and accumulate since the last read.

Limitations that make them near-useless for real games:
- They tell you *which* sprites, not *which pair*, and not *where*.
- They fire in the border and off-screen.
- With a multiplexer, hardware sprite 3 may be five different game entities in one frame  - 
  the register tells you nothing useful.
- They can only be read once per frame reliably.

**Recommendation:** do collisions in software.
- Bounding-box tests against your entity table (cheap: two 8-bit compares per axis with a
  pre-added radius).
- For player-vs-terrain, test the tile map directly at the character cell the player's
  feet occupy - far cheaper and more precise than `$D01F`.
- Reserve `$D01F` for a cheap "am I touching *any* foreground" query if it happens to fit
  your design (e.g. a single-sprite game).

Software box test, ~20 cycles:
```asm
    lda ax
    sec
    sbc bx
    clc
    adc #WIDTH          ; pre-biased
    cmp #WIDTH*2
    bcs no_hit
    ; ... same for Y
```

---

## 9. Sprite animation and RAM cost

64 bytes per frame adds up fast:

```
Player: 8 frames walk x 2 directions x 2 layers (body + overlay) = 32 sprites = 2 KB
Enemy A: 4 frames x 2 dir                                        =  8 sprites = 512 B
...
```

Mitigations:
- **Mirror horizontally in software** rather than storing both directions - a 24-bit
  reverse per row, done once when the direction changes, into a scratch sprite slot.
  Costs ~200 cycles per frame of animation, saves half your sprite RAM. Use a 256-byte
  bit-reverse table.
- **Share overlay frames** - the black outline often changes less than the body.
- **Keep sprite data in a bank you can switch to**, or copy the currently-needed frames
  into a small "sprite window" inside the VIC bank from a larger store elsewhere in RAM.
  A 64-byte copy is ~400 cycles; doing 4 per frame is affordable.
- **Compress the sprite store** and depack a whole enemy's set on level load.

---

## 10. Sprite tricks summary table

| Trick | Register(s) | Difficulty | Value for a game |
|---|---|---|---|
| Multiplexing | $D000–$D010, $D027+, ptrs | Medium | **Essential** |
| Overlay (colour/detail) | - (just 2 sprites) | Trivial | **Essential** |
| Multi-sprite big actors | - | Trivial | High |
| X/Y expansion | $D017 / $D01D | Trivial | High (cheap big objects) |
| Sprite stretching | $D017 mid-line | Hard | Medium (bars, pillars, panels) |
| Sprite crunch (MISC) | $D017 at cycle 15 | Very hard | Low |
| Sprites in opened border | $D011 / $D016 | Easy / Hard | High |
| Raster-split shared colours | $D025/$D026 | Easy | High |
| Priority behind background | $D01B | Trivial | High |
| Software mirroring | - | Easy | High (saves RAM) |
