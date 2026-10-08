# C64 game starter

A small but complete single-load game for a stock PAL or NTSC C64, built to be
grown into a real one: lanes of enemies, a ship, bullets, score, a 60-second
timer, title and game-over states, sound effects.

What it already does correctly, so you do not have to rediscover it:

- Takes over the machine: KERNAL/BASIC banked out, CIA interrupts off, RESTORE
  disarmed, all variables zeroed (real hardware does not power up with clean RAM).
- Raster IRQ chain with a fixed-cost IRQ side and a variable-cost main loop
  released once per frame. An overrunning main loop slows the game down; it
  never corrupts the display.
- Sprite multiplexer: 24 virtual sprites, persistent insertion sort,
  double-buffered display lists, 21-line reuse rule, batched IRQs with a
  "raster already passed" guard.
- PAL/NTSC detection; all raster lines are below 256 and timers count real
  seconds on both.
- Structure-of-arrays entities, 8.8 fixed-point movement, a state machine whose
  state changes apply at frame boundaries, edge-triggered joystick input.
- SFX on voice 3 with priorities, posted from the main loop and played from
  the IRQ; voices 1-2 left for music (`src/music.asm` explains the hook).
- Charset animation, char-based HUD, BCD score.
- Debug build: border colour bands show the cost of each part of the frame
  (light blue/cyan = multiplexer IRQs, yellow = bottom IRQ, green = game logic,
  purple = sprite sort), and the border flashes red on a missed frame.
- Build-time asserts for memory regions, zero page, BSS and sprite lane spacing.

## Build

Needs `64tass`, `python3`, and VICE (`x64sc`, `c1541`).

```sh
brew install tass64 vice          # macOS
sudo apt install 64tass vice      # Debian/Ubuntu (VICE ROMs may need installing separately)

make                # build/game.prg + build/game.d64
make run            # VICE, PAL
make run-ntsc       # VICE, NTSC
make shot           # emulate a few seconds, write build/shot.png, exit
make release        # DEBUG=0: no border bands
make hw ULTIMATE=192.168.1.64     # run on real hardware via Ultimate II+/64 REST API
```

## Layout

| File | Contents |
|---|---|
| `src/defs.asm` | build flags, registers, memory map constants, zero page |
| `src/main.asm` | BASIC stub, entry, main loop, includes |
| `src/init.asm` | machine takeover, PAL/NTSC detection, VIC setup |
| `src/irq.asm` | raster IRQ chain |
| `src/mplex.asm` | sprite multiplexer |
| `src/game.asm` | states, entities, input, collisions |
| `src/screen.asm` | playfield, HUD, messages, charset animation |
| `src/sfx.asm`, `src/music.asm` | sound |
| `assets/sprites.png` | sprite sheet, 24x21 cells, converted at build time |
| `tools/` | asset converters (PNG to sprites/charset/map) |
| `docs/memory-map.md` | where everything lives; keep it current |

## Growing it

- New sprite art: edit `assets/sprites.png` (24x21 cells, transparent background).
  Frame *n* is pointer `SPRITE_BASE_PTR + n`.
- Levels and screens: draw a PNG, convert with
  `tools/png2charset.py` (charset + map + colours, optional meta-tiles), and
  `.binary` the outputs.
- More sprites than lanes allow: raise `MP_MAX_VIRTUAL`, but keep at most 8
  sprites inside any 24-line band or the multiplexer drops the extras.
- Music: see `src/music.asm`.
