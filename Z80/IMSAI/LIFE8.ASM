; LIFE8.ASM -- 1D Game of Life, 8-cell ring, IMSAI front panel display
;
; Named in tribute to Jon Millen, author of "One-Dimensional Life,"
; BYTE Magazine, Vol 3 No 12, December 1978 -- the five-cell YYXYY
; neighborhood rule this program implements (same rule as MILLIFE.C /
; MILLIFE.PAS elsewhere in this repo). See jonmillen.com/1dlife
;
; This is a standalone, bare-metal program -- no CP/M, no BDOS calls.
; Runs forever, displaying each generation on the IMSAI's Programmed
; Output LEDs (port 0FFH, assumed). The panel is assumed active-low
; (0 bit = LED on), matching the author's recollection -- if the
; lights come out backwards, remove the CMA instruction in MAINLOOP.
;
; CONFIRMED WORKING on The High Nibble (an ESP32-based IMSAI 8080
; emulator), configured to emulate a Z80 at 4MHz. Live LED pattern
; matched a from-scratch simulation of the seed value exactly,
; transient blip included -- see IMSAI/README.md for the full writeup.
; Assembled successfully with both Macroassembler AS and the stock
; CP/M 2.2 ASM.COM (CP/M ASSEMBLER VER 2.0). Timing constants (DELAY1/
; DELAY2/DELAY3) have been tuned and confirmed on this hardware too --
; see IMSAI/README.md for the settled values and how they were found.
;
; Design note: this deliberately favors simple, easy-to-verify-by-hand
; subroutines (memory variables for loop state, one clear A-in/A-out
; convention per call) over clever register-packed code. An earlier
; draft tried to be more register-efficient and had two real bugs from
; it (a mis-accumulating pack routine, and a loop counter silently
; clobbered by a nested call) -- simplicity won out on purpose here.
;
; Assembled for classic Intel 8080 mnemonics (works with both AS and
; classic ASM.COM). Adjust ORG below to match wherever this
; machine's usable RAM actually starts.

        ORG     0100H

OUTPORT EQU     0FFH            ; Programmed Output port -- confirm this
DELAY1  EQU     0FFH            ; innermost delay loop count -- TUNE ON HARDWARE
DELAY2  EQU     0FFH            ; middle delay loop count -- TUNE ON HARDWARE
DELAY3  EQU     004H            ; outer delay loop count -- confirmed on
                                 ; hardware: gives ~1-1.25s per generation,
                                 ; a good pace (016H, the original tuned
                                 ; value, worked but was slower, ~4-5s)

; ------------------------------------------------------------------
; Entry point
; ------------------------------------------------------------------
START:  LXI     H,SEED
        MOV     A,M
        STA     SEEDCUR         ; keep a working copy of the current seed
        CALL    UNPACK          ; unpack SEEDCUR into CELLA[0..7]

MAINLOOP:
        CALL    PACK            ; A := packed byte from CELLA (cell0=bit0)
        CMA                     ; invert -- panel is active-low
        OUT     OUTPORT
        CALL    DELAY

        CALL    STEP            ; compute CELLB from CELLA (Millen's rule)
        CALL    CHECKDEAD       ; Z flag set if CELLB is all-zero
        JZ      RESEED
        CALL    CHECKFULL       ; Z flag set if CELLB is all-one
        JZ      RESEED

        CALL    COPYBTOA        ; CELLA := CELLB
        JMP     MAINLOOP

RESEED: LDA     SEEDCUR
        RLC                     ; rotate seed so reseeds aren't identical
        STA     SEEDCUR
        CALL    UNPACK
        JMP     MAINLOOP

; ------------------------------------------------------------------
; UNPACK -- explode SEEDCUR's bits into CELLA[0..7] (0 or 1 each).
; cell0 = bit0 of SEEDCUR, ... cell7 = bit7.
; Clobbers: A, B, C, H, L.
; ------------------------------------------------------------------
UNPACK: LXI     H,CELLA
        LDA     SEEDCUR
        MVI     B,8
UNPLP:  MOV     C,A             ; C = remaining bits still to process
        ANI     01H             ; isolate current bit0
        MOV     M,A             ; store 0 or 1 into CELLA[current]
        INX     H
        MOV     A,C
        RRC                     ; rotate right so next bit becomes bit0
        DCR     B
        JNZ     UNPLP
        RET

; ------------------------------------------------------------------
; PACK -- build a byte in A from CELLA[0..7], cell0 = bit0 ... cell7 = bit7.
; Standard "shift-and-or" building from the high end down, so cell7
; (processed first) ends up shifted left the most (into bit7), and
; cell0 (processed last) ends up unshifted (bit0).
; Clobbers: A, B, H, L.
; ------------------------------------------------------------------
PACK:   LXI     H,CELLA+7       ; start at the highest index
        MVI     B,8
        XRA     A               ; running result := 0
PAKLP:  ADD     A               ; shift left, zero-fill bit0 (A := A+A)
        ORA     M               ; OR in CELLA[current] (always 0 or 1)
        DCX     H               ; move to next-lower index
        DCR     B
        JNZ     PAKLP
        RET

; ------------------------------------------------------------------
; GETCELLA -- input: A = index (0-7). Output: A = CELLA[index].
; Walks HL forward from CELLA by INX, one step at a time, rather than
; computing an address directly -- avoids needing B/C as an address
; scratch pair that a caller might be relying on elsewhere.
; Preserves B/C via push/pop (caller's BC is untouched on return).
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
; SETCELLB -- input: A = index (0-7), C = value (0 or 1).
; Stores C into CELLB[index]. Same INX-walk approach as GETCELLA, same
; B/C preservation via push/pop.
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
; WRAP8 -- input: A (any value from -2 to 9, which is all this program
; ever produces). Output: A wrapped into 0..7. Only ever needs at most
; one add-8 or one subtract-8 given that input range.
; Clobbers: A only.
; ------------------------------------------------------------------
WRAP8:  CPI     0
        JP      W8A
        ADI     8
W8A:    CPI     8
        JM      W8DONE
        SUI     8
W8DONE: RET

; ------------------------------------------------------------------
; NEIGHSUM -- input: A = i (0-7). Output: A = sum of CELLA at ring
; positions (i-2, i-1, i+1, i+2 mod 8) -- the four Y cells in Millen's
; YYXYY neighborhood. Uses memory (NSI) to hold the index rather than
; a register, and C as a running total -- safe because GETCELLA always
; preserves the caller's BC pair via push/pop, so C survives across
; each GETCELLA call intact. WRAP8 touches only A, so it can't disturb
; C either.
; ------------------------------------------------------------------
NEIGHSUM:
        STA     NSI
        MVI     C,0

        LDA     NSI
        SUI     2
        CALL    WRAP8
        CALL    GETCELLA
        ADD     C
        MOV     C,A

        LDA     NSI
        SUI     1
        CALL    WRAP8
        CALL    GETCELLA
        ADD     C
        MOV     C,A

        LDA     NSI
        ADI     1
        CALL    WRAP8
        CALL    GETCELLA
        ADD     C
        MOV     C,A

        LDA     NSI
        ADI     2
        CALL    WRAP8
        CALL    GETCELLA
        ADD     C
        MOV     C,A

        MOV     A,C
        RET

; ------------------------------------------------------------------
; STEP -- compute CELLB[i] from CELLA using Millen's rule for each of
; the 8 ring positions:
;   result = alive  if dead  and neighbor-sum is 2 or 3  (birth)
;   result = alive  if alive and neighbor-sum is 2 or 4   (survival)
;   result = dead   otherwise
; Loop index (SI) and the computed neighbor sum (SUM) are both kept in
; memory rather than registers, so nothing here depends on a register
; surviving across any of the CALLs below.
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

        ; currently dead
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
        CPI     8
        JNZ     STEPLP
        RET

; ------------------------------------------------------------------
; COPYBTOA -- CELLA[0..7] := CELLB[0..7]
; ------------------------------------------------------------------
COPYBTOA:
        LXI     H,CELLB
        LXI     D,CELLA
        MVI     B,8
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
        MVI     B,8
CDLP:   MOV     A,M
        ORA     A
        RNZ                     ; found a live cell -- return with Z clear
        INX     H
        DCR     B
        JNZ     CDLP
        XRA     A               ; force Z flag set (A=0)
        RET

; ------------------------------------------------------------------
; CHECKFULL -- Z flag set on return if CELLB is all one
; ------------------------------------------------------------------
CHECKFULL:
        LXI     H,CELLB
        MVI     B,8
CFLP:   MOV     A,M
        CPI     1
        RNZ                     ; found a dead cell -- return with Z clear
        INX     H
        DCR     B
        JNZ     CFLP
        XRA     A               ; force Z flag set
        RET

; ------------------------------------------------------------------
; DELAY -- triple-nested delay loop (DELAY3 * DELAY2 * DELAY1 total
; inner iterations), tune all three constants on real hardware. Three
; tiers instead of two gives a much wider tunable range without
; needing anything bigger than 8-bit counters.
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

; ------------------------------------------------------------------
; Data
; ------------------------------------------------------------------
SEED:       DB      00011011B   ; = 27 decimal. Settles (like every possible
                                 ; seed does, in ~2 gens -- an 8-cell ring is
                                 ; just too small for a longer transient) into
                                 ; a 5-generation cycle instead of the default
                                 ; original seed's boring 2-generation one --
                                 ; found by simulating all 256 possible seeds.
                                 ; Change freely; see IMSAI/README.md for the
                                 ; full cycle-length distribution across seeds.
SEEDCUR:    DB      0
NSI:        DB      0           ; NEIGHSUM's index scratch
SI:         DB      0           ; STEP's loop index
SUM:        DB      0           ; STEP's computed neighbor sum
CELLA:      DS      8
CELLB:      DS      8

        END     START
