; ---------------------------------------------------------------------------
; sfx.asm: priority sound effects on SID voice 3
;
; Voice 3 is reserved for effects, voices 1-2 are left for music. The main
; loop only posts a request (sfx_play); the bottom IRQ starts and steps the
; effect (sfx_update), so the SID is only ever written from one place.
; A request replaces the playing effect only if its priority is >= the
; playing one's.
; ---------------------------------------------------------------------------

SFX_SHOOT       = 0
SFX_HIT         = 1
SFX_OVER        = 2
SFX_NONE        = $ff

;                  shoot  hit    over
sfx_priority    .byte 1,     2,     3
sfx_wave        .byte $21,   $81,   $11     ; saw, noise, triangle (+ gate)
sfx_ad          .byte $09,   $0a,   $0c
sfx_sr          .byte $00,   $00,   $a8
sfx_freq        .byte $40,   $28,   $18     ; start frequency, high byte
sfx_sweep       .byte $fc,   $ff,   $ff     ; added to the high byte per frame
sfx_length      .byte 8,     12,    45      ; frames

        .virtual bss_end_used
sfx_request     .byte ?
sfx_current     .byte ?
sfx_timer       .byte ?
sfx_freq_hi     .byte ?
bss_end_sfx
        .endvirtual
        .cerror bss_end_sfx > BSS_END, "BSS overflow"

sfx_init
        lda #SFX_NONE
        sta sfx_request
        sta sfx_current
        lda #0
        sta sfx_timer
        rts

; X = effect. Main loop side: only records the request.
sfx_play
        ldy sfx_request
        bmi +
        lda sfx_priority,x
        cmp sfx_priority,y
        bcc ++                  ; a louder request is already pending
+       stx sfx_request
+       rts

; IRQ side, once per frame.
sfx_update
        ldx sfx_request
        bmi _step
        lda #SFX_NONE
        sta sfx_request
        ldy sfx_current
        bmi _start
        lda sfx_priority,x
        cmp sfx_priority,y
        bcc _step               ; lower priority than the playing effect
_start  stx sfx_current
        lda #0
        sta SID_V3_CTRL         ; gate off, so the envelope restarts
        sta SID_V3_FREQ
        lda sfx_ad,x
        sta SID_V3_AD
        lda sfx_sr,x
        sta SID_V3_SR
        lda #$08
        sta SID_V3_PW+1
        lda sfx_freq,x
        sta sfx_freq_hi
        sta SID_V3_FREQ+1
        lda sfx_length,x
        sta sfx_timer
        lda sfx_wave,x
        sta SID_V3_CTRL
        rts

_step   lda sfx_timer
        beq _done
        dec sfx_timer
        beq _release
        ldx sfx_current
        lda sfx_freq_hi
        clc
        adc sfx_sweep,x
        sta sfx_freq_hi
        sta SID_V3_FREQ+1
_done   rts
_release
        ldx sfx_current
        lda sfx_wave,x
        and #$fe                ; gate off: release phase
        sta SID_V3_CTRL
        lda #SFX_NONE
        sta sfx_current
        rts
