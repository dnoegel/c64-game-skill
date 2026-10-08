# 64tass quick reference (as used by the starter)

64tass is a fast C cross-assembler (`brew install tass64`, `apt install 64tass`)
with no JVM dependency. Kick Assembler and ACME are equally valid choices
(`02-toolchain.md`); do not mix their syntax into 64tass files.

## Command line (from the starter Makefile)

```sh
64tass --ascii --case-sensitive -Wall -Wno-implied-reg \
       -I src -I build -D DEBUG=1 \
       --vice-labels --labels=build/game.lbl --list=build/game.lst \
       src/main.asm -o build/game.prg
```

- Default output is a CBM PRG (2-byte load address + one contiguous block).
  Gaps between `* =` regions are filled, so data placed far from code bloats
  the PRG; copy or decompress it into place at init instead.
- `--vice-labels` output loads into the VICE monitor with `-moncommands`.
- The listing (`--list`) shows addresses and bytes: use it to check tables.
- `-D NAME=value` overrides a symbol defined inside `.weak ... .endweak`.

## Syntax

```asm
NAME    = $d020                 ; constant
        .weak
DEBUG   = 1                     ; default, overridable with -D DEBUG=0
        .endweak

        * = $0801               ; set program counter
        .word (+), 2026         ; BASIC stub: 2026 SYS start
        .null $9e, format("%d", start)
+       .word 0

label                           ; labels start in column 0, no colon needed
        lda #$00                ; instructions are indented
_local  dex                     ; _name: local to the previous normal label
-       bne -                   ; anonymous: - (backward) and + (forward)
        beq ++                  ; ++ / -- skip one anonymous label

        .byte 1, 2, $ff         ; also .word, .fill n[, value], .char (signed)
        .text "HELLO"           ; encoded with the current .enc
        .enc "screen"           ; built-in screen-code encoding
        .enc "none"
        .binary "file.bin"      ; .binary "file.prg", 2 skips a load address

        .if DEBUG != 0          ; .if needs a boolean: write "!= 0"
        .endif
        .cerror * > $4000, "code too big"   ; build-time assert
        .for i := 0, i < 64, i += 1         ; assemble-time loop
        .char round(3 * sin(i * 2.0 * pi / 64))
        .endfor

table   = [$00c0, -$0120]       ; lists: <table and >table apply per element
        .byte <table, >table

        .virtual $c000          ; reserve labels without emitting bytes (BSS)
counter .byte ?
buffer  .fill 256
        .endvirtual

name    .macro color            ; macro definition
        lda #\color
        sta $d020
        .endm
        #name 2                 ; invocation
```

## Pitfalls

- A label named like a built-in function (`random`, `len`, `size`) triggers a
  shadow warning and can break expressions. Pick another name.
- `<A != <B` parses unexpectedly; parenthesise: `(<A) != (<B)`.
- `.proc` blocks are omitted when unreferenced; plain labels are always kept.
- Branch range is -128..+127. Fix "branch too far" by inverting the branch
  around a `jmp`, not with `--long-branch` (it silently changes cycle counts).
