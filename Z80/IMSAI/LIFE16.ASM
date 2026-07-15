; LIFE16.ASM -- 1D Game of Life, 16-cell ring, IMSAI front panel display
;
; Same rule and same overall structure as LIFE8.ASM in this folder, but
; the ring is 16 cells instead of 8. Since the Programmed Output panel
; only has 8 physical LEDs, a 16-cell colony is shown as two sequential
; 8-bit halves per generation -- low cells (0-7) displayed, a pause,
; then high cells (8-15) displayed, another pause, then the next
; generation is computed. This is a genuine improvement over 8 cells,
; not just a bigger number: an exhaustive simulation of all 65536
; possible 16-bit seeds found some settle into a 48-generation cycle
; (after an 8-generation transient) -- versus 8 cells, where every one
; of the 256 possible seeds settles within 2 generations into a cycle
; no longer than 5. Sixteen cells is a real qualitative jump, not a
; marginal one.
;
; Named in tribute to Jon Millen, author of "One-Dimensional Life,"
; BYTE Magazine, Vol 3 No 12, December 1978 -- the five-cell YYXYY
; neighborhood rule this program implements (same rule as MILLIFE.C /
; MILLIFE.PAS / LIFE8.ASM elsewhere in this repo). See jonmillen.com/1dlife
;
; Standalone, bare-metal -- no CP/M, no BDOS. Same active-low panel
; assumption as LIFE8.ASM (CMA before each OUT) -- confirmed correct on
; real (fake) hardware, same panel/port as LIFE8.ASM.
;
; CONFIRMED WORKING on The High Nibble (an ESP32-based IMSAI 8080
; emulator), configured to emulate a Z80 at 4MHz. Assembled with the
; classic Digital Research ASM.COM (CP/M ASSEMBLER VER 2.0). Display
; and duplexing logic both correct, and the timing (DELAY1/DELAY2/
; DELAY3 for the main per-generation pause, HALFDELAY1/HALFDELAY2 for
; the shorter pause between the LO and HI halves) has been tuned and
; confirmed on hardware too -- the overall rhythm reads clearly as
; intended: a quick LO-HI pair, then a longer pause, repeating --
; "1-2---1-2---1-2." No further tuning needed at the values below.
;
; Reuses LIFE8.ASM's verified GETCELLA/SETCELLB/WRAP pattern (just with
; a 16 instead of an 8), and the same hand-verified pack/unpack logic
; duplicated for two halves instead of parameterized, on the theory
; that duplication is safer to verify by hand than cleverness.

        ORG     0100H

OUTPORT EQU     0FFH            ; Programmed Output port -- confirmed
DELAY1  EQU     0FFH            ; innermost delay loop count -- confirmed on hardware
DELAY2  EQU     0FFH            ; middle delay loop count -- confirmed on hardware
DELAY3  EQU     004H            ; outer delay loop count -- confirmed on hardware,
                                 ; same value LIFE8.ASM settled on; gives the
                                 ; intended "1-2---1-2---1-2" rhythm at 4MHz Z80
HALFDELAY1 EQU  0FFH            ; shorter delay between the LO and HI halves
HALFDELAY2 EQU  0FFH            ; of the same generation -- confirmed on hardware,
                                 ; long enough to read as a clearly held state
                                 ; (was 020H, ~35ms -- too short, that was the
                                 ; original flicker's actual cause)

; ------------------------------------------------------------------
; Entry point
; ------------------------------------------------------------------
START:  LDA     SEEDL
        STA     SEEDLCUR
        LDA     SEEDH
        STA     SEEDHCUR
        CALL    UNPACKLO        ; unpack SEEDLCUR into CELLA[0..7]
        CALL    UNPACKHI        ; unpack SEEDHCUR into CELLA[8..15]

MAINLOOP:
        CALL    PACKLO          ; A := packed byte from CELLA[0..7]
        CMA
        OUT     OUTPORT
        CALL    HALFDELAY

        CALL    PACKHI          ; A := packed byte from CELLA[8..15]
        CMA
        OUT     OUTPORT
        CALL    DELAY

        CALL    STEP            ; compute CELLB from CELLA (Millen's rule)
        CALL    CHECKDEAD       ; Z flag set if CELLB is all-zero
        JZ      RESEED
        CALL    CHECKFULL       ; Z flag set if CELLB is all-one
        JZ      RESEED

        CALL    COPYBTOA        ; CELLA := CELLB
        JMP     MAINLOOP

RESEED: LDA     SEEDLCUR
        RLC
        STA     SEEDLCUR
        LDA     SEEDHCUR
        RLC
        STA     SEEDHCUR
        CALL    UNPACKLO
        CALL    UNPACKHI
        JMP     MAINLOOP

; ------------------------------------------------------------------
; UNPACKLO -- explode SEEDLCUR's bits into CELLA[0..7]
; UNPACKHI -- explode SEEDHCUR's bits into CELLA[8..15]
; Same logic as LIFE8.ASM's UNPACK, duplicated for each half rather
; than parameterized.
; ------------------------------------------------------------------
UNPACKLO:
        LXI     H,CELLA
        LDA     SEEDLCUR
        MVI     B,8
UPLOLP: MOV     C,A
        ANI     01H
        MOV     M,A
        INX     H
        MOV     A,C
        RRC
        DCR     B
        JNZ     UPLOLP
        RET

UNPACKHI:
        LXI     H,CELLA+8
        LDA     SEEDHCUR
        MVI     B,8
UPHILP: MOV     C,A
        ANI     01H
        MOV     M,A
        INX     H
        MOV     A,C
        RRC
        DCR     B
        JNZ     UPHILP
        RET

; ------------------------------------------------------------------
; PACKLO -- A := packed byte from CELLA[0..7] (cell0=bit0...cell7=bit7)
; PACKHI -- A := packed byte from CELLA[8..15] (cell8=bit0...cell15=bit7)
; Same shift-and-or logic as LIFE8.ASM's PACK, duplicated for each half.
; ------------------------------------------------------------------
PACKLO: LXI     H,CELLA+7
        MVI     B,8
        XRA     A
PLOLP:  ADD     A
        ORA     M
        DCX     H
        DCR     B
        JNZ     PLOLP
        RET

PACKHI: LXI     H,CELLA+15
        MVI     B,8
        XRA     A
PHILP:  ADD     A
        ORA     M
        DCX     H
        DCR     B
        JNZ     PHILP
        RET

; ------------------------------------------------------------------
; GETCELLA -- input: A = index (0-15). Output: A = CELLA[index].
; Identical to LIFE8.ASM's version -- this walk-by-INX approach never
; hardcoded 8 anywhere, so it works unchanged for a 16-entry array.
; ------------------------------------------------------------------
GETCELLA:
        PUSH    B
        MOV     B,A
        LXI     H,CELLA
GCLOOP: MOV     A,B
        ORA     A
        JZ      GCDONE
        INX     H
        DCR     B
        JMP     GCLOOP
GCDONE: MOV     A,M
        POP     B
        RET

; ------------------------------------------------------------------
; SETCELLB -- input: A = index (0-15), C = value (0 or 1).
; Identical approach to LIFE8.ASM's version, same reasoning as above.
; ------------------------------------------------------------------
SETCELLB:
        PUSH    B
        MOV     B,A
        LXI     H,CELLB
SETLOOP:
        MOV     A,B
        ORA     A
        JZ      SETDONE
        INX     H
        DCR     B
        JMP     SETLOOP
SETDONE:
        MOV     A,C
        MOV     M,A
        POP     B
        RET

; ------------------------------------------------------------------
; WRAP16 -- input: A (any value from -2 to 17, which is all this
; program ever produces for a 16-cell ring). Output: A wrapped into
; 0..15. Same two-branch approach as LIFE8.ASM's WRAP8, just with 16
; instead of 8 -- verified by the same reasoning: the input range only
; ever needs at most one add-16 or one subtract-16 to land in range.
; ------------------------------------------------------------------
WRAP16: CPI     0
        JP      W16A
        ADI     16
W16A:   CPI     16
        JM      W16DONE
        SUI     16
W16DONE:
        RET

; ------------------------------------------------------------------
; NEIGHSUM -- input: A = i (0-15). Output: A = sum of CELLA at ring
; positions (i-2, i-1, i+1, i+2 mod 16). Same structure as LIFE8.ASM's
; version, just calling WRAP16 instead of WRAP8.
; ------------------------------------------------------------------
NEIGHSUM:
        STA     NSI
        MVI     C,0

        LDA     NSI
        SUI     2
        CALL    WRAP16
        CALL    GETCELLA
        ADD     C
        MOV     C,A

        LDA     NSI
        SUI     1
        CALL    WRAP16
        CALL    GETCELLA
        ADD     C
        MOV     C,A

        LDA     NSI
        ADI     1
        CALL    WRAP16
        CALL    GETCELLA
        ADD     C
        MOV     C,A

        LDA     NSI
        ADI     2
        CALL    WRAP16
        CALL    GETCELLA
        ADD     C
        MOV     C,A

        MOV     A,C
        RET

; ------------------------------------------------------------------
; STEP -- same Millen's-rule logic as LIFE8.ASM's STEP, just looping
; 0..15 instead of 0..7.
; ------------------------------------------------------------------
STEP:   XRA     A
        STA     SI              ; SI := 0
STEPLP: LDA     SI
        CALL    NEIGHSUM        ; A := neighbor sum for cell SI
        STA     SUM

        LDA     SI
        CALL    GETCELLA        ; A := CELLA[SI]  (0 or 1)
        ORA     A
        JNZ     STALIVE

        LDA     SUM
        CPI     2
        JZ      SETALIVE
        CPI     3
        JZ      SETALIVE
        JMP     SETDEAD

STALIVE:
        LDA     SUM
        CPI     2
        JZ      SETALIVE
        CPI     4
        JZ      SETALIVE
        JMP     SETDEAD

SETALIVE:
        MVI     C,1
        JMP     STSTORE
SETDEAD:
        MVI     C,0

STSTORE:
        LDA     SI
        CALL    SETCELLB        ; CELLB[SI] := C

        LDA     SI
        INR     A
        STA     SI
        CPI     16
        JNZ     STEPLP
        RET

; ------------------------------------------------------------------
; COPYBTOA -- CELLA[0..15] := CELLB[0..15]
; ------------------------------------------------------------------
COPYBTOA:
        LXI     H,CELLB
        LXI     D,CELLA
        MVI     B,16
CBALP:  MOV     A,M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     CBALP
        RET

; ------------------------------------------------------------------
; CHECKDEAD -- Z flag set on return if CELLB is all zero
; ------------------------------------------------------------------
CHECKDEAD:
        LXI     H,CELLB
        MVI     B,16
CDLP:   MOV     A,M
        ORA     A
        RNZ
        INX     H
        DCR     B
        JNZ     CDLP
        XRA     A
        RET

; ------------------------------------------------------------------
; CHECKFULL -- Z flag set on return if CELLB is all one
; ------------------------------------------------------------------
CHECKFULL:
        LXI     H,CELLB
        MVI     B,16
CFLP:   MOV     A,M
        CPI     1
        RNZ
        INX     H
        DCR     B
        JNZ     CFLP
        XRA     A
        RET

; ------------------------------------------------------------------
; DELAY -- triple-nested, shown after both halves of a generation.
; HALFDELAY -- shorter double-nested delay, shown between the LO and
; HI halves of the SAME generation, so each half is actually visible
; as its own distinct display rather than blurring together.
; ------------------------------------------------------------------
DELAY:  PUSH    B
        PUSH    D
        MVI     D,DELAY3
DLYOUT3:
        MVI     B,DELAY2
DLYOUT: MVI     C,DELAY1
DLYIN:  DCR     C
        JNZ     DLYIN
        DCR     B
        JNZ     DLYOUT
        DCR     D
        JNZ     DLYOUT3
        POP     D
        POP     B
        RET

HALFDELAY:
        PUSH    B
        MVI     B,HALFDELAY2
HDOUT:  MVI     C,HALFDELAY1
HDIN:   DCR     C
        JNZ     HDIN
        DCR     B
        JNZ     HDOUT
        POP     B
        RET

; ------------------------------------------------------------------
; Data
; ------------------------------------------------------------------
; Seed 5471 (0x155F) -- found by exhaustively simulating all 65536
; possible 16-bit seeds: an 8-generation transient, then a 48-
; generation cycle, the longest cycle length possible for a 16-cell
; ring under this rule. Change freely; see IMSAI/README.md.
SEEDL:      DB      05FH        ; low byte  (cells 0-7)
SEEDH:      DB      015H        ; high byte (cells 8-15)
SEEDLCUR:   DB      0
SEEDHCUR:   DB      0
NSI:        DB      0           ; NEIGHSUM's index scratch
SI:         DB      0           ; STEP's loop index
SUM:        DB      0           ; STEP's computed neighbor sum
CELLA:      DS      16
CELLB:      DS      16

        END     START
