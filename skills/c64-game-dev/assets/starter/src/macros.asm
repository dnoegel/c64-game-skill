; ---------------------------------------------------------------------------
; macros.asm: debug and utility macros. All debug output disappears with
; -D DEBUG=0.
; ---------------------------------------------------------------------------

; Border colour profiling inside an IRQ: the band height on screen is the
; handler's cost in raster lines (63 cycles each on PAL).
irq_prof_begin .macro color
        .if DEBUG != 0
        lda BORDER
        pha
        lda #\color
        sta BORDER
        .endif
        .endm

irq_prof_end .macro
        .if DEBUG != 0
        pla
        sta BORDER
        .endif
        .endm

; Border colour profiling in the main loop.
prof .macro color
        .if DEBUG != 0
        lda #\color
        sta BORDER
        .endif
        .endm

; Halt with a recognisable border colour, so a failed check is visible on
; real hardware without a debugger. Use as: #assert_fail RED
assert_fail .macro color
        .if DEBUG != 0
        sei
        lda #\color
-       sta BORDER
        jmp -
        .endif
        .endm

; 16-bit add of an immediate to a zero page or absolute word
add16i .macro addr, value
        clc
        lda \addr
        adc #<\value
        sta \addr
        lda \addr+1
        adc #>\value
        sta \addr+1
        .endm
