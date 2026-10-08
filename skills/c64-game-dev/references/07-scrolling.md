# 07 - Scrolling and Border Tricks

FLD, VSP, linecrunch, AGSP, and opening the borders - all of these come from the same two
facts about the VIC-II internals stated in [`03-vic-ii-timing.md`](03-vic-ii-timing.md):

> **Cycle 14:** `VC = VCBASE`, `VMLI = 0`, and if a bad line condition holds, `RC = 0`.
> **Cycle 58:** if `RC == 7` then `VCBASE = VC`; otherwise `RC` is incremented.

Manipulate when bad lines happen, and you control where the screen is drawn.

---

## 1. Hardware fine scroll

The cheap, always-correct baseline.

- `$D016` bits 2–0 = **XSCROLL**, 0–7 pixels horizontal offset.
- `$D011` bits 2–0 = **YSCROLL**, 0–7 pixels vertical offset (default 3).

### Horizontal scroll loop

```
XSCROLL 7 -> 6 -> 5 -> 4 -> 3 -> 2 -> 1 -> 0 -> (shift the screen 1 char) -> 7 -> ...
```

Each frame you decrement XSCROLL. When it wraps, you must **shift the whole screen one
character left** and write a new rightmost column. That's the expensive part:

```
Screen shift: 1000 bytes moved  ~= 8,000+ cycles unrolled     <- too slow
Colour shift: 1000 bytes moved  ~= 8,000+ cycles              <- much too slow
```

### Avoiding the shift: the sliding window

Don't move the data - move the **screen base**. Reserve a wider region and change
`$D018`'s screen pointer. But `$D018` only moves the screen in **1 KB steps**, which is
25 rows, not 1 column. So this doesn't directly work horizontally. Options:

- **8 pre-shifted screens** (8 KB): cycle `$D018` through 8 screen RAMs each holding the
  map shifted by one character. Update all 8 as new columns arrive. Costs 8 KB and 8×
  the column-write work, but eliminates the bulk shift. Rarely worth it.
- **VSP / AGSP** (below): change the *screen data start offset* directly. This is the real
  answer, at the cost of a hardware compatibility risk.
- **Accept the shift, but do less of it.** Most horizontal scrollers only scroll a
  **band** of the screen (e.g. 16 rows instead of 25) and put a static status panel in the
  rest. Shifting 16×40 = 640 bytes is ~5,000 cycles unrolled - feasible once every 8
  frames.

### Vertical scroll

Vertical is easier: `$D018` moves the screen base in 1 KB steps, and a row shift is 40
screen + 40 colour bytes. And you can use a **double-height screen buffer** with the
screen base flipping between two 1 KB pages while you fill the off-screen rows. Or
**linecrunch/FLD** (below) to move the start point without moving data.

### Rate

At 1 pixel/frame you scroll 50 px/s - slow. Most games scroll 2 px/frame (100 px/s) or
more. Scrolling 2 px/frame means a char shift every 4 frames, which gives you 4 frames to
amortise the column work across. **Amortising the shift across frames is the standard
technique**: shift 10 rows per frame over 4 frames rather than 40 rows in one.

---

## 2. FLD - Flexible Line Distance

**What it does:** pushes the screen graphics downward by an arbitrary number of raster
lines, without moving any data.

**How:** on each raster line inside the display area, change YSCROLL (`$D011` bits 2–0)
so that the bad line condition is **never** satisfied. With no bad line, the VIC never
fetches a new row of characters and never advances `RC`/`VCBASE` - it sits in idle state
displaying background colour (or, in some modes, whatever is at `$3FFF`). When you stop
suppressing, the display resumes exactly where it left off, just lower down.

```asm
; called from a stable raster IRQ at the top of the display area
fld_loop:
    lda $d012
    clc
    adc #$01
    and #$07
    ; make YSCROLL differ from (raster+1)&7 so no bad line occurs
    eor #$07                ; or simply: sta a value that never matches
    sta zp_tmp
    lda $d011
    and #$f8
    ora zp_tmp
    sta $d011
    ; wait for the next line
    ...
    dex
    bne fld_loop
```

The commonly used compact form: read `$D012`, add 1, mask to 3 bits, write into
`$D011`'s low bits - this deliberately keeps YSCROLL equal to the *next* line so the
compare on the current line fails.

**Costs:** one raster line's worth of CPU per FLD line, and it must be raster-stable. You
also lose display area - everything below is pushed down and off the bottom.

**Uses in games:**
- Smooth vertical "wobble" of a bitmap or char area (sine table into the FLD count).
- Opening a status panel by pushing the playfield down.
- Giving yourself CPU time: **no bad lines = 63 cycles/line**. FLD is used as a
  cycle-recovery technique in raster-heavy routines (sprite stretchers use it for exactly
  this).
- Vertical scrolling of a whole screen without shifting data - combined with linecrunch.

---

## 3. Linecrunch

The opposite of FLD: **skip a whole text row per raster line**.

**How:** on a line where a bad line is happening, change `$D011` YSCROLL *before cycle 14
is over* so that a *different* line becomes the bad one. The result is that `RC` gets
reset and `VCBASE` advances - you jump a whole character row (8 pixel rows) in a single
raster line.

Chain a series of linecrunches and you can move the graphics generator to **any vertical
position within about 24 raster lines**.

**Uses:** vertical AGSP scrolling, screen "collapsing" effects, moving the start of the
screen without touching memory.

---

## 4. VSP - Variable Screen Positioning (a.k.a. DMA delay / HSP)

**What it does:** shifts the entire screen horizontally by whole characters *by changing
where the VIC starts reading the video matrix* - no data movement at all. Combine with
XSCROLL for pixel-smooth scrolling and you have a full-speed hardware horizontal scroller
for free.

**How (conceptually):** trigger/abort a bad line at a very specific late cycle in the
line, so the VIC's `VC`/`VCBASE` bookkeeping ends up offset. Each VSP trigger shifts the
screen start by 40 bytes (one row's worth), which - since the screen wraps - appears as a
horizontal shift.

**Exact cycle:** references disagree by ±1 depending on numbering convention and
PAL/NTSC. **Do not trust a number in prose - port a known-good reference implementation**
(Codebase64's AGSP article has working ACME and Kick Assembler versions).

### The VSP bug - read this before using VSP

**VSP crashes some real C64s.** This is well-documented, and it is a *hardware* problem,
not a coding error.

The mechanism (Linus Åkesson, *Safe VSP*):
- The C64's DRAM needs regular refresh; the VIC provides it.
- During a VSP trigger, the VIC changes its address lines at an abnormal moment. Address
  bits 3–7 are momentarily "neither a valid one nor a valid zero."
- The RAS (Row Address Strobe) may latch this undefined voltage, putting the DRAM row
  register into a **metastable** state that flickers between values.
- The row multiplexer then connects multiple memory rows to the same sense lines, and
  charge flows between cells - **corrupting data**.

**Which addresses are affected:** only memory locations whose address ends in hex **7 or
F** (i.e. address bits 3–7 all ones). Any fragile cell in a page can be corrupted into
the value of another fragile cell in the same page.

**How likely:** it varies by machine, DRAM manufacturer, temperature, and PSU. Some C64s
never fail; some fail within seconds. That's why VSP is common in demos and rare in
commercial games - though *Mayhem in Monsterland* and *Another World* did use it.

### Safe VSP - the three mitigations

1. **Make all fragile bytes in a page identical.** If every byte at `$xx07, $xx0F, $xx17,
   …` in a page holds the same value, corruption between them is a no-op. For code pages,
   fill them with `$EA` (NOP); for font data, make the bottom line of each character
   blank so the fragile byte is always `$00`.
2. **Skip fragile locations entirely.** Use the undocumented opcode `$80` (NOP immediate,
   2 bytes) to step over a fragile address in a code stream; design data structures with
   gaps at those offsets.
3. **Continuously restore.** Keep a master copy of the affected data in a safe region and
   rewrite it every frame, overwriting any corruption before it's visible. This is what
   the *Safe VSP* demo does.

Reference: <https://www.linusakesson.net/scene/safevsp/>

### VSP in 2026

There is also a hardware-side fix (Individual Computers' "VSP-Fix" for their boards), and
newer analysis suggests the risk can be engineered around reliably. But for a game
intended for **arbitrary original hardware**, treat VSP as a technique that requires the
Safe VSP discipline throughout your memory map - that is a real, ongoing constraint on how
you lay out data, not a one-time fix.

**Default recommendation:** design the scroll model *without* VSP first. If the
scroll performance is insufficient, evaluate VSP + Safe VSP discipline as a deliberate
architectural decision, not a late optimisation.

---

## 5. AGSP - Any Given Screen Position

**AGSP = VSP (horizontal) + linecrunch (vertical).** Together they let you place the
screen start at any byte offset, giving true 8-way scrolling of a full-screen character
or bitmap display with essentially zero per-frame data movement.

Cost:
- Inherits the VSP crash risk in full.
- Consumes the top ~12% of the screen (roughly the first 24 raster lines) for the
  linecrunch sequence.
- Only one row of video matrix data (40 bytes from the current AGSP offset) needs to be
  prepared per step, which is the whole point.

Used by Hannes Sommer's *Fred's Back* series for scrolling colourful bitmap graphics.

---

## 6. Opening the borders

The VIC-II's border logic uses two flip-flops (vertical and horizontal) that are set/
cleared by raster-line and X-position comparisons. The comparison values depend on RSEL
(`$D011` bit 3) and CSEL (`$D016` bit 3). If you change the mode so that the "set border"
comparison **never matches**, the border never closes.

Only **sprites** are visible in the opened border - the character/bitmap generator does
not run there.

### Top/bottom border - easy

Vertical flip-flop:
- **Set** (border on) when raster == 251 (RSEL=1) or 247 (RSEL=0).
- **Cleared** (border off) when raster == 51 (RSEL=1) or 55 (RSEL=0), if DEN=1.

To open: run in 25-row mode (RSEL=1, compare at 251). Set up a raster IRQ that fires
somewhere in lines **247–250** and switch to 24-row mode (RSEL=0). Line 247 has already
passed, so the flip-flop is not set; line 251 no longer matches. Border stays open through
the bottom and into the top of the next frame. Then switch back to RSEL=1 before line 247
of the next frame.

```asm
irq_open_border:            ; fires at raster ~$F9 (249)
    lda $d011
    and #$f7                ; RSEL = 0 (24 rows)
    sta $d011
    ; ... chain to an IRQ at the top of the frame that sets RSEL=1 again
```

**This does not require cycle-exact timing.** It's one register toggle per frame. Do it in
every game that wants sprites above/below the playfield.

### Side borders - hard

The horizontal flip-flop is checked **every raster line**, so you must toggle CSEL
(`$D016` bit 3) at the right cycle on **every single line** where you want the side
borders open.

- Right border compare: X = 344 (CSEL=1) / 335 (CSEL=0), around cycle 57.
- Left border compare: X = 24 (CSEL=1) / 31 (CSEL=0).

The technique: shortly before the right-border compare would fire, switch to 38-column
mode (whose compare at 335 has already passed), then switch back to 40 columns before the
next line. Classic implementations use `dec $d016` / `inc $d016` (read-modify-write, and
the dummy read/write timing is part of the trick) at an exact cycle.

Requirements:
- **Stable raster** ([`04-raster-irq.md`](04-raster-irq.md)).
- Cycle-exact per-line code - with 8 sprites active you have ~44 cycles/line to work with,
  and bad lines must be suppressed (FLD-style YSCROLL stepping) or accounted for.
- Costs most of your CPU for the region where it's active.

**Realistic use in a game:** open the side borders for a **band** of the screen (e.g.
the status bar area, or the top 40 lines) rather than the whole display. A common trick is
to open the side borders only in the top/bottom border region, where there are no bad
lines and no competing work - that gives you full-width sprite space above and below the
playfield almost for free.

---

## 7. Choosing a scroll model

| Model | Cost/frame | Compatibility risk | Recommended for |
|---|---|---|---|
| Flip-screen (no scroll) | ~0 (redraw on transition) | None | Platformers, adventures, arcade |
| Vertical only, double-buffered screen | Low | None | Vertical shooters |
| Horizontal, banded (16 rows) | Medium (~5k cyc/8 frames) | None | Side-scrolling shooters/platformers |
| Horizontal, full screen, char shift | High (~10k cyc/8 frames) | None | Only with a light game loop |
| Horizontal via VSP | Very low | **VSP crash risk** | Only with Safe VSP discipline |
| 8-way via AGSP | Very low | **VSP crash risk** + 12% screen | Demos, expert projects |
| 8-way via char shift + colour RAM | Very high | None | Realistically needs blanking or heavy amortisation |

**Default recommendation:** start with flip-screen or banded horizontal scrolling.
Both give a professional result with zero hardware risk and leave 80% of the frame budget
for actual gameplay.

---

## 8. Related: raster splits for free colour

Not scrolling, but the same IRQ machinery, and very high value:

- Change `$D021` (background) per screen band → sky gradient, water, ground layers.
- Change `$D025`/`$D026` (shared sprite multicolours) per band → sprites in the top half
  can use a different palette from those in the bottom half. Effectively doubles the
  available sprite colours.
- Change `$D020` (border) per band → framed playfields, HUD backgrounds.
- Change `$D018` per band → different charset / screen RAM per band (see
  [`06-charmode-graphics.md`](06-charmode-graphics.md) §9).

Each of these costs one IRQ (~50 cycles) and looks like a hardware feature nobody else
has.
