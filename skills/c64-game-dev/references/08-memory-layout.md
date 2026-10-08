# 08 - Memory Layout and Banking

64 KB is the whole world. Planning this early - before content production - saves an
enormous amount of pain.

---

## 1. The three banking systems (they are independent)

1. **CPU banking** via `$0001` - which of RAM / BASIC ROM / KERNAL ROM / Char ROM / I/O
   the *CPU* sees at a given address.
2. **VIC banking** via `$DD00` bits 1–0 - which 16 KB window the *VIC* can see.
3. **Cartridge banking** via a cartridge register (e.g. `$DE00`) - which page of ROM/flash
   appears at `$8000` or `$A000`. Only relevant for cartridge builds
   ([`11-cartridge.md`](11-cartridge.md)).

They interact but are configured separately. A classic confusion: setting `$01 = $34`
(all RAM to the CPU) does **not** change what the VIC sees; the VIC never sees I/O and
always sees the char ROM in banks 0 and 2.

---

## 2. Reclaiming RAM

Setting `$01 = $35` (RAM everywhere except I/O) gives you back:

```
$A000-$BFFF   8 KB   (BASIC ROM area)
$E000-$FFFF   8 KB   (KERNAL ROM area, minus the vectors at $FFFA-$FFFF)
              -----
             16 KB extra
```

Total usable RAM with a game running:

```
$0000-$0001   CPU port                                    2 bytes (reserved)
$0002-$00FF   zero page                                 254 bytes  <- precious
$0100-$01FF   stack                                     256 bytes  (you only need ~32)
$0200-$03FF   ex-KERNAL workspace - FREE in a game      512 bytes
$0400-$FFF9   everything else                        ~63.4 KB
$FFFA-$FFFF   IRQ/NMI/RESET vectors                       6 bytes (reserved)
```

Realistically **~52–56 KB** for code + data after screens, charsets, and sprites.

### Zero page
`$02–$FF` is entirely yours once BASIC/KERNAL are out. 254 bytes of 3-cycle,
2-byte-instruction storage. Use it for:
- All 16-bit pointers (`(zp),Y` is the only indirect addressing mode)
- Hot loop counters and per-frame temporaries
- The multiplexer's working variables
- Anything read/written more than a few times per frame

Zero-page indexed (`lda zp,x`) is 4 cycles vs 4/5 for `lda abs,x` - plus one byte
shorter. Self-modifying zero-page addresses are a common speed trick.

### The stack page
You only need ~32 bytes of stack (IRQ frames + a few `jsr` levels). The other ~224 bytes
of `$0100–$01FF` are usable as data if you set the stack pointer low and never let it
underflow. Many engines put sprite tables there. Slightly risky; document it clearly if
you do it.

### `$0200–$03FF`
512 bytes of ex-KERNAL workspace, completely free. Note `$0334–$03FB` is a common home for
small routines in single-load demos, and `$0400` is the default screen.

---

## 3. The VIC bank problem

The VIC sees only 16 KB. Everything it must read - **charset, screen RAM, sprite data,
bitmap** - has to live in that window.

| $DD00 & 3 | Bank | Range | Char ROM shadow at | Fully usable? |
|---|---|---|---|---|
| `%11` | 0 | $0000–$3FFF | $1000–$1FFF | No - 4 KB lost |
| `%10` | 1 | $4000–$7FFF | none | Yes |
| `%01` | 2 | $8000–$BFFF | $9000–$9FFF | No - 4 KB lost |
| `%00` | 3 | $C000–$FFFF | none | Yes |

- **Banks 1 and 3** are fully usable (no char ROM shadow).
- In banks 0 and 2, the 4 KB at offset $1000–$1FFF is unusable for graphics data (the VIC
  reads char ROM there regardless of `$01`). The CPU still sees RAM there - you can put
  code or non-VIC data in it.
- The VIC reads `$3FFF` (bank-relative `$3FFF`) when idle - in some border/invalid-mode
  tricks the contents of that byte are displayed. Keep it at `$00` unless you're
  deliberately exploiting it.

### Bank 3 ($C000–$FFFF) caveat
The VIC has no concept of I/O - for the VIC, `$D000–$DFFF` is plain RAM. So bank 3 is
fully usable for graphics **from the VIC's point of view**, but the *CPU* needs `$01 =
$34` (all RAM) to write to `$D000–$DFFF`, which means no I/O access during those writes.
Workable but awkward. **Bank 1 ($4000–$7FFF) is the pragmatic default.**

### Switching banks mid-frame
`$DD00` can be changed from a raster IRQ, giving you effectively 32 KB of graphics data
across a frame (e.g. one bank for the status bar, one for the playfield). It costs
nothing extra and is a legitimate way to blow past the 16 KB limit. Do the switch in the
border or on a row boundary.

---

## 4. A worked memory map (floppy, single-load)

```
$0002-$00FF   Zero page               254 B   pointers, hot vars
$0100-$011F   Stack                    32 B
$0120-$01FF   Sprite sort tables      224 B   (stack page reuse)
$0200-$03FF   Multiplexer tables      512 B
$0400-$07E7   (unused / scratch)
$0800-$3FFF   Game code               14 KB
--- VIC BANK 1 ($4000-$7FFF) -----------------------------------------
$4000-$47FF   Charset A                2 KB   playfield
$4800-$4FFF   Charset B                2 KB   status bar / alt tiles
$5000-$53FF   Screen RAM 0             1 KB   (sprite ptrs at $53F8)
$5400-$57FF   Screen RAM 1             1 KB   (double buffer)
$5800-$5FFF   (free, 2 KB)
$6000-$6FFF   Sprite data              4 KB   64 sprites
$7000-$7FFF   Sprite data / tiles      4 KB
----------------------------------------------------------------------
$8000-$9FFF   Level map data           8 KB
$A000-$BFFF   More code / data         8 KB   (BASIC ROM banked out)
$C000-$CFFF   Music + player           4 KB
$D000-$DFFF   I/O
$E000-$FFF9   Compressed level store   8 KB   (KERNAL banked out)
$FFFA-$FFFF   Vectors
```

## 5. A worked memory map (cartridge)

With a cartridge, code and read-only data live in ROM banks and RAM is almost entirely
free for state.

```
$8000-$9FFF   Cartridge ROM window (banked)     8 KB per bank
$A000-$BFFF   Second ROM window or RAM
$0800-$7FFF   Almost entirely free RAM for the working set
```

The pattern: a small resident "kernel" in RAM (IRQ handlers, the bank-switch trampoline,
the current level's decompressed data), with everything else paged in on demand. See
[`11-cartridge.md`](11-cartridge.md).

---

## 6. Planning discipline

1. **Write the memory map down before you write code** and keep it in the repo. Update it
   in the same commit that changes it.
2. **Use assembler segments/constants**, never raw addresses:
   ```asm
   .const VIC_BANK      = 1
   .const VIC_BASE      = VIC_BANK * $4000
   .const CHARSET       = VIC_BASE + $0000
   .const SCREEN0       = VIC_BASE + $1000
   .const SCREEN1       = VIC_BASE + $1400
   .const SPRITE_BASE   = VIC_BASE + $2000
   .const SPRITE_PTRS   = SCREEN0 + $03F8
   .const D018_SCREEN0  = ((SCREEN0 & $3fff) >> 6) | ((CHARSET & $3fff) >> 10)
   ```
   Then moving a block is one constant change.
3. **Emit a memory-usage report from the build.** Kick Assembler's `-showmem` prints a
   block map; check it every build and fail loudly on overlaps.
4. **Reserve a slack region** (1–2 KB) from the start. You will need it.
5. **Decide the double-buffering strategy early.** Screen RAM double-buffering costs 1 KB
   and eliminates a whole class of tearing bugs; it's usually worth it.

---

## 7. RAM under I/O

`$D000–$DFFF` is 4 KB of RAM the CPU can reach with `$01 = $34`. Access pattern:

```asm
    sei                     ; IRQs must not fire while I/O is banked out!
    lda #$34
    sta $01
    ; ... read/write $D000-$DFFF as RAM ...
    lda #$35
    sta $01
    cli
```

Rules:
- **Always `sei` around it.** An IRQ firing while I/O is banked out will read garbage
  vectors and crash. (With `$01 = $34` the vectors at `$FFFA` are still RAM, so it can
  work, but `$D019` acknowledgement won't - so just disable interrupts.)
- Good for **bulk storage** read/written in blocks: compressed level data, sample data,
  save-state buffers, undo buffers. Bad for anything touched per-frame.
- The VIC can see this RAM directly if you're in bank 3 - a nice trick for a big graphics
  store, at the cost of the bank-3 awkwardness above.

---

## 8. Memory-saving techniques ranked by value

| Technique | Typical saving | Cost |
|---|---|---|
| Bank out BASIC + KERNAL (`$01 = $35`) | **16 KB** | Must supply own vectors, no KERNAL routines |
| Compress level/graphics data ([`12`](12-compression.md)) | 40–70 % of data | Depack time on load |
| Tile-based maps instead of raw screens | 4–16× on map data | Tile decode per screen |
| Charset animation instead of extra chars | 100s of bytes | - |
| Software mirroring of sprites | 50 % of sprite data | ~200 cycles per direction change |
| Reuse chars across tiles | 20–40 % of charset | Art discipline |
| Overlays / multi-load (floppy) | Unbounded | Load pauses, [`10`](10-disk-and-loaders.md) |
| Cartridge banks | Unbounded | Cartridge production, [`11`](11-cartridge.md) |
| Pack booleans into bit flags | 8× on flags | Mask/shift instructions |
| Use `$0200–$03FF` and the stack page | ~700 bytes | Documentation discipline |
| RAM under I/O | 4 KB | `sei` + banking around access |
