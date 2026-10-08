# 17 - Resources

Links were verified in August 2026; mirrors and domains change, so re-check before relying on one.

> **Warning: `codebase64.org` now redirects to an unrelated commercial site.** The Codebase64
> wiki content lives at the mirrors below. Update any old bookmarks.

---

## 1. Primary technical references

| Resource | URL | Why |
|---|---|---|
| **Codebase64** (mirror 1) | <https://codebase.c64.org> | The scene's collective knowledge base - code for every technique in these docs |
| **Codebase64** (mirror 2) | <https://codebase64.pokefinder.org> | Same content, second mirror |
| **VIC-II reference** (Christian Bauer, 1996) | <https://www.zimmers.net/cbmpics/cbm/c64/vic-ii.txt> | **The** authoritative cycle-by-cycle VIC-II document. Read it once fully |
| C64-Wiki | <https://www.c64-wiki.com> | Register reference, hardware, tools, games |
| PAL/NTSC differences | <https://codebase.c64.org/doku.php?id=base%3Antsc_pal_differences> | |
| PAL/NTSC differences (technical) | <http://unusedino.de/ec64/technical/misc/vic656x/pal-ntsc.html> | |
| Reliable PAL/NTSC detector | <https://www.the-dreams.de/articles/pal-ntsc-detector.txt> | Use this rather than writing your own |
| Illegal opcodes demystified | <https://www.masswerk.at/nowgobang/2021/6502-illegal-opcodes> | Best modern explanation |
| How illegal opcodes really work | <https://www.pagetable.com/?p=39> | The hardware-level why |
| C64 memory map | <https://www.c64-wiki.com/wiki/Memory_Map> | |

---

## 2. Technique-specific articles

### Raster / IRQ
- Double IRQ stable raster - <https://codebase.c64.org/doku.php?id=base:the_double_irq_method>
- Making stable raster routines (Pasi Ojala) - <https://www.antimon.org/dl/c64/code/stable.txt>
- Stabilizing the VIC-II raster - <https://bumbershootsoft.wordpress.com/2015/12/29/stabilizing-the-vic-ii-raster/>
- VIC-II interrupt timing - <https://bumbershootsoft.wordpress.com/2015/07/26/vic-ii-interrupt-timing-or-how-i-learned-to-stop-worrying-and-love-unstable-rasters/>
- Raster interrupts & splitscreen (C64 OS) - <https://c64os.com/post/rasterinterruptsplitscreen>
- C64 raster interrupts: timing & techniques - <https://kodiak64.com/blog/raster-interrupts-c64/>

### Bad lines / timing
- Flickering scanlines: the VIC-II and bad lines - <https://bumbershootsoft.wordpress.com/2014/12/06/flickering-scanlines-the-vic-ii-and-bad-lines/>
- VIC-II for beginners: rasters and cycles - <https://dustlayer.com/vic-ii/2013/4/25/vic-ii-for-beginners-beyond-the-screen-rasters-cycle>
- Hardware basics: know your clock - <https://dustlayer.com/c64-architecture/2013/5/7/hardware-basics-part-1-tick-tock-know-your-clock>
- Speedcode - <https://codebase.c64.org/doku.php?id=base%3Aspeedcode>

### Sprites
- Sprite multiplexing (Cadaver) - <https://codebase.c64.org/doku.php?id=base%3Asprite_multiplexing>
- Sprite stretching - <https://codebase64.pokefinder.org/doku.php?id=base:stretching_sprites>
- Stretching sprites (Pasi Ojala) - <http://www.antimon.org/dl/c64/code/streech.txt>
- Massively Interleaved Sprite Crunch (lft) - <https://www.linusakesson.net/scene/lunatico/misc.php>
- Spritework on the C64 - <https://bumbershootsoft.wordpress.com/2026/02/21/spritework-on-the-commodore-64/>
- Putting sprite multiplexing to work - <https://bumbershootsoft.wordpress.com/2026/02/28/c64-putting-sprite-multiplexing-to-work/>
- Sprites and raster timing - <https://bumbershootsoft.wordpress.com/2016/02/05/sprites-and-raster-timing-on-the-c64/>
- VIC-II for beginners: sprites - <https://dustlayer.com/vic-ii/2013/4/28/vic-ii-for-beginners-part-5-bringing-sprites-in-shape>
- How C64 sprites work - <https://retrogamecoders.com/how-c64-sprites-work/>

### Scrolling / borders / VSP
- **Safe VSP (lft)** - <https://www.linusakesson.net/scene/safevsp/> - read before using VSP
- Perpetual Fragility (lft, linecrunch/AGSP detail) - <https://www.linusakesson.net/scene/perpetual-fragility/>
- AGSP / Any Given Screen Position - <https://codebase.c64.org/doku.php?id=base%3Aagsp_any_given_screen_position>
- Variable screen placement - <https://bumbershootsoft.wordpress.com/2015/04/19/variable-screen-placement-the-vic-iis-forbidden-technique/>
- Variable screen position explained - <https://setsideb.com/variable-screen-position-on-the-commodore-64/>
- The future of VSP scrolling - <https://kodiak64.co.uk/blog/future-of-VSP-scrolling>
- VSP-Fix (hardware side) - <https://wiki.icomp.de/wiki/VSP-Fix>
- FLD, bad lines and flexible line distance - <https://nurpax.github.io/posts/2018-06-19-bintris-on-c64-part-5.html>
- Simple FLD effect - <http://www.0xc64.com/2015/11/17/simple-fld-effect/>
- FLD, scrolling the screen - <http://www.antimon.org/dl/c64/code/fld.txt>
- Opening top and bottom borders - <https://aartbik.blogspot.com/2019/09/opening-top-and-bottom-borders-on.html>
- Opening the borders - <https://www.antimon.org/dl/c64/code/opening.txt>
- Side border bitmap scroller (Raistlin) - <https://c64demo.com/side-border-bitmap-scroller/>

### Character graphics
- Character animation (C64 OS) - <https://c64os.com/post/characteranimation>
- VIC-II and FLI timing (C64 OS) - <https://c64os.com/post/flitiming2>

### Loaders
- A simple diskdrive IRQ-loader dissected (Cadaver) - <https://cadaver.github.io/rants/irqload.html>
- Fastloaders overview - <https://codebase64.pokefinder.org/doku.php?id=base%3Afastloaders>
- GCR decoding on the fly (lft) - <https://www.linusakesson.net/programming/gcr-decoding/>
- Krill's Loader - <https://www.c64-wiki.com/wiki/Krill%27s_Loader>, release on CSDb: <https://csdb.dk/release/?id=220685>
- Krill's loader quick setup guide - <http://plush.de/map/>
- Comparison of IRQ loaders - <https://www.c64-wiki.com/wiki/Comparison_of_IRQ_loaders>

---

## 3. Tools

### Assemblers & compilers
| Tool | URL |
|---|---|
| Kick Assembler | <https://theweb.dk/KickAssembler/> |
| ACME | <https://sourceforge.net/projects/acme-crossass> |
| 64tass | <https://sourceforge.net/projects/tass64> |
| cc65 / ca65 | <https://cc65.github.io> |
| **oscar64** | <https://github.com/drmortalwombat/oscar64> |
| llvm-mos | <https://llvm-mos.org> |
| c64jasm | <https://nurpax.github.io/c64jasm/> |

### IDE / editors
| Tool | URL |
|---|---|
| VS64 (VS Code extension) | <https://github.com/rolandshacks/vs64> |
| Relaunch64 | <https://github.com/sjPlot/Relaunch64> |

### Emulators & debuggers
| Tool | URL |
|---|---|
| **VICE** (use `x64sc`) | <https://vice-emu.sourceforge.io> |
| Retro Debugger / C64 Debugger | <https://github.com/slajerek/RetroDebugger> |
| C64 Debugger manual (PDF) | <https://files.commodore.software/reference-material/manuals/commodore-64-manuals/software-manuals/c64-debugger-manual-v0.64.56.pdf> |
| IceBro | <https://github.com/Sakrac/IceBro> |

### Graphics
| Tool | URL |
|---|---|
| CharPad C64 Pro + SpritePad C64 Pro | <https://subchristsoftware.itch.io/c64-pro-editions> |
| CharPad C64 (free, older) | <https://subchristsoftware.itch.io/charpad-c64-free> |
| Spritemate (browser, free) | <https://www.spritemate.com> / <https://github.com/Esshahn/spritemate> |

### Music
| Tool | URL |
|---|---|
| GoatTracker (macOS) | <http://www.sidmusic.org/goattracker/mac/> |
| SID-Wizard manual | <https://www.c64.cz/data2/download/x11/113614/SID-Wizard-1.4-UserManual.pdf> |

### Compression
| Tool | URL |
|---|---|
| Exomizer | <https://bitbucket.org/magli143/exomizer> |
| TSCrunch | <https://github.com/tonysavon/TSCrunch> |
| pucrunch | <https://github.com/mist64/pucrunch> |
| Packer archive | <https://www.zimmers.net/anonftp/pub/cbm/c64/packers/> |

---

## 4. Hardware / Ultimate II+

| Resource | URL |
|---|---|
| **Ultimate II+ / U64 documentation** | <https://1541u-documentation.readthedocs.io/> |
| Quick guide | <https://1541u-documentation.readthedocs.io/en/latest/quick_guide.html> |
| Command Interface (UCI) | <https://1541u-documentation.readthedocs.io/en/latest/command%20interface.html> |
| Core UCI architecture (registers) | <https://1541u-documentation.readthedocs.io/en/latest/uci/core_uci_architecture.html> |
| UCI reference PDF v1.0 | <https://rr.pokefinder.org/rrwiki/images/d/d0/Command_interface_v1.0.pdf> |
| Firmware source / releases | <https://github.com/markusC64/1541ultimate2> |
| Older firmware | <https://ultimate64.com/OlderFirmware> |

### Cartridge hardware
| Resource | URL |
|---|---|
| GMod2/Magic Desk/Ocean DIY cartridge | <https://www.freepascal.org/~daniel/gmod2/> |
| MagicDesk2 open hardware | <https://github.com/crystalct/MagicDesk2> |
| c64-uni-cart | <https://github.com/msolajic/c64-uni-cart> |

---

## 5. Source code to study

| Repo | What |
|---|---|
| <https://github.com/Piddewitt/C64-Game-Source-Code> | Reverse-engineered sources of classic C64 games |
| <https://github.com/mwenge/iridisalpha> | Fully documented disassembly of Jeff Minter's *Iridis Alpha* |
| <https://github.com/lvcabral/retaliate64> | Complete modern C64 game, source available |
| <https://github.com/hhprg/C64Engine> | A C64 game engine |
| <https://github.com/leissa/c64engine> | Another C64 game engine |
| <https://github.com/nealvis/c64_samples_kick> | Kick Assembler sample projects |
| <https://github.com/topics/c64?l=assembly> | GitHub's C64 assembly topic - browse regularly |

---

## 6. Communities

| Community | URL | Character |
|---|---|---|
| **CSDb** | <https://csdb.dk> | The demoscene database - releases, sources, forums. Where the deep expertise is |
| **Lemon64 forums** | <https://www.lemon64.com/forum/> | Friendly, game-focused, very active. Best place to ask beginner-to-intermediate questions |
| Codebase64 | <https://codebase.c64.org> | Wiki, editable - contribute back |
| comp.sys.cbm | <https://groups.google.com/g/comp.sys.cbm> | Historical archive, still occasionally useful |

---

## 7. Publishers (if you want a physical release)

| Publisher | URL | Notes |
|---|---|---|
| **Protovision** | <https://www.protovision.games> | Published *Sam's Journey*. Professional physical releases |
| **Psytronik** | <https://psytronik.net> | Long-running, floppy/tape/cartridge/disk editions. Binary Zone retro store: <http://binaryzone.org/retrostore/> |
| **RGCD** | <https://rgcd.co.uk> | Cartridge specialists; runs the 16 KB cartridge competition |
| **Poly.Play** | <https://www.polyplay.xyz> | Physical retro releases across platforms |
| itch.io | <https://itch.io> | Digital self-publishing; most modern C64 games appear here too |

### Competitions
- **RGCD C64 16KB Cartridge Game Development Competition**  - 
  <https://www.rgcd.co.uk/2013/05/c64-16kb-cartridge-game-development.html>;
  2019 edition: <https://demozoo.org/parties/3899/> · <https://csdb.dk/event/?id=2784>

---

## 8. Press and community coverage

| Outlet | URL |
|---|---|
| **Zzap!64** (relaunched print, Fusion Retro Books) | <https://fusionrgamer.com/zzap-64-legacy/> |
| Indie Retro News | <https://www.indieretronews.com/search/label/C64> |
| Vintage is The New Old | <https://www.vintageisthenewold.com/tag/c64-homebrew-games> |
| Modern C64 | <https://modernc64.com> |
| GenerationAmiga (covers C64) | <https://www.generationamiga.com> |
| c64universe | <https://c64universe.com> |
| Lemon64 game database by year | <https://www.lemon64.com/games/list.php?list_year=2025> |
| Games That Weren't (cancelled/unreleased) | <https://www.gamesthatwerent.com> |

---

## 9. Frameworks, engines and developer sites

| Resource | URL | What |
|---|---|---|
| **`c64gameframework`** (Cadaver / Lasse Öörni) | <https://github.com/cadaver/c64gameframework> | **The** open-source production engine: 24-sprite multiplexer, sprite cache, multidirectional scrolling, loader for disk/EasyFlash/GMod2 |
| Covert Bitops | <https://cadaver.github.io> | Öörni's site - *Metal Warrior*, *Hessian*, *Steel Ranger*, plus technical rants |
| **C64 Studio** (Georg Rottensteiner) | <https://github.com/GeorgRottensteiner/C64Studio> | .NET IDE: assembly + BASIC, built-in charset/sprite/media editors, VICE debugging |
| Georg Rottensteiner - GR Games | <https://www.georg-rottensteiner.de/en/c64.html> | Games and tools; also the "Project J" 100-step tutorial series |
| C64Engine | <https://github.com/hhprg/C64Engine> | A C64 game engine |
| c64engine | <https://github.com/leissa/c64engine> | Another C64 game engine |
| Retaliate64 | <https://github.com/lvcabral/retaliate64> | Complete modern shooter with full source |
| SEUCK | <https://www.c64-wiki.com/wiki/S.E.U.C.K.> | No-code shoot-em-up construction kit; Sideways SEUCK for horizontal |

---

## 10. Developer accounts and postmortems

| Source | URL | Value |
|---|---|---|
| **Chester Kollschen interview** (*Sam's Journey*) | <https://www.commodoreplus.org/p/interview-with-chester-kollschen-en.html> | Tools, team structure, design philosophy |
| **"Writing a Commodore 64 Game in the 2020s: a Retrospective"** (Sven Krasser, *Cab Hustle*) | <https://www.skrasser.com/blog/2023/03/03/writing-a-commodore-64-game-in-the-2020s-a-retrospective/> | **The best solo postmortem available.** Tooling, timeline, design lessons, market reality |
| Eye of the Beholder - Modern C64 writeup | <https://modernc64.com/2023/04/03/eye-of-the-beholder-by-jackasser/> | Cartridge decision, custom pre-linker |
| Prince of Persia C64 (Mr. SID) | <https://csdb.dk/release/?id=102248> · <https://www.rgcd.co.uk/2011/10/prince-of-persia-c64.html> | Reverse-engineering port strategy |
| Steel Ranger dev thread | <https://www.lemon64.com/forum/viewtopic.php?t=63275> | Multi-year public development in the open |
| Interview with Lasse Öörni | <https://www.lemon64.com/forum/viewtopic.php?t=67162> | |
| Grey (C64 raycaster) coverage | <https://hackaday.com/2025/11/21/commodores-most-popular-computer-gets-doom-style-shooter/> | 16 fps 3D on stock hardware via colour-map updates |
| DOOM C64U | <https://hondani.com/doom> | 3D targeting the accelerated C64 Ultimate |

---

## 11. Art resources

| Resource | URL |
|---|---|
| Lospec C64 pixel art tutorials | <https://lospec.com/pixel-art-tutorials/tags/c64> |
| C64 hires bitmap workflow (Agnes Heyer) | <https://lospec.com/pixel-art-tutorials/commodore-64-hires-bitmap-workflow-and-image-conversion-by-agnes-heyer> |
| Creating pixel art with C64 limitations (Cem Tezcan) | <https://cemtezcan.com/blog/MNor/creating-pixel-art-with-commodore-64-limitations> |
| "From Zero to Koala" - learning C64 graphics | <https://marincomics.com/c64-graphics.html> |
| c64gfx.com - C64 pixel art gallery/archive | <https://c64gfx.com> |

---

## 12. Hardware, new and old

| Resource | URL |
|---|---|
| **Commodore 64 Ultimate** (2025 FPGA machine) | <https://www.commodore.net> |
| Ultimate II+ / U64 documentation | <https://1541u-documentation.readthedocs.io/> |

---

## 13. Modern games worth studying

| Game | Year | Notable for |
|---|---|---|
| **Sam's Journey** | 2017 | The benchmark. 2,000 screens, 27 levels, disk + cartridge, sprite overlays. Sold 3,000+ |
| **Eye of the Beholder** | 2022 | 1 MB EasyFlash cartridge to overcome memory limits; custom pre-linker; C128 VDC automap |
| **Steel Ranger / Hessian / MW Ultra** | 2016–20 | Covert Bitops' reusable engine - and it's **open source** |
| **Soulless / Joe Gunn** | 2012–16 | Georg Rottensteiner; the tool-builder approach |
| **Nixy and the Seeds of Doom** | 2024 | SFX proximity culling; Spectrum source done natively |
| **Prince of Persia** | 2011 | Rotoscoped animation, reverse-engineered from Apple II |
| **Cab Hustle** | 2022 | Best-documented solo postmortem; C + assembly, 18 months of weekends |
| **Grey** | 2025 | 16 fps raycast 3D on stock hardware |
| **Mayhem in Monsterland** | 1993 | The classic VSP-in-a-commercial-game example |
| **Another World** | 2019 (C64) | VSP, polygon rendering |
| **Turrican I/II** | 1990/91 | The reference for 8-way scrolling + multiplexing |
| **Armalyte / Katakis** | 1988 | The technical benchmark of the commercial era |
| **The Last Ninja** | 1987 | Isometric 3D + **real-time sprite decompression** |
| **International Karate +** | 1987 | Three fighters, masterful multiplexing and animation |
| **Creatures 1/2** | 1990/92 | Colour and animation quality |
| **Fred's Back** series | | AGSP scrolling bitmap graphics |

CSDb and Lemon64 both have release pages and forum threads with developer commentary for
most of these.

---

## 14. Recommended reading order for a newcomer to the platform

**Technical:**
1. Dustlayer's *VIC-II for Beginners* series (parts 1–5) - the gentlest correct
   introduction.
2. Bauer's VIC-II reference, §3 (memory access) and §3.14 (cycle timing) - skim, then
   return to it constantly.
3. Codebase64's *sprite multiplexing* article - the single most useful game technique.
4. Cadaver's *IRQ loader dissected* - even if you use Krill's loader, understanding what
   it does matters.
5. lft's *Safe VSP* - even if you never use VSP, it teaches you how deep the hardware
   rabbit hole goes.

**Practical / project:**
6. Sven Krasser's *Cab Hustle* retrospective - the most honest account of what a solo C64
   project actually involves.
7. The `c64gameframework` README and memory map - a modern, shipped engine's specification.
8. The Chester Kollschen interview - how a professional-quality C64 game is produced.
