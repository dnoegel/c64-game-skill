; ---------------------------------------------------------------------------
; defs.asm: build flags, hardware registers, memory map, zero page
;
; Every address the game uses is derived from the constants in this file.
; Moving a block means changing one line here and in docs/memory-map.md.
; ---------------------------------------------------------------------------

; ---- build flags (override with 64tass -D NAME=value) ----------------------
        .weak
DEBUG           = 1             ; 1 = border profiling bands + overrun flash
NUM_ENEMIES     = 15
        .endweak

; ---- VIC-II ----------------------------------------------------------------
VIC             = $d000
SPR0_X          = $d000
SPR0_Y          = $d001
SPR_MSB         = $d010
VIC_CR1         = $d011         ; RST8 | ECM | BMM | DEN | RSEL | YSCROLL
VIC_RASTER      = $d012
SPR_ENABLE      = $d015
VIC_CR2         = $d016         ; MCM | CSEL | XSCROLL
SPR_EXPAND_Y    = $d017
VIC_MEM         = $d018
VIC_IRR         = $d019
VIC_IMR         = $d01a
SPR_PRIORITY    = $d01b
SPR_MC          = $d01c
SPR_EXPAND_X    = $d01d
SPR_SPR_COLL    = $d01e
SPR_BG_COLL     = $d01f
BORDER          = $d020
BGCOL0          = $d021
SPR_MC0         = $d025
SPR_MC1         = $d026
SPR0_COL        = $d027
COLOR_RAM       = $d800

; ---- SID -------------------------------------------------------------------
SID             = $d400
SID_V3_FREQ     = $d40e
SID_V3_PW       = $d410
SID_V3_CTRL     = $d412
SID_V3_AD       = $d413
SID_V3_SR       = $d414
SID_VOLUME      = $d418

; ---- CIA -------------------------------------------------------------------
CIA1_PRA        = $dc00         ; joystick port 2 (active low)
CIA1_DDRA       = $dc02
CIA1_ICR        = $dc0d
CIA2_PRA        = $dd00         ; bits 0-1: VIC bank (inverted)
CIA2_DDRA       = $dd02
CIA2_ICR        = $dd0d

; ---- CPU vectors (KERNAL banked out, $01 = $35) ----------------------------
NMI_VECTOR      = $fffa
IRQ_VECTOR      = $fffe

; ---- colours -----------------------------------------------------------------
BLACK = 0
WHITE = 1
RED = 2
CYAN = 3
PURPLE = 4
GREEN = 5
BLUE = 6
YELLOW = 7
ORANGE = 8
BROWN = 9
LIGHT_RED = 10
DARK_GREY = 11
GREY = 12
LIGHT_GREEN = 13
LIGHT_BLUE = 14
LIGHT_GREY = 15

; ---- memory map (see docs/memory-map.md) -------------------------------------
CODE_START      = $0801
CODE_LIMIT      = $4000         ; code + data must end below the VIC bank

VIC_BANK        = 1
VIC_BASE        = VIC_BANK * $4000
CHARSET         = VIC_BASE + $0000      ; 2 KB
SCREEN          = VIC_BASE + $0800      ; 1 KB
SPRITE_PTRS     = SCREEN + $03f8
SPRITE_DATA     = VIC_BASE + $1000      ; up to 64 frames
SPRITE_BASE_PTR = (SPRITE_DATA - VIC_BASE) / 64

D018_VALUE      = ((SCREEN & $3fff) >> 6) | ((CHARSET & $3fff) >> 10)
DD00_BANK_BITS  = 3 - VIC_BANK

BSS_START       = $c000         ; uninitialised RAM, zeroed by init
BSS_END         = $c800

; ---- raster schedule (PAL and NTSC safe: every line < 256) -------------------
RASTER_TOP      = 20            ; write the first 8 sprites
RASTER_BOTTOM   = 252           ; swap sprite list, music/sfx, release the main loop

; ---- screen layout -------------------------------------------------------------
HUD_ROW         = 0
FIELD_TOP_ROW   = 1
FIELD_BOTTOM_ROW = 24

; Playfield bounds in sprite coordinates (sprite X=24,Y=50 is the top left pixel)
FIELD_MIN_X     = 24 + 8
FIELD_MAX_X     = 24 + 320 - 8 - 24
FIELD_MIN_Y     = 50 + 16
FIELD_MAX_Y     = 50 + 200 - 8 - 21

; ---- zero page -----------------------------------------------------------------
        .virtual $02
zp_tmp0         .byte ?
zp_tmp1         .byte ?
zp_tmp2         .byte ?
zp_ptr0         .word ?
zp_ptr1         .word ?
frame_flag      .byte ?         ; set by the bottom IRQ, cleared by the main loop
frame_overrun   .byte ?         ; frames where the main loop missed vsync
frame_count     .byte ?
is_pal          .byte ?         ; 1 = PAL (312 lines), 0 = NTSC
joy_now         .byte ?         ; held: bit0 up,1 down,2 left,3 right,4 fire
joy_pressed     .byte ?         ; edge: set only on the frame it went down
rng_seed        .byte ?
zp_free                         ; modules allocate their own zero page from here
        .endvirtual
