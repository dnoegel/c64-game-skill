# 01 - Hardware Reference

Quick-lookup reference. The authoritative document for VIC-II behaviour is Christian
Bauer's *"The MOS 6567/6569 video controller (VIC-II) and its application in the
Commodore 64"* (1996) - <https://www.zimmers.net/cbmpics/cbm/c64/vic-ii.txt>. When this
file and Bauer disagree, Bauer is right.

---

## 1. System overview

| Chip | Role |
|---|---|
| **6510** | CPU. 6502 core + 6-bit I/O port at $0000/$0001 used for memory banking |
| **VIC-II** (6569 PAL / 6567 NTSC) | Video, sprites, raster IRQs. Sees only 16 KB at a time |
| **SID** (6581 / 8580) | 3-voice synthesiser, also 2 A/D converters (paddles) |
| **CIA #1** (6526 @ $DC00) | Keyboard, joysticks, timers → **IRQ** line |
| **CIA #2** (6526 @ $DD00) | Serial/IEC bus, user port, **VIC bank select** → **NMI** line |
| **PLA** | Address decoding / memory banking logic |
| **Colour RAM** | 1000 × 4-bit static RAM at $D800, always visible, never banked |

### Clocks

| | PAL (6569) | NTSC (6567R8) | NTSC (6567R56A, early) |
|---|---|---|---|
| CPU clock | 985,248 Hz | 1,022,727 Hz | 1,022,727 Hz |
| Cycles per raster line | 63 | 65 | 64 |
| Raster lines per frame | 312 | 263 | 262 |
| Cycles per frame | **19,656** | **17,095** | 16,768 |
| Refresh rate | ~50.12 Hz | ~59.83 Hz | ~60.99 Hz |

---

## 2. Memory map (default, ROMs enabled)

```
$0000-$0001   6510 I/O port (DDR / data)   <- banking control
$0002-$00FF   Zero page                     <- your most valuable 254 bytes
$0100-$01FF   Stack
$0200-$03FF   KERNAL/BASIC workspace, vectors, tape buffer
$0400-$07E7   Default screen RAM (1000 bytes)
$07F8-$07FF   Default sprite pointers (screen base + $3F8)
$0800-$9FFF   BASIC program area / free RAM
$A000-$BFFF   BASIC ROM      (RAM underneath)
$C000-$CFFF   Free RAM (4 KB, never covered by ROM) <- great for code
$D000-$DFFF   I/O and Character ROM (RAM underneath)
$E000-$FFFF   KERNAL ROM     (RAM underneath)
```

### I/O area detail ($D000–$DFFF)

```
$D000-$D3FF   VIC-II       (47 registers, mirrored every $40)
$D400-$D7FF   SID          (29 registers, mirrored every $20)
$D800-$DBFF   Colour RAM   (1000 nibbles; upper 4 bits float/undefined)
$DC00-$DCFF   CIA #1       (mirrored every $10)
$DD00-$DDFF   CIA #2       (mirrored every $10)
$DE00-$DEFF   I/O 1        (cartridge / expansion)
$DF00-$DFFF   I/O 2        (cartridge / REU / **Ultimate Command Interface**)
```

### Banking via $01 (the 6510 port)

Set $0000 (DDR) to `$2F` (default) so bits 0–5 are outputs, then:

| $01 | LORAM / HIRAM / CHAREN | $A000-$BFFF | $D000-$DFFF | $E000-$FFFF |
|---|---|---|---|---|
| `$37` | 111 | BASIC ROM | I/O | KERNAL ROM |
| `$36` | 110 | RAM | I/O | KERNAL ROM |
| `$35` | 101 | RAM | **I/O** | **RAM** |
| `$34` | 100 | RAM | **RAM** | RAM |
| `$33` | 011 | BASIC ROM | **Char ROM** | KERNAL |
| `$30` | 000 | RAM | RAM | RAM |

**Game default: `$35`.** All RAM except I/O - you get $A000–$BFFF and $E000–$FFFF as RAM
(16 KB extra!) while keeping VIC/SID/CIA reachable. You must supply your own IRQ/NMI/RESET
vectors at $FFFA–$FFFF, which is exactly where you want your own IRQ handler anyway.

Use `$34` (all RAM) briefly when you need to read/write the RAM hidden under I/O.

> **Careful:** with `$35` the KERNAL is gone, so no `$FFD2` printing, no stock IEC
> routines, no NMI restore handler. That's normally what you want in a game.

Bits 3–5 of $01 are cassette control; bit 4 (`CASS SENSE`) is an input - always mask it
when read-modify-writing $01.

---

## 3. VIC-II register reference ($D000–$D02E)

| Addr | Name | Description |
|---|---|---|
| $D000–$D00F | M0X..M7Y | Sprite 0–7 X (even) and Y (odd) coordinates |
| $D010 | MSIGX | Bit *n* = sprite *n* X coordinate bit 8 (X ≥ 256) |
| $D011 | **CR1** | b7 RST8 (raster bit 8), b6 ECM, b5 BMM, b4 DEN, b3 RSEL, b2–0 **YSCROLL** |
| $D012 | RASTER | Read: current raster line (low 8 bits). Write: IRQ compare value |
| $D013/$D014 | LPX/LPY | Light pen latch |
| $D015 | SPENA | Sprite enable, bit per sprite |
| $D016 | **CR2** | b4 MCM, b3 CSEL, b2–0 **XSCROLL** (bits 7–5 unused, read as 1) |
| $D017 | YXPAND | Sprite Y (vertical) expand, bit per sprite |
| $D018 | **VMCSB** | b7–4 = VM13–VM10 (screen base), b3–1 = CB13–CB11 (charset/bitmap base) |
| $D019 | **IRR** | IRQ status/latch. b0 raster, b1 sprite-bg coll, b2 sprite-sprite coll, b3 lightpen, b7 IRQ pending |
| $D01A | IMR | IRQ enable mask, same bit layout |
| $D01B | SPBGPR | Sprite-background priority (1 = sprite behind background) |
| $D01C | SPMC | Sprite multicolour enable, bit per sprite |
| $D01D | XXPAND | Sprite X (horizontal) expand, bit per sprite |
| $D01E | SPSPCL | Sprite-sprite collision (**clear-on-read**) |
| $D01F | SPBGCL | Sprite-background collision (**clear-on-read**) |
| $D020 | EC | Border colour |
| $D021–$D024 | B0C–B3C | Background colours 0–3 |
| $D025/$D026 | MM0/MM1 | Sprite multicolour 0 / 1 (shared by all sprites) |
| $D027–$D02E | M0C–M7C | Sprite 0–7 individual colour |

### $D011 / $D016 mode bits

| ECM | BMM | MCM | Mode |
|---|---|---|---|
| 0 | 0 | 0 | Standard text (hires char) |
| 0 | 0 | 1 | Multicolour text |
| 0 | 1 | 0 | Standard bitmap (hires) |
| 0 | 1 | 1 | Multicolour bitmap |
| 1 | 0 | 0 | ECM text (64 chars, 4 backgrounds) |
| 1 | * | * | Invalid modes - screen goes black (used deliberately for effects) |

### $D018 decoding

```
$D018 = (screen_base >> 6) & $F0  |  (char_base >> 10) & $0E
```
Screen base is relative to the current VIC bank in 1 KB steps (16 options).
Charset base is in 2 KB steps (8 options). Bitmap base uses only bit 3 (CB13) → two
options per bank ($0000 or $2000 within the bank).

**Sprite pointers** live at `screen_base + $3F8` .. `+$3FF`. Sprite data address =
`vic_bank + (pointer * 64)`.

### Display window geometry

| | RSEL/CSEL = 1 | RSEL/CSEL = 0 |
|---|---|---|
| First/last raster line | 51 – 250 (25 rows) | 55 – 246 (24 rows) |
| First/last X coordinate | 24 – 343 (40 cols) | 31 – 334 (38 cols) |

Sprite coordinate `X = $18 (24)`, `Y = $32 (50)` puts the sprite's top-left at the
top-left of the display window.

---

## 4. Interrupt vectors

| Vector | ROM path (KERNAL on) | Direct (KERNAL off, $01 = $35) |
|---|---|---|
| IRQ | $FFFE → KERNAL → `$0314/$0315` | `$FFFE/$FFFF` in RAM |
| NMI | $FFFA → KERNAL → `$0318/$0319` | `$FFFA/$FFFB` in RAM |
| RESET | $FFFC | `$FFFC/$FFFD` |

The KERNAL path costs ~40 extra cycles and adds jitter. For game code, bank the KERNAL
out and take `$FFFE` directly.

**IRQ sources to disable at startup:**
```asm
    sei
    lda #$7f
    sta $dc0d          ; disable all CIA#1 IRQs (timer A runs by default!)
    sta $dd0d          ; disable all CIA#2 NMIs
    lda $dc0d          ; acknowledge any pending
    lda $dd0d
    lda #$01
    sta $d01a          ; enable VIC raster IRQ
    lda #$ff
    sta $d019          ; ack any pending VIC IRQ
```

> `$D019` is acknowledged by **writing a 1 to the latch bit**. Many sources use
> `asl $d019` (shifts b7 into carry, writes back a value with b0 set) or `lda #$ff /
> sta $d019`. Forgetting this causes an immediate re-entry loop.

Restarting the RESTORE key NMI: point $FFFA at an `rti` to make it harmless, or hook it
for a debug feature.

---

## 5. CIA reference (the parts you'll use)

| Addr (CIA1 / CIA2) | Function |
|---|---|
| $DC00 / $DD00 | Port A. CIA1: keyboard column / **joystick port 2**. CIA2 b0–1: **VIC bank** |
| $DC01 / $DD01 | Port B. CIA1: keyboard row / **joystick port 1** |
| $DC02/$DC03 | Data direction A / B |
| $DC04/$DC05 | Timer A lo/hi |
| $DC06/$DC07 | Timer B lo/hi |
| $DC08–$DC0B | TOD clock (10ths, sec, min, hr) |
| $DC0C | Serial shift register |
| $DC0D | ICR - read: status (clears), write: mask (b7 = set/clear) |
| $DC0E/$DC0F | CRA / CRB - timer control |

### VIC bank select ($DD00, bits 1–0 - **inverted**)

| $DD00 & 3 | VIC bank | Address range | Char ROM shadow? |
|---|---|---|---|
| `%11` | 0 | $0000–$3FFF | Yes, at $1000–$1FFF |
| `%10` | 1 | $4000–$7FFF | No |
| `%01` | 2 | $8000–$BFFF | Yes, at $9000–$9FFF |
| `%00` | 3 | $C000–$FFFF | No |

Set DDR first: `lda #$03 / sta $dd02`. Then read-modify-write to avoid clobbering the
serial bus bits:
```asm
    lda $dd00
    and #$fc
    ora #$02          ; %10 -> bank 1 at $4000
    sta $dd00
```

> **Trap:** the VIC always reads the **character ROM** at $1000–$1FFF and $9000–$9FFF
> from its own perspective, regardless of $01. You cannot put graphics data there in
> banks 0 and 2. Also, the VIC cannot see the RAM under I/O when in bank 3  - 
> $D000–$DFFF reads as RAM for the VIC (it has no I/O), so bank 3 *is* usable, but
> $3FFF/$7FFF/$BFFF/$FFFF is what the VIC fetches when idle.

### Joystick read (port 2 = $DC00)

```
bit 0 = up, 1 = down, 2 = left, 3 = right, 4 = fire   (0 = pressed)
```
Reading $DC01 (port 1) conflicts with keyboard scanning; port 2 is the conventional
single-player port. Set `$DC02 = $00` (port A all inputs) if you want a clean joystick-2
read while not scanning the keyboard.

---

## 6. SID register reference ($D400)

Per voice (offsets 0, 7, 14 for voices 1–3):

| Offset | Register |
|---|---|
| +0/+1 | Frequency lo/hi |
| +2/+3 | Pulse width lo/hi (12-bit) |
| +4 | Control: b7 noise, b6 pulse, b5 saw, b4 triangle, b3 test, b2 ring mod, b1 sync, b0 **gate** |
| +5 | Attack (hi nibble) / Decay (lo nibble) |
| +6 | Sustain (hi nibble) / Release (lo nibble) |

Global:

| Addr | Register |
|---|---|
| $D415/$D416 | Filter cutoff lo (3 bits) / hi (8 bits) |
| $D417 | Resonance (b7–4) / filter routing (b3 ext, b2–0 voices 3–1) |
| $D418 | b7–4 filter mode (b4 LP, b5 BP, b6 HP, b7 voice 3 off), **b3–0 master volume** |
| $D419/$D41A | Paddle X / Y (A/D converters) |
| $D41B | Oscillator 3 output (read - useful as a random source) |
| $D41C | Envelope 3 output (read) |

`$D41B` read gives you free pseudo-randomness if voice 3 is set to noise.

---

## 7. Sprite fundamentals

| Property | Value |
|---|---|
| Count | 8 hardware sprites |
| Size | 24 × 21 pixels hires, 12 × 21 multicolour (double-width pixels) |
| Data | 63 bytes, aligned to 64 bytes |
| Location | `vic_bank + pointer × 64` (pointer at screen_base + $3F8 + n) |
| Colours | 1 individual colour (hires); multicolour adds 2 shared colours ($D025/$D026) |
| Expansion | ×2 horizontal ($D01D) and/or ×2 vertical ($D017), per sprite |
| Priority | **Lower sprite number wins.** Sprite 0 is always on top |
| vs background | $D01B bit set = sprite drawn *behind* non-background pixels |

Multicolour bit pairs:

| Bits | Colour source |
|---|---|
| `00` | Transparent |
| `01` | $D025 (sprite multicolour 0, shared) |
| `10` | $D027+n (sprite's own colour) |
| `11` | $D026 (sprite multicolour 1, shared) |

Collision registers `$D01E`/`$D01F` are **cleared on read** and accumulate every collision
since the last read - including collisions in the border and off-screen. They tell you
*which* sprites collided, not *where*. Most games use them as a cheap broad-phase and do
their own box test, or ignore them entirely.

---

## 8. Colour palette

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

Useful luminance ordering (dark → light), for dithering and ramps:
`0, 6, 9, 11, 2, 4, 8, 12, 14, 5, 10, 15, 3, 13, 7, 1`

Greys `0, 11, 12, 15, 1` form a clean 5-step ramp - the backbone of most C64 art.

---

## 9. Cycle costs cheat sheet

```
Instruction timing traps:
  abs,X / abs,Y / (zp),Y   +1 cycle if the index crosses a page boundary
  branches                 +1 if taken, +2 if taken across a page
  RMW instructions (INC/DEC/ASL/ROL/LSR/ROR) do a dummy read then a write
                           -> useful for double-writes to $D016/$D011 tricks

Handy timing filler:
  nop            2 cycles  ($EA)
  bit $ea        3 cycles  (zp)
  bit $eaea      4 cycles  (abs)
  nop $ea        3 cycles  (illegal DOP zp, $04)
  nop $eaea      4 cycles  (illegal TOP abs, $0C)
  nop $ea,x      4 cycles  (illegal, $14)
  jmp *+3        3 cycles
  IRQ entry      7 cycles + 0..7 for finishing the current instruction
  RTI            6 cycles
```
