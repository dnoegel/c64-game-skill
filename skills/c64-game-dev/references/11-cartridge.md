# 11 - Cartridge Development

A cartridge removes the loading problem entirely and gives you hundreds of kilobytes to
megabytes of instantly-available data. For a large game it is transformative - *Eye of
the Beholder* only became possible on C64 when its author targeted EasyFlash.

---

## 1. How C64 cartridges work

The expansion port exposes two chip-select lines and two control lines:

| Signal | Meaning |
|---|---|
| `ROML` | Active when the CPU reads `$8000–$9FFF` |
| `ROMH` | Active when the CPU reads `$A000–$BFFF` (or `$E000–$FFFF` in Ultimax mode) |
| `GAME` | Cartridge control line |
| `EXROM` | Cartridge control line |

`GAME` and `EXROM` together select the memory configuration:

| EXROM | GAME | Mode |
|---|---|---|
| 1 | 1 | No cartridge (normal C64) |
| 0 | 1 | **8K mode** - ROM at `$8000–$9FFF` |
| 0 | 0 | **16K mode** - ROM at `$8000–$BFFF` |
| 1 | 0 | **Ultimax mode** - ROM at `$E000–$FFFF`, most RAM disabled |

Also available: `$DE00–$DEFF` (I/O 1) and `$DF00–$DFFF` (I/O 2) for the cartridge's own
registers - this is where bank-switching registers live.

### Autostart
The C64 KERNAL checks for the "CBM80" signature at `$8004` on reset:

```asm
* = $8000
    .word cold_start        ; $8000-$8001 cold start vector
    .word warm_start        ; $8002-$8003 warm start vector (NMI)
    .byte $C3, $C2, $CD, $38, $30   ; "CBM80" in PETSCII with high bits
cold_start:
    sei
    cld
    ldx #$ff
    txs
    stx $8004               ; kill the signature so a reset doesn't re-enter
    jsr $fda3               ; KERNAL IOINIT
    jsr $fd50               ; RAMTAS
    jsr $fd15               ; RESTOR
    jsr $ff5b               ; CINT
    cli
    jmp game_start
```

---

## 2. Cartridge formats worth considering

| Format | Max size | Banking | On-cart save | Notes |
|---|---|---|---|---|
| **Magic Desk** | 512 KB (1 MB in some variants) | `$DE00` selects an 8 KB bank at `$8000` | ❌ | Simple, well supported, cheap DIY hardware. **VICE added Magic Desk 16K support in r45695, June 2025** |
| **GMod2** | 512 KB flash + 2 KB EEPROM | `$DE00` | ✅ (EEPROM) | Modern, actively used, DIY-buildable |
| **EasyFlash** | 1 MB (2× 512 KB, ROML+ROMH) | `$DE00` bank, `$DE02` control | ✅ (flash write) | The scene standard for large games. Hardware widely available |
| **EasyFlash 3** | 1 MB + extras | | ✅ | Adds a menu, USB, freezer |
| **GMod3** | > 1 MB | Different paging scheme | ✅ | For when 1 MB isn't enough |
| Ocean | 512 KB | `$DE00` | ❌ | Classic commercial format, well emulated |

### Choosing

- **No saves needed → Magic Desk.** Simplest hardware, simplest software, cheapest to
  produce, DIY-friendly.
- **Saves needed → GMod2 or EasyFlash.** GMod2's separate EEPROM is cleaner than
  EasyFlash's in-place flash writing.
- **Large game (> 512 KB) → EasyFlash** (1 MB) or GMod3.

DIY hardware:
- GMod2/Magic Desk/Ocean-compatible DIY cartridge:
  <https://www.freepascal.org/~daniel/gmod2/>
- MagicDesk2 open hardware: <https://github.com/crystalct/MagicDesk2>
- Kits are available from sellmyretro and similar.

---

## 3. Bank switching in practice (Magic Desk / EasyFlash style)

```asm
; --- Magic Desk: write bank number to $DE00 ---
BANKREG = $de00

select_bank:            ; A = bank number
    sta BANKREG
    rts
```

The critical rule: **the code performing the bank switch must not be in the window being
switched.** Two solutions:

### A. RAM trampoline (recommended)
Copy a tiny stub into RAM at startup. All cross-bank calls go through it.

```asm
; --- in RAM ---
far_call:               ; A = bank, X/Y = target address lo/hi
    sta BANKREG
    stx jump+1
    sty jump+2
jump:
    jsr $ffff           ; self-modified target in the banked window
    lda #RESIDENT_BANK
    sta BANKREG
    rts
```

With nested calls you need a small bank stack:

```asm
far_call:
    ldx bank_sp
    lda current_bank
    sta bank_stack,x
    inc bank_sp
    ; ... switch, call ...
    dec bank_sp
    ldx bank_sp
    lda bank_stack,x
    sta current_bank
    sta BANKREG
    rts
```

### B. Mirror the trampoline in every bank
Place the identical switch stub at the same address in *all* banks. Then the switch is
transparent - after the write, the CPU continues executing the same bytes from the new
bank. Costs a few bytes per bank, avoids any RAM cost. This is a very common trick.

### Data access across banks
Reading data from another bank has the same problem in reverse. The usual pattern is a
`far_read` helper in RAM (or a bank-mirrored stub) that switches, copies a block into a
RAM buffer, and switches back. For per-byte access this is far too slow - **always copy
in blocks**.

---

## 4. Architecture for a cartridge game

```
RAM  $0800-$CFFF   the working set:
                     - IRQ handlers, multiplexer, music player (resident)
                     - the bank trampoline
                     - current level's decompressed map
                     - entity state, screens, charsets, sprite data
ROM  $8000-$9FFF   the currently paged-in bank (8 KB)
                     - bank 0: boot + resident code that gets copied to RAM
                     - bank 1..N: level data, graphics sets, music, text, code overlays
```

Key design points:

1. **Copy the resident engine to RAM at boot.** Executing from a banked ROM window means
   you can never switch banks while that code runs. Get the engine into RAM once, then the
   ROM is pure data + overlay code.
2. **Treat banks as a random-access asset store.** With no seek time, you can pull a
   charset or a level in a couple of milliseconds. This is the whole advantage.
3. **You may not need compression at all.** With 512 KB–1 MB, store data uncompressed for
   instant access. Compress only if you're genuinely tight.
4. **VIC-visible data must be in RAM.** The VIC cannot read the cartridge. Every charset,
   sprite, and screen must be copied from ROM into the VIC bank. Budget for those copies
   (a 2 KB charset copy is ~12,000 cycles - one frame with the screen blanked).

---

## 5. On-cartridge saving

### GMod2
2 KB serial EEPROM, accessed via a bit-banged protocol through the cartridge register.
Slow (it's I²C-ish) but 2 KB is plenty for save games and high scores. Well documented in
the GMod2 hardware project.

### EasyFlash
Writes to the flash chip itself. Requires:
- Erasing a sector (flash erases in blocks, typically 64 KB) before writing.
- Following the flash chip's command sequence (unlock writes to specific addresses).
- **Reserving a dedicated sector** for save data so you never erase code.
- Flash has limited erase cycles (typically 100k+, so not a practical concern, but don't
  write every frame).

### Recommendation
If saving matters, **GMod2**. The separate EEPROM is simpler, safer, and can't brick the
game by erasing the wrong sector.

---

## 6. Building and testing `.crt` files

VICE ships `cartconv`:

```sh
# Magic Desk, 512 KB from a raw binary of concatenated 8 KB banks
cartconv -t md -i build/cart.bin -o build/game.crt -n "My Game"

# EasyFlash
cartconv -t easyflash -i build/cart.bin -o build/game.crt -n "My Game"

# list supported types
cartconv -t help
```

Test in VICE:
```sh
x64sc -cartcrt build/game.crt
```

Test on hardware: **an Ultimate II+ emulates EasyFlash and GMod2 cartridges directly**  - 
put the `.crt` on the USB stick and mount it. This is a huge advantage: you can develop
and test the entire cartridge build without owning a single flash cartridge. See
[`13-ultimate-ii-plus.md`](13-ultimate-ii-plus.md).

For a real release you'd have EasyFlash/GMod2 carts flashed, or work with a publisher
(Protovision, Psytronik, RGCD) who handles production.

---

## 7. Floppy *and* cartridge from one codebase

Worth planning for, since you mentioned both as possibilities.

The abstraction: **an asset-fetch layer**.

```asm
; load_asset: X = asset ID
;   floppy build   -> looks up (track, sector, length) and calls the fastloader
;   cartridge build-> looks up (bank, offset, length) and calls the bank copier
```

Everything above this layer is identical. Below it, two implementations selected at
assemble time.

`oscar64` supports this pattern directly: its linker places code/data from virtual
cartridge banks into **overlay files** when targeting `.d64`, and into real cartridge
banks when targeting `.crt` - the calls look like normal function calls in both cases.
If you're writing in C, that's a strong reason to pick oscar64.

Practical differences to design around:
- **Cartridge has no load delay; floppy does.** Don't build gameplay that requires
  instant asset access unless the floppy build can pre-load it.
- **Cartridge builds can be much larger.** Either ship the same content on both (limited
  by the floppy) or make the cartridge version an "extended edition."
- **Saving works differently.** Abstract that too.
