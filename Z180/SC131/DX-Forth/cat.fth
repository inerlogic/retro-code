\ ============================================================
\  CAT.FTH, paged file viewer for DX-Forth
\  Usage:  INCLUDE CAT.FTH
\          CAT DXFORTH.GLO
\  Any key continues; 'q' or Esc quits early.
\ ============================================================

DECIMAL

0 VALUE CFID
0 VALUE CLINES
CREATE CBUF 128 ALLOT

: CAT ( "filename" -- )
  BL WORD COUNT R/O OPEN-FILE THROW TO CFID
  0 TO CLINES
  BEGIN
    CBUF 128 CFID READ-LINE THROW
  WHILE
    CBUF SWAP TYPE CR
    CLINES 1+ TO CLINES
    CLINES 20 MOD 0= IF
      ." -- more (any key, q to quit) --"
      KEY DUP 27 = SWAP [CHAR] q = OR IF
        CFID CLOSE-FILE THROW EXIT
      THEN
      CR
    THEN
  REPEAT
  DROP
  CFID CLOSE-FILE THROW ;
