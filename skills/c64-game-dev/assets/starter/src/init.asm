; ---------------------------------------------------------------------------
; init.asm: take over the machine
;
; After init_system: KERNAL and BASIC are banked out ($01 = $35), CIA
; interrupts are off, NMI (RESTORE) is harmless, BSS is zeroed, the VIC is
; looking at VIC_BANK, and is_pal is known.
; ---------------------------------------------------------------------------

init_system
        sei
        cld

        lda #$7f
        sta CIA1_ICR            ; CIA1 timer IRQ runs by default: stop it
        sta CIA2_ICR            ; CIA2 NMIs off
        lda CIA1_ICR            ; ack anything pending
        lda CIA2_ICR
        lda #0
        sta VIC_IMR
        lda #$ff
        sta VIC_IRR

        lda #$2f                ; 6510 port: default direction
        sta $00
        lda #$35                ; RAM everywhere except I/O
        sta $01

        lda #<nmi_return        ; RESTORE key now does nothing
        sta NMI_VECTOR
        lda #>nmi_return
        sta NMI_VECTOR+1
        lda #<nmi_return        ; a stray BRK or IRQ before irq_init is harmless
        sta IRQ_VECTOR
        lda #>nmi_return
        sta IRQ_VECTOR+1

        jsr clear_ram           ; real hardware does not power up with zeroed RAM
        jsr detect_pal
        jsr init_vic
        jsr init_sid
        rts

; Zero the engine's zero page and BSS. Never assume RAM contents: VICE starts
; with a regular pattern, real machines do not.
clear_ram
        lda #0
        ldx #zp_end - $02
-       sta $02-1,x
        dex
        bne -

        lda #<BSS_START
        sta zp_ptr0
        lda #>BSS_START
        sta zp_ptr0+1
        ldx #>(BSS_END - BSS_START)
        lda #0
        tay
-       sta (zp_ptr0),y
        iny
        bne -
        inc zp_ptr0+1
        dex
        bne -
        rts

; PAL has 312 raster lines, NTSC 263 (or 262). Find the highest line number
; with bit 8 set: PAL ends at $137, NTSC at $106/$105.
detect_pal
-       bit VIC_CR1             ; wait until we are in lines 256+
        bpl -
        lda #0
        sta zp_tmp0
-       lda VIC_RASTER
        cmp zp_tmp0
        bcc +
        sta zp_tmp0
+       bit VIC_CR1
        bmi -
        lda zp_tmp0
        cmp #$20
        lda #0
        rol a                   ; carry set = PAL
        sta is_pal
        rts

init_vic
        lda #0
        sta VIC_CR1             ; blank while we build the screen

        lda CIA2_DDRA
        ora #$03
        sta CIA2_DDRA
        lda CIA2_PRA
        and #$fc
        ora #DD00_BANK_BITS
        sta CIA2_PRA
        lda #D018_VALUE
        sta VIC_MEM
        lda #$08                ; 40 columns, hires characters, XSCROLL 0
        sta VIC_CR2

        lda #BLACK
        sta BORDER
        sta BGCOL0
        lda #0
        sta SPR_MC
        sta SPR_PRIORITY
        sta SPR_EXPAND_X
        sta SPR_EXPAND_Y

        jsr copy_charset
        jsr copy_sprites
        jsr mplex_init
        rts

; Copy the ROM font into the VIC bank (screen codes $00-$7f), then overlay
; the game's own tiles from screen code TILE_FIRST up.
copy_charset
        lda #$33                ; character ROM visible at $d000
        sta $01
        ldx #0
-       lda $d000,x
        sta CHARSET,x
        lda $d100,x
        sta CHARSET + $100,x
        lda $d200,x
        sta CHARSET + $200,x
        lda $d300,x
        sta CHARSET + $300,x
        inx
        bne -
        lda #$35
        sta $01

        ldx #tiles_end - tiles - 1
-       lda tiles,x
        sta CHARSET + TILE_FIRST * 8,x
        dex
        bpl -
        rts

copy_sprites
        lda #<sprite_frames
        sta zp_ptr0
        lda #>sprite_frames
        sta zp_ptr0+1
        lda #<SPRITE_DATA
        sta zp_ptr1
        lda #>SPRITE_DATA
        sta zp_ptr1+1
        ldx #>(sprite_frames_end - sprite_frames + 255)
        ldy #0
-       lda (zp_ptr0),y
        sta (zp_ptr1),y
        iny
        bne -
        inc zp_ptr0+1
        inc zp_ptr1+1
        dex
        bne -
        rts

init_sid
        ldx #$18
        lda #0
-       sta SID,x
        dex
        bpl -
        lda #$0f                ; full volume
        sta SID_VOLUME
        rts
