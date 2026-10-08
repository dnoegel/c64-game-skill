# 27 - Publishing and Release

Getting the finished game to players.

---

## 1. Release formats

| Format | Reaches | Effort | Notes |
|---|---|---|---|
| **`.prg` / `.d64` on itch.io** | Emulator users, SD2IEC/Ultimate owners | Minimal | The default. Do this regardless of anything else |
| **`.crt` cartridge image** | Ultimate/EasyFlash/GMod2 owners | Low (you already built it) | Include if you have a cartridge build |
| **Physical disk (5.25")** | Collectors, purists | Publisher handles it | Real production cost |
| **Physical tape** | Collectors | Publisher handles it | Psytronik still does tape editions |
| **Physical cartridge** | Collectors, and required for large games | Publisher handles it | Higher unit cost, premium pricing |
| **Magazine cover disk** | Zzap!64 readers | Low | Excellent visibility; comes with a deadline |
| **CSDb release** | The demoscene | Minimal | The scene's system of record |

**Ship digitally first, physically second.** Digital costs nothing, reaches most players,
and generates the feedback and reviews that make a physical edition viable.

### What a release package should contain

```
mygame.d64          the game, autostarting
mygame.crt          cartridge version if applicable
mygame-ntsc.d64     if you ship separate NTSC (Sam's Journey did)
README.txt          controls, story, credits, system requirements
screenshots/        3-5 good ones, actual pixels, no filters
manual.pdf          if there's more to say
```

**System requirements must be explicit:** PAL/NTSC, required drive, whether a cartridge or
REU is needed, whether it works on a C64 Mini/Maxi.

---

## 2. Working with a publisher

The main C64 publishers: **Protovision** (DE), **Psytronik Software** (UK), **RGCD** (UK),
**Poly.Play** (DE), **Double Sided Games**.

### What they do
Manufacturing (disk/tape duplication, cartridge flashing, printed manuals, boxes, inlays),
distribution, storefront, and some marketing. Psytronik in particular offers tiered
editions - standard disk/tape up through "Premium" and "Premium+" boxed editions.

### When to approach
**With a playable vertical slice**, not a pitch and not a finished game. They can advise
on format, scope, and whether the market wants what you're making. Protovision had
manufacturing stock prepared for *Sam's Journey* while the last levels were still in
testing - that coordination needs lead time.

### Terms
Informal by mainstream industry standards. Expect a revenue share or a per-unit
arrangement, usually agreed by email. Nobody is getting rich; the publisher is largely
providing a service (production and distribution) that would otherwise be a nightmare for
an individual.

### Self-publishing physical
Possible - flash cartridges, duplicate disks, print inlays - but it's a genuinely
different job from making games, involving inventory, shipping, customs, and support.
Most developers hand this to a publisher for good reason.

---

## 3. Competitions as a release route

The **RGCD C64 16KB Cartridge Game Development Competition** is the best-established.

Rules (2019 edition, representative):
- Working **16 KB cartridge ROM** (`.CRT` at 16,464 bytes or `.BIN` at 16,384 bytes)
- Compression allowed and encouraged, but the **final file must not exceed 16 KB**
- Must be your own work, not previously released or sold commercially
- **PAL required; NTSC optional but recommended**
- Deadline typically 1 July, announced the previous December (~6 months)
- Minimum 6 entries or the competition doesn't run

Several compo entries have gone on to commercial releases. It's a low-risk way to get a
finished game, a deadline, an audience, and a relationship with a publisher.

Also: demoparty game compos (X, Datastorm, Gubbdata, Revision) and itch.io retro jams.

---

## 4. Getting coverage

In rough order of value-per-effort:

1. **A dev thread on Lemon64 and/or CSDb, started early.** Free testers, free feedback,
   and an audience that's already invested by release day. *Steel Ranger* and *Sam's
   Journey* both did this.
2. **Zzap!64.** Relaunched in print (Fusion Retro Books, 2021, bi-monthly) plus a
   long-running online edition. Reviews new homebrew. A cover disk slot or a review is the
   highest-value C64 coverage available - and a cover disk deadline is a useful forcing
   function.
3. **Indie Retro News / Vintage is The New Old / Modern C64 / GenerationAmiga.** High
   volume, cover essentially every release. Send them a link and screenshots.
4. **YouTube retro channels.** Disproportionate reach. A single video can be most of your
   audience.
5. **CSDb release entry.** The scene's system of record.
6. **Mastodon / Bluesky / X retro-computing communities.** Active and receptive to
   in-progress screenshots and GIFs.

The *Cab Hustle* experience is instructive: a solo weekend project received a Zzap!64
cover disk slot, YouTube pickup, and print reviews. **Attention in this niche is cheap
relative to any modern platform.**

### What to send
- One paragraph: what the game is, in plain language
- 3–5 screenshots of actual gameplay at correct aspect ratio
- A short GIF or 30-second video
- Download link
- Credits and system requirements

---

## 5. Piracy

Expect it. A cracked version of *Cab Hustle* appeared within hours of release and
accumulated 760+ downloads.

**Do nothing about it.** Copy protection on the C64 is a solved problem - for the crackers.
Effort spent on protection is effort not spent on the game, and cracked releases function
as distribution and a signal of interest. Some developers now release a "cracked-style"
version themselves or include a scene-style intro as a nod.

The one thing worth doing: **make the legitimate version better** - manual, box, extras,
and a version that's clearly the definitive one.

---

## 6. Licensing and credits

- **Credit everyone**: coder, artist, musician, testers, and the authors of any tools,
  loaders, or code you used. The scene runs on attribution and notices when it's missing.
- **Krill's Loader, `c64gameframework`, Exomizer, GoatTracker players** - all have their
  own terms. Read them; most are permissive but want credit.
- **Music licensing:** agree terms with your composer in writing before release, including
  whether the tunes can appear on HVSC (the High Voltage SID Collection) and in
  compilations.
- **Don't build a commercial release on someone else's IP.** Scene ports of commercial
  games survive on goodwill and generally aren't sold.
- Pick a licence for your own source if you release it. The scene norm is permissive.

---

## 7. Post-release

- **Expect bug reports about hardware you don't own.** Have a plan: a version number
  visible on the title screen, and a way for people to tell you what hardware they're on.
- **Patch releases are normal** - `v1.01`, `v1.02` are common on CSDb.
- **Note the firmware/emulator versions you tested against** in the release notes. When
  someone reports a problem, that's the first thing to check.
- **Keep the build reproducible.** You will need to rebuild in a year.

---

## 8. Release checklist

- [ ] Runs from cold boot on real hardware
- [ ] PAL/NTSC situation resolved (auto-detect, separate builds, or a clear warning)
- [ ] Tested on a real 1541 with real media, if shipping on floppy
- [ ] Tested on both 6581 and 8580 SID
- [ ] All debug code stripped
- [ ] Version number visible on the title screen
- [ ] Controls shown in-game, not just in the README
- [ ] Credits screen with everyone on it
- [ ] Loading screens/pauses covered by something
- [ ] Completable end to end by someone who isn't you
- [ ] Screenshots at correct aspect ratio, no scanline filters
- [ ] itch.io page live with clear system requirements
- [ ] CSDb entry created
- [ ] Press links sent (Indie Retro News, Zzap!64, VITNO)
- [ ] Source/tools released if you intend to
- [ ] A copy of the exact build archived somewhere you'll still have in five years
