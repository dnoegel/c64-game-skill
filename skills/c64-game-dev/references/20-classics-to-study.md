# 20 - Classic Games Worth Studying

The C64's commercial peak produced techniques that are still the state of the art. This is
a study list: what each game did, and what to take from it.

---

## 1. The technical canon

The games consistently named as the most technically advanced C64 titles:

| Game | Year | Author(s) | What it demonstrates |
|---|---|---|---|
| **Armalyte** | 1988 | Dan Phillips (Cyberdyne) | The most *polished* C64 shooter. Huge sprite counts, smooth horizontal scroll, coherent art. Often cited as the technical benchmark of its era |
| **Katakis** | 1988 | Manfred Trenz | R-Type-like; density of action + background detail |
| **Turrican** / **Turrican II** | 1990/91 | Manfred Trenz | Multidirectional scrolling with huge levels, enormous sprite counts, graphics "many did not believe possible on a C64". Turrican II's 15-minute intro sequence is a technical showcase in itself |
| **Creatures** / **Creatures 2** | 1990/92 | John & Steve Rowlands | Colour, sprite density, and animation quality far beyond the norm |
| **Mayhem in Monsterland** | 1993 | John & Steve Rowlands | The peak. Used **VSP** and other demo techniques in a commercial game to achieve scroll speed and colour density "unseen on C64 before" |
| **The Last Ninja** | 1987 | System 3 | Isometric 3D **plus real-time sprite decompression** - a memory technique, not just a graphics one |
| **International Karate +** | 1987 | Archer Maclean | Three simultaneous fighters with fluid animation; masterful sprite multiplexing and animation compression |

### What to actually learn from them

- **Turrican / Katakis / Armalyte** → sprite multiplexing at scale, and the discipline of
  designing levels so sprites distribute vertically ([`05-sprites.md`](05-sprites.md)).
- **Mayhem in Monsterland** → that demo techniques *can* ship in a commercial game, and
  what it costs (it is the canonical example of VSP in a game - read
  [`07-scrolling.md`](07-scrolling.md) §4 on the risks).
- **The Last Ninja** → **real-time decompression as a memory strategy**. Store sprites
  compressed, decompress on demand. This is the same idea as Cadaver's sprite cache 30
  years later. It's the most reusable idea on this list.
- **International Karate +** → animation quality beats animation quantity. Fewer, better
  frames.
- **Creatures** → colour discipline. Study how they get vibrancy out of a fixed 16-colour
  palette with per-cell restrictions.

---

## 2. Design canon (as opposed to technical)

Worth studying for *game* reasons rather than engine reasons:

| Game | Why |
|---|---|
| **Boulder Dash** | Perfect example of a simple cellular simulation producing deep gameplay. Tiny code, enormous design space |
| **Wizball** | Original mechanics, colour-collection premise built around the platform's palette |
| **Paradroid** | The influence/transfer minigame; UI design under extreme constraint |
| **Impossible Mission** | Procedural room contents, memorable audio, pacing |
| **Uridium** | Scroll speed as the entire aesthetic |
| **Bubble Bobble** | Single-screen design that made **softsprites** viable (simple backgrounds, no scrolling) - see [`06-charmode-graphics.md`](06-charmode-graphics.md) §6 |
| **Elite** | Procedural generation as a memory technique |
| **Sensible Soccer / Cannon Fodder** | Readable tiny sprites, excellent game feel |

---

## 3. The technique lineage

Roughly how the tricks entered games, which tells you what's proven:

```
Demoscene discovers          Commercial games adopt         Modern games use
------------------------     ------------------------       ----------------
Raster IRQs (early 80s)  ->  split screens, status bars  ->  universal
Sprite multiplexing      ->  Turrican, Armalyte, IK+     ->  universal (16-24 sprites)
Opening top/bottom       ->  many arcade games           ->  common, near-free
  border
Opening side borders     ->  rare (too expensive)        ->  rare, banded use only
FLD                      ->  status panel reveals        ->  occasional
VSP / AGSP               ->  Mayhem, Another World,      ->  rare (crash risk)
                             Fred's Back
FLI                      ->  title screens only          ->  title screens only
Sprite stretching        ->  bars, pillars, panels       ->  occasional
Sprite crunch (MISC)     ->  never                       ->  demos only
Realtime decompression   ->  Last Ninja                  ->  standard (sprite caches)
Charset animation        ->  everywhere                  ->  everywhere
```

**Reading:** the techniques that made it into commercial games are the ones worth your
time. The ones that stayed in demos (FLI in-game, sprite crunch, full-screen side borders)
stayed there for good reasons - they consume the CPU budget a game needs.

---

## 4. Where to find the source

Reverse-engineered and documented sources are available for a surprising number of games:

| Resource | Contents |
|---|---|
| <https://github.com/Piddewitt/C64-Game-Source-Code> | Reverse-engineered assembler sources for a set of classic games, sometimes with enhanced versions |
| <https://github.com/mwenge/iridisalpha> | **Fully documented disassembly** of Jeff Minter's *Iridis Alpha*. Excellent for seeing how a real 80s game was structured |
| <https://csdb.dk> | Sources attached to many releases; also the place to find demo sources for specific effects |
| <https://www.gamesthatwerent.com> | Unreleased/cancelled games, often with development history and sometimes code |
| <https://github.com/cadaver/c64gameframework> | **A modern, complete, shipped engine** - arguably more useful than any 80s disassembly |

### How to study a disassembly productively

1. Find the **main loop** and the **IRQ handler** first. Everything else hangs off those.
2. Identify the **memory map** - where's the charset, screen, sprites, map data?
3. Find the **entity table** and how it's iterated.
4. Look at what's in **zero page**. That tells you what the author considered hot.
5. Count the **frame budget** - how much does the IRQ do vs the main loop?

Don't try to read it linearly. It's ~30 KB of undocumented assembly.

---

## 5. A caution about 80s game design

A recurring theme in modern C64 forum discussion: many 80s C64 games were **badly designed
by modern standards** - brutal difficulty, unfair enemy placement, poor feedback, no
onboarding, arbitrary instant deaths. This was partly deliberate (coin-op economics,
extending short games) and partly immaturity of the craft.

**Copy the technical achievements, not the design conventions.** The most successful
modern C64 games - *Sam's Journey* explicitly - deliberately reject 80s design defaults:
no lives, no game-over, free saving, exploration-friendly. See
[`21-game-design.md`](21-game-design.md).

---

## 6. A practical study plan

If you have limited time, in priority order:

1. **Read `c64gameframework`'s documentation and memory map.** Modern, shipped, complete.
2. **Play *Sam's Journey*, *Soulless*, and *Steel Ranger*** with a developer's eye. Note
   sprite counts, scroll behaviour, screen transitions, how they handle load pauses.
3. **Play *Armalyte* and *Turrican II*** and count sprites on screen. Then think about how
   they're distributed vertically.
4. **Read the *Iridis Alpha* disassembly's main loop and IRQ.**
5. **Watch a modern C64 game's dev thread on Lemon64 from the start.** The problem-solving
   in public is more instructive than any finished artifact.
