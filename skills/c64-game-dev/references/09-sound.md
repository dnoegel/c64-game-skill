# 09 - Sound and Music

---

## 1. The SID chip

Three voices. Each has an oscillator (triangle / sawtooth / pulse / noise), an ADSR
envelope, and can be ring-modulated or hard-synced with its neighbour. One shared
multi-mode filter (low/band/high pass) that any subset of voices can be routed through.

Register map is in [`01-hardware-reference.md`](01-hardware-reference.md) §6.

### 6581 vs 8580 - this matters

| | 6581 (early breadbins) | 8580 (C64C / later) |
|---|---|---|
| Filter | Wildly variable between chips, "warmer", strong distortion | Consistent, cleaner, more predictable cutoff curve |
| Combined waveforms | Weak/quiet | Much louder and cleaner |
| $D418 "digi" volume trick | Works well (audible click) | Barely works without a hardware mod |
| Same tune sounds | Bassy, gritty | Brighter, thinner |

**Consequence:** a tune tuned on an 8580 can sound wrong on a 6581 and vice versa,
especially filter-heavy tunes. An Ultimate II+ can emulate/switch SID types - **test
your music on both**. Many modern releases pick one and accept the difference; some
include a SID-type option in the menu.

A common pragmatic choice: **compose on 8580** (more consistent behaviour) and check that
it's tolerable on 6581, or avoid heavy filter dependence entirely.

---

## 2. Music tools

| Tool | Notes |
|---|---|
| **GoatTracker 2** | Cross-platform, GPL, by Lasse Öörni. Scene standard. Relocatable player, multi-speed support, SFX support. macOS builds available |
| **SID-Wizard** | By Hermit. Runs on the C64 itself and cross-platform. `SIDmaker` exports `.sid` or a standalone `.prg`. Very capable player with several player variants trading size vs features |
| **CheeseCutter** | Another well-regarded tracker |
| **SidTracker64** | iOS app, good for sketching melodies |

For a game, the important criteria are: **player size**, **player CPU cost per call**, and
**SFX integration**.

---

## 3. Integrating a tune

The standard workflow with GoatTracker:

1. Compose the tune.
2. Export a **relocated player + data** at a chosen address (e.g. `$C000`). GoatTracker's
   packer lets you choose the load address and strip unused features.
3. `.import binary` or `.incbin` the result at that address in your build.
4. At game start, `jsr $C000` with the accumulator holding the **tune number**  - 
   this is the init entry point.
5. Every frame from your raster IRQ, `jsr $C003` - the play entry point.

```asm
MUSIC_INIT = $c000
MUSIC_PLAY = $c003

    ; --- init ---
    lda #0              ; tune 0
    jsr MUSIC_INIT

    ; --- in the frame IRQ ---
    inc $d020           ; profiling: how much of the frame does this eat?
    jsr MUSIC_PLAY
    dec $d020
```

The exact entry-point convention depends on the player; check the tracker's docs. Common
layouts are `init` at +0, `play` at +3, and sometimes an SFX entry at +6.

### Multi-speed tunes
A 2× (or 4×) speed tune must be called 2 (or 4) times per frame at evenly spaced raster
positions. Implement as extra raster IRQs at e.g. lines 50 and 206 for 2×. Multi-speed
gives noticeably better arpeggios and vibrato, at 2–4× the CPU cost. Budget for it.

### Cost
Measure with the `$D020` trick. Typical figures:
- Simple 1× player: ~800–1,200 cycles/frame (4–6 % of the frame)
- Feature-heavy 1× player: up to ~2,500 cycles
- 2× multi-speed: double the above

That is a significant slice of your ~12,000 usable cycles. If the music player is
starving the game, options are: use a lighter player variant, drop to 1× speed, or move
the play call into the lower border where you have slack.

---

## 4. Sound effects - the hard part

You have 3 voices and the music wants all of them. Approaches, in increasing order of
quality:

### A. Reserve a voice
Give voice 3 permanently to SFX; compose all music for 2 voices. Simple, robust, and the
music sounds thin. Used by plenty of 80s games.

### B. Voice stealing with priority
The music uses all 3 voices; when an SFX plays, it takes over one voice for its duration
and the music resumes there afterwards.

- Requires a player that supports it (GoatTracker and SID-Wizard both do, via an SFX
  channel/table mechanism).
- Choose the *least noticeable* voice - usually the one currently playing the least
  prominent part. Simple heuristic: steal whichever voice has the shortest remaining
  note, or always steal voice 3.
- Give SFX a priority value so an explosion overrides a footstep.

### C. Proximity/relevance culling
*Nixy and the Seeds of Doom* (2024) uses a **proximity calculation** so enemy/event sounds
only play when the player is near enough for them to matter. This dramatically reduces
voice contention without any player complexity. Cheap and very effective - steal it.

### D. Dedicated SFX engine
A small table-driven engine: each SFX is a list of `(frames, freq_delta, waveform, ad, sr)`
steps. ~200 bytes of code plus a few bytes per effect. Gives you full control and lets you
implement priority and stealing exactly how you want.

```asm
; SFX descriptor
;  byte 0: duration in frames
;  byte 1: waveform/control value
;  byte 2: AD
;  byte 3: SR
;  byte 4-5: start frequency
;  byte 6-7: per-frame frequency delta (signed)
;  byte 8: priority
```

### Practical recommendation
Start with **(A) reserve voice 3** to get sound working, then upgrade to **(B) + (C)**
once the game is playable. Don't build a sophisticated SFX engine before you know what
sounds the game actually needs.

---

## 5. Sample playback ("digis")

Two techniques:

- **$D418 volume modulation** - write the sample value to the master volume nibble at a
  high rate (typically 4–8 kHz via a CIA timer). 4-bit quality, and it works well on 6581
  but is very quiet on 8580 without a hardware fix. Eats most of the CPU while playing.
- **Pulse-width modulation** - set a voice to a pulse waveform with the test bit and
  modulate the pulse width. Works better on 8580.

**For a game:** digis are viable for a title-screen speech sample or a one-off "GAME
OVER" voice, played while nothing else happens. They are not viable during gameplay. They
also consume a lot of RAM (4 kHz × 4 bits = 2 KB per second even at 4-bit packed).

---

## 6. Practical checklist

- [ ] Decide music player and its address early; it's a fixed cost in the memory map.
- [ ] Profile the play routine with `$D020` on the first day you integrate it.
- [ ] Call the player from a **stable position in the frame** (top of the frame IRQ) so
      the cost is predictable.
- [ ] Never call the player from the main loop - jitter causes audible wobble.
- [ ] Decide the SFX strategy before the composer writes the in-game tunes; "voice 3 is
      reserved" is a constraint they need to know.
- [ ] Test on both 6581 and 8580 (the Ultimate II+ makes this easy).
- [ ] Have a "music off / SFX off" option in the menu - some players want it, and it's a
      useful debug switch when profiling.
- [ ] If you use a tune from a musician, sort out licensing/credits early. The scene is
      generally generous but expects attribution.
