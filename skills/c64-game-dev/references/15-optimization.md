# 15 - Optimization Cookbook

At ~1 MHz, optimisation isn't a polish step - it's a design constraint. These are the
techniques that actually move the needle, roughly in order of payoff.

---

## 1. Tables instead of computation

The 6510 does a table lookup in 4 cycles. It does almost nothing else that fast.

| Instead of | Use |
|---|---|
| Multiply by a constant | Shift/add, or a table |
| General multiply | Squares table (`a*b = f(a+b) − f(a−b)`, `f(x)=x²/4`) |
| Divide | Reciprocal table, or restructure to avoid it |
| `sin`/`cos` | 256-byte table, cosine = sine offset by 64 |
| `row * 40` | 25-entry lo/hi table of row addresses |
| Bit reversal | 256-byte table |
| Colour from char code | 256-byte table |
| `2^n` | 8-byte table (`$01,$02,$04,…`) - used constantly for sprite bit masks |
| Sprite Y → IRQ line | Precomputed during the sort |

Generate all of them at assemble time. Kick Assembler:

```java
.var mulTab = List()
.for (var i=0; i<256; i++) .eval mulTab.add((i*i)/4)
sqrlo: .fill 256, mulTab.get(i) & $ff
sqrhi: .fill 256, mulTab.get(i) >> 8

rowlo: .fill 25, <($0400 + i*40)
rowhi: .fill 25, >($0400 + i*40)

bit_mask: .byte $01,$02,$04,$08,$10,$20,$40,$80
```

**Cost:** RAM. A 512-byte table that saves 20 cycles × 30 calls/frame = 600 cycles/frame
is almost always a good trade.

---

## 2. Zero page

```
lda $12      3 cycles, 2 bytes
lda $1234    4 cycles, 3 bytes
lda $12,x    4 cycles, 2 bytes
lda $1234,x  4-5 cycles, 3 bytes    (+1 on page cross)
lda ($12),y  5-6 cycles, 2 bytes    (the only indirect mode)
```

Put in zero page: all pointers, all inner-loop counters, all per-frame temporaries, the
multiplexer's working set. You have 254 bytes - spend them deliberately, and keep a list
in the repo of what's allocated where.

**Avoid page-boundary crossings** in indexed loops: align hot tables to page boundaries
(`.align $100`) so `lda table,x` is always 4 cycles, not sometimes 5. Kick Assembler's
`.align` makes this free.

---

## 3. Self-modifying code

The 6510 has no register-indirect jump and no register-relative addressing. SMC fills both
gaps and is completely idiomatic on this platform - not a hack.

```asm
; Variable source address, no zero-page pointer needed
    lda src_lo
    sta copy+1
    lda src_hi
    sta copy+2
    ldy #63
copy:
    lda $ffff,y     ; <- patched
    sta dest,y
    dey
    bpl copy
```

```asm
; Variable immediate value
    lda new_colour
    sta fill+1
    ...
fill:
    lda #$00        ; <- patched
```

```asm
; Computed jump
    lda routine_lo,x
    sta go+1
    lda routine_hi,x
    sta go+2
go: jsr $ffff
```

**Saves:** an entire zero-page pointer (2 bytes) and 1–2 cycles per access vs `(zp),y`.

**Rules:**
- SMC is fine in RAM, impossible in ROM. If you're doing a **cartridge** build, keep all
  SMC in code that has been copied to RAM ([`11-cartridge.md`](11-cartridge.md)).
- Comment every patch site clearly (`; PATCHED by build_sprite_list`), or it becomes
  unmaintainable.
- SMC inside an IRQ handler that can be re-entered is a bug factory. Don't.

---

## 4. Speedcode (loop unrolling)

Replace a loop with straight-line code. Removes the index arithmetic, the compare, and the
branch - often more than half the cost of a tight loop.

```asm
; Loop: 11 cycles per byte
    ldy #39
loop:
    lda src,y
    sta dst,y
    dey
    bpl loop

; Unrolled: 8 cycles per byte, and no Y register needed
    lda src+0
    sta dst+0
    lda src+1
    sta dst+1
    ...
```

Generate it, don't type it:

```java
.for (var i=0; i<40; i++) {
    lda src + i
    sta dst + i
}
```

**Cost:** 6 bytes per copied byte. A full-screen speedcode copy is ~6 KB. That's why demos
talk about "9,000 bytes of speedcode for a 10,000-cycle effect."

**Partial unrolling** is the pragmatic middle ground: unroll 8 iterations inside a loop
that runs N/8 times. Gets ~80 % of the benefit for ~12 % of the size.

**Where it pays:** screen/colour copies, sprite data moves, the multiplexer's register
writes, any inner loop executed more than ~20 times per frame.

---

## 5. Illegal (undocumented) opcodes

The NMOS 6510 executes a set of undocumented instructions that combine two operations in
the cycle count of one. They work on **every real C64** (all use NMOS 6502 cores), are
supported by all modern cross-assemblers, and are used routinely by the scene.

| Opcode | Effect | Equivalent | Saving |
|---|---|---|---|
| **LAX** `zp/abs/(zp),y` | `A = X = M` | `LDA` + `LDX` | 1 instruction, ~3 cycles |
| **SAX** `zp/abs` | `M = A AND X` | - | Genuinely new operation |
| **DCP** `zp/abs,x` | `M = M-1; CMP` | `DEC` + `CMP` | ~4 cycles - great for loop counters |
| **ISC/ISB** | `M = M+1; SBC` | `INC` + `SBC` | ~4 cycles |
| **SLO** | `M = M<<1; A = A OR M` | `ASL` + `ORA` | ~4 cycles |
| **RLA** | `M = ROL M; A = A AND M` | `ROL` + `AND` | ~4 cycles |
| **SRE** | `M = M>>1; A = A EOR M` | `LSR` + `EOR` | ~4 cycles |
| **RRA** | `M = ROR M; A = A ADC M` | `ROR` + `ADC` | ~4 cycles |
| **ANC** `#imm` | `A = A AND #imm`, then bit 7 → carry | - | Sign test for free |
| **ALR** `#imm` | `A = (A AND #imm) >> 1` | `AND` + `LSR` | 2 cycles |
| **ARR** `#imm` | `A = (A AND #imm)`, then ROR with odd flags | - | Useful in multiply routines |
| **SBX/AXS** `#imm` | `X = (A AND X) − imm`, no borrow in | - | **Very useful** - 16-bit-free decrement of X |
| **NOP** `zp` / `abs` / `zp,x` | Do nothing, 3/4/4 cycles | - | **Cycle-exact timing filler** |

### The two you'll use most

**`nop zp` / `nop abs` for timing.** In cycle-exact raster code you need 3- and 4-cycle
do-nothings. `bit $ea` (3) and `bit $eaea` (4) work but clobber flags; the illegal NOPs
don't:
```asm
    nop $ea         ; $04 - 3 cycles, no side effects
    nop $eaea       ; $0C - 4 cycles
    nop $ea,x       ; $14 - 4 cycles
```

**`lax`** collapses the extremely common `lda something / tax` into one instruction.

### Caveats
- Some disassemblers and older emulators mishandle them. VICE `x64sc` is correct.
- The "unstable" ones (`SHA`, `SHX`, `SHY`, `TAS`, `LAS`, `ANE/XAA`, `LXA`) behave
  differently between chips and temperatures. **Avoid those entirely.** The ones in the
  table above are stable.
- CMOS 65C02 (not used in any C64) does not have them. Irrelevant here, but relevant if
  you ever port.

References: <https://www.masswerk.at/nowgobang/2021/6502-illegal-opcodes> and
<https://www.pagetable.com/?p=39>

---

## 6. Instruction-level tricks

```asm
; Compare and branch on zero - free
    lda value
    beq is_zero             ; no CMP needed, LDA sets Z

; Negative test - free
    lda value
    bmi is_negative

; Increment a 16-bit value (only 5 cycles in the common case)
    inc ptr
    bne +
    inc ptr+1
+

; Add signed 8-bit to 16-bit (sign extension without a branch)
    lda delta
    ora #$7f
    bmi +
    lda #$00
+   ; A is now $ff or $00 = sign extension
    ; ... then add

; Clear memory fast (4 cycles/byte, unrolled: 4)
    lda #0
    ldx #0
-   sta buffer,x
    sta buffer+$100,x
    sta buffer+$200,x
    sta buffer+$300,x
    inx
    bne -

; Table lookup with the result in the index - chain lookups
    lda table1,x
    tax
    lda table2,x

; Use the stack as a fast source (3 cycles/byte with PLA)
    ; ... set S, then a run of PLA is the fastest possible sequential read
```

### `jsr`/`rts` costs 12 cycles
In inner loops, inline the callee. Use macros so the source stays readable:

```java
.macro DrawSprite(n) {
    lda spr_x + n
    sta $d000 + n*2
    ...
}
```

### Branch, don't jump
`bne`/`beq` are 2–3 cycles and 2 bytes; `jmp` is 3 cycles and 3 bytes. Restructure so
hot paths fall through and cold paths branch away.

---

## 7. Algorithmic wins (the biggest ones)

No amount of cycle-shaving beats not doing the work:

| Win | Typical saving |
|---|---|
| Only redraw what changed (dirty rectangles / incremental column update) | 10–50× |
| Amortise a big update across N frames | N× peak cost |
| Ocean sort (incremental) instead of a full re-sort each frame | 5–20× |
| Tile-based map instead of raw screens | 4–16× data, similar in time |
| Spatial partitioning for collisions (grid buckets) instead of N² | N/4× at N=24 |
| Skip off-screen entities early | 2–5× |
| Charset animation instead of redrawing instances | 10–100× |
| Blank the screen (`DEN=0`) for a heavy one-off operation | +40 % cycles, no bad lines |

**Culling first.** The cheapest test is `lda ent_xhi,x / cmp #screen_right / bcs skip`.
Do it before anything else in every entity loop.

---

## 8. What NOT to optimise

- **The main-loop dispatch.** 600 cycles/frame for clean entity dispatch is fine.
- **Init code.** Runs once. Make it readable.
- **Anything you haven't measured.** Use the `$D020` band and the Retro Debugger's raster
  view. Programmer intuition about 6502 hot spots is frequently wrong.
- **Code size, before you're near the limit.** Speedcode trades bytes for cycles; if
  you're at 30 KB of 52 KB, spend the bytes.

---

## 9. A measurement discipline

```asm
.const PROFILE = true

.macro ProfStart(colour) {
    .if (PROFILE) {
        lda #colour
        sta $d020
    }
}
.macro ProfEnd() {
    .if (PROFILE) {
        lda #0
        sta $d020
    }
}
```

Assign each subsystem a colour. Run the game and you get a live, colour-coded bar chart of
the frame budget down the left border. This is the single most valuable debugging tool on
the platform and it costs 8 cycles per band.
