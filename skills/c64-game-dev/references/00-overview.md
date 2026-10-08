# 00 - Overview & Strategy

## What "modern C64 game development" actually means in 2026

The scene has changed a lot since the 80s. Three things dominate current practice:

1. **Cross-development is the norm.** Nobody writes on the machine. You edit on a modern
   PC/Mac, assemble with a cross-assembler (or compile C with `oscar64` / `llvm-mos`),
   test in VICE with a source-level debugger, and transfer to real hardware over USB/SD.
   An Ultimate II+ / Ultimate 64 is the usual tool for the last step.

2. **The distribution medium determines the architecture.** A single-load 64K game, a
   multi-load floppy game with an IRQ loader, and a 512K–1MB cartridge game are three
   fundamentally different engines. Decide this *early* - see
   [`10-disk-and-loaders.md`](10-disk-and-loaders.md) and [`11-cartridge.md`](11-cartridge.md).

3. **The "impossible" demoscene tricks are now standard game technique.** Sprite
   multiplexing, opened borders, FLD, VSP/AGSP, and stable rasters all appear in modern
   commercial-quality releases (*Sam's Journey*, *Eye of the Beholder*, *Nixy and the Seeds
   of Doom*, *Prince of Persia*, *Rescue on Fractalus*). The tricks are documented,
   reproducible, and covered in this knowledge base.

## The fundamental constraints

| Resource | Budget |
|---|---|
| CPU | ~0.985 MHz PAL; **19,656 cycles/frame**, realistically ~12–15k after display overhead |
| RAM | 64 KB total; ~52 KB usable with ROMs banked out and a screen + charset resident |
| VIC-II view of RAM | Only **16 KB at a time** (one of four banks) |
| Hardware sprites | **8 total, 8 per raster line**, 24×21 hires or 12×21 multicolour |
| Colours | Fixed 16-colour palette; per-cell colour restrictions in every mode |
| Colour RAM | 1000 nibbles at $D800, **cannot be relocated or banked** |
| Sound | 3 voices, one SID; music and SFX must share them |
| Disk | D64 = 170 KB (664 blocks); stock load is ~400 bytes/s without a fastloader |

Everything in these documents is about buying back one of those budgets by spending
another one.

## The three big levers

### Lever 1 - Raster interrupts
The single most important technique. By interrupting at a known raster line you can
change *any* VIC-II register mid-frame: sprite positions (multiplexing), screen
memory pointer (split screens, more than 256 chars), colours, scroll registers, graphics
mode. Almost every trick in this knowledge base is "a raster IRQ plus one register write
at the right cycle."

→ [`04-raster-irq.md`](04-raster-irq.md)

### Lever 2 - Character mode over bitmap mode
Bitmap mode costs 8000 bytes + 1000 bytes screen RAM and is expensive to animate.
Character mode costs 2048 bytes of charset + 1000 bytes screen and gives you free
hardware scrolling, cheap tile maps, cheap animation (redefine a char and every instance
on screen animates), and ~10× less data to move. **Almost every good C64 game is
character-based.** Bitmap is for static screens, cutscenes, and title pictures.

→ [`06-charmode-graphics.md`](06-charmode-graphics.md)

### Lever 3 - Precomputation
The 6510 is slow but RAM access is fast and uniform. Multiplication tables, sine tables,
row-address tables, pre-shifted sprite data, and unrolled "speedcode" are how you make
things fast. If a value can be computed at assemble time, compute it at assemble time  - 
Kick Assembler's scripting language is excellent for this.

→ [`15-optimization.md`](15-optimization.md)

## Choosing a game shape

The engine cost of a genre varies enormously. Rough guide:

| Genre | Difficulty | Main technical burden |
|---|---|---|
| Single-screen arcade (Bubble Bobble-like) | Low | Sprite multiplexing only |
| Flip-screen platformer / adventure | Low–Med | Screen decompression, entity management |
| Horizontal scroller (shoot-em-up) | Medium | Hardscroll + column update in raster budget |
| 8-way scrolling (Turrican-like) | High | Full char-map scroll, colour RAM is the bottleneck |
| Isometric / 3D-ish | High | Softsprite masking and sorting |
| Dungeon crawler / RPG | Med–High | Data volume; needs cartridge or good loader |
| Vector / filled 3D | Very High | Speedcode, everything else is secondary |

A pragmatic first project: **character-based, flip-screen or single-direction scrolling,
hardware-sprite actors with multiplexing, single-load or simple two-part load.** That
exercises the whole toolchain without the colour-RAM scroll problem eating your budget.

## Recommended technical baseline

Based on current scene practice, a sensible default stack:

- **Assembler:** Kick Assembler (best-in-class macro/scripting for table generation),
  or `oscar64` if you want C with assembly for the hot paths.
- **Editor:** VS Code + the VS64 extension (supports acme/kick/llvm/cc65/oscar64).
- **Emulator/debugger:** VICE 3.9+ with `--moncommands` symbol files; Retro Debugger
  (formerly C64 Debugger) for visual memory/raster inspection.
- **Graphics:** CharPad C64 Pro + SpritePad C64 Pro (paid, ~$15 each, still actively
  updated), or the free browser tool Spritemate.
- **Music:** GoatTracker 2 (cross-platform, GPL) or SID-Wizard.
- **Compression:** Exomizer for size, TSCrunch for speed of in-game depacking.
- **Loader:** Krill's Loader (the scene standard; works with real 1541 and Ultimate II+).
- **Target:** PAL first, with an NTSC compatibility pass planned from day one.
- **Hardware test:** Ultimate II+ (or any SD/USB drive emulator) - `.prg` over USB/network, plus `.d64` and `.crt` testing.

## Proposed next steps

1. Decide medium: floppy (multi-load) vs cartridge. This gates memory planning.
2. Decide genre/scroll model. This gates the raster budget.
3. Stand up a "hello raster bar" build: assembler → `.prg` → VICE → Ultimate II+.
   Prove the whole pipeline before writing engine code.
4. Build the IRQ backbone (stable raster + music call + multiplexer) as the first
   real component; everything else hangs off it.
5. Lock the memory map ([`08-memory-layout.md`](08-memory-layout.md)) before content
   production starts. Moving it later is painful.
