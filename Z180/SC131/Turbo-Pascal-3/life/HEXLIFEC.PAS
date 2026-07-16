program HexLifeC;

{ HEXLIFEC.PAS -- color variant of HEXLIFE.PAS. Same toroidal 2D Conway's
  Life, same 160x18 grid, same seedable LFSR, same silent checksum-based
  reseed, same confirmed-working ESC fix (frequent KeyPressed checks
  inside Step's loop) -- the only thing that changes is DrawGrid: instead
  of printing a plain hex digit, it colors the digit's TEXT by its value
  (0 ascending), keeping the actual hex character visible rather than
  replacing it with a solid block like HEXPI.PAS/MILLIFE.PAS do.


  Each hex digit packs 4 consecutive cells (same MSB-first packing scheme
  used for AUTOLIF.BAS's hex-encoding change and the IMSAI Z80/8080
  assembly programs elsewhere in this repo).

  Classic 8-neighbor Conway's Life rule (same as AUTOLIF.BAS/LIFE.BAS),
  not Millen's 1D 4-neighbor rule -- what's borrowed from the 1D life
  programs here is the TECHNIQUE, not the rule: a rolling checksum
  history (same "checksum := checksum*3 + cell" approach as MILLIF2.C)
  detects when the grid has settled into a repeating cycle, and silently
  reseeds with a fresh random grid when it has -- no visible message,
  unlike MILLIF2.C's announced version.

  Grid deliberately sized smaller than the full terminal (40 hex columns
  = 160 cells wide, 18 rows) rather than filling all 80x24 -- two 320x24
  grids would have been 15360 bytes, a meaningful fraction of a modest
  CP/M TPA; at 160x18 it's 5760 bytes, a much more comfortable margin.
  The border and "Seed:/Generation:/Checksum:" header are static chrome
  around this smaller field -- drawn once at startup/reseed, never
  redrawn during normal per-generation steps, and can be turned off
  entirely via the SHOW_CHROME constant below if you'd rather have the
  borderless look (modern/virtual terminals don't have the burn-in
  concern a border was originally meant to help with anyway).}

const
  SHOW_CHROME = True;        { set False + recompile for the borderless look }
  HIDE_CURSOR = True;        { set False + recompile to see the cursor track
                               where the redraw currently is -- useful as a
                               visual indicator of the "wave," which is the
                               whole reason to leave this toggle-able rather
                               than picking one and committing }

  HEXCOLS  = 40;             { playing-field width in hex digits }
  GRIDW    = 160;            { HEXCOLS * 4 -- cell width }
  GRIDH    = 18;             { cell height }
  HISTLEN  = 8;              { checksum history length, matches MILLIF2.C }

  { Box is HEXCOLS+2 wide (border chars each side); centered in an
    80-column terminal: (80 - 42) div 2 = 19. Header line sits one row
    above the box. }
  BOXLEFT  = 19;
  BOXTOP   = 2;

  { Fixed column positions for the "Seed: NNNNNN  Generation: NNNNNN
    Checksum: NNNNNN" header line, computed by hand from field widths
    rather than as const expressions (this environment's const section
    doesn't reliably support arithmetic, going by earlier precedent in
    this same file). }
  SEEDCOL     = 25;   { BOXLEFT + 6 ("Seed: ") }
  GENLABELCOL = 33;   { SEEDCOL + 6 (seed num) + 2 (spaces) }
  GENNUMCOL   = 45;   { GENLABELCOL + 12 ("Generation: ") }
  CHKLABELCOL = 52;   { GENNUMCOL + 6 (gen num) + 1 (space) }
  CHKNUMCOL   = 62;   { CHKLABELCOL + 10 ("Checksum: ") }

type
  { Explicit string sizes required for TP3 }
  THexDigits = string[16];
  TNumStr = string[8];

  TGrid = array[1..GRIDW, 1..GRIDH] of Byte;

var
  CellA, CellB: TGrid;
  History: array[1..HISTLEN] of Integer;
  Gen: Integer;
  Ch: Char;
  KeepRunning: Boolean;
  HexDigits: THexDigits;
  RandSeed: Integer;
  SeedVal: Integer;
  LastChecksum: Integer;

{ Same LFSR as MILLIFE.PAS's already-hardware-confirmed GetRnd -- reused
  here instead of Pascal's built-in Random()/Randomize(), specifically
  because it's seedable with a real, user-typed, displayable number
  (matching AUTOLIF.BAS's seed-prompt convention), where Randomize just
  seeds from an internal clock with nothing to show or type back in. }
function GetRnd: Integer;
begin
  if (RandSeed and 1) <> 0 then
    RandSeed := (RandSeed shr 1) xor $A1A1
  else
    RandSeed := RandSeed shr 1;
  GetRnd := RandSeed and 1;
end;

{ GetRnd only ever returns a single bit, so build a 7-bit value (0-127)
  from 7 calls and threshold it to approximate the ~35% alive-density
  AUTOLIF.BAS uses: 45/128 = 35.2%, close enough. }
function GetRndPct: Boolean;
var
  I, V: Integer;
begin
  V := 0;
  for I := 1 to 7 do V := (V * 2) + GetRnd;
  GetRndPct := (V < 45);
end;

procedure SeedGrid;
var
  X, Y: Integer;
begin
  for X := 1 to GRIDW do
    for Y := 1 to GRIDH do
      if GetRndPct then CellA[X, Y] := 1
      else CellA[X, Y] := 0;
end;

procedure ClearHistory;
var
  I: Integer;
begin
  for I := 1 to HISTLEN do History[I] := 0;
end;

procedure Step;
var
  X, Y, S, CellCounter: Integer;
  XM, XP, YM, YP: Integer;
begin
  CellCounter := 0;
  for X := 1 to GRIDW do
  begin
    { X-wrap only depends on X, not Y -- hoisted out of the inner loop
      so it's computed once per column (GRIDW times total) instead of
      once per cell (GRIDW*GRIDH times) like the old NeighborSum did. }
    if X = 1 then XM := GRIDW else XM := X - 1;
    if X = GRIDW then XP := 1 else XP := X + 1;

    for Y := 1 to GRIDH do
    begin
      if Y = 1 then YM := GRIDH else YM := Y - 1;
      if Y = GRIDH then YP := 1 else YP := Y + 1;

      S := CellA[XM, YM] + CellA[XM, Y] + CellA[XM, YP]
         + CellA[X, YM]                 + CellA[X, YP]
         + CellA[XP, YM] + CellA[XP, Y] + CellA[XP, YP];

      if CellA[X, Y] = 1 then
      begin
        if (S = 2) or (S = 3) then CellB[X, Y] := 1
        else CellB[X, Y] := 0;
      end
      else
      begin
        if S = 3 then CellB[X, Y] := 1
        else CellB[X, Y] := 0;
      end;

      { Confirmed by direct hardware testing: checking KeyPressed only
        once per generation (~2 seconds of uninterrupted computation
        with zero I/O calls) reliably fails to catch ESC, even a single
        clean press with no spamming. Checking every 200 cells (~14
        times per generation) instead reliably works. Root mechanism
        not fully understood (possibly some UART/BDOS-level behavior on
        this specific machine that needs reasonably frequent polling to
        catch an incoming byte before it's lost) -- but this fix is
        confirmed via isolated test stubs, independent of any display
        logic. See Turbo-Pascal-3/life/README.md for the full debugging story. }
      CellCounter := CellCounter + 1;
      if CellCounter >= 200 then
      begin
        CellCounter := 0;
        if KeyPressed then
        begin
          Read(Kbd, Ch);
          if Ch = #27 then KeepRunning := False;
        end;
      end;
    end;
  end;
end;

function ComputeChecksum: Integer;
var
  X, Y: Integer;
  Sum: Integer;
begin
  Sum := 0;
  for X := 1 to GRIDW do
    for Y := 1 to GRIDH do
      Sum := (Sum * 3) + CellB[X, Y];   { natural 16-bit overflow is fine,
                                          same crude-but-workable hash as
                                          MILLIF2.C uses }
  ComputeChecksum := Sum;
end;

function LoopDetected(Checksum: Integer): Boolean;
var
  I: Integer;
  Found: Boolean;
begin
  Found := False;
  for I := 1 to HISTLEN do
    if Checksum = History[I] then Found := True;
  for I := HISTLEN downto 2 do
    History[I] := History[I - 1];
  History[1] := Checksum;
  LoopDetected := Found;
end;

procedure CopyBToA;
var
  X, Y: Integer;
begin
  for X := 1 to GRIDW do
    for Y := 1 to GRIDH do
      CellA[X, Y] := CellB[X, Y];
end;

{ Draws the static border + "Seed:/Generation:/Checksum:" labels (and
  the seed number itself, which -- unlike generation/checksum -- doesn't
  change during a run, so it's drawn here once rather than in the
  per-generation update). Called once at startup and once per reseed --
  never during normal per-generation steps. }
procedure DrawChrome;
var
  Y: Integer;
  Line: string[42];
  S: TNumStr;
begin
  if not SHOW_CHROME then Exit;

  GotoXY(BOXLEFT, BOXTOP - 1);
  Write('Seed: ');
  GotoXY(SEEDCOL, BOXTOP - 1);
  Str(SeedVal, S);
  while Length(S) < 6 do S := S + ' ';
  Write(S);

  GotoXY(GENLABELCOL, BOXTOP - 1);
  Write('Generation: ');

  GotoXY(CHKLABELCOL, BOXTOP - 1);
  Write('Checksum: ');

  Line := '+';
  for Y := 1 to HEXCOLS do Line := Line + '-';
  Line := Line + '+';
  GotoXY(BOXLEFT, BOXTOP);
  Write(Line);

  for Y := 1 to GRIDH do
  begin
    GotoXY(BOXLEFT, BOXTOP + Y);
    Write('|');
    GotoXY(BOXLEFT + HEXCOLS + 1, BOXTOP + Y);
    Write('|');
  end;

  GotoXY(BOXLEFT, BOXTOP + GRIDH + 1);
  Write(Line);
end;

{ Updates only the Generation and Checksum NUMBERS, not their label text
  (which DrawChrome already drew) -- padded to a fixed width so a
  shrinking digit count doesn't leave stale characters behind. }
procedure DrawHeaderNumbers;
var
  S: TNumStr;
begin
  if not SHOW_CHROME then Exit;

  Str(Gen, S);
  while Length(S) < 6 do S := S + ' ';
  GotoXY(GENNUMCOL, BOXTOP - 1);
  Write(S);

  Str(LastChecksum, S);
  while Length(S) < 6 do S := S + ' ';
  GotoXY(CHKNUMCOL, BOXTOP - 1);
  Write(S);
end;

{ Heat-map gradient, ordered by perceived brightness/heat rather than
  grouped by color family (unlike HEXPI.PAS's original table, which this
  no longer directly mirrors) -- 0 = dark gray (deliberately, not true
  black, so it stays visible) through F = full bright white. }
procedure DrawGrid;
var
  X, Y, G, Bit, Nibble, Bucket, CellX, ScreenX, ScreenY, LastBucket: Integer;
  DigitChar: string[1];
begin
  LastBucket := -1;   { sentinel -- guaranteed to differ from any real
                         0-7 bucket, so the very first cell always emits
                         its color code rather than assuming a color is
                         already active }
  for Y := 1 to GRIDH do
  begin
    if SHOW_CHROME then ScreenY := BOXTOP + Y else ScreenY := BOXTOP + Y - 1;
    if SHOW_CHROME then ScreenX := BOXLEFT + 1 else ScreenX := BOXLEFT;
    GotoXY(ScreenX, ScreenY);
    for G := 0 to HEXCOLS - 1 do
    begin
      Nibble := 0;
      for Bit := 0 to 3 do
      begin
        CellX := (G * 4) + Bit + 1;
        Nibble := (Nibble * 2) + CellA[CellX, Y];
      end;
      DigitChar := Copy(HexDigits, Nibble + 1, 1);

      { Collapsed from 16 colors to 8. This also directly cuts down the
        number of transmitted color codes under change-detection below:
        two adjacent cells that previously needed different bold/plain
        codes (e.g. nibble 4 and 5) now share a bucket and emit nothing
        extra between them -- a real fix for the visible "wave," not
        just a simplification. }
      Bucket := Nibble div 2;   { 0,1->0  2,3->1  4,5->2  6,7->3
                                   8,9->4  10,11->5  12,13->6  14,15->7 }

      { Only emit a color code when the color actually CHANGES from the
        previous cell -- skips the redundant escape sequences when
        neighboring cells share a bucket, which is common in Life grids.
        No separate reset (\x1b[0m) needed anymore: ALL 8 colors are now
        consistently bold, so every color-change code re-asserts "bold
        on" as part of itself -- there's never a moment where bold needs
        CLEARING, only reasserting, and reasserting doesn't need a reset
        first. The earlier reset was only necessary because the palette
        used to mix bold and plain codes; making the palette uniformly
        bold removes the inconsistency the reset existed to fix, and
        roughly halves the escape sequence length for every transition. }
      if Bucket <> LastBucket then
      begin
        case Bucket of
          0: Write(#27, '[1;30m', DigitChar); { dark gray -- coldest }
          1: Write(#27, '[1;34m', DigitChar); { blue }
          2: Write(#27, '[1;36m', DigitChar); { cyan }
          3: Write(#27, '[1;32m', DigitChar); { green }
          4: Write(#27, '[1;33m', DigitChar); { yellow }
          5: Write(#27, '[1;31m', DigitChar); { red }
          6: Write(#27, '[1;35m', DigitChar); { magenta }
          7: Write(#27, '[1;37m', DigitChar); { bright white -- hottest }
        end;
        LastBucket := Bucket;
      end
      else
      begin
        Write(DigitChar);
      end;
    end;
  end;
  Write(#27, '[0m');   { reset color so DrawHeaderNumbers/DrawChrome
                          don't inherit the last cell's color next time }
end;

begin
  HexDigits := '0123456789ABCDEF';

  Write('TYPE A RANDOM NUMBER (1-32767) TO SEED GAME: ');
  ReadLn(SeedVal);
  RandSeed := SeedVal;

  ClrScr;
  if HIDE_CURSOR then Write(#27, '[?25l');
  SeedGrid;
  ClearHistory;
  Gen := 0;
  LastChecksum := 0;
  KeepRunning := True;
  DrawChrome;

  while KeepRunning do
  begin
    DrawHeaderNumbers;
    DrawGrid;

    if KeepRunning then
    begin
      Step;
      LastChecksum := ComputeChecksum;
      if LoopDetected(LastChecksum) then
      begin
        { Automatically alter the seed to prevent the same loop }
        { Uses a shift-and-add logic optimized for Turbo Pascal 3 }
        SeedVal := ((SeedVal shl 1) or (SeedVal shr 14)) + 1;
        RandSeed := SeedVal;

        { Silent reseed -- no message }
        ClrScr;
        SeedGrid;
        ClearHistory;
        Gen := 0;
        LastChecksum := 0;
        DrawChrome;
      end
      else
      begin
        CopyBToA;
        Gen := Gen + 1;
      end;
    end;
  end;

  ClrScr;
  Write(#27, '[?25h');   { always restore the cursor on exit, regardless of
                            HIDE_CURSOR -- harmless if it was never hidden,
                            essential if it was }
  Write('Stopped at generation ', Gen);
  WriteLn;
end.

