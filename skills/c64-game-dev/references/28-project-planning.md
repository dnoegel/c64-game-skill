# 28 - Project Planning

The C64 scene is full of abandoned ambitious projects. This document is about not becoming
one of them.

---

## 1. The failure mode

The most common way a C64 game dies:

> One person, on their first C64 project, simultaneously writing the engine, the tools,
> the art, the music, and the level design, with no deadline and an open-ended scope.

Every one of those factors is individually survivable. Together they are fatal, because
progress in each area is slow, none of them ever feels finished, and there's no external
pressure to converge.

Compare with what actually ships:

| Project | Team | Deadline | Scope discipline |
|---|---|---|---|
| *Sam's Journey* | 3 people, clear roles | Publisher coordination | Huge scope, but 3 dedicated people |
| *Cab Hustle* | 1 | Zzap!64 cover disk | Single mechanic, MVP-first |
| RGCD compo entries | Usually 1–2 | Hard 1 July deadline | **16 KB hard limit** |
| *Eye of the Beholder* | 1 | None - took 16 years | Succeeded only after cartridge removed the blocker |
| *Steel Ranger* / *Hessian* | 1–2 | None | **Reused an engine built over 20 years** |

The two reliable substitutes for a team are **a hard deadline** and **a reused engine**.

---

## 2. Roles

The three roles, and roughly how the work splits on a mid-size project:

| Role | Responsibilities | Share of effort |
|---|---|---|
| **Programmer** | Engine, tools, build pipeline, loader, integration | ~45 % |
| **Artist / level designer** | Charsets, tiles, sprites, maps, level layout, UI | ~40 % |
| **Musician** | Music, SFX design | ~15 % |

If you're doing all three, expect the project to take **roughly three times** as long as
your programming estimate - and expect the art and level design to be the parts that
actually stall, because they're the parts where "good enough" is hardest to judge.

### Finding collaborators
The scene has active artists and musicians who work on C64 projects. Lemon64 and CSDb both
have "looking for" threads, and posting a dev thread with a playable demo attracts people
far more effectively than asking cold. **A working prototype is the recruiting tool.**

Agree up front: credit, revenue split if it sells, and what happens if someone drops out.

---

## 3. Scoping

### The 30 % rule
**Scope so that you'd still be proud of the game at 30 % of the planned content.** That's
approximately what will exist when enthusiasm runs out. If the game is only good at 100 %
completion, it will never be good.

Practically: build a game that's complete and satisfying at 15 levels, then add more if
momentum holds - rather than a game that only makes sense with 40.

### Content estimates

| Task | Time |
|---|---|
| One final-quality 8×8 character | 5–20 min |
| A 256-char tileset for one world | 2–5 days |
| One sprite frame with overlay | 20–60 min |
| Full character animation set (8 frames × 2 dirs × 2 layers) | 2–4 days |
| One designed + populated room | 20–60 min |
| One SID tune | 1–5 days |
| Asset converter + validation | 1–2 weeks |
| Fastloader integration | **1–2 weeks** (consistently underestimated) |
| Sprite multiplexer (working, robust) | 1–2 weeks |
| Scrolling engine (multidirectional) | 3–8 weeks |

**200 rooms at 40 minutes = ~130 hours** of level design alone, before playtesting.

### Realistic timelines (part-time)

| Project | Duration |
|---|---|
| 16 KB compo game | 2–6 months |
| Small commercial game (20–40 screens) | 6–18 months |
| Mid-size (*Soulless* class, 100+ rooms) | 1–3 years |
| Large (*Sam's Journey* class) | Multiple years, 3 people |

*Cab Hustle*: 18 months of occasional weekends for a single-mechanic game. That's a fair
solo baseline.

---

## 4. Phasing

### Phase 0 - Prove the pipeline (week 1)
Get a moving square and a raster bar running **on real hardware via the Ultimate II+**,
built by a Makefile from a source file. Do not skip this. The pipeline is the risk; the
game logic is not.

Deliverable: `make run` (VICE) and `make hw` (Ultimate II+) both work.

### Phase 1 - The backbone (weeks 2–6)
- Stable raster IRQ chain
- Music player integrated and profiled
- Sprite multiplexer working with 16+ sprites
- Memory map locked and documented
- `$D020` profiling bands in place

Deliverable: sprites moving around a screen at 50 Hz with music, and you know the cycle
cost of every part.

### Phase 2 - Vertical slice (months 2–5)
**One complete level, playable start to finish, with title screen, music, gameplay, death,
and game over.** Every system exercised at least once.

This is the single most important milestone. It tells you whether the game is fun, whether
the engine is fast enough, whether the art pipeline works, and whether you want to keep
going. It's also what you show a publisher and post in your dev thread.

### Phase 3 - Content (the long middle)
Levels, enemies, music, polish. This is where tooling quality determines whether you
finish. If content production is painful, fix the tools before making more content.

### Phase 4 - Ship (final 20 %)
Compatibility testing, balance, bug fixing, packaging, press. **Budget 20 % of total
project time for this.** It always takes longer than expected.

---

## 5. Managing the middle

The content phase is where projects die. Countermeasures:

- **Keep the iteration loop under 30 seconds.** Edit → build → run. If it's five minutes,
  content quality degrades because nobody iterates.
- **Ship something publicly every few weeks** - a GIF, a screenshot, a playable build to
  testers. External visibility sustains momentum better than willpower.
- **Track size and cycles every build.** Watching the numbers move is motivating and
  catches problems early.
- **Do the boring parts early.** The loader, the save system, the pause menu. Leaving them
  to the end guarantees the project ends before they do.
- **Have a cheat/skip key from day one.** You'll test the last level a thousand times.
- **Timebox tool-building.** It's more comfortable than making content and can consume the
  project.

---

## 6. Deciding the medium - early

This is the highest-leverage early decision. It determines memory planning, asset
strategy, and engine architecture.

| | Floppy (D64/D81) | Cartridge (EasyFlash/GMod2/Magic Desk) |
|---|---|---|
| Capacity | 170 KB per D64 side; ~800 KB per D81 | 512 KB – 1 MB+ |
| Load time | Real; needs a fastloader | None |
| Engine impact | Streaming/overlays, resident core | Bank switching, RAM trampolines, no SMC in ROM |
| Production | Cheap | More expensive |
| Testing | Real 1541 required before release | Ultimate II+ emulates it directly |
| Compression | Usually essential | Often unnecessary |

**Decide now.** *Eye of the Beholder* lost 12 years to not deciding. *Sam's Journey* shipped
both and used the cartridge for the save feature.

If you're genuinely unsure, **build the asset-fetch abstraction from the start**
([`11-cartridge.md`](11-cartridge.md) §7) - or use oscar64, whose overlay/banking model
targets both from one codebase ([`25-frameworks-and-engines.md`](25-frameworks-and-engines.md) §3).

---

## 7. A concrete default plan

Assumes: a solo developer (so far), an Ultimate II+ or similar for hardware testing, floppy or cartridge undecided.

**Proposed plan:**

1. **Week 1:** Phase 0. Prove the pipeline end to end. assembler → VICE → real hardware.
2. **Weeks 2–6:** Phase 1. Build the IRQ backbone and a 16-sprite multiplexer. This teaches
   you the machine and produces reusable code regardless of what the game turns out to be.
3. **Decide the genre now**, from [`22-genre-engine-patterns.md`](22-genre-engine-patterns.md).
   Recommended: **flip-screen exploration** or **single-screen arcade** - both leave enough
   budget that the game can be good rather than merely technically interesting.
4. **Target the next RGCD 16 KB cartridge compo** if the timing works. The hard size limit
   is the best scope discipline available, cartridge builds are directly testable on an
   Ultimate II+, and it comes with a deadline and an audience.
5. **Recruit an artist** once you have a moving prototype. This is the single highest-impact
   thing you can do for the finished quality.
6. **Post a dev thread on Lemon64** from Phase 1 onward.
7. **Vertical slice by month 5.** Then decide whether to grow it.

---

## 8. Signs the project is in trouble

- The iteration loop has crept over a minute and nobody's fixed it
- You've been building tools for three weeks and haven't added a game feature
- The memory map is out of date and you're not sure what's where
- There's no playable build you'd show anyone
- You're adding systems instead of content
- You haven't run it on real hardware in a month
- The scope has grown since the last time you wrote it down

All of these are recoverable, and all of them get worse if ignored.

---

## 9. Definition of done

Write this at the start and don't move it:

> The game is done when: a player can start it from a cold boot on a real C64, understand
> the controls without reading anything, play through [N] levels, reach an ending, and
> save their progress - and someone who isn't me has done that.

Everything beyond that is optional.
