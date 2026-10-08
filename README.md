# C64 Game Dev skill

An agent skill for building Commodore 64 games that run on real hardware.
Works with Claude Code and Codex (same `SKILL.md` format).

It gives the agent:

- **A working starter game** in 64tass assembly: machine takeover, raster IRQ
  chain, a 24-sprite multiplexer with double-buffered display lists, entity
  system, state machine, priority SFX, HUD, PAL/NTSC detection, debug border
  profiling and build-time memory asserts. Scaffold it with one command.
- **Asset converters** (Python standard library only): PNG sheets to sprite
  data, PNG screens/levels to charset + map + colours + meta-tiles, with C64
  colour-rule checks.
- **A 29-chapter knowledge base** covering VIC-II timing, raster IRQs,
  sprites, character graphics, scrolling, memory banking, SID, loaders,
  cartridges, compression, Ultimate II+ workflow, optimisation, testing,
  game design, art, content pipelines, publishing and project planning.
- **Workflow and hard rules**: the decisions to make first, the build order,
  how to verify, and the bugs that typically cost days.

## Install

### Claude Code (plugin)

```
/plugin marketplace add dnoegel/c64-game-skill
/plugin install c64-game-dev@c64-game-skill
```

### Claude Code or Codex (local skill)

```sh
git clone https://github.com/dnoegel/c64-game-skill.git
cd c64-game-skill
./install.sh            # links into ~/.claude/skills and ~/.codex/skills
./install.sh --codex    # only Codex;  --claude for only Claude Code
./install.sh --copy     # copy instead of symlink
```

Project-local alternative: copy `skills/c64-game-dev` into a repository's
`.claude/skills/` (Claude Code) or `.agents/skills/` / `.codex/skills/` (Codex).

## Use

Ask for C64 work and the skill triggers on its own, for example:

- "Start a new C64 game: single-screen arcade, floppy release."
- "Add a second enemy type that follows the player."
- "Why does my sprite multiplexer flicker at the bottom of the screen?"
- "Plan the memory map for a 2-disk adventure with an IRQ loader."

Or create a project directly:

```sh
skills/c64-game-dev/scripts/new_project.sh ~/code/mygame mygame
cd ~/code/mygame && make && make run
```

Toolchain for the starter: `64tass`, `python3`, VICE (`x64sc`, `c1541`).

```sh
brew install tass64 vice        # macOS
sudo apt install 64tass vice    # Debian/Ubuntu
```

## Layout

```
.claude-plugin/          Claude Code plugin and marketplace manifests
skills/c64-game-dev/
  SKILL.md               entry point: workflow, rules, budgets, reference index
  agents/openai.yaml     Codex UI metadata
  references/            knowledge base chapters, loaded on demand
  scripts/               new_project.sh, png2sprites.py, png2charset.py
  assets/starter/        the starter game project
install.sh               local installer for Claude Code and Codex
```

## Status

The starter assembles cleanly (no errors or warnings) in debug and release
configurations, and the converters and scaffolder are tested. The game
itself has not yet been run in an emulator or on hardware as part of this
repository's checks; run `make shot` / `make run` in a scaffolded project to
see it.
