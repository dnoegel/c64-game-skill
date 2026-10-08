# Memory map

Single-load PRG, KERNAL and BASIC banked out (`$01 = $35`), VIC bank 1.
Change this file in the same commit as `src/defs.asm`.

```
$0002-$0022   Zero page: engine + game variables (zp_end asserts < $100)
$0100-$01FF   Stack
$0200-$07FF   Free (KERNAL workspace and default screen, unused)
$0801-$12FF   BASIC stub, code, tables, sprite source data (asserted < $4000)
$1300-$3FFF   FREE, about 11 KB: grow code and data here
--- VIC bank 1 ($4000-$7FFF), DD00 bits = %10 -------------------------------
$4000-$47FF   Charset: ROM font copy ($00-$7F) + game tiles from $40
$4800-$4BE7   Screen RAM
$4BF8-$4BFF   Sprite pointers
$4C00-$4FFF   Free (second screen for double buffering)
$5000-$5FFF   Sprite data, 64 frames, pointer = $40 + frame
$6000-$7FFF   Free (8 KB: second charset, more sprites, bitmap)
-----------------------------------------------------------------------------
$8000-$BFFF   Free (16 KB, BASIC ROM banked out above $A000)
$C000-$C3FF   BSS: multiplexer tables, entity arrays, sfx state (zeroed at init)
$C400-$C7FF   BSS reserve (BSS_END = $C800)
$C800-$CFFF   Free (suggested music location)
$D000-$DFFF   I/O (VIC, SID, colour RAM, CIA)
$E000-$FFF9   Free (8 KB, KERNAL banked out)
$FFFA-$FFFF   NMI / RESET / IRQ vectors, written at runtime
```

Raster schedule (every line is below 256, so the same code runs on NTSC):

| Line | Handler | Work |
|---|---|---|
| 20 | `irq_top` | write sprites 0-7, schedule multiplexer IRQs |
| sprite Y - 3 | `irq_mplex` | rewrite a reused hardware sprite (batched when several are due) |
| 252 | `irq_bottom` | swap sprite list, SFX, music, release the main loop |
