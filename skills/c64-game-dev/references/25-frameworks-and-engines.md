# 25 - Existing Frameworks, Engines and Shortcuts

You don't have to start from zero. Options ranked from "no code at all" to "write
everything yourself."

---

## 1. `c64gameframework` - Lasse Öörni (Cadaver)

<https://github.com/cadaver/c64gameframework>

**The most valuable single resource for a serious C64 action game.** A complete,
production-proven assembly framework for multidirectionally scrolling games - a modified
version powers *MW ULTRA*, and it descends from the engines behind *Metal Warrior*,
*Hessian*, and *Steel Ranger*.

### What it gives you

| Feature | Detail |
|---|---|
| Display | 50 Hz screen update, 22 visible scrolling rows |
| Actors | Update every **second** frame, with **sprite movement interpolated** on the off-frame - halves logic cost, looks smooth at 50 Hz |
| Sprites | **24-sprite multiplexer**; logical sprites (multi-hardware-sprite composites); X-expansion |
| Sprite memory | **Realtime depacking with a sprite cache** - decouples total animation data from the 16 KB VIC bank |
| Collision | Graphically editable collision bounds |
| Memory | Dynamic allocation for sprites, level data, and code |
| Loading | Covert Bitops Loadersystem V2.2x - **disk, EasyFlash, and GMod2**, plus SD2IEC fastloading via ELoad |
| Audio | Miniplayer music/SFX with **SID filter compensation for 6581 vs 8580** |
| Acceleration | Uses C128 / SuperCPU fast modes when available, activated in the vertical border |
| Compression | Exomizer 3 |
| Tools | Editors for world design, sprites, and object placement |

### Memory model
```
$0200-$02FF   fastloader buffers
              engine code
$4xxx-$Cxxx   dynamic allocation
              sprite cache
              game variables
```

### Constraints
- **The video bank must stay at `$C000–$FFFF`** for fastloader compatibility.
- Dynamic loading routines don't check for file-not-found - a wrong disk side fails
  silently.
- Build system uses a Makefile and expects MinGW on Windows (adaptable).

### Verdict
If you're building a scrolling action game, **read this before writing a line of your
own**. Even if you don't use it directly, its feature list is the specification you should
be building toward, and three of its ideas (sprite cache, 25 Hz actors with 50 Hz
interpolation, SID filter compensation) are worth stealing regardless.

---

## 2. C64 Studio - Georg Rottensteiner

<https://github.com/GeorgRottensteiner/C64Studio>

A .NET IDE built specifically for C64 game development, in continuous development since
2011 and still shipping updates (8.x).

- Project-based C64 **assembly (ACME syntax) and BASIC V2**
- Built-in **charset, sprite, and media editors** - one integrated environment instead of
  five tools
- **VICE debugging integration**
- Builds to binary, `.prg`, `.t64`, `.d64`, and cartridge formats
- Also supports C128, VIC-20, and MEGA65

**Verdict:** Windows/.NET, so on macOS it needs a VM or Parallels. But it's the only tool
that puts code, graphics, and build in one place, and it's written by someone who ships
commercial C64 games with it. Worth evaluating if you'd rather have one environment than a
Makefile plus five apps.

---

## 3. oscar64 - C/C++ with real banking support

<https://github.com/drmortalwombat/oscar64>

Covered in [`02-toolchain.md`](02-toolchain.md), but worth restating here as an engine-level
decision:

- C99 + much of C++ (templates, lambdas)
- **Disk overlays and banked cartridges are first-class**: the linker places code/data from
  virtual cartridge banks into overlay files for `.d64` targets, or into real banks for
  cartridge targets, and **you call across them like normal functions**
- Native 6502 codegen for hot paths, bytecode for size-critical code
- Inline assembly for the raster-critical parts

**This directly solves the dual-target problem** (floppy *and* cartridge from one
codebase) that [`11-cartridge.md`](11-cartridge.md) §7 describes. If you're seriously
considering both media, oscar64 is a strong argument for writing the game in C.

---

## 4. Other frameworks and starting points

| Project | Notes |
|---|---|
| <https://github.com/hhprg/C64Engine> | A C64 game engine |
| <https://github.com/leissa/c64engine> | Another C64 game engine |
| <https://github.com/lvcabral/retaliate64> | A complete, modern, shipped shooter with full source - good end-to-end reference |
| <https://github.com/nealvis/c64_samples_kick> | Kick Assembler sample projects |
| **TRSE** (Turbo Rascal Syntax Error) | A Pascal-like language + IDE targeting many retro platforms, with built-in level/graphics editors. Broad but shallow per-platform; its editors were designed with other systems in mind |
| **VS64** | VS Code extension supporting acme/kick/llvm/cc65/oscar64 - the pragmatic macOS choice |

---

## 5. No-code: SEUCK and its descendants

**Shoot-'Em-Up Construction Kit** (Sensible Software, 1987) lets you build a complete
vertically-scrolling shooter with **no programming at all**: draw sprites and backgrounds,
design attack waves, place enemies.

Modern developments:
- **Sideways SEUCK** (Jon Wells, 2008) - horizontal scrolling variant
- **Modern SEUCK engine optimisations** - reworked engines that fix the original's
  performance limits
- **CharPad and SpritePad can load and save SEUCK format**, so you can use modern
  cross-platform art tools with it
- An active community (Alf Yngve, Jon Wells and others) has produced a large body of
  SEUCK games, some commercially released

**Why it's worth knowing about even if you won't use it:**
1. Its **"Attack Waves" designer** is the canonical data model for shooter enemy patterns.
   If you build a shooter, that structure (per-wave: spawn position, path, timing) is the
   one to copy.
2. It's a legitimate route to a finished game if programming isn't the point for you.
3. It's a fast way to prototype whether a shooter design is fun before building an engine.

---

## 6. Decision guide

| Situation | Recommendation |
|---|---|
| First C64 project, want to learn the machine | **Write it yourself in assembly.** Start small (single-screen or 16 KB compo). The learning is the point |
| Building a scrolling action game seriously | **Start from `c64gameframework`**, or at minimum read it thoroughly first |
| Want C productivity, targeting both floppy and cartridge | **oscar64** |
| Prefer one integrated environment, have Windows available | **C64 Studio** |
| Want a shooter without an engine | **SEUCK / Sideways SEUCK** |
| Prototyping a design | SEUCK, or a quick build in C |

### A note on "not invented here"

The C64 scene has a strong open-source culture - Cadaver, Rottensteiner and others have
released entire engines and IDEs. Using them is normal and expected, and **crediting them
is mandatory**. Building your own engine is also completely normal, and is the right choice
if learning the hardware is one of your goals.

What is *not* a good idea is building your own engine while also doing your own art, music,
level design, and tools, on a first project, with no deadline. See
[`28-project-planning.md`](28-project-planning.md).

---

## 7. What to build yourself regardless

Even on top of a framework, expect to write:

- **Your asset converter** ([`24-content-pipeline.md`](24-content-pipeline.md) §4) - nobody
  else's data layout matches yours
- **Your game logic** - entity behaviours, state machines, the actual game
- **Level/content tooling** if the volume is large
- **Build glue** - Makefile, disk image assembly, deployment to the Ultimate II+

And expect to spend real time on **the loader** if you're on floppy. It is consistently
the part of C64 projects that takes longest relative to expectations.
