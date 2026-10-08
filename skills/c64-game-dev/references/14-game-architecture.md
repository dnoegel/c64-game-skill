# 14 - Game Architecture Patterns

How to structure a C64 game so it stays buildable as it grows.

---

## 1. The frame structure

Everything hangs off one decision: **what runs in the IRQ, and what runs in the main
loop.**

```
IRQ (fixed cost, must never overrun):
  - stable raster setup
  - music player call
  - sprite multiplexer register writes
  - raster splits ($D021, $D018, $D016, $D011)
  - fastloader chunk transfer
  - set frame_flag at the end of the visible area

MAIN LOOP (variable cost, may overrun into the next frame gracefully):
  - read input
  - update entity logic
  - collision detection
  - sort sprites for the NEXT frame
  - update screen / scroll
  - trigger asset loads
```

```asm
mainloop:
    lda frame_flag
    beq mainloop            ; wait for vertical sync
    lda #0
    sta frame_flag

    inc $d020               ; --- profiling band start
    jsr read_input
    jsr update_player
    jsr update_enemies
    jsr update_bullets
    jsr check_collisions
    jsr build_sprite_lists  ; -> back buffer
    jsr swap_sprite_buffers
    jsr update_scroll
    dec $d020               ; --- profiling band end
    jmp mainloop
```

**Why the flag and not `jsr` from the IRQ:** if the main loop overruns a frame, you get a
slowdown (acceptable - the game just runs at 25 fps for a moment). If the IRQ overruns,
you get visual corruption or a lockup (unacceptable).

### Detecting overrun
Set a second flag when the frame IRQ fires while `frame_flag` is still set. During
development, flash the border red when that happens. You'll immediately see which
gameplay situations blow the budget.

---

## 2. Entity representation

Do **not** use structs-of-bytes. Use **structure of arrays** (SoA) - parallel arrays
indexed by entity number:

```asm
MAX_ENTITIES = 24

ent_type:     .fill MAX_ENTITIES, 0
ent_xlo:      .fill MAX_ENTITIES, 0
ent_xhi:      .fill MAX_ENTITIES, 0
ent_y:        .fill MAX_ENTITIES, 0
ent_dxlo:     .fill MAX_ENTITIES, 0
ent_dxhi:     .fill MAX_ENTITIES, 0
ent_dy:       .fill MAX_ENTITIES, 0
ent_frame:    .fill MAX_ENTITIES, 0
ent_state:    .fill MAX_ENTITIES, 0
ent_timer:    .fill MAX_ENTITIES, 0
ent_hp:       .fill MAX_ENTITIES, 0
```

Why SoA on 6502:
- `lda ent_x,x` is 4 cycles with a plain index. Array-of-structs needs a multiply
  (or a stride table) to compute the offset - several extra cycles *per field access*.
- With ≤ 256 entities the index fits in X or Y, and there's no 16-bit arithmetic at all.
- Fields you don't touch in a given loop cost nothing.

Keep `MAX_ENTITIES` ≤ 128 if you can, so you can use the high bit of `ent_type` as an
"active" flag and test it with `bpl`/`bmi`.

### Sub-pixel positions
Store X as 16-bit (`xlo` = fraction, `xhi` = pixels) so entities can move at fractional
speeds. This is what makes movement feel smooth. Y is often 8-bit + a separate fraction
byte only for entities that need it (gravity).

### Entity dispatch
A jump table indexed by type:

```asm
update_entities:
    ldx #MAX_ENTITIES-1
loop:
    lda ent_type,x
    beq next                ; 0 = inactive
    tay
    lda update_lo,y
    sta jump+1
    lda update_hi,y
    sta jump+2
jump:
    jsr $ffff
next:
    dex
    bpl loop
    rts
```

~25 cycles of dispatch overhead per entity. With 24 entities that's 600 cycles/frame  - 
acceptable. If it isn't, split entities into fixed-purpose pools (bullets, enemies,
pickups) each with a dedicated loop and no dispatch at all. Pools are faster and usually
simpler; use dispatch only when you genuinely need heterogeneous behaviour.

---

## 3. State machines

Game states (title / playing / paused / dying / level-complete / game-over) as a simple
index into a jump table, with the main loop dispatching once per frame:

```asm
game_state:  .byte 0

mainloop:
    ; ... wait for frame ...
    ldx game_state
    lda state_lo,x
    sta j+1
    lda state_hi,x
    sta j+2
j:  jsr $ffff
    jmp mainloop
```

Each state has an `enter` and an `update`. Changing state sets a pending value that's
applied at the top of the next frame - never mid-update, or you'll get half-updated
frames.

Per-entity state machines use the same pattern with `ent_state,x`.

---

## 4. Double buffering

Three separate things can be double-buffered; each solves a different problem:

| Buffer | Cost | Solves |
|---|---|---|
| **Sprite multiplexer tables** | ~200 bytes | Sprite flicker/tearing when the sort runs while IRQs read |
| **Screen RAM** | 1 KB | Visible tearing while redrawing the playfield |
| **Colour RAM** | not possible | - (colour RAM can't be relocated) |

Sprite table double-buffering is **essential**. Screen double-buffering is a nice-to-have
that costs 1 KB and a `$D018` write per frame - usually worth it if you redraw large
areas.

Since colour RAM can't be buffered, the standard trick is to make colour a function of the
character code (see [`06-charmode-graphics.md`](06-charmode-graphics.md) §3) so it changes
only when the char changes, in the same write pass.

---

## 5. Input handling

```asm
read_input:
    lda $dc00               ; joystick 2
    eor #$ff                ; active-low -> active-high
    and #$1f
    tax
    eor joy_prev            ; bits that changed
    and joy_now             ; ...and are now pressed
    sta joy_pressed         ; edge-triggered "just pressed"
    stx joy_now
    stx joy_prev
    rts
```

Keep `joy_now` (held) and `joy_pressed` (edge). Almost every input bug on the C64 is
"fire repeats because you tested held instead of pressed."

**Keyboard:** if you need it, scan `$DC00`/`$DC01` yourself (write a column mask to
`$DC00`, read rows from `$DC01`) rather than banking the KERNAL back in. A full 8-column
scan is ~100 cycles. Watch out: scanning the keyboard writes to `$DC00`, which conflicts
with reading joystick 2 - do the joystick read first, then restore `$DC02`/`$DC00`.

---

## 6. Random numbers

Options, cheapest first:

```asm
; A. SID noise (free, decent quality) - set voice 3 to noise, then:
    lda $d41b

; B. 8-bit LFSR (~12 cycles, deterministic/repeatable - good for level gen)
rnd:
    lda seed
    asl
    bcc +
    eor #$1d
+   sta seed
    rts

; C. A 256-byte table of pre-generated random bytes, indexed by a moving pointer
```

Use **B or C for anything that must be reproducible** (procedural levels, demo playback,
replays). Use A for cosmetic randomness.

---

## 7. Fixed-point maths

The 6510 has no multiply or divide. Standard tools:

### Multiplication by a constant → shifts and adds
```asm
; A * 5
    sta tmp
    asl
    asl                     ; A*4
    clc
    adc tmp                 ; A*5
```

### General 8×8 multiply → the squares table trick
```
a*b = (f(a+b) - f(a-b)) where f(x) = x^2/4
```
Two 512-byte tables of `x²/4` (one for the low byte, one for the high), and multiplication
becomes ~30 cycles of table lookups and a 16-bit subtract. Generate the tables at
assemble time with Kick Assembler.

### Division
Usually avoidable. If you need `x/8`, shift. If you need a reciprocal, use a table. True
division is expensive - restructure the maths so you don't need it.

### Trig
256-entry sine table (angle 0–255 maps to 0–360°), values scaled to your needs. Cosine is
the same table offset by 64. Generate at assemble time.

```java
// Kick Assembler
.fill 256, round(sin(toRadians(i*360/256)) * 127) & $ff
```

---

## 8. Data-driven design

Hardcoding enemy behaviour in assembly is how a C64 project dies. Put behaviour in tables:

```asm
; enemy type table - one entry per enemy type
enemy_sprite:   .byte 12, 16, 20, 24
enemy_speed:    .byte  1,  2,  1,  3
enemy_hp:       .byte  1,  3,  2,  8
enemy_score:    .byte  1,  5,  3, 20
enemy_ai:       .byte AI_WALK, AI_CHASE, AI_PATROL, AI_BOSS
```

Then a small number of generic AI routines parameterised by these tables. Adding an enemy
becomes a data change, not a code change. This is the single biggest factor in whether a
C64 game project reaches completion.

Push it further: define levels, waves, dialogue, and cutscenes as bytecode interpreted by
a small VM. A ~300-byte interpreter that handles "spawn enemy X at Y", "wait N frames",
"play tune M", "show text T" will save you kilobytes and weeks.

---

## 9. Debugging aids to build in from the start

- **`$D020` profiling bands** around each subsystem, toggleable with a build flag.
- **Frame overrun indicator** (flash the border when the main loop misses vsync).
- **A debug overlay** - a few chars in the top row showing entity count, free list size,
  frame time in raster lines.
- **A cheat/skip key** - invulnerability, skip level, spawn item. You will test the last
  level a thousand times.
- **Deterministic mode** - fixed RNG seed, so bugs reproduce.
- **Assertion macro** that halts with a distinctive border colour and a code, so you know
  *which* assertion fired on real hardware:
  ```asm
  .macro ASSERT_CODE(code) {
      .if (DEBUG) {
          lda #code
          sta $d020
          jmp *
      }
  }
  ```

Strip all of it with a single `.const DEBUG = false` for the release build.

---

## 10. Project discipline

1. **Get something playable on real hardware in week one.** A square that moves and a
   raster bar. The pipeline is the risk, not the game logic.
2. **Lock the memory map early** ([`08-memory-layout.md`](08-memory-layout.md)).
3. **Build the IRQ backbone before the game.** Stable raster + music + multiplexer is the
   foundation; everything else assumes it.
4. **Profile from day one.** You cannot retrofit performance into a C64 game.
5. **Data over code.** Every hardcoded behaviour is technical debt at 1 MHz.
6. **Ship a vertical slice.** One complete level with title, music, gameplay, and game-over
   proves the whole thing works. Then produce content.
7. **Scope brutally.** The scene is littered with ambitious unfinished C64 games. Sam's
   Journey took years with an experienced team.
