; ---------------------------------------------------------------------------
; game.asm: the example game ("lane shooter"), states and entities
;
; Entities are structure-of-arrays, indexed by X/Y. Entity i is shown with
; virtual sprite i, so no mapping table is needed.
;
;   0                 player
;   1..NUM_BULLETS    player bullets
;   FIRST_ENEMY..     enemies, NUM_ENEMIES of them, in horizontal lanes
;
; Enemies stay in lanes LANE_GAP lines apart and bob by at most +-BOB, so no
; more than ENEMIES_PER_LANE + bullets + player sprites ever share a line.
; Designing the level around the 8-sprites-per-line limit is cheaper than
; fighting it in the multiplexer.
; ---------------------------------------------------------------------------

NUM_BULLETS     = 3
FIRST_BULLET    = 1
FIRST_ENEMY     = FIRST_BULLET + NUM_BULLETS
NUM_ENTITIES    = FIRST_ENEMY + NUM_ENEMIES
ENEMIES_PER_LANE = 3
NUM_LANES       = (NUM_ENEMIES + ENEMIES_PER_LANE - 1) / ENEMIES_PER_LANE
LANE_TOP        = FIELD_MIN_Y + 6
LANE_GAP        = 30
BOB             = 3

PLAYER_Y        = FIELD_MAX_Y
PLAYER_SPEED    = 2
BULLET_SPEED    = 5
HIT_DX          = 6             ; in half pixels (12 px)
HIT_DY          = 14
GAME_SECONDS    = $60           ; BCD

FRAME_PLAYER    = 0
FRAME_BULLET    = 1
FRAME_ENEMY     = 2             ; two animation frames

STATE_TITLE     = 0
STATE_PLAY      = 1
STATE_OVER      = 2
STATE_NONE      = $ff

TILE_FIRST      = $40           ; screen codes $40+ are the game's own tiles
TILE_STAR       = $40
TILE_GROUND     = $41

        .cerror NUM_ENTITIES > MP_MAX_VIRTUAL, "more entities than virtual sprites"
        .cerror NUM_LANES > 8, "lane tables hold 8 lanes"
        .cerror LANE_GAP - 2 * BOB < MP_MIN_GAP, "lanes too close: multiplexer would drop sprites"
        .cerror LANE_TOP + (NUM_LANES - 1) * LANE_GAP + BOB > PLAYER_Y - 21, "lanes overlap the player"

        .virtual zp_free_mplex
game_state      .byte ?
next_state      .byte ?
state_timer     .byte ?
score           .fill 3         ; BCD, low byte first
seconds         .byte ?         ; BCD
second_frames   .byte ?
zp_end
        .endvirtual
        .cerror zp_end > $100, "zero page overflow"

        .virtual bss_free_mplex
ent_active      .fill NUM_ENTITIES
ent_x_frac      .fill NUM_ENTITIES
ent_x_lo        .fill NUM_ENTITIES
ent_x_hi        .fill NUM_ENTITIES  ; X bit 8 ($ff while moving off the left edge)
ent_y           .fill NUM_ENTITIES
ent_dx_lo       .fill NUM_ENTITIES  ; signed 8.8 pixels per frame
ent_dx_hi       .fill NUM_ENTITIES
ent_lane_y      .fill NUM_ENTITIES
ent_hx          .fill NUM_ENTITIES  ; X / 2, for 8-bit collision tests
ent_ptr         .fill NUM_ENTITIES
ent_col         .fill NUM_ENTITIES
bss_end_used
        .endvirtual
        .cerror bss_end_used > BSS_END, "BSS overflow"

; ---------------------------------------------------------------------------
game_init
        lda #$a5
        sta rng_seed
        lda #0
        sta CIA1_DDRA           ; port A all inputs: clean joystick 2 reads
        jsr draw_playfield
        jsr sfx_init
        jsr music_init
        lda #STATE_NONE
        sta game_state
        lda #STATE_TITLE
        sta next_state
        rts

; ---------------------------------------------------------------------------
; Main loop body, once per frame. State changes requested during a frame
; take effect at the start of the next one, never halfway through an update.
game_frame
        lda next_state
        cmp #STATE_NONE
        beq +
        sta game_state
        ldx #STATE_NONE
        stx next_state
        tax
        jsr call_enter
+       ldx game_state
        lda state_update_hi,x   ; tail call: the update returns to our caller
        pha
        lda state_update_lo,x
        pha
        rts                     ; "RTS jump" to the pushed address + 1

call_enter
        lda state_enter_hi,x
        pha
        lda state_enter_lo,x
        pha
        rts

state_enter_lo  .byte <(title_enter-1), <(play_enter-1), <(over_enter-1)
state_enter_hi  .byte >(title_enter-1), >(play_enter-1), >(over_enter-1)
state_update_lo .byte <(title_update-1), <(play_update-1), <(over_update-1)
state_update_hi .byte >(title_update-1), >(play_update-1), >(over_update-1)

; ---- title: enemies fly as an attract mode ------------------------------------
title_enter
        jsr spawn_enemies
        lda #0
        sta ent_active          ; no player
        jsr hide_bullets
        jsr draw_hud
        ldx #msg_title - messages
        jmp show_message

title_update
        jsr update_enemies
        lda joy_pressed
        and #$10
        beq +
        lda #STATE_PLAY
        sta next_state
+       rts

; ---- play ----------------------------------------------------------------------
play_enter
        lda #0
        sta score
        sta score+1
        sta score+2
        lda #GAME_SECONDS
        sta seconds
        jsr reset_second
        jsr spawn_player
        ldx #msg_clear - messages
        jsr show_message
        jmp draw_hud

play_update
        jsr update_player
        jsr update_bullets
        jsr update_enemies
        jsr check_hits
        jsr tick_clock
        jmp draw_hud

; ---- game over ---------------------------------------------------------------
over_enter
        lda #0
        sta ent_active
        jsr hide_bullets
        lda #50                 ; ignore fire for a moment
        sta state_timer
        ldx #SFX_OVER
        jsr sfx_play
        ldx #msg_over - messages
        jmp show_message

over_update
        jsr update_enemies
        lda state_timer
        beq +
        dec state_timer
        rts
+       lda joy_pressed
        and #$10
        beq +
        lda #STATE_PLAY
        sta next_state
+       rts

; ---------------------------------------------------------------------------
; Joystick 2 with edge detection. joy_pressed has a bit set only on the
; frame the direction/button went down: test it for "fire once" actions.
read_joystick
        lda CIA1_PRA
        eor #$ff                ; active low -> active high
        and #$1f
        tax
        eor joy_now             ; changed bits...
        and #$1f
        sta joy_pressed
        txa
        and joy_pressed         ; ...that are down now
        sta joy_pressed
        stx joy_now
        rts

; 8-bit Galois LFSR, period 255. Deterministic: same seed, same game.
rand8
        lda rng_seed
        asl a
        bcc +
        eor #$1d
+       sta rng_seed
        rts

; ---------------------------------------------------------------------------
spawn_player
        lda #1
        sta ent_active
        lda #<(24 + 160 - 12)
        sta ent_x_lo
        lda #>(24 + 160 - 12)
        sta ent_x_hi
        lda #PLAYER_Y
        sta ent_y
        lda #SPRITE_BASE_PTR + FRAME_PLAYER
        sta ent_ptr
        lda #WHITE
        sta ent_col
        rts

hide_bullets
        lda #0
        ldx #NUM_BULLETS - 1
-       sta ent_active + FIRST_BULLET,x
        dex
        bpl -
        rts

update_player
        lda joy_now
        and #$04                ; left
        beq _right
        lda ent_x_lo
        sec
        sbc #PLAYER_SPEED
        sta ent_x_lo
        lda ent_x_hi
        sbc #0
        sta ent_x_hi
        bmi _clamp_left
        bne _fire
        lda ent_x_lo
        cmp #FIELD_MIN_X
        bcs _fire
_clamp_left
        lda #FIELD_MIN_X
        sta ent_x_lo
        lda #0
        sta ent_x_hi
        beq _fire
_right  lda joy_now
        and #$08
        beq _fire
        lda ent_x_lo
        clc
        adc #PLAYER_SPEED
        sta ent_x_lo
        lda ent_x_hi
        adc #0
        sta ent_x_hi
        beq _fire
        lda ent_x_lo
        cmp #<(FIELD_MAX_X + 1)
        bcc _fire
        lda #<FIELD_MAX_X
        sta ent_x_lo
_fire   lda ent_x_hi            ; keep X/2 current for collisions
        lsr a
        lda ent_x_lo
        ror a
        sta ent_hx
        lda joy_pressed
        and #$10
        beq _done
        ldx #NUM_BULLETS - 1    ; find a free bullet
-       lda ent_active + FIRST_BULLET,x
        beq _spawn
        dex
        bpl -
_done   rts
_spawn  lda #1
        sta ent_active + FIRST_BULLET,x
        lda ent_x_lo
        sta ent_x_lo + FIRST_BULLET,x
        lda ent_x_hi
        sta ent_x_hi + FIRST_BULLET,x
        lda ent_hx
        sta ent_hx + FIRST_BULLET,x
        lda #PLAYER_Y - 12
        sta ent_y + FIRST_BULLET,x
        lda #SPRITE_BASE_PTR + FRAME_BULLET
        sta ent_ptr + FIRST_BULLET,x
        lda #YELLOW
        sta ent_col + FIRST_BULLET,x
        ldx #SFX_SHOOT
        jmp sfx_play

update_bullets
        ldx #FIRST_BULLET + NUM_BULLETS - 1
-       lda ent_active,x
        beq +
        lda ent_y,x
        sec
        sbc #BULLET_SPEED
        sta ent_y,x
        cmp #FIELD_MIN_Y
        bcs +
        lda #0
        sta ent_active,x
+       dex
        cpx #FIRST_BULLET
        bcs -
        rts

; ---------------------------------------------------------------------------
spawn_enemies
        ldx #FIRST_ENEMY
        ldy #0                  ; lane
_lane   lda #ENEMIES_PER_LANE
        sta zp_tmp0
        tya
        sta zp_tmp2
_one    cpx #NUM_ENTITIES
        beq _done
        lda #1
        sta ent_active,x
        ldy zp_tmp2
        lda lane_y,y
        sta ent_lane_y,x
        sta ent_y,x
        lda lane_colour,y
        sta ent_col,x
        lda lane_speed_lo,y
        sta ent_dx_lo,x
        lda lane_speed_hi,y
        sta ent_dx_hi,x
        jsr rand8              ; X spread across the lane
        and #$7f
        clc
        adc #FIELD_MIN_X + 40
        sta ent_x_lo,x
        lda #0
        sta ent_x_hi,x
        sta ent_x_frac,x
        lda #SPRITE_BASE_PTR + FRAME_ENEMY
        sta ent_ptr,x
        inx
        dec zp_tmp0
        bne _one
        ldy zp_tmp2
        iny
        bne _lane
_done   rts

lane_y          .for i := 0, i < NUM_LANES, i += 1
                .byte LANE_TOP + i * LANE_GAP
                .endfor
lane_colour     .byte RED, ORANGE, LIGHT_GREEN, CYAN, PURPLE, LIGHT_RED, GREEN, LIGHT_BLUE
lane_speed      = [$00c0, -$0120, $0160, -$00e0, $0100, -$01a0, $0080, -$0140]
lane_speed_lo   .byte <lane_speed
lane_speed_hi   .byte >lane_speed

; Sine bob, +-BOB pixels over 64 frames
bob_table       .for i := 0, i < 64, i += 1
                .char round(BOB * sin(i * 2.0 * pi / 64))
                .endfor

update_enemies
        lda frame_count         ; shared animation frame
        lsr a
        lsr a
        lsr a
        and #1
        clc
        adc #SPRITE_BASE_PTR + FRAME_ENEMY
        sta zp_tmp1

        ldx #FIRST_ENEMY
_loop   lda zp_tmp1
        sta ent_ptr,x

        ldy #0                  ; X += DX, 8.8 fixed point, sign-extended
        clc
        lda ent_x_frac,x
        adc ent_dx_lo,x
        sta ent_x_frac,x
        lda ent_dx_hi,x
        bpl +
        dey
+       adc ent_x_lo,x
        sta ent_x_lo,x
        tya
        adc ent_x_hi,x
        sta ent_x_hi,x

        bmi _left               ; off the left edge (negative)
        bne _right_check        ; X >= 256
        lda ent_x_lo,x
        cmp #FIELD_MIN_X
        bcs _y
_left   lda #FIELD_MIN_X
        sta ent_x_lo,x
        lda #0
        sta ent_x_hi,x
        lda ent_dx_hi,x
        bpl _y                  ; already moving right
        bmi _bounce
_right_check
        lda ent_x_lo,x
        cmp #<(FIELD_MAX_X + 1)
        bcc _y
        lda #<FIELD_MAX_X
        sta ent_x_lo,x
        lda ent_dx_hi,x
        bmi _y                  ; already moving left
_bounce lda #0                  ; DX = -DX
        sec
        sbc ent_dx_lo,x
        sta ent_dx_lo,x
        lda #0
        sbc ent_dx_hi,x
        sta ent_dx_hi,x

_y      txa                     ; Y = lane + bob(frame + 8 * index)
        asl a
        asl a
        asl a
        clc
        adc frame_count
        and #63
        tay
        lda bob_table,y
        clc
        adc ent_lane_y,x
        sta ent_y,x

        lda ent_x_hi,x          ; X / 2 for collisions
        lsr a
        lda ent_x_lo,x
        ror a
        sta ent_hx,x

        inx
        cpx #NUM_ENTITIES
        beq +
        jmp _loop
+       rts

; ---------------------------------------------------------------------------
; Bullets against enemies: a box test on X/2 and Y. The hardware collision
; registers say which sprites touched, not where, and they also report
; collisions between unrelated multiplexed sprites, so games test boxes.
check_hits
        ldx #FIRST_BULLET
_bullet lda ent_active,x
        beq _next_bullet
        lda ent_hx,x
        sta zp_tmp0
        lda ent_y,x
        sta zp_tmp1
        ldy #FIRST_ENEMY
_enemy  lda ent_hx,y
        sec
        sbc zp_tmp0
        bcs +
        eor #$ff                ; carry is clear: -A = ~A + 1
        adc #1
+       cmp #HIT_DX
        bcs _next_enemy
        lda ent_y,y
        sec
        sbc zp_tmp1
        bcs +
        eor #$ff
        adc #1
+       cmp #HIT_DY
        bcs _next_enemy
        lda #0                  ; hit
        sta ent_active,x
        jsr enemy_hit
        jmp _next_bullet
_next_enemy
        iny
        cpy #NUM_ENTITIES
        bne _enemy
_next_bullet
        inx
        cpx #FIRST_BULLET + NUM_BULLETS
        bne _bullet
        rts

; Y = enemy. Preserves X.
enemy_hit
        sed                     ; BCD score; the IRQs clear D on entry
        clc
        lda score
        adc #$10
        sta score
        lda score+1
        adc #0
        sta score+1
        lda score+2
        adc #0
        sta score+2
        cld

        lda ent_dx_hi,y         ; respawn at the edge it moves away from
        bmi +
        lda #FIELD_MIN_X
        sta ent_x_lo,y
        lda #0
        sta ent_x_hi,y
        beq ++
+       lda #<FIELD_MAX_X
        sta ent_x_lo,y
        lda #>FIELD_MAX_X
        sta ent_x_hi,y
+       txa
        pha
        ldx #SFX_HIT
        jsr sfx_play
        pla
        tax
        rts

; ---------------------------------------------------------------------------
; One game second is 50 frames on PAL and 60 on NTSC.
reset_second
        lda #50
        ldx is_pal
        bne +
        lda #60
+       sta second_frames
        rts

tick_clock
        dec second_frames
        bne _done
        jsr reset_second
        sed
        lda seconds
        sec
        sbc #1
        sta seconds
        cld
        bne _done
        lda #STATE_OVER
        sta next_state
_done   rts

; ---------------------------------------------------------------------------
; Copy entity state to the multiplexer's virtual sprites.
entities_to_sprites
        ldx #NUM_ENTITIES - 1
-       lda ent_active,x
        beq _hide
        lda ent_x_lo,x
        sta spr_x_lo,x
        lda ent_x_hi,x
        and #1
        sta spr_x_hi,x
        lda ent_y,x
        sta spr_y,x
        lda ent_ptr,x
        sta spr_ptr,x
        lda ent_col,x
        sta spr_col,x
        dex
        bpl -
        rts
_hide   lda #MP_PARK_Y
        sta spr_y,x
        dex
        bpl -
        rts
