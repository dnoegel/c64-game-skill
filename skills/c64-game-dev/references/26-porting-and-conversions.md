# 26 - Porting and Conversions

Relevant if you ever port an existing game to the C64, port your C64 game elsewhere, or
prototype on a modern machine first.

---

## 1. Porting *to* the C64

### From the Apple II - easiest
Both are **6502-based**. Game logic can often be understood and re-implemented directly
rather than reverse-engineered from behaviour. Mr. SID's *Prince of Persia* (2011) took
this route, reverse-engineering the Apple II original's code over ~2.5 years.

Differences to handle: graphics (Apple II's odd hi-res format vs VIC-II modes), sound
(speaker clicks vs SID), memory layout, and timing.

### From the ZX Spectrum - common, with a trap
Historically the most common conversion direction, and the source of the "Speccy port"
reputation.

| | ZX Spectrum | C64 |
|---|---|---|
| CPU | Z80 (faster per-instruction, more registers) | 6510 |
| Graphics | 256×192 bitmap, attribute colour per 8×8 | Char/bitmap modes, 8 hardware sprites |
| Sprites | **None** - all software | 8 hardware |
| Scrolling | Software only | **Hardware fine scroll** |
| Sound | Beeper (48K) / AY (128K) | SID |

**The trap:** a direct port keeps the Spectrum's all-software-sprite approach and ignores
the VIC-II's hardware sprites and hardware scrolling. The result runs worse and looks worse
than a native C64 game - this is exactly why "Speccy port" is an insult on Lemon64.
*Fairlight* and *Rogue Trooper* are cited examples of plain Spectrum ports using software
sprites only.

**Do it properly:** take the *design* and *content*, re-implement the *engine* natively.
*Nixy and the Seeds of Doom* (2024) is the model - a C64 version of a Spectrum game with
substantial improvements, including a native sound approach.

The Z80 being quicker than the 6510 also means Spectrum code ported instruction-for-
instruction will be slower on the C64. Budget for restructuring, not translation.

### From the Amiga / 16-bit - hardest
*Eye of the Beholder* is the case study. The problems are **memory and rendering speed**,
not logic. It took a 1 MB EasyFlash cartridge to make it possible at all, plus custom
build tooling to manage ~128 ROM banks.

Approach: treat it as **a new game that shares a design and an art direction**. Re-do the
graphics for the C64's palette and cell constraints; re-do the music for 3 voices; rebuild
the engine around the raster budget.

### From a modern engine (Unity, Godot, etc.)
Only the *design* ports. Prototyping the game design on a modern engine first is a
legitimate and underused technique - you can iterate on fun in hours instead of days, then
implement the proven design on the C64. Just constrain the prototype honestly:
one button, 8 movable objects, 16 colours, 160×200.

---

## 2. Porting *from* the C64

Sven Krasser ported *Cab Hustle* to PC using MinGW-w64 + SDL2, recreating the music in
Renoise and SFX in Supercollider.

**The result: fewer than 20 downloads.** His conclusion - *"C64 exclusivity benefited from
niche audience concentration."*

The lesson is worth taking seriously: **a C64 game is visible on the C64 and invisible on
PC.** The retro niche is small but concentrated and attentive; Steam is enormous and
indifferent. Unless you have a specific reason, ship on the C64 and stay there.

(A practical footnote from that port: the compiled PC executable triggered antivirus
false-positives due to an unusual toolchain and high-entropy compressed audio. Budget time
for that if you do port.)

---

## 3. Multi-platform 8-bit releases

Some developers release across C64, ZX Spectrum, Amstrad CPC, and MSX simultaneously.

- If written in **C** (oscar64 / z88dk / cc65), much of the game logic is portable;
  the platform layer (graphics, input, sound) is rewritten per target.
- Art must be redone per platform - the colour models are completely different.
- Music must be redone per platform - SID, AY, and beeper are not interchangeable.

**Realistic assessment:** roughly 40 % of the work is shared and 60 % is per-platform.
Worth it if you have collaborators for the other platforms; not worth it solo.

---

## 4. C64 vs C128 vs accelerated hardware

A growing consideration in 2026.

| Target | Notes |
|---|---|
| **Stock PAL C64** | The baseline. Everything in this knowledge base assumes it |
| **C128 in C64 mode** | Mostly transparent. Can be *exploited*: **2 MHz mode**, the **VDC chip for a second screen**, and the numeric keypad. *Eye of the Beholder*'s C128 version uses the VDC for a real-time automap - cheap goodwill for owners |
| **SuperCPU** | 20 MHz accelerator. `c64gameframework` activates fast mode in the vertical border when present |
| **REU** | Instant asset staging via DMA. Should be optional, never required |
| **Ultimate 64 / C64 Ultimate (2025)** | FPGA machines; the C64 Ultimate can run the 6510 core at up to **64 MHz** with a 16 MB REU. *DOOM C64U* targets this explicitly |

### The emerging split
There is now a real divide between:
- **"Runs on a real 1982 breadbin"** - the traditional, and still the respected, target
- **"Requires accelerated modern hardware"** - enables genuinely new genres (3D, large
  worlds) but excludes most owners

**Decide which you're targeting, and say so clearly in your release notes.** A middle path
that works well: build for stock hardware, and *detect and use* accelerators for optional
improvements (faster loading with an REU, higher framerate with a SuperCPU, extra screen
on a C128). `c64gameframework` demonstrates this pattern.

---

## 5. NTSC as an internal "port"

Worth framing this way: supporting NTSC is a porting exercise within the C64 itself. 17,095
cycles instead of 19,656, 65 cycles per line instead of 63, 63 border lines instead of 112.

See [`16-testing-compat.md`](16-testing-compat.md) §1. Note that *Sam's Journey* shipped
**separate PAL and NTSC disk versions** rather than a single auto-detecting build - a
legitimate and much simpler solution when you're shipping physical media.

---

## 6. Checklist for any port

- [ ] Is the *design* right for the C64's controls (one button) and sprite limits?
- [ ] Are you porting the engine or reimplementing it? (Reimplement.)
- [ ] Has the art been redrawn for the C64 palette and cell rules, not converted?
- [ ] Has the music been rewritten for 3 SID voices, not transcribed?
- [ ] Does the data fit? If not, is a cartridge the answer?
- [ ] Do you have permission / is the IP situation clear?
- [ ] Are you using hardware sprites and hardware scrolling, or fighting the machine?
