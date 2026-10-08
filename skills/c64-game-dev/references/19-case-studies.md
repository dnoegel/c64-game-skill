# 19 - Case Studies: Modern C64 Games

What actually shipped, how it was built, and what to take from each. These are the closest
things the platform has to postmortems.

---

## 1. Sam's Journey (2017) - Knights of Bytes

**The benchmark for modern C64 game production.**

| | |
|---|---|
| Genre | Original scrolling platformer |
| Scale | 27 levels, 3 overworld maps, **2,000+ screens**, 19 music tracks |
| Team | 3: Chester Kollschen (code, project lead), Stefan Gutsch (graphics + level design), Alex Ney (music) |
| Tools | **ca65 + ld65** (the cc65 suite's assembler and linker), written in assembly; NinjaTracker for music |
| Formats | Two 5.25" double-sided disks (PAL/NTSC) **and** a PAL cartridge with an integrated save function |
| Publisher | Protovision |
| Sales | **3,000+ copies** - exceptional for the platform |

### Technical/production takeaways

- **Cross-developed on a desktop PC**, not on the C64. Kollschen cites speed and comfort
  for larger projects.
- **But tested on real hardware with real controllers**: *"You need to test with actual
  controllers to check if you got the controls right."* Emulator keyboard controls lie to
  you about game feel.
- **Assembly, not C** - and a conventional toolchain (ca65/ld65) rather than an exotic one.
  The linker mattered: managing that much content needs proper segments.
- **Both disk and cartridge editions from one codebase.** The cartridge adds saving. This
  is exactly the dual-target situation you're considering - see
  [`11-cartridge.md`](11-cartridge.md) §7.
- **Design philosophy:** no lives, no game-over screens. Free exploration, free saving.
  Explicitly modelled on *Super Mario Bros. 3*, *Kirby's Dream Land*, *Kid Chameleon*,
  and *Donkey Kong Country*, with original mechanics (six costumes with distinct
  abilities, climbing, swimming, item manipulation).
- **Content scale is the differentiator, not tricks.** 2,000 screens is a tile-and-map
  data problem solved by good tooling and a dedicated level designer - not by a clever
  raster effect.

### The lesson
The thing that made *Sam's Journey* extraordinary was **a dedicated artist/level designer
and a dedicated musician**, freeing the programmer to do nothing but engine and tools.
Role separation is the single biggest predictor of a finished, polished C64 game.

---

## 2. Eye of the Beholder (2022) - Andreas Larsson (JackAsser)

**The "impossible port" made possible by cartridge memory.**

| | |
|---|---|
| Genre | First-person dungeon crawler (port of the 1991 Amiga/DOS game) |
| Format | **1 MB EasyFlash cartridge**; C64 and C128 versions |
| Tools | **ca65 exclusively**, plus a **custom pre-linker written by the author** to handle ROM segmentation and bank layout automatically |
| History | First attempted in 2006 targeting C128 + disk; **stalled on memory limitations**. Restarted in 2018 after a suggestion to target EasyFlash |

### Takeaways

- **The medium unblocked the project.** A game that was impossible on floppy became
  possible on a 1 MB cartridge. If your design needs more content than a disk holds,
  choosing cartridge *early* is not a compromise - it's the enabling decision.
- **Custom build tooling was essential.** With ~128 banks of ROM, manual bank assignment
  is unmanageable. He wrote a pre-linker to automate it. Expect to build project-specific
  tools; budget time for them.
- **Rendering speed was the major hurdle**, not memory, once the memory was solved.
- **The C128 version exploits the target platform properly**: 1351 mouse support, numpad
  movement, 2 MHz mode, and the **VDC chip driving a second screen with a real-time
  automap**. Platform-specific enhancements are cheap goodwill.
- 16 years elapsed between first attempt and release. Long C64 projects are normal; they
  succeed when someone removes the structural blocker.

---

## 3. Prince of Persia (2011) - Mr. SID

**Reverse-engineering as a porting strategy.**

| | |
|---|---|
| Effort | ~2.5 years |
| Method | Reverse-engineered from the original **Apple II** version's code |
| Format | EasyFlash cartridge required |
| Notable | Preserved the rotoscoped animation that defines the original |

### Takeaways

- **Port from the closest architecture.** The Apple II is also 6502-based, so the game
  logic could be understood and re-implemented directly rather than reinvented. If you
  ever port, source-platform choice matters enormously.
- **The animation was the product.** Everything else served preserving those frames.
  Identifying the one thing that must be perfect, and spending the whole memory budget on
  it, is a legitimate strategy.
- Received the original creator's approval. Worth noting: **the scene's ports of
  commercial IP exist in a grey area** and generally survive on goodwill. For an original
  game this isn't your problem, but don't build a commercial plan on someone else's IP.

---

## 4. Steel Ranger / Hessian / Metal Warrior - Lasse Öörni (Covert Bitops)

**The reusable-engine approach, and the most valuable open-source resource on the platform.**

Öörni (also known as Cadaver) has shipped C64 action-adventures for over two decades,
each built on an evolving in-house engine. Crucially, **he open-sourced it**:

### `c64gameframework` - <https://github.com/cadaver/c64gameframework>

A multidirectional-scrolling game framework in assembly. Its feature list is effectively a
specification for what a serious C64 action game engine needs:

- **50 Hz screen update**, with actor updates every *second* frame and **interpolation of
  sprite movement** between them - a smart way to halve logic cost without halving
  perceived smoothness
- **22 visible scrolling rows**
- **24-sprite multiplexer**
- **Realtime sprite depacking via a sprite cache** - sprites stored compressed, decompressed
  on demand into a cache. This is how you get large animation sets into a VIC bank
- **Logical sprites** (multiple hardware sprites treated as one) with X-expansion
- **Graphically editable collision bounds**
- **Dynamic memory allocation** for sprites, level data, and code
- **Loader** based on Covert Bitops Loadersystem V2.2x - supports **disk, EasyFlash, and
  GMod2**, plus SD2IEC fastloading via the ELoad protocol
- **Miniplayer music/SFX** with **SID filter compensation for 6581 vs 8580**
- **Accelerated CPU mode on C128 and SuperCPU**, activated in the vertical border
- **Exomizer 3** compression
- Included editors for world design, sprites, and object placement

Memory model: fastloader buffers at `$0200–$02FF`, engine code, dynamic allocation region
`$4xxx–$Cxxx`, sprite cache, game variables. **Constraint: the video bank must stay at
`$C000–$FFFF`** for fastloader compatibility.

Build: Makefile, requires MinGW on Windows.

Known rough edge: the dynamic loading routines don't check for file-not-found, so wrong
disk sides fail silently.

### Takeaways

- **This is the single best code to read** if you're building an action game. It is a
  complete, shipped, production engine.
- The **sprite cache with realtime depacking** is the key idea for content-heavy games:
  it decouples "how much animation exists" from "how much fits in the 16 KB VIC bank."
- **Actor updates at 25 Hz with interpolated sprite positions at 50 Hz** is a
  general-purpose technique worth stealing regardless of engine.
- The **SID filter compensation** shows how a shipping developer actually handles the
  6581/8580 problem: compensate in the player rather than pick a side.

---

## 5. Soulless / Joe Gunn / Guns 'n' Ghosts - Georg Rottensteiner

**The tool-builder approach.**

Rottensteiner has shipped many commercial C64 games (Psytronik/RGCD) while simultaneously
building and maintaining **C64 Studio** - a .NET IDE for C64 assembly and BASIC with an
ACME-syntax internal assembler, VICE debugging integration, built-in charset/sprite/media
editors, and output to `.prg`, `.t64`, `.d64`, and cartridge formats. Still actively
developed (8.x releases).

He also built a **GUI element editor** specifically for *Soulless*.

### Takeaways

- **Build the tool when the tool is the bottleneck.** A game with 70+ rooms (*Joe Gunn*)
  or a custom UI (*Soulless*) justifies a dedicated editor.
- His *Guns 'n' Ghosts* grew out of **"Project J"** - a 100-step public C64 game
  programming tutorial series (2011–2013). Teaching in public produced a shipping
  commercial game. Worth reading as a structured learning path.
- One person *can* do code + tools across many titles - but note the games have separate
  artists and musicians (*Soulless* graphics by Trevor "Smila" Storey, music by others).

---

## 6. Cab Hustle (2022) - Sven Krasser

**The honest solo-hobbyist postmortem.** The most directly applicable case study for a
first project.

| | |
|---|---|
| Scope | Space Taxi-like with gravity physics and time pressure |
| Timeline | **18 months, "mostly weekends every couple of weeks"** (Apr 2021 – Oct 2022) |
| Language | **Mostly C (cc65)**, assembly only for screen updates and the ISR |
| Tools | cc65/ca65, **Aseprite** (sprites), **CharPad** (characters/rooms), **GoatTracker** (music), **Python** (asset pipeline), **pucrunch** (executable compression) |

### Technical notes

- **C was fast enough for gameplay logic** even unoptimised. Assembly was needed for the
  interrupt handler specifically because *"invoking any non-trivial C function will
  clobber"* cc65's pseudo-registers.
- **Python asset pipeline**: post-processed CharPad exports, transformed sprites, and
  **packed room data with zlib**. Decompression caused a slight delay on screen change  - 
  acceptable for an MVP.
- Only tested on real hardware late, with community help.

### The lessons that matter most

1. **"Very few players viewed the instructions."** Despite documentation addressing the
   most common frustrations. **Concepts must be self-explanatory or explained in-game.**
   This is the highest-value single insight in this document.
2. **Community expectation vs. developer vision.** Players wanted a straight *Space Taxi*
   clone; he built something else and took criticism for it. Know which you're making.
3. **Difficulty balancing split the audience.** The physics were "too hard" for most
   players. On a platform whose audience skews nostalgic and casual, err easier than your
   instinct.
4. **An external deadline (a Zzap!64 cover disk slot) forced the MVP out the door** - at
   the cost of cutting polish. Deadlines ship games.
5. **MVP-first worked.** Shipping something incomplete generated the feedback and audience
   that shaped it.
6. **Disproportionate coverage.** Zzap!64, YouTube, and print reviews for a weekend
   project.
7. **The PC port got fewer than 20 downloads.** C64 exclusivity was an *advantage* - a
   concentrated niche audience beats an invisible presence on a crowded platform.

---

## 7. Nixy and the Seeds of Doom (2024)

Multi-screen platformer, C64 version of a ZX Spectrum original, with substantial
improvements over the source. Music/SFX built with GoatTracker pushed to its limits.

**Standout technique:** a **proximity calculation** so enemy and event sound effects only
play when the player is close enough to care. This solves the 3-voice contention problem
by *reducing demand* rather than by building a more complex mixer. Cheap, effective,
steal it. See [`09-sound.md`](09-sound.md) §4.

---

## 8. The 3D frontier (2025–2026)

Several raycasting/3D FPS projects are in development - *T.R.S.I. – The Red Serpent
Invasion*, *Grey*, *Escape From PETSCII Castle*.

**Grey** is the notable stock-hardware achievement: **16 fps on a vanilla C64**, with the
speed coming from *"clever use of the system's colour mapping functionality - updating
colour maps is faster than redrawing the screen."* That is a pure C64 insight: the win
came from choosing a representation where the per-frame update is small, not from a faster
renderer.

**DOOM C64U** targets the new Commodore 64 Ultimate specifically - 6510 core at up to
64 MHz plus a 16 MB REU, with fixed-point math and a pipeline built around a hard frame
deadline.

### Takeaway
The general 3D technique is universal: **replace runtime math with precomputed lookup
tables**. See [`15-optimization.md`](15-optimization.md) §1. And note the emerging split
between "runs on a real 1982 C64" and "runs on accelerated modern hardware" - decide
which you're targeting.

---

## 9. Cross-cutting patterns

What the successful projects have in common:

| Pattern | Evidence |
|---|---|
| **Role separation** (coder / artist / musician) | Sam's Journey, Soulless, Nixy |
| **Reusable engine across titles** | Covert Bitops, Rottensteiner |
| **Custom build tooling for the specific problem** | JackAsser's pre-linker, Rottensteiner's GUI editor, Krasser's Python pipeline |
| **Conventional toolchains** (ca65/ACME/cc65), not exotic ones | Sam's Journey, EotB, Cab Hustle |
| **Testing on real hardware with real controllers** | Sam's Journey explicitly; Cab Hustle learned it late |
| **Public dev threads for testers and feedback** | Steel Ranger, Sam's Journey |
| **Choosing the medium to fit the design, early** | EotB (cartridge unblocked it), Sam's Journey (disk + cart) |
| **Deadlines** | Cab Hustle (cover disk), RGCD compo entrants |
| **Data volume over tricks** | Sam's Journey's 2,000 screens beat any raster effect |

And the most common failure mode, visible in what *doesn't* ship: **one person attempting
code, art, music, level design, and tools simultaneously on a first project with no
deadline.**
