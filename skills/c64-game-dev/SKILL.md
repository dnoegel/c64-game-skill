---
name: c64-game-dev
description: Use when designing, building, debugging, optimizing, or releasing a Commodore 64 game or C64 program for real hardware: 6502/6510 assembly, VIC-II raster interrupts, sprite multiplexing, character/tile graphics, scrolling, SID sound, memory banking, disk/cartridge formats, PAL/NTSC compatibility, VICE, Ultimate II+, asset conversion, and scoping a C64 game project.
---

# C64 Game Development

Build Commodore 64 games that run on real hardware (stock PAL C64, NTSC
compatible), cross-developed on a modern machine. This skill carries a tested
starter engine, asset converters, and a 29-chapter reference distilled from
current scene practice.

## Resources in this skill

| Path | What it is |
|---|---|
| `scripts/new_project.sh <dir> [name]` | Scaffold a project from the starter (64tass + Makefile + converters) |
| `assets/starter/` | Working single-load game: IRQ chain, 24-sprite multiplexer, entities, states, SFX, HUD, PAL/NTSC detection |
| `scripts/png2sprites.py` | PNG sheet to sprite data (hires/multicolour, 64-byte frames), stdlib only |
| `scripts/png2charset.py` | PNG to charset + map + colours (+ meta-tiles), enforces colour rules and the 256-char limit |
| `references/*.md` | The knowledge base. Load only the chapters the task needs (index below) |
| `references/assembler-64tass.md` | 64tass syntax used by the starter, and pitfalls |

Paths are relative to this skill's directory.

## Workflow

### 1. Pin down the four decisions first

They gate memory map and raster budget; changing them later is a rewrite.
Ask the user (one batch, each with a recommended default) only for what the
request leaves open:

1. **Medium**: single-load PRG/D64 (default for a first game), multi-load floppy
   (needs an IRQ loader), or cartridge (EasyFlash/Magic Desk/GMod2).
   `references/10-disk-and-loaders.md`, `references/11-cartridge.md`
2. **Genre and scroll model**: single-screen and flip-screen are cheap;
   8-way scrolling is the most expensive (colour RAM cannot be double-buffered).
   `references/22-genre-engine-patterns.md`, `references/07-scrolling.md`
3. **Language**: assembly (default, starter uses 64tass) or C with
   oscar64/llvm-mos plus assembly for IRQs and the multiplexer.
   `references/02-toolchain.md`, `references/25-frameworks-and-engines.md`
4. **Scope**: content volume, team, deadline. Most C64 projects die of scope.
   `references/28-project-planning.md`, `references/21-game-design.md`

### 2. Start from the starter, not from a blank file

```sh
<skill>/scripts/new_project.sh ~/code/mygame mygame
cd ~/code/mygame && make          # needs 64tass, python3, VICE (x64sc, c1541)
```

Read `assets/starter/README.md` and `docs/memory-map.md` of the new project
before changing it. The starter already solves machine takeover, the IRQ
chain, multiplexing with double-buffered lists, PAL/NTSC, input edges, SFX
priorities and build-time memory asserts. Grow it; do not replace these parts
unless the design requires it (for example a scroller replaces the screen
code, not the IRQ backbone).

If the user's project already exists, follow its assembler and conventions
instead; port starter patterns, not syntax.

### 3. Build in this order

1. Pipeline proven: build, run in VICE, run on hardware (`make hw`).
2. IRQ backbone and multiplexer (done in the starter).
3. Lock the memory map (`docs/memory-map.md` + `src/defs.asm`) before content.
4. One playable vertical slice: title, one level, music, game over.
5. Then content, driven by data tables, not code.

### 4. Verify every change

- **Assemble cleanly**: zero errors, zero warnings. The starter uses `.cerror`
  asserts for memory regions; add one whenever you rely on an address or size.
- **Measure, do not guess**: debug builds paint border bands per subsystem
  (one band line = 63 cycles PAL). Red border flash = missed frame.
- **Run it** when the user allows emulator runs: `make shot` (PAL) and
  `make shot-ntsc` emulate a few seconds headless and save a PNG to inspect;
  `make run` for interactive testing. Do not launch emulators or send to
  hardware if the user has said not to; then rely on assembly, asserts, and a
  careful read of IRQ/stack/flag logic, and say that runtime was not tested.
- **Real hardware** before calling timing work done: VICE `x64sc` is close, not
  identical. `references/16-testing-compat.md` has the test matrix.

## Hard rules (the bugs that cost days)

- Use `x64sc`, never `x64`.
- `$01 = $35` for games: KERNAL/BASIC gone, so own `$FFFE` (IRQ) and `$FFFA`
  (NMI, point it at an `rti`). Disable CIA IRQs (`$7F` to `$DC0D`/`$DD0D`, then
  read both) before `cli`.
- Every IRQ handler: save A/X/Y, `cld` if the main loop ever uses decimal mode,
  acknowledge `$D019` (`asl $d019` or write `$FF`), restore, `rti`.
- Never reset the stack (`txs`) inside a subroutine; do it at the entry point.
- IRQs do fixed-cost register writes. Variable work goes in the main loop,
  released by a flag from a lower-border IRQ. Overrun must mean slowdown,
  never corruption.
- Keep raster compare lines below 256 or handle RST8 (`$D011` bit 7). NTSC has
  only 263 lines (262 on old VIC); waiting for line > 262 hangs.
- Multiplexer: sorted by Y, hardware sprite reused only 21+ lines after its
  previous use, registers written before the raster reaches the new Y,
  display lists double-buffered, an "already passed" guard on every chained IRQ.
- The VIC sees one 16 KB bank (`$DD00` bits 0-1, inverted). In banks 0 and 2
  the character ROM shadows `$1000-$1FFF` / `$9000-$9FFF`: no graphics there.
- Colour RAM (`$D800`) cannot move or be double-buffered. Prefer colour per
  character ("char-locked" colour) so colour writes follow char writes.
- Real C64 RAM is not zeroed at power-on. Initialise every variable.
- `$D01E`/`$D01F` collisions clear on read and say which sprites, not where;
  use box tests for gameplay.
- Edge-trigger the fire button (pressed this frame), not level.
- Never trust a cycle count from prose (including these references) for VSP,
  sprite crunch or side borders: copy a known-good implementation and test on
  hardware.

## Budgets to design against

```
PAL   312 lines x 63 cycles = 19,656 cycles/frame, 50.12 Hz
NTSC  263 lines x 65 cycles = 17,095 cycles/frame, 59.83 Hz
Bad line: ~40 cycles stolen. 8 sprites on a line: ~19 stolen. Both: ~4 left.
Realistic game logic budget after display, music, multiplexer: 11-14k cycles PAL.
Music: 1,000-2,500 cycles. Full 1000-char screen copy: ~8,000 cycles.
8 sprites per line, 24x21 (12x21 multicolour), 1 own + 2 shared colours.
Charset 256 chars x 8 bytes; screen 1000 bytes; 16 fixed colours.
D64: 664 blocks (~166 KB) usable; stock load ~400 bytes/s, so use a fastloader.
```

## Reference index

Load the chapter that matches the task; each is self-contained.

| Task | Read |
|---|---|
| Strategy, constraints, what kind of game fits | `00-overview.md` |
| Register addresses, memory map, palette, cycle costs | `01-hardware-reference.md` |
| Assemblers, C compilers, VICE, debuggers, tools | `02-toolchain.md`, `assembler-64tass.md` |
| Bad lines, sprite DMA, frame budget, PAL/NTSC timing | `03-vic-ii-timing.md` |
| Raster IRQs, stable raster, IRQ chains | `04-raster-irq.md` |
| Sprites: multiplexing, overlays, stretching, collisions | `05-sprites.md` |
| Char modes, tile engines, softsprites, bitmap, splits | `06-charmode-graphics.md` |
| Scrolling, FLD, linecrunch, VSP/AGSP, open borders | `07-scrolling.md` |
| Memory layout, banking, VIC banks, worked memory maps | `08-memory-layout.md` |
| SID, music players, SFX strategies, 6581 vs 8580 | `09-sound.md` |
| D64/D81, fastloaders, IRQ loaders, multi-load, saves | `10-disk-and-loaders.md` |
| Cartridges: formats, bank switching, CRT builds | `11-cartridge.md` |
| Exomizer, TSCrunch, in-game decompression | `12-compression.md` |
| Ultimate II+ transfer loop, UCI, REU | `13-ultimate-ii-plus.md` |
| Engine structure, entities, state machines, fixed point | `14-game-architecture.md` |
| Speedcode, tables, illegal opcodes, self-modifying code | `15-optimization.md` |
| PAL/NTSC, chip revisions, test matrix, release checks | `16-testing-compat.md` |
| Links: tools, articles, sources, communities | `17-resources.md` |
| Scene, publishers, compos, market | `18-modern-c64-scene.md` |
| Modern game case studies | `19-case-studies.md` |
| Classic games to study and how | `20-classics-to-study.md` |
| Game design within C64 limits | `21-game-design.md` |
| Engine patterns per genre, decision table | `22-genre-engine-patterns.md` |
| Art: palette, colour rules, overlays, charset budgets | `23-art-and-graphics-production.md` |
| Level data, tile maps, converters, authoring | `24-content-pipeline.md` |
| Existing frameworks and engines | `25-frameworks-and-engines.md` |
| Porting to and from the C64 | `26-porting-and-conversions.md` |
| Release formats, publishers, checklist | `27-publishing-and-release.md` |
| Scoping, phases, roles, definition of done | `28-project-planning.md` |

## Asset pipeline

Keep editable sources (PNG, CharPad `.ctm`, SpritePad `.spd`, tracker songs)
in the repo and convert in the Makefile, never by hand:

```sh
tools/png2sprites.py assets/hero.png -o build/hero.bin --mc --mc0 black --mc1 lightred
tools/png2charset.py assets/level1.png --mode mc --bg black --mc1 darkgrey --mc2 grey \
    -o build/chars.bin --map build/level1.map --char-colours build/chars.col \
    --tiles 2x2 --tile-data build/tiles.bin --tile-map build/level1.tmap
```

Both report colour-rule violations with cell or pixel coordinates; pass them
to the artist instead of silently "fixing" art. `--strict` fails the build.

## Hardware loop

`make hw ULTIMATE=<ip>` POSTs the PRG to an Ultimate II+/Ultimate 64 REST API
(`/v1/runners:run_prg`). Sending to hardware is an action on the user's
device: only do it when asked. DMA loading is not representative of a real
1541 load; test the D64 with a real or emulated drive before release.
