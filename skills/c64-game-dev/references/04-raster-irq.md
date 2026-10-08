# 04 - Raster IRQs and Stable Rasters

The interrupt system is the backbone of a C64 game engine. This document covers: basic
raster IRQs, the jitter problem, stable raster techniques, IRQ chaining, NMI usage, and
CIA timer IRQs.

---

## 1. Basic raster IRQ

The VIC-II can raise an IRQ when the raster counter reaches a chosen line.

```asm
; ---- setup ----------------------------------------------------------
    sei
    lda #$35            ; RAM + I/O, no KERNAL/BASIC
    sta $01

    lda #$7f
    sta $dc0d           ; kill CIA#1 timer IRQs
    sta $dd0d           ; kill CIA#2 NMIs
    bit $dc0d           ; ack pending
    bit $dd0d

    lda #<irq
    sta $fffe
    lda #>irq
    sta $ffff

    lda #$01
    sta $d01a           ; enable raster IRQ source
    lda #$32            ; raster line 50
    sta $d012
    lda $d011
    and #$7f            ; clear RST8 -> raster compare < 256
    sta $d011

    lda #$ff
    sta $d019           ; ack any pending VIC IRQ
    cli
    jmp *

; ---- handler --------------------------------------------------------
irq:
    pha                 ; must preserve A/X/Y yourself when using $FFFE
    txa
    pha
    tya
    pha

    inc $d020
    ; ... do work ...
    dec $d020

    lda #$ff
    sta $d019           ; ACK - forget this and you loop forever

    pla
    tay
    pla
    tax
    pla
    rti
```

### Raster lines above 255

`$D012` is only the low 8 bits. Bit 7 of `$D011` is **RST8**, the 9th bit.

```asm
setraster:              ; A = low byte, carry = bit 8
    sta $d012
    lda $d011
    and #$7f
    bcc +
    ora #$80
+   sta $d011
```

A common convenience: keep a table of IRQ line numbers < 256 only, and use the border
region 251–311 by triggering at line 251 and doing a short wait.

### Acknowledging

`$D019` bit 0 is a latch. Acknowledge by writing a 1 to that bit position:
`lda #$ff / sta $d019`, or the idiomatic `asl $d019` (reads, shifts bit 7 into carry,
writes back with bit 0 set - 6 cycles, saves a register). Also note `$D019` bit 7 tells
you an IRQ is pending from *some* VIC source, handy for multi-source dispatch.

---

## 2. The jitter problem

A raster IRQ is signalled at cycle 0 of the target line, but the CPU:

- must **finish the instruction it is currently executing** (2–7 cycles, more if a page
  boundary is crossed), then
- spends **7 cycles** pushing PC and status and loading the vector.

So the first instruction of your handler executes somewhere in **cycles 7–14** of the
target line: a **7-cycle jitter**. On a bad line, or with sprite DMA, the delay is worse
and less predictable.

For sprite multiplexing and colour splits inside the border, 7 cycles of jitter is
usually fine. For opening the side borders, FLI, or anything that must write a register
on an exact cycle, it is fatal - you get a ragged, flickering edge.

---

## 3. Stable raster: the double IRQ method

The standard, well-understood technique. The idea:

1. First IRQ fires with 0–7 cycles of jitter.
2. Inside it, re-point the IRQ vector to a second handler and set `$D012` to the **next**
   line, acknowledge, and re-enable interrupts (`cli`) **without** returning.
3. Execute a run of `nop`s. Because a `nop` is only 2 cycles, when the second IRQ fires
   the CPU is either just finishing a `nop` or one cycle into one - **jitter is now 1
   cycle**.
4. In the second handler, remove the last cycle with a `$D012` comparison trick.

```asm
; ---- IRQ 1: jittery entry -------------------------------------------
irq1:
    ; (no register saving needed if we never return through it)
    lda #<irq2
    sta $fffe
    lda #>irq2
    sta $ffff
    inc $d012           ; fire again on the very next line
    lda #$ff
    sta $d019           ; ack
    tsx                 ; remember stack pointer
    cli                 ; allow the next IRQ while still "inside" this one
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop                 ; enough NOPs to definitely cover a whole line

; ---- IRQ 2: 1-cycle jitter ------------------------------------------
irq2:
    txs                 ; discard the nested IRQ's stack frame
    ; --- remove the final cycle of jitter ---
    lda $d012
    cmp $d012
    beq *+2             ; taken (3 cyc) or not taken (2 cyc) -> equalised
    ; ===== from here we are cycle-exact =====

    ; ... cycle-critical work ...

    lda #<irq1          ; restore for next frame
    sta $fffe
    lda #>irq1
    sta $ffff
    lda #<next_line
    sta $d012
    lda #$ff
    sta $d019
    ; NOTE: because of the txs above, restore registers appropriately
    rti
```

**Why `lda $d012 / cmp $d012 / beq *+2` works:** the two reads happen 3 cycles apart. If
the IRQ entered one cycle later, the raster counter has advanced between the reads, the
compare fails, the branch is not taken (2 cycles); if it entered one cycle earlier, the
values match, the branch is taken (3 cycles). Either way, execution converges on the same
cycle. This "raster compare + branch" idiom is the standard tail of every stabiliser.

**Gotcha:** the second IRQ pushes another frame on the stack. `tsx` before `cli` and `txs`
at the start of IRQ 2 keeps the stack from growing. Because you're throwing away the outer
frame, you must be careful about what `rti` returns to - the usual approach is that IRQ 2
does the `rti` and the outer frame is simply discarded.

---

## 4. Stable raster: the NMI variant

An NMI cannot be masked, and if you arrange for the CPU to be executing a known
instruction sequence, an NMI-based stabiliser can achieve **guaranteed 0-cycle jitter**.
The common recipe:

- Use a CIA timer NMI programmed to exactly one frame (`19,656 − 1 = 19,655 = $4CC7`)
  so it re-fires at the identical point every frame.
- Sync the timer once against a raster IRQ, then never touch it again.

Advantages: rock-solid, no per-frame stabilising cost.
Disadvantages: you lose the RESTORE key, you must keep the timer running, and NMIs can
interrupt your IRQ handlers (which is sometimes exactly what you want - a music NMI that
plays regardless of raster load - and sometimes a nightmare).

Practical recommendation: **use the double-IRQ method for game work**; reach for NMI
stabilisation only if you're doing FLI or side borders across the whole screen.

---

## 5. IRQ chaining (the pattern you'll actually use)

A game needs many IRQs per frame at different lines. The standard structure is a table of
`(raster_line, handler_address)` pairs and a self-advancing index.

```asm
irq_index:  .byte 0
irq_lines:  .byte  50,  90, 140, 200, 251
irq_lo:     .byte <ir0, <ir1, <ir2, <ir3, <ir4
irq_hi:     .byte >ir0, >ir1, >ir2, >ir3, >ir4
NUM_IRQS = 5

next_irq:                       ; call at the end of every handler
    ldx irq_index
    inx
    cpx #NUM_IRQS
    bne +
    ldx #0
+   stx irq_index
    lda irq_lines,x
    sta $d012
    lda irq_lo,x
    sta $fffe
    lda irq_hi,x
    sta $ffff
    lda #$ff
    sta $d019
    rts
```

### The "already passed" hazard

If handler N takes so long that the raster has already passed the line for handler N+1,
the next IRQ won't fire until the *next frame* - a visible glitch or a total lockup. The
standard guard, from the Codebase64 multiplexer article:

```asm
    ; after setting $d012 to the next target:
    lda irq_lines,x
    sec
    sbc #$03            ; small safety margin
    cmp $d012
    bcc handle_directly ; raster already past it -> just run the next handler inline
```

Every sprite multiplexer needs this. Without it you get sprites vanishing for a frame
whenever the load spikes.

---

## 6. CIA timer IRQs

Sometimes you want a periodic interrupt not tied to a raster line - e.g. a music player
running at a rate other than 50 Hz, or a fastloader's transfer timing.

```asm
    lda #$c7            ; 19655 = $4CC7 -> exactly one PAL frame
    sta $dc04
    lda #$4c
    sta $dc05
    lda #$81
    sta $dc0d           ; enable Timer A IRQ
    lda #$11
    sta $dc0e           ; start Timer A, continuous mode
```

Notes:
- Acknowledge a CIA IRQ by **reading** `$DC0D` (this clears the flags).
- CIA timers are *not* stalled by bad lines - they count real cycles. This makes them
  excellent for a stable frame reference but means they drift relative to the raster if
  the value isn't exactly one frame.
- CIA #1 → IRQ, CIA #2 → NMI. Choose accordingly.
- `$DC0D` write uses bit 7 as set/clear: `$81` = enable Timer A, `$01` = disable Timer A,
  `$7F` = disable everything.

### Music at a non-50Hz rate

Many tunes are composed for 50 Hz (one call per frame). Multi-speed tunes (2×, 4×) are
called 2 or 4 times per frame - normally implemented as extra raster IRQs at evenly
spaced lines rather than a CIA timer, so they stay phase-locked to the display.

---

## 7. Priorities and a suggested IRQ layout

A workable default frame layout for a game:

```
raster  0-49    (upper border)   IRQ A: sprite multiplexer "frame start"  - 
                                 write the first 8 sprites' registers,
                                 call the music player
raster 51-250   (display)        IRQ B..N: multiplexer re-writes,
                                 split-screen changes ($D018 for a status bar,
                                 $D011 mode change, colour splits)
raster 251      (lower border)   IRQ Z: set a "frame done" flag; main loop
                                 does game logic + sprite sorting here
```

Main loop:

```asm
mainloop:
    lda frame_flag
    beq mainloop
    lda #0
    sta frame_flag

    jsr read_input
    jsr update_entities
    jsr sort_sprites        ; produces the multiplexer's tables for NEXT frame
    jsr update_screen
    jmp mainloop
```

**Double-buffer the multiplexer tables** so the sorting done in the main loop never
modifies the tables the IRQs are currently reading. This is the standard cure for
sprite flicker.

---

## 8. Common bugs

| Symptom | Cause |
|---|---|
| Machine locks up immediately | Forgot to acknowledge `$D019`, or `$D012` set to a line already passed |
| Stack overflow after a few seconds | `cli` inside an IRQ without matching `tsx`/`txs` |
| Random crashes | Not preserving A/X/Y when using `$FFFE` directly |
| Everything works in VICE, glitches on hardware | Relying on cycle counts that ignore sprite DMA or bad lines |
| Effect drifts one line per frame | `$D012` compare set to a value the raster passes twice, or RST8 not handled |
| Works PAL, hangs NTSC | Waiting for `$D012` > 262 |
| Occasional one-frame sprite dropout | Missing the "already passed" guard in the IRQ chain |
| Colour split lands one line off on some machines | Different VIC-II revision timing - test on real hardware |
