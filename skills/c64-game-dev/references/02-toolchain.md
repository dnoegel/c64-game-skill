# 02 - Toolchain and Build Pipeline

Everything here runs on macOS, Linux and Windows unless noted.

---

## 1. Assemblers

| Tool | Language | Why pick it | Where |
|---|---|---|---|
| **Kick Assembler** | Java | **Recommended.** Best-in-class scripting (a full expression/macro language) for generating tables, sine curves, unrolled speedcode, charsets at assemble time. Excellent VICE/C64Debugger integration | <https://theweb.dk/KickAssembler/> |
| **ACME** | C | Fast, simple, ubiquitous in the scene. Most Codebase64 examples are ACME | <https://sourceforge.net/projects/acme-crossass> |
| **64tass** | C | Turbo Assembler-compatible syntax, very capable, good scoping | <https://sourceforge.net/projects/tass64> |
| **ca65** | C (part of cc65) | Needed if you use cc65; a proper linker with segments | <https://cc65.github.io> |
| **c64jasm** | JavaScript/Node | Modern, scriptable in JS, good debug-info output | <https://nurpax.github.io/c64jasm/> |

**The bundled starter uses 64tass** (native binary, in Homebrew and Debian, no JVM; see
[`assembler-64tass.md`](assembler-64tass.md)). For a project started from scratch,
**Kick Assembler** remains an excellent choice. The scripting language pays for itself the first time
you need 256 entries of `sin(x)*32+32` or a 2 KB block of unrolled `lda #$xx / sta $d0xx`.

```java
// Kick Assembler: generate a sine table at assemble time
.var sinTable = List()
.for (var i = 0; i < 256; i++) {
    .eval sinTable.add(round(sin(toRadians(i*360/256)) * 40 + 40))
}
sintab: .fill 256, sinTable.get(i)

// Generate unrolled speedcode
copyfast:
.for (var i = 0; i < 40; i++) {
    lda source + i
    sta $0400 + i
}
    rts
```

Install: `brew install openjdk` then run `java -jar KickAss.jar`. Wrap it in a shell
script or Makefile target.

---

## 2. C compilers

Writing a whole C64 game in assembly is entirely reasonable, but C is now genuinely
viable for game logic with assembly for the hot paths.

| Tool | Notes |
|---|---|
| **oscar64** | **Best current option for games.** C99 + much of C++ (templates, lambdas). Aggressive optimisation; ~442 Dhrystone/s on a stock C64 at `-O3`. Native 6502 codegen for hot functions, optional bytecode for size. **Has built-in support for disk overlays and banked cartridges** - the linker places code/data from virtual cartridge banks into overlay files you load and call as normal functions. <https://github.com/drmortalwombat/oscar64> |
| **llvm-mos** | Full Clang/LLVM port to 6502. C++11, whole-program optimisation. Excellent codegen, heavier toolchain. <https://llvm-mos.org> |
| **cc65** | The old standard. Mature, huge library, but the code generator is dated and slow compared to the above. Fine for tools and non-realtime code |
| **KickC** | C-to-6502 targeting readable assembly output. Interesting but less active |

**Recommendation:** if you want C, use **oscar64** - its overlay/banking support maps
directly onto both of your distribution targets (floppy and cartridge), which is a big
practical advantage. Write the IRQ handlers, multiplexer, and any raster-critical code in
assembly regardless.

---

## 3. Editor / IDE

**VS Code + VS64** (<https://github.com/rolandshacks/vs64>) is the current best setup.
Supports `acme`, `kick`, `llvm`, `cc65`, and `oscar64`; handles building, launching VICE,
and debugging.

Alternatives: Sublime with the Kick Assembler package; Relaunch64 (dedicated C64 IDE);
plain Makefile + any editor.

---

## 4. Emulator and debugging

### VICE
<https://vice-emu.sourceforge.io> - the reference emulator. `brew install vice` or grab
the macOS build. Use `x64sc` (the cycle-accurate build), **not** `x64` (the fast,
inaccurate one). For C64 development accuracy matters more than speed.

Key features:
- Built-in monitor: `break $c000`, `step`, `next`, `disass`, `m $0400`, `d`, `g`
- `--moncommands file.txt` loads a symbol/breakpoint script at startup
- Kick Assembler and c64jasm can emit VICE symbol files automatically
- Warp mode, save/load snapshots, VIC-II/sprite viewers
- `-autostart game.prg`

Typical launch:
```sh
x64sc -autostart build/game.prg -moncommands build/game.vs
```

### Retro Debugger (formerly C64 Debugger)
<https://github.com/slajerek/RetroDebugger> - a visual debugger with a **live raster-time
display**, memory maps, sprite/charset viewers, and source-level stepping when fed debug
info from Kick Assembler. Invaluable for raster work: you can literally see where in the
frame your code executes.

### IceBro
<https://github.com/Sakrac/IceBro> - connects to a running VICE instance and mirrors CPU
state, RAM, labels, and breakpoints. Lighter-weight alternative.

### The `$D020` technique
Regardless of tooling, `inc $d020` / `dec $d020` around a routine to see its raster cost
is still the fastest way to profile, and it works identically on real hardware. See
[`03-vic-ii-timing.md`](03-vic-ii-timing.md) §4.

---

## 5. Graphics tools

| Tool | Purpose | Notes |
|---|---|---|
| **CharPad C64 Pro** | Charsets, tiles, tile colours, maps | The standard. ~$15 on itch.io, actively maintained (3.8.x, 2025). Exports binary/asm/PNG |
| **SpritePad C64 Pro** | Sprite sets, animations, overlays | Companion to CharPad, same vendor |
| **Spritemate** | Browser-based sprite editor | Free. Multicolour, overlays, SpritePad import, **assembly source export**, and can extract sprites from a VICE snapshot. <https://www.spritemate.com> |
| **Multipaint** | Bitmap art (multicolour/hires) | Cross-platform, good for title screens |
| **Project One / PETSCII editors** | PETSCII art | For text screens and menus |
| **Tiled** | General tile map editor | Not C64-native; usable with a custom exporter script if you prefer it to CharPad |

Both CharPad and SpritePad are from Subchrist Software:
<https://subchristsoftware.itch.io/c64-pro-editions>

**Pipeline advice:** keep the *source* files (`.ctm`, `.spd`) in the repo and export
binaries as a **build step**, so regenerating assets is reproducible. Write a small
Python/Node script to convert the exported binaries into the exact layout your engine
wants (e.g. de-interleaving, re-ordering, appending colour tables).

---

## 6. Music tools

| Tool | Notes |
|---|---|
| **GoatTracker 2** | Cross-platform (macOS build available), GPL, by Lasse Öörni. The scene default. Exports a relocatable player + data at a chosen address |
| **SID-Wizard** | Runs on the C64 itself and cross-platform; `SIDmaker` utility converts `.swm` to `.sid` or a standalone C64 executable |
| **SidTracker64** | iOS; nice for sketching |
| **CheeseCutter** | Another tracker with a strong following |

Integration is covered in [`09-sound.md`](09-sound.md).

---

## 7. Packaging and transfer

| Tool | Purpose |
|---|---|
| **c1541** (ships with VICE) | Build `.d64`/`.d71`/`.d81` images from the command line - scriptable, essential for the build |
| **exomizer** | Compression + self-extracting `.prg` generation. <https://bitbucket.org/magli143/exomizer> |
| **TSCrunch** | Fast-decompressing alternative. <https://github.com/tonysavon/TSCrunch> |
| **cartconv** (ships with VICE) | Convert binaries to `.crt` cartridge images |
| **Ultimate II+** | USB stick, or network/FTP transfer of `.prg`/`.d64`/`.crt` - see [`13-ultimate-ii-plus.md`](13-ultimate-ii-plus.md) |

Building a disk image:
```sh
c1541 -format "mygame,01" d64 build/game.d64 \
      -attach build/game.d64 \
      -write build/loader.prg loader \
      -write build/part1.prg  "part1" \
      -write build/music.prg  "music"
```

---

## 8. A concrete build setup

```
c64-game/
├── Makefile
├── src/
│   ├── main.asm
│   ├── irq.asm
│   ├── multiplex.asm
│   └── ...
├── assets/
│   ├── charset.ctm         (CharPad source)
│   ├── sprites.spd         (SpritePad source)
│   └── music.sng           (GoatTracker source)
├── build/                  (generated, gitignored)
└── tools/
    └── convert_assets.py
```

```makefile
KICKASS = java -jar $(HOME)/tools/KickAss.jar
VICE    = x64sc

all: build/game.d64

build/game.prg: src/main.asm assets/*.bin
	$(KICKASS) src/main.asm -o $@ -vicesymbols -showmem

build/game.d64: build/game.prg
	c1541 -format "game,01" d64 $@ -attach $@ -write $< game

run: build/game.prg
	$(VICE) -autostart $< -moncommands build/main.vs

.PHONY: all run
```

Add a `make hw` target once the hardware transfer method is settled - either copying
to a mounted USB/SD volume or pushing over the network.

---

## 9. Version control notes

Put the project under version control before writing code:

```sh
git init
```

`.gitignore`:
```
build/
*.prg
*.d64
*.crt
*.vs
```

Keep asset *sources* (`.ctm`, `.spd`, `.sng`) in version control; they're small and
binary-diffable enough. Keep generated binaries out.

---

## 10. Reference code archives worth cloning

- **Codebase64** - the scene's collective knowledge base. Live mirrors:
  <https://codebase.c64.org> and <https://codebase64.pokefinder.org>.
  > **Warning:** the old `codebase64.org` domain now redirects to an unrelated
  > commercial site.
  > Use the two mirrors above.
- **CSDb** <https://csdb.dk> - releases, sources, and the scene's discussion forums.
- Reverse-engineered game sources:
  <https://github.com/Piddewitt/C64-Game-Source-Code>,
  <https://github.com/mwenge/iridisalpha>
- Working modern engines: <https://github.com/hhprg/C64Engine>,
  <https://github.com/leissa/c64engine>
