# 16 - Compatibility and Testing

The C64 was made for 12 years across many revisions. "Works on my C64" is not a release
criterion.

---

## 1. PAL vs NTSC

The biggest compatibility axis by far.

| | PAL (6569) | NTSC (6567R8) | NTSC (6567R56A) |
|---|---|---|---|
| CPU clock | 985,248 Hz | 1,022,727 Hz | 1,022,727 Hz |
| Cycles/line | 63 | 65 | 64 |
| Lines/frame | 312 | 263 | 262 |
| Cycles/frame | **19,656** | **17,095** | 16,768 |
| Refresh | ~50.12 Hz | ~59.83 Hz | ~60.99 Hz |
| Non-display lines | 112 | 63 | 62 |
| Sprite X wrap | above 404 | above 412 | - |

### The four ways NTSC breaks a PAL game

1. **Hangs.** Any `cmp $d012 / bne` loop waiting for a line > 262 never completes.
   Also `$D012` compare values ≥ 263 never fire.
2. **Frame overrun.** A PAL-tuned 14,000-cycle workload does not fit 17,095 cycles minus
   overheads. The game slows to half speed or corrupts.
3. **Cycle-exact routines break.** 2 extra cycles per line means every raster-stable
   routine, side-border opener, and FLI needs per-platform padding.
4. **Speed.** Frame-locked movement runs ~20 % faster on NTSC. Music plays ~20 % faster
   and higher in pitch.

### Detection

```asm
; Detect PAL/NTSC by counting raster lines
; Result in A: 0 = PAL, 1 = NTSC (6567R8), 2 = NTSC (6567R56A), 3 = PAL-N/Drean
detect_video:
    sei
-   lda $d012           ; wait for a known raster line
    bne -
-   lda $d011
    bpl +               ; wait until RST8 is set (line >= 256)
    bmi -
+
    ; count how far the raster goes
    ...
```

The robust reference implementation is Silver Dream's detector:
<https://www.the-dreams.de/articles/pal-ntsc-detector.txt> - it distinguishes all four
variants (PAL, NTSC, old NTSC, PAL-N/Drean). **Use that rather than rolling your own.**

A cruder, adequate method: read `$D012` in a tight loop for one frame and record the
maximum value seen; > 300 = PAL.

### Strategies

| Strategy | Effort | Result |
|---|---|---|
| **PAL only** | Zero | Works for most European users, broken in North America |
| **PAL only + a warning screen** | Trivial | Honest; do this at minimum |
| **Speed compensation** | Low | Detect NTSC, skip 1 frame in 6 of the game logic so it runs at PAL speed. Music still sounds slightly off |
| **Full NTSC support** | High | Separate raster tables, adjusted timing constants, tested workloads |

**Recommendation:** design the frame budget to fit **NTSC** from the start (17,095 cycles,
63 border lines) even if you only ship PAL. It costs nothing at design time and leaves the
door open. Then implement detection + a warning screen for v1, and full support later if
the game finds an audience.

Never use a `$D012` value above 250 as an IRQ trigger unless you've specifically handled
NTSC.

---

## 2. VIC-II revisions

| Chip | System | Notes |
|---|---|---|
| 6569R1/R3/R4/R5 | PAL | Minor timing/colour differences; R1 is rare and has notable sprite quirks |
| 6567R56A | early NTSC | 64 cycles/line, 262 lines - different from all other NTSC |
| 6567R8 | NTSC | The common NTSC chip |
| 6572 | PAL-N (Drean, Argentina) | Different again |
| 8562/8565 | C64C (HMOS) | Different colour output and some "grey dot" behaviour |

Practical impact: minor for a game, significant for cycle-exact demo effects. The one to
watch is **6567R56A** - if you support NTSC, detect it separately.

---

## 3. SID revisions

| | 6581 | 8580 |
|---|---|---|
| Filter | Highly variable chip-to-chip, distorted, "warm" | Consistent, cleaner |
| Combined waveforms | Weak/quiet | Loud and clear |
| `$D418` digi | Works | Barely audible without a mod |

Test music on both. An Ultimate II+ lets you switch SID type in its settings - use it.
See [`09-sound.md`](09-sound.md).

---

## 4. The VSP / DRAM issue

If you use VSP or AGSP ([`07-scrolling.md`](07-scrolling.md) §4), **some real C64s will
crash**, depending on the DRAM chips, temperature, and PSU. Testing on one machine proves
nothing.

If VSP is in the game:
- Apply Safe VSP discipline (fragile bytes at addresses ending in 7 or F) across the whole
  memory map, not just the graphics area.
- Test on as many physical machines as you can get access to, warm and cold.
- Consider an in-game "safe mode" option that disables the VSP-based scroll.

If VSP is not in the game, this is a non-issue. That's a strong argument for the
non-VSP scroll models.

---

## 5. Drive compatibility

- **1541** - the baseline. If your fastloader works on a real 1541, it works.
- **1541-II** - mostly identical, slightly different ROM.
- **1571 / 1581** - different geometry and capabilities. A loader that only knows 1541
  GCR will fail. Krill's loader handles all of them.
- **SD2IEC / Pi1541 / Ultimate drive emulation** - increasingly common among real users.
  Support varies by loader; Krill's loader explicitly targets these.
- **Different 1541 ROM revisions** - mostly transparent, but drive-code uploaders
  occasionally assume ROM addresses.

**Test the release build on a real 1541 with a real floppy.** Ultimate II+ drive emulation
is very good but is not a 1541 - see [`13-ultimate-ii-plus.md`](13-ultimate-ii-plus.md) §6.

---

## 6. Other hardware variance

| Thing | Impact |
|---|---|
| **C64 vs C64C vs C128 (in C64 mode)** | Mostly transparent; C128 has a slightly different KERNAL and the 2 MHz mode must be off |
| **JiffyDOS / replacement KERNALs** | If you bank the KERNAL out immediately, irrelevant. If you use KERNAL routines, test with JiffyDOS |
| **Cartridges present** (Action Replay, freezers) | Can occupy `$DE00`/`$DF00` and conflict with your cartridge registers or the UCI |
| **Joystick port 1 vs 2** | Port 2 is conventional. Offer both; some users have a broken port |
| **PSU quality** | Marginal PSUs make VSP and other DRAM-edge techniques fail more often |
| **REU present** | Should never be required; detect and use optionally |
| **Composite vs S-Video vs modern upscalers** | Affects how colour-dithering art reads. Check your art on a real CRT if any |

---

## 7. A practical test matrix

| Frequency | Test |
|---|---|
| Every build | VICE `x64sc` PAL, true drive emulation ON |
| Every build | VICE `x64sc` NTSC - catches raster hangs immediately |
| Every build | Assembler memory report - fail on region overlap |
| Daily | Real C64 + Ultimate II+ |
| Weekly | Ultimate II+ with SID type toggled 6581/8580 |
| Weekly | Ultimate II+ with drive type toggled 1541/1571/1581 |
| Milestone | Real 1541 + real floppy, full boot-to-endgame run |
| Milestone | Cold boot test (fresh power-on, no prior state) |
| Milestone | A second physical C64, different revision |
| Pre-release | Real flash cartridge if shipping on cart |
| Pre-release | Long soak: leave the game running for an hour on the attract screen |

### Automating the emulator tests
VICE can run headless with a script:
```sh
x64sc -console -limitcycles 100000000 \
      -moncommands test/checkpoints.txt \
      -autostart build/game.prg
```
Use monitor checkpoints to assert that the game reaches a known state, and dump memory to
compare against a golden file. Cheap regression testing.

---

## 8. Common real-hardware-only bugs

| Symptom | Likely cause |
|---|---|
| Works in VICE, glitches on hardware | Cycle counts that ignore sprite DMA or bad lines; or you're using `x64` instead of `x64sc` |
| Random crashes after minutes | Stack growth (`cli` in an IRQ without `tsx`/`txs`); or uninitialised RAM you assumed was zero |
| Works on cold boot, breaks on warm reset | Relying on the KERNAL having initialised something; assuming RAM contents |
| Loader works on Ultimate, fails on 1541 | IEC timing assumptions; drive emulation is more forgiving |
| Sprite flickers at one specific screen position | Multiplexer IRQ colliding with a bad line; missing "already passed" guard |
| Colour split lands a line off on one machine | VIC revision timing difference |
| Corrupted graphics after a while, only some machines | VSP/DRAM metastability |
| Music sounds wrong on a friend's machine | 6581 vs 8580 |

### Uninitialised RAM
VICE fills RAM with a predictable pattern; a real C64 does not. **Explicitly initialise
every variable.** This is the single most common "works in the emulator" bug. Make your
init code zero its whole data region, and test with VICE's `-ramInitPattern` options to
vary the startup pattern.

---

## 9. Release checklist

- [ ] PAL and NTSC behaviour decided and implemented (or a clear warning screen)
- [ ] Tested on real hardware from a cold boot
- [ ] Tested with a real 1541 and real media (if shipping on floppy)
- [ ] Tested on both SID types
- [ ] All debug code stripped (`DEBUG = false`), `$D020` bands removed
- [ ] No reliance on uninitialised memory
- [ ] Reset/RESTORE behaviour defined (either handled or safely disabled)
- [ ] Disk change prompts tested (multi-disk)
- [ ] Save/load tested including a full disk and a write-protected disk
- [ ] Attract mode soak-tested for an hour
- [ ] The game is completable start to finish on real hardware, by someone who isn't you
