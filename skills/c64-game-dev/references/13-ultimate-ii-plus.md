# 13 - Ultimate II+ Development Workflow

Your dev/test hardware. This document covers what it gives you as a developer, and its
limitations as a testing platform.

Official docs: <https://1541u-documentation.readthedocs.io/>

---

## 1. What it is

A cartridge that plugs into the C64 expansion port and provides:

- **Disk drive emulation** - 1541, 1571, 1581 (and multiple drives at once), from
  `.d64`/`.d71`/`.d81` images on USB/SD.
- **Cartridge emulation** - a large set of C64/C128 cartridge types including
  **EasyFlash** and **GMod2** from `.crt` files.
- **Tape emulation** - `.tap`/`.t64`.
- **REU emulation** - up to 16 MB RAM expansion unit.
- **SID emulation** - additional SIDs, plus SID type selection.
- **Machine code monitor** and a freezer.
- **Network connectivity** (Ethernet on some models), FTP server, telnet, modem emulation.
- **A ReST API** for machine control, file operations, and configuration.
- **The Ultimate Command Interface (UCI)** - a programmatic API your C64 code can call.

---

## 2. Development transfer loop

Ranked by convenience:

### A. Network (best, if your unit has Ethernet)
The Ultimate runs an **FTP server** and exposes a **ReST API**. You can script the whole
loop:

```sh
# push a build
curl -T build/game.prg ftp://ultimate.local/Usb0/dev/

# or use the ReST API to load and run it directly
curl -X POST "http://ultimate.local/v1/runners:run_prg" \
     --data-binary @build/game.prg
```

Add a `make hw` target that pushes and runs. This turns hardware testing into a
one-keystroke operation and is worth setting up on day one.

The ReST API reference in the official docs covers routes for: about/system info,
configuration, machine control (reset, reboot, pause), floppy operations (mount/unmount),
data streams (U64 only), and file manipulation.

### B. USB stick
Copy `.prg`/`.d64`/`.crt` to a USB stick, plug into the Ultimate, navigate the menu.
Reliable, works on every model, but the sneakernet round-trip gets old fast.

### C. DMA load
The Ultimate can inject a `.prg` straight into C64 memory via DMA on the expansion port  - 
effectively instant, no loading at all.

**Important caveats from the official docs:**
- DMA load requires a small piece of software on the C64, so a special **loader cartridge**
  is enabled to perform the DMA. This **disables your configured cartridge** and you lose
  speed-loader capabilities for that session.
- Alternative: go to the BASIC prompt with your cartridge active and select **"DMA"** on
  the `.prg` in the menu. This loads without invoking the cartridge - but **it does not
  work for all PRGs**.

DMA load is excellent for iterating on a single-load `.prg`. It is *not* representative of
how your game will load for a user on a real 1541.

---

## 3. The Ultimate Command Interface (UCI)

A programmatic API your C64 code can use to talk to the Ultimate directly - file access,
network, machine control - without going through the IEC bus. Much faster than the serial
bus and useful for development tooling and for Ultimate-aware features.

### Registers

Mapped at **`$DF1B`–`$DF1F`**, masking the last five registers of the REU.

| Address | Function | Access |
|---|---|---|
| `$DF1B` | SoftwareIEC bus ID | read |
| `$DF1C` | **Control** (write) / **Status** (read) | R/W |
| `$DF1D` | **Command data** (write) / **Identification** (read) | R/W |
| `$DF1E` | **Response data** | read |
| `$DF1F` | **Status data** | read |

### Control register (`$DF1C` write)

| b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0 |
|---|---|---|---|---|---|---|---|
| DMA | TRIGGER | IRQ | reserved | CLR_ERR | ABORT | DATA_ACC | **PUSH_CMD** |

### Status register (`$DF1C` read)

| b7 | b6 | b5–4 | b3 | b2 | b1 | b0 |
|---|---|---|---|---|---|---|
| DATA_AV | STAT_AV | STATE | ERROR | ABORT_P | DATA_ACC | CMD_BUSY |

`STATE` (bits 5–4): `00` Idle · `01` Command Busy · `10` Data Last · `11` Data More

### Detection

Read `$DF1D`. It returns **`$C9`** when an Ultimate is present and no IRQ is active
(`$49` - bit 7 cleared - when an IRQ is active). Use this to detect the Ultimate at
runtime and enable dev features conditionally.

```asm
detect_ultimate:
    lda $df1d
    and #$7f
    cmp #$49            ; $C9 & $7F = $49
    beq present
    ; not present
```

### Command protocol

1. Verify the protocol is **idle** (read `$DF1C`, check STATE).
2. Write the command **byte by byte** into `$DF1D`.
3. Write `1` to **PUSH_CMD** (`$DF1C` bit 0) → state becomes Command Busy.
4. Poll until the state becomes **Data Last** or **Data More**.
5. Read response bytes from `$DF1E` and status bytes from `$DF1F`.
6. Write `1` to **DATA_ACC** (`$DF1C` bit 1). If the state was Data Last, it returns to
   Idle; otherwise it goes back to Command Busy for more data.

### Command targets

The docs define several targets, each with its own command set:

| Target | Purpose |
|---|---|
| **Ultimate DOS** | File system access - open, read, write, directory listing |
| **Network** | TCP/UDP sockets, HTTP |
| **Control** | Machine control: reset, mount images, configuration |
| **Software IEC** | IEC bus commands and status codes |
| **HTTP** | HTTP protocol mapped onto UCI |

Reference PDF (v1.0): <https://rr.pokefinder.org/rrwiki/images/d/d0/Command_interface_v1.0.pdf>
Current docs: <https://1541u-documentation.readthedocs.io/en/latest/command%20interface.html>

### What to actually use it for

**Development tooling** - this is the high-value use:
- A debug build that loads assets directly from the Ultimate's filesystem, bypassing the
  fastloader entirely. Iterate on level data without rebuilding a D64.
- Dumping profiling data or a crash log to a file on the USB stick.
- A "hot reload" path: watch for a changed file and reload it.

**Shipping features** - be careful:
- Anything gated on the UCI only works for Ultimate owners. Fine as a bonus (e.g.
  instant loading on Ultimate hardware), never as a requirement.
- **Always keep the standard path working** and detect the Ultimate at runtime.

---

## 4. REU

The Ultimate emulates a RAM Expansion Unit (up to 16 MB). The REU's DMA controller can
move blocks between C64 RAM and REU RAM at roughly **1 byte per cycle** - vastly faster
than a CPU copy loop.

REU registers at `$DF00–$DF0A`:

| Addr | Register |
|---|---|
| `$DF00` | Status (read) |
| `$DF01` | Command |
| `$DF02/03` | C64 base address lo/hi |
| `$DF04/05/06` | REU base address lo/hi/bank |
| `$DF07/08` | Transfer length lo/hi |
| `$DF09` | IRQ mask |
| `$DF0A` | Address control (fixed/increment) |

Transfer types (command register bits 0–1): C64→REU, REU→C64, swap, compare.

### Use cases
- Instant "loading" - stage the whole game in REU at start, then DMA levels in.
- Huge decompressed asset caches.
- Fast screen buffers / undo state.

### Caveat
An REU is **not standard hardware**. A game requiring one excludes most real-hardware
users. Treat it as an optional accelerator (detect it, use it if present, fall back
otherwise), or a "director's cut" feature - never a requirement.

Also note the UCI occupies `$DF1B–$DF1F`, which shadows the last five REU registers.
That's harmless for normal REU use (those registers aren't used) but worth knowing.

---

## 5. Using the Ultimate for compatibility testing

This is where it really earns its keep. In the Ultimate's settings you can switch:

| Setting | Test |
|---|---|
| **SID type (6581 / 8580)** | Music sounds right on both |
| **Drive type (1541 / 1571 / 1581)** | Your loader handles each |
| **Drive ROM** | Loader works with different 1541 ROM revisions |
| **Cartridge mode (EasyFlash / GMod2 / …)** | Cartridge build without owning a flash cart |
| **REU on/off** | Graceful degradation |

Combined with the actual C64 it's plugged into (giving you real VIC-II, real DRAM, real
PSU behaviour), that covers most of the compatibility matrix.

---

## 6. What the Ultimate II+ does NOT tell you

Important - this is the main risk of developing exclusively against it:

1. **Drive emulation is not a real 1541.** The Ultimate's drive emulation is very good,
   but a custom fastloader that pushes the IEC timing hard can work on the Ultimate and
   fail on a real 1541 (or vice versa). **Test the release build on a real 1541 before
   shipping.**
2. **DMA load hides all loading problems.** If you develop with DMA load, you will not
   notice that your loader is broken until very late.
3. **It doesn't reproduce the VSP/DRAM bug.** The VSP crash depends on the DRAM in the
   specific C64 the Ultimate is plugged into - which is a real test, but only of *that
   one machine*. See [`07-scrolling.md`](07-scrolling.md) §4.
4. **It's PAL or NTSC depending on the host C64.** Testing the other standard needs either
   a second machine or VICE.
5. **Cartridge emulation ≠ real cartridge.** Timing of the bank-switch register and the
   `GAME`/`EXROM` handling is emulated. Verify on real flash hardware before a cartridge
   release.

### Suggested test matrix

| Stage | Platform |
|---|---|
| Every build | VICE `x64sc` (PAL) |
| Every build | VICE `x64sc` (NTSC) - catches raster hangs early |
| Daily | Real C64 + Ultimate II+ |
| Weekly | Real C64 + Ultimate II+ with SID/drive settings varied |
| Pre-release | Real 1541 with a real floppy |
| Pre-release | Real flash cartridge (if shipping on cart) |
| Pre-release | A second C64, ideally a different revision/board |

---

## 7. Firmware and updates

Keep the firmware reasonably current - Gideon adds cartridge types, drive fixes, and UCI
features regularly. Note which firmware version you tested against in your release notes;
if a user reports a problem, that's the first thing to check.

Older firmware archive: <https://ultimate64.com/OlderFirmware>
Source/releases: <https://github.com/markusC64/1541ultimate2>
