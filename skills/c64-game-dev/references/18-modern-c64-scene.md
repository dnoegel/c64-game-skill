# 18 - The Modern C64 Scene

Context for the project: who is making C64 games in 2026, where they appear, and what
"success" looks like on this platform.

---

## 1. The scene is genuinely healthy

The C64 has more active game development now than at any point since the mid-90s. Lemon64
lists dozens of new releases per year; 2025 alone produced 30+ notable titles. The reasons:

- **Cross-development removed the barrier.** You no longer need a real C64 to write for it.
- **Modern C compilers work.** `oscar64` and `llvm-mos` made the platform accessible to
  people who don't want to write assembly.
- **Storage stopped being a constraint.** SD2IEC, Ultimate II+/64, and flash cartridges
  mean distribution is trivial and cartridge formats are testable without hardware.
- **A small but real commercial market exists.** Physical releases sell in the hundreds
  to low thousands.
- **New official hardware.** Commodore (the revived company) shipped the **Commodore 64
  Ultimate** in November 2025 - an FPGA machine (AMD Artix-7, real SID chips, HDMI, WiFi,
  USB) from $299, with a C64C-styled edition following in late 2026. That's brought a
  wave of new owners looking for new software.

### What this means for a new project
There is an audience, there are publishers, there is press coverage, and there are
established distribution channels. A finished, polished C64 game will find players. The
constraint is finishing it.

---

## 2. Who makes the games

Rough taxonomy of active developers:

| Type | Example | Character |
|---|---|---|
| **Small pro-quality teams** | Knights of Bytes (*Sam's Journey*) - 3 people: coder, artist, musician | Multi-year projects, commercial release, production values matching or exceeding the 80s commercial peak |
| **Prolific solo veterans** | Lasse Öörni / Covert Bitops (*Metal Warrior*, *Hessian*, *Steel Ranger*), Georg Rottensteiner (*Soulless*, *Joe Gunn*) | Own engines and tools, reused across many titles. Often open-source their frameworks |
| **Demoscene coders doing games** | JackAsser (*Eye of the Beholder*), Mr. SID (*Prince of Persia*) | Technically extreme, often ports or "impossible" projects |
| **Solo hobbyists** | e.g. Sven Krasser (*Cab Hustle*) | Weekend projects, often C + assembly, MVP-first |
| **Tool-based creators** | SEUCK / Sideways SEUCK community (Alf Yngve, Jon Wells) | Prolific, no assembly required |
| **Artists and musicians for hire** | Trevor "Smila" Storey, various SID composers | The scene has a working ecosystem of collaborators |

**The single most important structural observation:** the best modern C64 games are made by
**small teams with clear role separation** - one coder, one artist, one musician - or by
solo developers who have built reusable engines over many years. A solo developer doing
code + art + music + level design from scratch on their first project is the most common
failure mode.

---

## 3. Publishers

| Publisher | Country | Notes |
|---|---|---|
| **Protovision** | Germany | Published *Sam's Journey*. Professional physical production, long-running, strong distribution |
| **Psytronik Software** | UK | Very prolific. Tape, disk, cartridge, "Premium"/"Premium+" tiered editions. Runs the Binary Zone retro store |
| **RGCD** | UK | Cartridge specialists. Runs the 16KB cartridge competition. Often co-publishes with Psytronik |
| **Poly.Play** | Germany | Physical retro releases across platforms |
| **Double Sided Games** | - | Newer, active in physical C64 releases |
| Self-publish (itch.io) | - | Digital-first, keeps all revenue, no production risk |

### How publishing typically works
You bring a finished or near-finished game. The publisher handles manufacturing (disk
duplication, cartridge flashing, printed manuals, boxes), distribution, and some marketing.
Terms vary and are usually informal by mainstream games-industry standards. Many
developers release digitally on itch.io *and* license a physical edition - the two
audiences barely overlap.

**Approach a publisher when you have a playable vertical slice**, not before and not at
the very end. They can advise on format, scope, and market fit.

---

## 4. Competitions and jams

| Event | Format | Why it matters |
|---|---|---|
| **RGCD C64 16KB Cartridge Compo** | 16 KB `.crt`/`.bin`, ~6 months, PAL required (NTSC optional but encouraged), minimum 6 entries or no compo | The single best on-ramp. A hard size limit forces scope discipline, and it has produced many now-commercial games |
| Demoparty game compos | Varies (X, Revision, Datastorm, Gubbdata…) | Deadline pressure, visibility in the scene |
| itch.io retro jams | Varies | Low stakes, good for a first release |

**Strong recommendation:** consider building your first C64 project as a **16 KB cartridge
compo entry**. The size limit is a feature - it prevents the scope creep that kills most
first projects, forces you to learn the whole pipeline (including cartridge builds, which
an Ultimate II+ can test directly), and gives you a real deadline and an audience.

---

## 5. Press and visibility

| Outlet | What it is |
|---|---|
| **Zzap!64** | Relaunched in print by Fusion Retro Books (2021) and running bi-monthly; also a long-running online incarnation. Reviews new homebrew. A Zzap!64 review is the single highest-value coverage a C64 game can get |
| **Indie Retro News** | Very high volume, covers essentially every C64 release |
| **Vintage is The New Old** | Similar, good homebrew coverage |
| **Lemon64** | Game database, reviews, and the most active general-purpose forum |
| **CSDb** | The demoscene database. Releases, sources, forums, and the deepest technical expertise |
| **YouTube retro channels** | Disproportionate reach; a single video can drive most of a game's audience |
| **Modern C64 / GenerationAmiga / c64universe** | Blogs covering new releases |

Notable from the *Cab Hustle* retrospective: a solo weekend project got a Zzap!64 cover
disk slot, YouTube pickup, and print reviews - **"unexpected multiplier effects"** far
beyond what the same effort would achieve on a modern platform. The niche is small but
attention within it is cheap.

Also noted in that retrospective: **cracking groups are still active.** A pirated version
of a commercial release appeared within hours and accumulated 760+ downloads. Treat it as
free distribution and a sign of interest rather than a problem to solve; anti-piracy
effort on the C64 is wasted effort.

---

## 6. Market realities

Honest expectations:

- **Sam's Journey sold 3,000+ copies** - that is an exceptional outlier from a
  multi-year, three-person, professional-quality project with a strong publisher.
- Typical physical runs are **a few hundred copies**.
- Digital itch.io releases are often free or pay-what-you-want.
- Nobody is making a living from C64 games. Budget it as a craft project that might
  break even on production costs.

**Reliable public sales data essentially doesn't exist** for this market - the *Sam's
Journey* figure is one of the few published numbers. Don't build financial plans on it.

The real return is: a finished thing you're proud of, a genuinely engaged audience, direct
contact with players, and a skill set (cycle-level optimisation, working within hard
constraints) that transfers.

---

## 7. Community norms

Things worth knowing before you engage:

- **Lemon64** is friendly and game-focused; the right place for beginner-to-intermediate
  questions. People will answer thoughtfully.
- **CSDb** is the demoscene; the expertise is deeper and the tone more terse. Search
  before asking.
- **Credit everyone.** Coder, artist, musician, testers, and anyone whose code or tools you
  used. The scene runs on attribution.
- **Release source or tools where you can.** Cadaver, Georg Rottensteiner, and others have
  open-sourced entire engines and IDEs. It's a strong norm and it's why the platform is
  accessible.
- **Ask before using someone's music or graphics.** Usually granted, always expected.
- **Post work-in-progress.** Dev threads on Lemon64 and CSDb generate testers, feedback,
  and early audience. *Steel Ranger* and *Sam's Journey* both had long public dev threads.

---

## 8. Implications for a new project

1. **A 3-role team beats a solo effort.** If you can find an artist and a musician, the
   project's odds improve dramatically. The scene has people who do exactly this.
2. **Consider the 16 KB cartridge compo as a first target.** It forces the right
   discipline and produces a real, finishable, testable artifact.
3. **Post a dev thread early.** Free testers, free feedback, free audience.
4. **Plan for both digital (itch.io) and physical (publisher) release** - they're
   different audiences and physical is handled by someone else.
5. **The C64 Ultimate launch means new, less hardcore owners.** Games with an accessible
   difficulty curve and in-game explanation of mechanics will do better than they would
   have five years ago. (See [`21-game-design.md`](21-game-design.md) - *Cab Hustle*'s
   main lesson was that almost nobody reads the instructions.)
