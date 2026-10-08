# 24 - Content Pipeline and Level Design

The thing that distinguishes finished C64 games from abandoned ones is usually **tooling**,
not engine cleverness. *Sam's Journey* has 2,000 screens because a dedicated designer had
tools that let them produce screens quickly.

---

## 1. The pipeline shape

```
  Authoring tool          Converter              Engine data           Package
  ──────────────          ─────────              ───────────          ────────
  CharPad (.ctm)   ─┐
  SpritePad (.spd) ─┤                                                  .prg
  Aseprite (.ase)  ─┼─> tools/convert.py ──> build/*.bin ──> assembler ──> .d64
  GoatTracker(.sng)─┤        (validate)         (engine layout)         .crt
  Tiled (.tmx)     ─┘
```

**Every arrow must be automated.** If a step requires a human clicking "export," it will be
skipped, and the build will silently ship stale data.

---

## 2. Data structures for levels

### Tile maps - the fundamental win

```
charset      256 chars x 8 bytes                    =  2,048 bytes
tileset      N tiles x (4 or 16) char indices       =  N*4 or N*16
tile colour  N bytes (one colour per tile)          =  N
tile props   N bytes (solid/hazard/climb/water/...) =  N
map          W x H tile indices                     =  W*H
```

Compression ratios versus raw screens:

| Representation | 100 screens of 40×25 |
|---|---|
| Raw screen + colour RAM | 200,000 bytes - impossible |
| Raw screen only, char-locked colour | 100,000 bytes - impossible |
| 2×2 tiles (20×13 per screen) | 26,000 bytes - tight |
| 4×4 tiles (10×7 per screen) | 7,000 bytes - comfortable |
| 4×4 tiles + Exomizer | ~2,000 bytes - easy |

**4×4-char tiles (32×32 pixels) is the sweet spot** for most games. One map byte covers a
32×32-pixel area.

### Meta-tiles
For very large worlds, add another level: **meta-tiles** made of tiles. A 4×4 meta-tile of
4×4 tiles covers 128×128 pixels in one byte. Modern C64 level editors increasingly support
this (some offer meta-tiles up to 6×6). Diminishing returns past two levels of indirection.

### Screen/room tables (flip-screen games)

```asm
; per-room record
room_map_lo:   .byte ...   ; pointer to the room's tile data
room_map_hi:   .byte ...
room_exit_n:   .byte ...   ; room index when exiting north (or $ff = wall)
room_exit_s:   .byte ...
room_exit_e:   .byte ...
room_exit_w:   .byte ...
room_spawn:    .byte ...   ; index into a spawn table
room_music:    .byte ...
room_flags:    .byte ...   ; dark / underwater / no-save / boss
```
9 bytes per room. 200 rooms = 1,800 bytes of metadata. Cheap.

### Entity spawn tables

```asm
; variable-length per room, terminated by $ff
spawn_data:
    .byte ENEMY_WALKER, 5, 12       ; type, tile_x, tile_y
    .byte ENEMY_FLYER, 18, 4
    .byte ITEM_KEY, 30, 20
    .byte $ff
```

### Tile property tables

One byte per tile (or per char, if you prefer char-level granularity):

```asm
TILE_EMPTY  = %00000000
TILE_SOLID  = %00000001
TILE_HAZARD = %00000010
TILE_CLIMB  = %00000100
TILE_WATER  = %00001000
TILE_ITEM   = %00010000
TILE_EXIT   = %00100000
```

Collision then costs one table lookup and a bit test. Do **not** use hardware sprite
collision for terrain - see [`05-sprites.md`](05-sprites.md) §8.

---

## 3. Authoring tools

| Tool | Strength | Weakness |
|---|---|---|
| **CharPad C64 Pro** | Native C64 data model (charset + tiles + tile colours + map + attributes). Correct by construction. Exports binary/asm | Windows-focused (runs under Wine/Parallels on macOS); its map model may not match your engine exactly |
| **C64 Studio** | Integrated IDE + charset/sprite/media editors; assembles and debugs too | Windows/.NET |
| **Tiled** | Excellent general-purpose map editor, cross-platform, free, scriptable, great UX | Knows nothing about the C64 - you must write both an importer for the tileset and an exporter |
| **Custom editor** | Fits your engine exactly; can preview the real game | You have to build and maintain it |
| **Aseprite** | Best animation tooling | Not C64-aware; needs a validating converter |

### The custom-editor question

Several shipping developers built their own: Georg Rottensteiner built a **GUI element
editor** specifically for *Soulless*; JackAsser wrote a **custom pre-linker** for *Eye of
the Beholder*'s ROM banking; Sven Krasser wrote a **Python asset pipeline** for
*Cab Hustle*.

**Build a custom tool when:**
- Your data model diverges meaningfully from what CharPad produces
- A non-programmer needs to author content and the generic tool is confusing
- You need in-editor preview of actual game behaviour (enemy paths, physics)
- The content volume is large enough that a 20 % speedup pays for the tool

**Don't build one when:** you're on your first project and haven't shipped anything. Use
CharPad, discover what's actually painful, then build the tool that fixes *that*.

A pragmatic middle path: **CharPad for graphics, Tiled or a text format for layout, Python
to glue.** You get good tools for the hard parts and full control over the data.

---

## 4. The converter

This is the most important piece of infrastructure in the project. Write it in Python.

Responsibilities:

1. **Parse** the tool exports (CharPad `.ctm`, SpritePad `.spd`, or their raw binary
   exports).
2. **Transform** into the engine's exact memory layout.
3. **Validate** - and fail the build on error:
   - Character count within budget
   - No cell exceeding the mode's colour limit
   - Colour RAM values in range (0–7 for multicolour cells)
   - Sprite data fits the allocated region
   - Every tile referenced by the map exists
   - Every room exit points at a valid room
   - Every spawn type has a handler
4. **Generate derived tables** - tile property tables, colour lookup tables, row address
   tables, animation frame pointers.
5. **Compress** where appropriate ([`12-compression.md`](12-compression.md)).
6. **Report** - bytes per asset category, chars used, sprites used, remaining budget.

```python
# sketch
def build():
    charset = load_charpad("assets/level1.ctm")
    validate_charset(charset, max_chars=200)
    tiles    = build_tiles(charset)
    tileprops= derive_properties(charset)
    maps     = [pack_map(r) for r in charset.maps]

    emit_bin("build/charset.bin", charset.chardata)
    emit_bin("build/tiles.bin",   tiles)
    emit_bin("build/tileprops.bin", tileprops)
    emit_bin("build/maps.bin",    exomize(b"".join(maps)))

    report(charset, tiles, maps)
```

**Validation is worth more than anything else here.** A converter that catches "tile 47
uses a colour RAM value of 12 in a multicolour cell" saves an afternoon of staring at
corrupted graphics on real hardware.

---

## 5. Level design workflow

1. **Block out** the level structure on paper or in a spreadsheet - room grid, progression,
   where the key items are. Cheap to change.
2. **Grey-box in the editor** - build the geometry with placeholder tiles. Play it.
3. **Iterate on play** before art. Most level problems are layout problems.
4. **Art pass** - replace placeholders with final tiles.
5. **Populate** - enemies, items, hazards.
6. **Balance pass** - playtest, adjust difficulty.

The critical enabler is **fast iteration**: edit → build → run must be under ~30 seconds.
If it's five minutes, the designer will stop iterating and the levels will be worse. This
is the strongest argument for automating the whole pipeline and for a one-key
`make run` / `make hw` ([`13-ultimate-ii-plus.md`](13-ultimate-ii-plus.md) §2).

### Design-for-the-engine constraints the designer must know

Write these down and give them to whoever designs levels:

- No more than N enemies active per screen (sprite budget)
- No more than 8 sprites can share a horizontal band
- Tiles are 32×32 pixels; the grid is the unit of design
- Only these tile types exist: [list]
- Characters available: [budget]
- Colours available in this world: [list]
- Rooms are exactly one screen (or: the scroll region is 22 rows)

---

## 6. Text and dialogue

Text eats memory fast. 40×25 = 1000 chars per screen; a conversation is several screens.

Techniques:
- **Dictionary compression.** Replace the ~100 most common words with single byte codes.
  Typically halves English text with a ~30-byte decoder. Very effective and cheap.
- **Screen-code storage.** Store text pre-converted to screen codes, not PETSCII/ASCII  - 
  saves the conversion at runtime.
- **A text VM.** Bytecodes for "print string N", "wait for fire", "clear window", "set
  colour", "branch on flag". A ~300-byte interpreter replaces a lot of bespoke code.
- **A proportional font** in a char-based text window is possible but expensive; usually
  not worth it. Careful writing to fit 38 columns is cheaper.

---

## 7. Build reproducibility

```makefile
ASSETS := $(wildcard assets/*.ctm assets/*.spd)

build/assets.stamp: $(ASSETS) tools/convert.py
	python3 tools/convert.py
	@touch $@

build/game.prg: $(SRC) build/assets.stamp
	$(KICKASS) src/main.asm -o $@ -showmem
```

- Assets rebuild when sources or the converter change.
- Pin tool versions (Exomizer, assembler) and record them in the repo.
- Print a size report on every build and watch the trend.
- Keep editor source files in version control; keep generated binaries out.

---

## 8. Content production estimates

Rough, for planning:

| Task | Time |
|---|---|
| One 8×8 character (final quality) | 5–20 min |
| A 256-char tileset for one world | 2–5 days |
| One 24×21 sprite frame (with overlay) | 20–60 min |
| A full character animation set (8 frames, 2 dirs, 2 layers) | 2–4 days |
| One designed and populated screen/room | 20–60 min |
| One SID tune | 1–5 days |
| Converter + validation tooling | 1–2 weeks |

**200 rooms at 40 minutes each is ~130 hours** of pure level design, before playtesting.
That is why *Sam's Journey* had a dedicated person doing graphics and level design and
nothing else. Scope accordingly.
