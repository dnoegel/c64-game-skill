# 10 - Disk, Loaders and Streaming

If the game ships on floppy and is bigger than ~50 KB, the loader becomes an engine
component, not an afterthought.

---

## 1. Disk formats

| Format | Drive | Tracks | Blocks | Bytes | Notes |
|---|---|---|---|---|---|
| **D64** | 1541 / 1571 | 35 (or 40) | 683 (664 free) | 174,848 | The universal standard |
| D71 | 1571 | 70 (double sided) | 1,366 (1,328 free) | 349,696 | Less common |
| **D81** | 1581 | 80 | 3,200 (3,160 free) | 819,200 | 3.5", much bigger, well supported by Ultimate II+ |
| D64 (40 track) | 1541 with mod | 40 | 768 | 196,608 | Non-standard, avoid for release |

### D64 geometry (you will need this for a custom loader)

Track 18 holds the BAM (block availability map) and directory. Speed zones:

| Tracks | Sectors/track |
|---|---|
| 1–17 | 21 |
| 18–24 | 19 |
| 25–30 | 18 |
| 31–35 | 17 |

Each sector is 256 bytes: 2 bytes of next-track/next-sector link + 254 bytes of data.
Files are stored as **linked lists of sectors**, which is why stock loading is slow - the
drive must read a sector, decode the link, seek, read the next.

**For a game, don't use the filesystem for bulk data.** Reserve a contiguous track range
and address it by track/sector directly. That's what every fastloader-based game does.

### Practical capacity
664 blocks × 254 bytes = ~168 KB per D64 side. A large game (Eye of the Beholder-class)
needs several disks or a cartridge. A D81 holds ~800 KB - roughly 5 D64s - and is a good
option if you're happy requiring a 1581 or an emulating device (which an Ultimate II+
provides).

---

## 2. Why you need a fastloader

| Method | Throughput |
|---|---|
| Stock KERNAL + 1541 | **~400 bytes/s** |
| Basic fastloader | 2–4 KB/s |
| Good modern loader (Krill 2-bit) | ~6–12 KB/s |
| Krill's **Transwarp** | ~16 KB/s (≈40× stock) |
| Ultimate II+ **DMA load** | Effectively instant (direct memory injection) |

Loading a 40 KB level at 400 bytes/s takes **100 seconds**. At 12 KB/s it takes 3.
That's the difference between a shippable game and an unshippable one.

### Why stock is so slow
Two reasons: the serial (IEC) protocol was crippled by a hardware bug in the original C64
and ended up bit-banged 1 bit at a time with handshaking, and the drive decodes GCR
(Group Coded Recording) sector data in a slow ROM routine.

Fastloaders fix both: they upload custom code into the drive's own 6502 (the 1541 is a
complete computer with 2 KB RAM), decode GCR on the fly, and use a faster custom transfer
protocol over the CLK and DATA lines.

---

## 3. Transfer protocols

| Protocol | Lines used | Notes |
|---|---|---|
| 1-bit | DATA (+ CLK handshake) | Simple, compatible, slow-ish |
| **2-bit** | CLK + DATA | Twice the throughput; only synchronises at the start of each byte, so timing requirements are strict |
| 2-bit ATN | + ATN | Used by some loaders for extra sync |
| Burst | - | 1571/1581 hardware burst mode; fast but drive-specific |

Krill's loader supports several and picks the best for the detected drive.

---

## 4. IRQ loaders - loading *during* gameplay

An **IRQ loader** (a.k.a. background loader) transfers data while the game keeps running.
The drive is doing the slow part (seeking, reading, GCR decoding); the C64 side only needs
to service the transfer periodically.

Architecture (from Cadaver's classic writeup):
- The loader installs a hook in the raster IRQ chain.
- Each frame, it transfers a chunk of bytes - as many as fit in the available cycles.
- The game polls a "load complete" flag rather than blocking.

This gives you **seamless level streaming**: the next room loads while the player is
still in the current one. It's how a modern C64 game avoids load screens.

Constraints:
- The IRQ handler must be interruptible-safe and bounded in time. Transfer a fixed number
  of bytes per call, not "until done."
- The drive must not be interrupted mid-sector or you lose sync and must retry.
- Serial-bus timing conflicts with anything else touching `$DD00` - remember `$DD00` also
  holds the VIC bank bits! **Always read-modify-write `$DD00`**, never `sta` a constant,
  or your loader and your VIC bank will fight.

---

## 5. Krill's Loader - the recommended choice

By Krill of Plush. The de-facto standard for modern C64 productions.

Features:
- Supports nearly every drive natively: 1541, 1571, 1581, SD2IEC, and **Ultimate II+ /
  Ultimate 64 drive emulation**.
- IRQ-loading (background) and blocking modes.
- Decodes GCR mostly on the fly with post-processing that keeps data aligned and split
  into low/high nibbles - this saves drive RAM and leaves room for extra functionality.
- Multiple transfer protocols, auto-selected.
- **Transwarp** variant: up to ~16 KB/s, ~40× stock speed, no hardware mods or cartridge.
- Configurable: you compile it with the features you need, keeping the resident footprint
  small.

Distribution: primarily via CSDb (<https://csdb.dk/release/?id=220685> - Repository
Version 192, 2022) and a git repository linked from there. There's also a "quick setup
guide for Windows users" at <http://plush.de/map/>. Compiling it requires ACME and a bit
of patience - there are Lemon64 threads specifically about getting the build working.

**Practical note:** budget real time for integrating a fastloader. It is the part of a
C64 project most likely to eat a week. Do it early, not at the end.

### Alternatives
- **Covert Bitops loader** (Cadaver) - simpler, 1 or 2-bit transfer, IRQ-safe, well
  documented, easier to understand and modify. Good if you want to *learn* rather than
  just ship. <https://cadaver.github.io/rants/irqload.html>
- **Spindle** (lft) - demo-oriented, extremely fast, but built around a demo-part
  structure rather than random file access.
- **Bitfire** - modern, fast, popular in demos, good docs.
- **Ultimate II+ / U64 DMA load** - see [`13-ultimate-ii-plus.md`](13-ultimate-ii-plus.md).
  Great for *development*; not a shipping solution for real-1541 users.

---

## 6. Structuring a multi-load game

### Single load
Everything fits in one `.prg` compressed with Exomizer. Simplest. Feasible up to roughly
50 KB of code + data after compression. **Do this if you can.**

### Two-part load
`loader.prg` (small, boots and shows a title) + `main.prg`. Trivial to implement, no
fastloader required. Good middle ground.

### Multi-part / streaming
```
BOOT     : installs the fastloader, sets up the IRQ chain, loads the front-end
FRONTEND : title screen, menu, high scores
CORE     : the resident engine (never unloaded)
LEVELn   : level data, loaded on demand
GFXn     : charset/sprite sets per world
MUSICn   : per-world tunes
```

Design rules:
- Keep the **resident core** small and stable. Everything it needs must be in RAM at all
  times: IRQ handlers, the loader, the multiplexer, the music player.
- **Load into a fixed buffer** and decompress from there, or load directly to the final
  address. Loading directly is faster; a buffer + decompress fits more on the disk.
- **Never load over the code that's running.** Obvious, and yet.
- Structure the disk so that sequentially loaded parts are physically sequential on disk  - 
  minimises seek time.

### Disk change handling
For a multi-disk release: detect the wrong disk (write a signature block), display a
"insert disk 2" prompt, and poll. Test this thoroughly - it's a common source of
release-day bugs, and testers with Ultimate II+ devices swap "disks" instantly while real
users don't.

---

## 7. Save games

Options:
- **Write back to the game disk** - requires the disk not be write-protected, and a
  fastsaver or the stock KERNAL save (slow but fine for a few hundred bytes).
- **Separate save disk** - safer, more user-friendly for original media.
- **Password/level codes** - zero disk I/O, still common and perfectly acceptable in a
  retro release. Strongly recommended for a first project.
- **Cartridge with on-board flash/EEPROM** - EasyFlash and GMod2 both support saving; see
  [`11-cartridge.md`](11-cartridge.md).

If you write to disk, remember that the KERNAL is banked out under `$01 = $35`. You'll
need to bank it back in (`$37`), `sei`, do the I/O, and restore - or use your fastloader's
save function if it has one.

---

## 8. Build integration

Generate the disk image in the build, every time:

```sh
c1541 -format "mygame,gd" d64 build/mygame.d64 \
  -attach build/mygame.d64 \
  -write build/boot.prg     "mygame" \
  -write build/core.prg     "core" \
  -write build/level01.prg  "l01" \
  -write build/level02.prg  "l02"
```

For track/sector-addressed data (fastloader style) you'll need a custom packer that writes
raw sectors into the D64 image. Write it in Python - the D64 format is simple and
well-documented, and having your own tool means the disk layout is part of the build,
reproducible and diffable.

Test the resulting image in VICE **with true drive emulation enabled** (`x64sc
-drive8type 1541 +virtualdev`) - virtual device mode bypasses the real IEC protocol and
will happily "work" with a loader that's actually broken.
