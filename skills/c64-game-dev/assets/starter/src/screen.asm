; ---------------------------------------------------------------------------
; screen.asm: playfield, HUD, messages, charset animation
; ---------------------------------------------------------------------------

MSG_ROW         = 12
NUM_STARS       = 48

screen_row_lo   .for row := 0, row < 25, row += 1
                .byte <(SCREEN + row * 40)
                .endfor
screen_row_hi   .for row := 0, row < 25, row += 1
                .byte >(SCREEN + row * 40)
                .endfor
color_row_hi    .for row := 0, row < 25, row += 1
                .byte >(COLOR_RAM + row * 40)
                .endfor
        .cerror (<SCREEN) != (<COLOR_RAM), "row tables assume screen and colour RAM share low bytes"

draw_playfield
        ldx #0                  ; clear screen, default colour
-       lda #$20
        sta SCREEN,x
        sta SCREEN + $100,x
        sta SCREEN + $200,x
        sta SCREEN + $2e8,x
        lda #LIGHT_GREY
        sta COLOR_RAM,x
        sta COLOR_RAM + $100,x
        sta COLOR_RAM + $200,x
        sta COLOR_RAM + $2e8,x
        inx
        bne -

        lda #NUM_STARS          ; random star field, keeping the message row free
        sta zp_tmp2
_star   jsr rand8
        and #31
        cmp #FIELD_TOP_ROW + 1
        bcc _star
        cmp #FIELD_BOTTOM_ROW - 1
        bcs _star
        cmp #MSG_ROW
        beq _star
        tax
        lda screen_row_lo,x
        sta zp_ptr0
        sta zp_ptr1
        lda screen_row_hi,x
        sta zp_ptr0+1
        lda color_row_hi,x
        sta zp_ptr1+1
-       jsr rand8
        and #63
        cmp #40
        bcs -
        tay
        lda #TILE_STAR
        sta (zp_ptr0),y
        jsr rand8
        and #3
        tax
        lda star_colours,x
        sta (zp_ptr1),y
        dec zp_tmp2
        bne _star

        ldx #39                 ; ground row and HUD
-       lda #TILE_GROUND
        sta SCREEN + FIELD_BOTTOM_ROW * 40,x
        lda #BROWN
        sta COLOR_RAM + FIELD_BOTTOM_ROW * 40,x
        lda hud_text,x
        sta SCREEN + HUD_ROW * 40,x
        lda #WHITE
        sta COLOR_RAM + HUD_ROW * 40,x
        sta COLOR_RAM + MSG_ROW * 40,x
        dex
        bpl -

        ldx #3                  ; video standard, shown so testers can report it
        lda is_pal
        bne +
        ldx #7
+       ldy #3
-       lda video_names,x
        sta SCREEN + HUD_ROW * 40 + 36,y
        dex
        dey
        bpl -
        rts

star_colours    .byte DARK_GREY, GREY, LIGHT_GREY, WHITE

        .enc "screen"
hud_text        .text " SCORE 000000             TIME 00       "
video_names     .text " PAL"
                .text "NTSC"
        .cerror video_names - hud_text != 40, "HUD text must be 40 columns"

; Write score and time digits into the HUD row.
draw_hud
        ldx #0
        ldy #2                  ; score: 3 BCD bytes, most significant first
-       lda score,y
        lsr a
        lsr a
        lsr a
        lsr a
        ora #$30                ; screen code of "0"
        sta SCREEN + HUD_ROW * 40 + 7,x
        lda score,y
        and #$0f
        ora #$30
        sta SCREEN + HUD_ROW * 40 + 8,x
        inx
        inx
        dey
        bpl -
        lda seconds
        lsr a
        lsr a
        lsr a
        lsr a
        ora #$30
        sta SCREEN + HUD_ROW * 40 + 31
        lda seconds
        and #$0f
        ora #$30
        sta SCREEN + HUD_ROW * 40 + 32
        rts

; X = offset of a message in "messages": column byte, text, $ff.
show_message
        ldy #39
        lda #$20
-       sta SCREEN + MSG_ROW * 40,y
        dey
        bpl -
        lda messages,x
        tay
        inx
-       lda messages,x
        cmp #$ff
        beq +
        sta SCREEN + MSG_ROW * 40,y
        inx
        iny
        bne -
+       rts

messages
msg_clear       .byte 0, $ff
msg_title       .byte 11
                .text "PRESS FIRE TO PLAY"
                .byte $ff
msg_over        .byte 15
                .text "GAME OVER"
                .byte $ff
        .enc "none"

; Charset animation: redefining one character animates every copy of it on
; screen for 8 bytes of writes. Twinkle the stars every 16 frames.
animate_chars
        lda frame_count
        and #15
        bne _done
        lda frame_count
        and #16
        lsr a                   ; 0 or 8
        tax
        ldy #0
-       lda star_frames,x
        sta CHARSET + TILE_STAR * 8,y
        inx
        iny
        cpy #8
        bne -
_done   rts

; Game tiles, copied over the ROM font from TILE_FIRST at init
tiles
        .byte %00000000         ; TILE_STAR
        .byte %00000000
        .byte %00000000
        .byte %00010000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %11111111         ; TILE_GROUND
        .byte %10101010
        .byte %01010101
        .byte %10101010
        .byte %01000100
        .byte %00010001
        .byte %01000100
        .byte %00000000
tiles_end

star_frames
        .byte %00000000, %00000000, %00000000, %00010000
        .byte %00000000, %00000000, %00000000, %00000000
        .byte %00000000, %00000000, %00010000, %00111000
        .byte %00010000, %00000000, %00000000, %00000000
