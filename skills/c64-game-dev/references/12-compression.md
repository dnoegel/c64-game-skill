# 12 - Compression

---

## 1. Why it matters

- A 168 KB D64 fills up fast with charsets, sprites, maps, screens, and music.
- Loading is slow (see [`10-disk-and-loaders.md`](10-disk-and-loaders.md)), and
  compressed data loads proportionally faster - often the decompression is *free* because
  you were waiting on the drive anyway.
- Level maps and screen data compress extremely well (tile maps are highly repetitive).

Cartridge builds often skip compression entirely - see
[`11-cartridge.md`](11-cartridge.md).

---

## 2. The crunchers

| Tool | Type | Ratio | Decrunch speed | Notes |
|---|---|---|---|---|
| **Exomizer** | Bit-oriented LZ | **Best** | Moderate | The standard. Also builds self-extracting `.prg`s. Very configurable |
| **TSCrunch** | Byte-aligned LZ+RLE hybrid | Good (close to Exomizer) | **Very fast** | Designed specifically to maximise 6502 decode speed. <https://github.com/tonysavon/TSCrunch> |
| **Dali** | LZ | Sometimes beats Exomizer | Fast | Newer, worth benchmarking |
| **Pucrunch** | LZ77 + RLE | Decent | Moderate | The historical standard; superseded but still works. <https://github.com/mist64/pucrunch> |
| **Subsizer** | Bit-oriented | Very good | Slow | Optimises hard, takes a long time to pack |
| **Doynax LZ** | LZ | Good | Fast | Popular in demos, streaming-friendly |
| **ByteBoozer / B2** | LZ | Good | Fast | Small decruncher, good balance |

### Choosing

- **Data you decompress once at load time** (levels, graphics sets) → **Exomizer**. The
  extra ratio is worth the extra milliseconds.
- **Data you decompress during gameplay** (a screen transition that must not stutter) →
  **TSCrunch** or **ByteBoozer**. Byte-aligned decoders are dramatically faster because
  they avoid per-bit shifting.
- **The final release `.prg`** → **Exomizer** in self-extracting mode.

Benchmark all of them on *your* data. Ratios vary a lot with content type: charset data,
tile maps, and code compress very differently.

---

## 3. Exomizer usage

```sh
# Self-extracting executable from a .prg (most common)
exomizer sfx sys -o build/game.prg build/raw.prg

# Compress raw data for in-game decompression
exomizer raw -o build/level01.exo assets/level01.bin

# Multiple files into a single memory image, then SFX
exomizer sfx $0810 -o build/game.prg \
    build/code.prg build/charset.prg build/sprites.prg

# Maximum effort (slower packing, better ratio)
exomizer sfx sys -M256 -o build/game.prg build/raw.prg
```

**On crunch levels:** newer Exomizer versions expose more options, and there are threads
on Lemon64 about specific versions producing *worse* results than v2 for some inputs.
Practical advice: **pin the Exomizer version in your build** and re-benchmark if you
upgrade. Don't assume newer is smaller.

The decruncher: Exomizer's raw mode ships a small 6502 decruncher (~200 bytes) you
`.incbin` into your project. Call it with a pointer to the compressed data and a target
address.

---

## 4. What compresses well

| Data type | Typical ratio | Notes |
|---|---|---|
| Tile maps | 3–8× | Very repetitive. Often the biggest win |
| Character sets | 1.5–2.5× | Depends on art style; lots of blank/repeated rows helps |
| Sprite data | 1.5–2× | Blank rows and shared outlines compress |
| Screen RAM dumps | 2–5× | Repeated background chars |
| Colour RAM | 4–10× | Usually large uniform runs |
| Code | 1.3–1.8× | Modest but free |
| SID music data | 1.5–2.5× | Pattern data is repetitive |
| Already-compressed data | ~1× | Never double-compress |

**Structural compression beats generic compression.** A 100×100 tile map stored as tile
indices (10 KB) beats the same area stored as raw chars (160 KB) by 16× *before* you run
Exomizer over it. Design the data format first, then compress.

---

## 5. Streaming vs bulk decompression

### Bulk (normal)
Load the whole compressed block, decompress to its final location, go. Simple. Needs
enough RAM for the compressed data *and* the output - unless you use an **in-place**
decruncher.

### In-place decompression
Load the compressed data at the *end* of the target region and decompress backwards into
the same space. Exomizer supports this and it saves a whole buffer's worth of RAM. Widely
used. Requires care with the safety margin (the packer reports the required offset).

### Streaming
Decompress as the data arrives from disk. Very RAM-efficient and hides the decompression
time entirely inside the load. Requires a loader and cruncher designed for it (doynax LZ
and Bitfire's format both support this). More complex; consider it only if you're tight.

---

## 6. Cost of decompression

Rough figures for decompressing 8 KB on a stock C64:

| Cruncher | Approximate time |
|---|---|
| TSCrunch | ~0.15–0.3 s |
| ByteBoozer | ~0.2–0.4 s |
| Exomizer | ~0.5–1.0 s |
| Pucrunch | ~0.6–1.2 s |

For comparison, *loading* that same 8 KB compressed to 3 KB:
- stock KERNAL: ~7.5 s
- Krill 2-bit at 8 KB/s: ~0.4 s

So with a stock loader, compression is a massive net win. With a fast loader, the
decompression time becomes comparable to the load time - which is exactly when
byte-aligned crunchers like TSCrunch start to matter.

**Always decompress with the screen blanked** (`$D011` bit 4 = 0) if it takes more than a
frame - no bad lines means ~40 % more cycles, and the user sees a clean transition rather
than a stuttering display.

---

## 7. Build integration

```makefile
ASSETS := charset sprites level01 level02

build/%.exo: assets/%.bin
	exomizer raw -o $@ $<

build/game.prg: build/raw.prg
	exomizer sfx sys -o $@ $<
	@ls -l $@
```

Print the sizes on every build. Track total size over time - it's the number that will
eventually decide whether you need a second disk.

---

## 8. Checklist

- [ ] Pin the cruncher version in the build; record it in the repo.
- [ ] Benchmark 2–3 crunchers on your actual data before committing.
- [ ] Design data structures for compactness *first* (tiles, bit-packing, index tables).
- [ ] Never compress data twice.
- [ ] Use a fast byte-aligned cruncher for anything decompressed during gameplay.
- [ ] Blank the screen during long decompressions.
- [ ] Verify the decompressed output byte-for-byte in the build (a checksum step catches
      packer bugs and truncated files early).
