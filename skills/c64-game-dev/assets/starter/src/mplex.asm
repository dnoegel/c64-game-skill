; ---------------------------------------------------------------------------
; mplex.asm: sprite multiplexer
;
; Game code fills the virtual sprite arrays (spr_*). Once per frame the main
; loop calls mplex_sort and mplex_build. The build writes a display list into
; the back half of a double buffer; the bottom IRQ swaps it in after the last
; sprite of the frame, so the IRQs never read a list being rewritten.
;
; Display list entry k uses hardware sprite k & 7. Entry k is only accepted if
; it starts at least MP_MIN_GAP lines below entry k-8 (the previous user of the
; same hardware sprite), otherwise it is dropped for this frame.
;
; Entries 0-7 are written by the top IRQ. Entry k >= 8 is written by an IRQ at
; line y - MP_PREWRITE. Entries that are already due are written in the same
; IRQ (batching), which also covers the "raster already passed" case.
; ---------------------------------------------------------------------------

MP_MAX_VIRTUAL  = 24            ; virtual sprites the game may use
MP_BUF          = 32            ; entries per display list half
MP_PREWRITE     = 3             ; lines before the sprite's Y to rewrite it
MP_MIN_GAP      = 21 + MP_PREWRITE
MP_PARK_Y       = $ff           ; spr_y value meaning "not shown"
MP_MAX_Y        = 250           ; sprites at or below this line are not shown

        .cerror MP_MAX_VIRTUAL > MP_BUF, "MP_MAX_VIRTUAL must fit one buffer half"

        .virtual zp_free
mp_front        .byte ?         ; 0 or MP_BUF: half the IRQs read
mp_end          .byte ?         ; one past the last front entry
mp_idx          .byte ?         ; next entry the IRQ chain writes
mp_pending      .byte ?         ; 1 = back half is complete, swap at next bottom IRQ
mp_pending_end  .byte ?
mp_enable       .byte ?         ; $d015 value for the front half
mp_pending_enable .byte ?
mp_base         .byte ?         ; build: back half base index
mp_si           .byte ?         ; build: position in sort_order
mp_d010         .byte ?         ; build: running $d010 value
mp_mask         .byte ?
zp_free_mplex
        .endvirtual

        .virtual BSS_START
; virtual sprites, written by game code
spr_x_lo        .fill MP_MAX_VIRTUAL
spr_x_hi        .fill MP_MAX_VIRTUAL    ; 0 or 1 (X bit 8)
spr_y           .fill MP_MAX_VIRTUAL    ; MP_PARK_Y hides the sprite
spr_ptr         .fill MP_MAX_VIRTUAL
spr_col         .fill MP_MAX_VIRTUAL
sort_order      .fill MP_MAX_VIRTUAL    ; persistent, so re-sorting is nearly free
; double-buffered display list: [0, MP_BUF) and [MP_BUF, 2 * MP_BUF)
dl_y            .fill MP_BUF * 2
dl_x_lo         .fill MP_BUF * 2
dl_d010         .fill MP_BUF * 2
dl_ptr          .fill MP_BUF * 2
dl_col          .fill MP_BUF * 2
dl_slot         .fill MP_BUF * 2        ; hardware sprite 0-7
dl_slot2        .fill MP_BUF * 2        ; hardware sprite * 2 (X/Y register offset)
dl_trig         .fill MP_BUF * 2        ; raster line of the IRQ that writes it
bss_free_mplex
        .endvirtual

; ---------------------------------------------------------------------------
; mplex_init: hide every virtual sprite, empty both display lists.
; Call with interrupts disabled.
; ---------------------------------------------------------------------------
mplex_init
        ldx #MP_MAX_VIRTUAL - 1
-       lda #MP_PARK_Y
        sta spr_y,x
        txa
        sta sort_order,x
        dex
        bpl -
        lda #0
        sta mp_front
        sta mp_end
        sta mp_idx
        sta mp_pending
        sta mp_enable
        sta SPR_ENABLE
        sta SPR_MSB
        rts

; ---------------------------------------------------------------------------
; mplex_sort: insertion sort of sort_order by spr_y, top to bottom.
; Entities move a few pixels per frame, so the previous order is almost
; sorted already and this runs in close to linear time ("Ocean sort").
; ---------------------------------------------------------------------------
mplex_sort
        ldx #1
_outer  cpx #MP_MAX_VIRTUAL
        bcs _done
        lda sort_order,x
        sta zp_tmp0             ; key: virtual sprite index
        tay
        lda spr_y,y
        sta zp_tmp1             ; key: Y
        stx zp_tmp2
_inner  lda sort_order-1,x
        tay
        lda spr_y,y
        cmp zp_tmp1
        beq _place
        bcc _place              ; y[j] <= key: stop
        tya
        sta sort_order,x        ; shift right
        dex
        bne _inner
_place  lda zp_tmp0
        sta sort_order,x
        ldx zp_tmp2
        inx
        bne _outer
_done   rts

; ---------------------------------------------------------------------------
; mplex_build: turn the sorted virtual sprites into the back display list.
; ---------------------------------------------------------------------------
mplex_build
        ; The previous list has not been swapped in yet (the main loop overran
        ; a frame): wait for the bottom IRQ. Overwriting it could race the swap,
        ; dropping it would freeze the sprites while the overrun lasts.
-       lda mp_pending
        bne -
        sta mp_si
        sta mp_d010

        lda mp_front
        eor #MP_BUF
        sta mp_base
        tax                     ; X = write position in the back half

_next   ldy mp_si
        cpy #MP_MAX_VIRTUAL
        beq _done
        inc mp_si
        lda sort_order,y
        tay                     ; Y = virtual sprite
        lda spr_y,y
        cmp #MP_MAX_Y
        bcs _done               ; sorted, so everything after is hidden too

        txa
        sec
        sbc mp_base
        cmp #8
        bcc _first8

        lda spr_y,y             ; reuse of a hardware sprite: check the gap
        sec
        sbc dl_y-8,x
        cmp #MP_MIN_GAP
        bcc _next               ; too close to its previous use: drop it
        lda spr_y,y
        sec
        sbc #MP_PREWRITE
        sta dl_trig,x
        bne _store              ; always taken (Y >= MP_MIN_GAP here)

_first8 lda #0                  ; written by the top IRQ
        sta dl_trig,x

_store  txa
        sec
        sbc mp_base
        and #7
        sta dl_slot,x
        stx zp_tmp0
        tax
        lda bit_mask,x
        sta mp_mask
        txa
        asl a
        ldx zp_tmp0
        sta dl_slot2,x

        lda spr_y,y
        sta dl_y,x
        lda spr_x_lo,y
        sta dl_x_lo,x
        lda spr_ptr,y
        sta dl_ptr,x
        lda spr_col,y
        sta dl_col,x

        lda spr_x_hi,y          ; update the running $d010 for this slot
        beq +
        lda mp_d010
        ora mp_mask
        bne ++
+       lda mp_mask
        eor #$ff
        and mp_d010
+       sta mp_d010
        sta dl_d010,x

        inx
        jmp _next

_done   stx mp_pending_end
        txa
        sec
        sbc mp_base
        cmp #8
        bcc +
        lda #8
+       tax
        lda enable_mask,x
        sta mp_pending_enable
        lda #1
        sta mp_pending          ; publish last
        rts

bit_mask        .byte $01, $02, $04, $08, $10, $20, $40, $80
enable_mask     .byte $00, $01, $03, $07, $0f, $1f, $3f, $7f, $ff

; ---------------------------------------------------------------------------
; mplex_swap: called by the bottom IRQ, after the last multiplexer IRQ of the
; frame. Makes a completed back list the front list.
; ---------------------------------------------------------------------------
mplex_swap
        lda mp_pending
        beq +
        lda mp_front
        eor #MP_BUF
        sta mp_front
        lda mp_pending_end
        sta mp_end
        lda mp_pending_enable
        sta mp_enable
        lda #0
        sta mp_pending
+       rts

; ---------------------------------------------------------------------------
; mplex_frame_start: called by the top IRQ. Writes entries until the next
; one is not yet due. Returns with the next IRQ scheduled (another
; multiplexer IRQ, or the bottom IRQ).
; ---------------------------------------------------------------------------
mplex_frame_start
        lda mp_enable
        sta SPR_ENABLE
        ldx mp_front
        cpx mp_end
        bcc mplex_write
        jmp schedule_bottom

; Entered with X = display list entry. Also the body of irq_mplex.
mplex_write
        ldy dl_slot2,x
        lda dl_y,x
        sta SPR0_Y,y
        lda dl_x_lo,x
        sta SPR0_X,y
        lda dl_d010,x
        sta SPR_MSB
        ldy dl_slot,x
        lda dl_ptr,x
        sta SPRITE_PTRS,y
        lda dl_col,x
        sta SPR0_COL,y
        inx
        cpx mp_end
        bcs _finished
        lda VIC_RASTER          ; next entry due within 2 lines (or passed)?
        clc
        adc #2
        cmp dl_trig,x
        bcs mplex_write         ; yes: write it now, in this IRQ
        stx mp_idx
        lda dl_trig,x
        sta VIC_RASTER
        lda #<irq_mplex
        sta IRQ_VECTOR
        lda #>irq_mplex
        sta IRQ_VECTOR+1
        rts
_finished
        jmp schedule_bottom

; ---------------------------------------------------------------------------
irq_mplex
        pha
        txa
        pha
        tya
        pha
        cld
        asl VIC_IRR
        #irq_prof_begin CYAN
        ldx mp_idx
        jsr mplex_write
        #irq_prof_end
        jmp irq_return
