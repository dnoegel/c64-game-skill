# 03 - VIC-II Timing, Bad Lines, and the Cycle Budget

This is the foundational document. Every trick in files 04–07 is an application of what's
here. Reference: Christian Bauer, *The MOS 6567/6569 video controller (VIC-II)*,
<https://www.zimmers.net/cbmpics/cbm/c64/vic-ii.txt>.

---

## 1. The core idea: the VIC steals cycles

The CPU and the VIC-II share the same memory bus, on alternating clock phases. Normally
the VIC uses phase 1 and the CPU uses phase 2 and nobody notices. But the VIC sometimes
needs *more* bandwidth than half a cycle, so it asserts **BA** (Bus Available) low, and
after three more cycles the CPU is frozen until the VIC is done.

Two things cause the VIC to steal cycles:

1. **Bad lines** - fetching the 40 character codes + colour nibbles for a text row.
2. **Sprite DMA** - fetching sprite data for each active sprite on the line.

Everything about C64 raster programming is scheduling around these two.

---

## 2. Bad lines

### The bad line condition

A **Bad Line Condition** exists on a raster line when *all* of these hold:

1. Raster line is in the range **$30 (48) … $F7 (247)**, and
2. The low three bits of the raster counter **equal YSCROLL** (`$D011 & $07`), and
3. The **DEN** bit ($D011 bit 4) was set at some point during raster line $30.

Condition (2) is the one you manipulate: with the default `YSCROLL = 3`, bad lines occur
at raster lines 51, 59, 67, … 243 - i.e. the first line of each of the 25 text rows.

### What a bad line costs

On a bad line the VIC pulls BA low in **cycle 12** and performs 40 c-accesses (character
code + colour) in **cycles 15–54**. The CPU is stalled for the duration plus the 3-cycle
BA lead-in, though the CPU may still complete up to three *write* cycles after BA goes
low (writes don't need the bus to be granted the same way).

Net effect on a PAL line:

```
Normal line:   63 cycles available to the CPU
Bad line:      ~23 cycles available to the CPU        (63 - 40)
```

### Why you care

- A raster IRQ that fires on a bad line is delayed further and jitters more.
- A tight raster loop that assumes 63 cycles/line breaks every 8 lines.
- Effects like FLD and VSP work *by manipulating the bad line condition*.

### Suppressing bad lines

Because condition (2) is a live comparison against `$D011 & 7`, you can prevent a bad
line by changing YSCROLL before the compare happens. This is exactly what FLD does
([`07-scrolling.md`](07-scrolling.md)). Conversely, setting YSCROLL to match the *current*
line's low bits before cycle 14 **creates** a bad line where there wasn't one - that's
linecrunch.

The internal registers involved (from Bauer):
- `VC` - video counter (current position in screen RAM)
- `VCBASE` - the value VC is reloaded from at the start of each line
- `RC` - row counter (0–7, which of the 8 pixel rows of the character we're on)
- `VMLI` - video matrix line index

> In the first phase of **cycle 14** of every line: `VC = VCBASE`, `VMLI = 0`, and *if a
> bad line condition holds*, `RC = 0`.
> In **cycle 58**: if `RC == 7` then `VCBASE = VC` (advance to the next text row);
> otherwise `RC` is incremented and the same character row is displayed again.

Those two sentences are the whole basis of FLD, VSP, linecrunch, and AGSP. Memorise them.

---

## 3. Sprite DMA

Each enabled sprite whose Y coordinate matches the current line does a **p-access**
(reads its pointer from `screen + $3F8 + n`) and three **s-accesses** (3 bytes of sprite
data). Sprite fetches happen in the cycles at the end/start of the line (cycles 55–62 and
0–10 on the following line, in Bauer's numbering).

Cost, PAL:

| Active sprites on the line | Cycles stolen | CPU cycles left (non-bad line) |
|---|---|---|
| 0 | 0 | 63 |
| 1 | 3 | 60 |
| 2 | 5 | 58 |
| 3 | 7 | 56 |
| 4 | 9 | 54 |
| 5 | 11 | 52 |
| 6 | 13 | 50 |
| 7 | 15 | 48 |
| 8 | **19** | **44** |

(Roughly 2 cycles per sprite plus fixed overhead; the exact figure depends on which
sprites are contiguous. The commonly used engineering numbers are **19 stolen for 8
sprites → 44 usable**, and **~23 usable on a bad line with no sprites**.)

### The worst case

Bad line **and** 8 sprites on the same line leaves roughly **4 usable cycles**. You
cannot do meaningful work there. Practical consequences:

- Any cycle-exact raster routine must be written for the worst case it will encounter,
  or must guarantee no sprites/bad lines in its window.
- Sprite multiplexer IRQs should be scheduled to fire on lines where you *know* the
  sprite load, not wherever is convenient.
- The trick used by demos and good games: **turn off the display in the region where
  you need CPU** (`DEN = 0` blanks and stops bad lines entirely), or place heavy work in
  the border where there are no bad lines.

### The border is free CPU time

Outside raster $30–$F7 there are no bad lines. On PAL you get 312 − 200 = **112 lines**
of border, i.e. ~7,000 cycles of uninterrupted CPU (minus sprite DMA for sprites parked
there). On NTSC you get only ~63 lines. **Design your per-frame work to fit in the NTSC
border budget if you want NTSC compatibility.**

---

## 4. The frame budget

```
PAL frame:  312 lines x 63 cycles = 19,656 cycles

Typical accounting for a game with 25 rows visible + 8 multiplexed sprites:
  - 25 bad lines x 40 stolen                = 1,000
  - sprite DMA, say 150 lines x ~13 avg     = 1,950
  - raster IRQ overheads, ~20 IRQs x ~40    =   800
  - SID player call                         =   800 - 2,500  (varies hugely!)
  - sprite multiplexer sort + register sets = 1,000 - 2,000
                                              ---------------
  Remaining for game logic + graphics       ~ 11,000 - 14,000 cycles
```

**Rules of thumb:**
- ~11,000 cycles ≈ 5,500 simple instructions per frame. That is not much.
- A full-screen 40×25 character copy (1000 bytes, unrolled `lda abs / sta abs`) costs
  ~8,000 cycles. You cannot do that every frame *and* have a game.
- A `jsr`/`rts` pair costs 12 cycles. In inner loops, inline instead.
- Music routines vary from ~800 (simple) to 2,500+ (heavy filter/arpeggio work) cycles.
  Measure yours by toggling `$D020` around the call.

### Measuring cycles on real hardware

The classic technique - do this constantly:

```asm
    inc $d020          ; change border colour
    jsr thing_to_measure
    dec $d020          ; back
```

The height of the coloured band on screen tells you how many raster lines the routine
takes. One raster line = 63 cycles PAL. This works identically in VICE and on your
Ultimate II+/real C64, needs no tooling, and is the single most useful debugging trick
on the platform.

For precise counts, VICE's monitor has a cycle counter, and Retro Debugger shows a live
raster-time visualisation of exactly where your code runs in the frame.

---

## 5. Cycle-level line layout (PAL, 6569)

Simplified, per Bauer's numbering (cycle 1 is the first cycle of the line):

```
cycle  1- 3   sprite 3,4,5 s-accesses (if active)
cycle  4-10   sprite 5,6,7 s-accesses (if active)
cycle 11      idle / refresh
cycle 12-14   DRAM refresh; BA goes low at 12 if bad line
cycle 15      VC = VCBASE; first c-access if bad line
cycle 15-54   40 c-accesses (bad line) + 40 g-accesses (graphics data)
cycle 55-56   sprite 0 p-access / expansion handling
cycle 57      right border compare (CSEL=1 -> X=344)
cycle 58      RC/VCBASE update; sprite MC/MCBASE update
cycle 59-62   sprite 0,1,2 s-accesses
cycle 63      (PAL only) extra cycle
```

Key cycles to remember:

| Cycle | Event | Exploited by |
|---|---|---|
| **12** | BA low if bad line | - |
| **14** | `VC = VCBASE`, `RC = 0` if bad line | linecrunch, FLD |
| **15** | sprite Y-expansion flip-flop / MCBASE update | **sprite crunch** |
| **~53–58** | writes to $D011 here can create/abort a bad line late | **VSP / DMA delay** |
| **57–58** | left/right border compare (CSEL) | **side border opening** |
| **58** | `VCBASE = VC` if `RC == 7` | linecrunch, VSP |

> Exact cycle numbers for VSP and sprite crunch are notoriously fiddly and differ by
> one between references depending on whether cycles are numbered from 0 or 1, and
> between PAL/NTSC. **Always validate against a working reference implementation**
> rather than trusting a number in prose (including this document). VICE is
> cycle-accurate enough to develop these against, but confirm on real hardware.

---

## 6. NTSC differences that break timing code

| | PAL | NTSC (6567R8) |
|---|---|---|
| Cycles/line | 63 | 65 |
| Lines/frame | 312 | 263 |
| Cycles/frame | 19,656 | 17,095 |
| Non-display lines | 112 | 63 |

Consequences:
- **Any wait loop on `$D012` for a value > 262 hangs forever on NTSC.**
- A PAL-tuned per-frame workload of 14,000 cycles will not fit an NTSC frame.
- Cycle-exact raster routines need per-platform NOP padding (2 extra cycles/line).
- FLI-type routines commonly degrade to FLD behaviour on NTSC.
- Sprite X wraparound differs: coordinates above 404 wrap on PAL, above 412 on NTSC.

See [`16-testing-compat.md`](16-testing-compat.md) for detection routines and strategy.

---

## 7. Practical guidance

1. **Structure the frame explicitly.** Decide up front: "raster 0–50 = sprite setup and
   music; 51–250 = multiplexer IRQs only; 251–311 = game logic." Then enforce it.
2. **Never do variable-length work inside a raster-critical IRQ.** Set a flag; do the
   work in the main loop.
3. **Put the main loop's heavy work in the lower border**, synchronised by an IRQ at
   raster ~251.
4. **Budget in cycles, not "it feels fast".** Instrument with `$D020` from day one.
5. **If a routine won't fit, blank the screen for it.** Clearing `$D011` bit 4 (DEN)
   during a level transition buys you the full 19,656 cycles with zero bad lines. Many
   commercial games blank for a frame or two when redrawing a screen.
