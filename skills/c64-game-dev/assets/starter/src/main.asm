; ---------------------------------------------------------------------------
; main.asm: entry point and main loop. Assemble with 64tass (see Makefile).
; ---------------------------------------------------------------------------

        .cpu "6502"
        .include "defs.asm"
        .include "macros.asm"

        * = CODE_START
        .word (+), 2026                 ; BASIC line: 2026 SYS <start>
        .null $9e, format("%d", start)
+       .word 0

start
        sei
        ldx #$ff                        ; we never return to BASIC: own the stack
        txs
        jsr init_system
        jsr game_init
        jsr irq_init
        lda #$1b                        ; screen on, 25 rows, YSCROLL 3, RST8 0
        sta VIC_CR1
        cli

; The main loop runs once per frame, released by the bottom IRQ. If it takes
; longer than a frame the game slows down, the display stays intact.
main_loop
        lda frame_flag
        beq main_loop
        lda #0
        sta frame_flag

        #prof GREEN                     ; game logic
        jsr read_joystick
        jsr game_frame
        jsr animate_chars
        jsr entities_to_sprites
        #prof PURPLE                    ; multiplexer sort + display list
        jsr mplex_sort
        jsr mplex_build
        #prof BLACK

        .if DEBUG != 0
        lda frame_overrun               ; missed a frame: red border until
        beq +                           ; the next one
        lda #0
        sta frame_overrun
        lda #RED
        sta BORDER
+
        .endif
        jmp main_loop

        .include "irq.asm"
        .include "mplex.asm"
        .include "game.asm"
        .include "screen.asm"
        .include "sfx.asm"
        .include "music.asm"
        .include "init.asm"

sprite_frames
        .binary "sprites.bin"           ; build/sprites.bin, from assets/sprites.png
sprite_frames_end
        .cerror sprite_frames_end - sprite_frames > $1000, "sprite data exceeds the 4 KB sprite area"

code_end
        .cerror code_end > CODE_LIMIT, format("code ends at $%04x, past CODE_LIMIT", code_end)
