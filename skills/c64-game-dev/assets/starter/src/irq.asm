; ---------------------------------------------------------------------------
; irq.asm: raster IRQ chain
;
;   RASTER_TOP     irq_top     write sprites 0-7,
;                              schedule multiplexer IRQs
;   (per sprite)   irq_mplex   rewrite reused hardware sprites
;   RASTER_BOTTOM  irq_bottom  swap sprite list, sfx/music, set frame_flag
;
; IRQs do fixed-cost register work only. Anything variable belongs in the
; main loop, which may overrun (slowdown) without breaking the display.
; ---------------------------------------------------------------------------

; Call with interrupts disabled, after init_system.
irq_init
        lda #<irq_top
        sta IRQ_VECTOR
        lda #>irq_top
        sta IRQ_VECTOR+1
        lda #RASTER_TOP
        sta VIC_RASTER
        lda VIC_CR1
        and #$7f                ; RST8 = 0: every compare line is < 256
        sta VIC_CR1
        lda #$01
        sta VIC_IMR             ; raster IRQ only
        lda #$ff
        sta VIC_IRR             ; ack anything pending
        rts

irq_top
        pha
        txa
        pha
        tya
        pha
        cld                     ; main loop may be in decimal mode
        asl VIC_IRR             ; ack early so a fast re-trigger is not lost
        #irq_prof_begin LIGHT_BLUE
        jsr mplex_frame_start   ; schedules the next IRQ itself
        #irq_prof_end
        jmp irq_return

irq_bottom
        pha
        txa
        pha
        tya
        pha
        cld
        asl VIC_IRR
        #irq_prof_begin YELLOW
        jsr mplex_swap
        jsr music_play
        jsr sfx_update

        lda frame_flag          ; main loop still busy with the last frame?
        beq +
        inc frame_overrun
+       lda #1
        sta frame_flag
        inc frame_count

        lda #<irq_top
        sta IRQ_VECTOR
        lda #>irq_top
        sta IRQ_VECTOR+1
        lda #RASTER_TOP
        sta VIC_RASTER
        #irq_prof_end
        ; fall through

irq_return
        pla
        tay
        pla
        tax
        pla
nmi_return
        rti

schedule_bottom
        lda #<irq_bottom
        sta IRQ_VECTOR
        lda #>irq_bottom
        sta IRQ_VECTOR+1
        lda #RASTER_BOTTOM
        sta VIC_RASTER
        rts
