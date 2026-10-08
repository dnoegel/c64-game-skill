# C64 game build. Requires: 64tass, python3, VICE (x64sc, c1541).
#
#   make            build build/game.prg and build/game.d64
#   make run        run in VICE (PAL), with labels loaded into the monitor
#   make run-ntsc   run in VICE as an NTSC machine
#   make shot       run headless for a few seconds, save build/shot.png
#   make shot-ntsc  same on NTSC: catches raster lines that do not exist there
#   make release    build with DEBUG=0 (no border profiling)
#   make hw         send build/game.prg to an Ultimate II+/64 over the network
#                   (make hw ULTIMATE=192.168.1.64)

NAME     ?= game
TASS     ?= 64tass
X64      ?= x64sc
C1541    ?= c1541
PYTHON   ?= python3
TOOLS    ?= tools
ULTIMATE ?= ultimate.local
DEBUG    ?= 1
# Cycles to emulate for 'make shot' (985248 per PAL second)
SHOT_CYCLES ?= 6000000

BUILD   := build
PRG     := $(BUILD)/$(NAME).prg
D64     := $(BUILD)/$(NAME).d64
SOURCES := $(wildcard src/*.asm)
ASSETS  := $(BUILD)/sprites.bin

ASFLAGS := --ascii --case-sensitive -Wall -Wno-implied-reg \
           -I src -I $(BUILD) -D DEBUG=$(DEBUG) \
           --vice-labels --labels=$(BUILD)/$(NAME).lbl \
           --list=$(BUILD)/$(NAME).lst

VICE_FLAGS := -default +sound -autostart-warp

.PHONY: all run run-ntsc shot shot-ntsc release hw clean

all: $(PRG) $(D64)

$(BUILD):
	mkdir -p $@

$(BUILD)/sprites.bin: assets/sprites.png $(TOOLS)/png2sprites.py | $(BUILD)
	$(PYTHON) $(TOOLS)/png2sprites.py $< -o $@

$(PRG): $(SOURCES) $(ASSETS) | $(BUILD)
	$(TASS) $(ASFLAGS) src/main.asm -o $@
	@$(PYTHON) -c "import os; n=os.path.getsize('$@'); print(f'$@: {n} bytes, \$$0801-\$${0x0801+n-3:04x}, {(n+253)//254} blocks')"

$(D64): $(PRG)
	$(C1541) -format "$(NAME),01" d64 $@ -write $< $(NAME) >/dev/null

run: all
	$(X64) $(VICE_FLAGS) -pal -moncommands $(BUILD)/$(NAME).lbl $(PRG)

run-ntsc: all
	$(X64) $(VICE_FLAGS) -ntsc -moncommands $(BUILD)/$(NAME).lbl $(PRG)

# Headless-ish check for agents and CI: emulate, screenshot, exit.
shot: all
	$(X64) $(VICE_FLAGS) -pal -warp -limitcycles $(SHOT_CYCLES) \
	       -exitscreenshot $(BUILD)/shot.png $(PRG) >$(BUILD)/vice.log 2>&1 || true
	@test -f $(BUILD)/shot.png && echo "screenshot: $(BUILD)/shot.png" || (echo "no screenshot, see $(BUILD)/vice.log"; exit 1)

shot-ntsc: all
	$(X64) $(VICE_FLAGS) -ntsc -warp -limitcycles $(SHOT_CYCLES) \
	       -exitscreenshot $(BUILD)/shot-ntsc.png $(PRG) >$(BUILD)/vice-ntsc.log 2>&1 || true
	@test -f $(BUILD)/shot-ntsc.png && echo "screenshot: $(BUILD)/shot-ntsc.png" || (echo "no screenshot, see $(BUILD)/vice-ntsc.log"; exit 1)

release:
	$(MAKE) clean
	$(MAKE) DEBUG=0 all

hw: $(PRG)
	curl --fail -sS -X POST "http://$(ULTIMATE)/v1/runners:run_prg" \
	     -H "Content-Type: application/octet-stream" --data-binary @$(PRG)
	@echo "sent $(PRG) to $(ULTIMATE)"

clean:
	rm -rf $(BUILD)
