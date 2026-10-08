; ---------------------------------------------------------------------------
; music.asm: music player hook
;
; No tune ships with the starter. To add one (GoatTracker 2, SID-Wizard,
; CheeseCutter all export a player + data):
;
;   1. Export for a free address range from docs/memory-map.md, e.g. $c800,
;      using voices 1-2 only (voice 3 belongs to sfx.asm).
;   2. Include the raw binary without its 2-byte load address:
;          * = $c800  (or a .logical block copied there at init)
;          .binary "music.prg", 2
;   3. Replace the bodies below with "lda #0 / jmp $c800" (init, A = subtune)
;      and "jmp $c803" (play). Check the player's addresses in the tracker's
;      export dialog.
;   4. Measure the play routine with the yellow border band (irq_bottom);
;      budget 1,000 to 2,500 cycles (16 to 40 raster lines).
; ---------------------------------------------------------------------------

music_init
        rts

music_play
        rts
