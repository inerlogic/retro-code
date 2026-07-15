program HexLife;

{ HEXLIFE.PAS -- 2D Conway's Life, toroidal (wraps all 4 sides), displayed
  as a fixed-position grid of hex digits inside a static bordered "playing
  field" instead of scrolling text.

  Each hex digit packs 4 consecutive cells (same MSB-first packing scheme
  used for AUTOLIF.BAS's hex-encoding change and the IMSAI Z80/8080
  assembly programs elsewhere in this repo).

  Classic 8-neighbor Conway's Life rule (same as AUTOLIF.BAS/LIFE.BAS),
  not Millen's 1D 4-neighbor rule -- what's borrowed from the 1D life
  programs here is the TECHNIQUE, not the rule: a rolling checksum
  history (same "checksum := checksum*3 + cell" approach as MILLIF2.C)
  detects when the grid has settled into a repeating cycle, and silently
  reseeds with a fresh random grid when it has -- no visible message,
  unlike MILLIF2.C's announced version. This exists specifically because
  AUTOLIF.BAS was watched settling permanently at generation 788 (seed
  23432) and just sitting there forever afterward -- this version won't
  do that.

  Grid deliberately sized smaller than the full terminal (40 hex columns
  = 160 cells wide, 18 rows) rather than filling all 80x24 -- two 320x24
  grids would have been 15360 bytes, a meaningful fraction of a modest
  CP/M TPA; at 160x18 it's 5760 bytes, a much more comfortable margin.
  The border and "Seed:/Generation:/Checksum:" header are static chrome
  around this smaller field -- drawn once at startup/reseed, never
  redrawn during normal per-generation steps, and can be turned off
  entirely via the SHOW_CHROME constant below if you'd rather have the
  borderless look (modern/virtual terminals don't have the burn-in
  concern).

   Compiled and run on the SC131 runnin ROMWBW. 
   Uses this system's built-in GotoXY/ClrScr (confirmed already in use by 
   TETRIS.PAS/DUNGEON.PAS/MILLIFE.PAS), not a hand-rolled ANSI wrapper.}

const
  SHOW_CHROME = True;        { set False + recompile for the borderless look }

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

{ Wrap V into 1..N (V only ever ranges N-1..N+2 given how this is called,
  so at most one adjustment in either direction is ever needed -- same
  reasoning already verified for the IMSAI assembly's WRAP8/WRAP16. }
function WrapCoord(V, N: Integer): Integer;
begin
  if V < 1 then WrapCoord := V + N
  else if V > N then WrapCoord := V - N
  else WrapCoord := V;
end;

function NeighborSum(X, Y: Integer): Integer;
var
  DX, DY, NX, NY, Total: Integer;
begin
  Total := 0;
  for DX := -1 to 1 do
    for DY := -1 to 1 do
      if not ((DX = 0) and (DY = 0)) then
      begin
        NX := WrapCoord(X + DX, GRIDW);
        NY := WrapCoord(Y + DY, GRIDH);
        Total := Total + CellA[NX, NY];
      end;
  NeighborSum := Total;
end;

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
begin
  CellCounter := 0;
  for X := 1 to GRIDW do
    for Y := 1 to GRIDH do
    begin
      S := NeighborSum(X, Y);
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
        logic. See TP3-life/README.md for the full debugging story. }
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

procedure DrawGrid;
var
  X, Y, G, Bit, Nibble, CellX, ScreenX, ScreenY: Integer;
  RowStr: string[40];
begin
  for Y := 1 to GRIDH do
  begin
    if SHOW_CHROME then ScreenY := BOXTOP + Y else ScreenY := BOXTOP + Y - 1;
    if SHOW_CHROME then ScreenX := BOXLEFT + 1 else ScreenX := BOXLEFT;
    RowStr := '';
    for G := 0 to HEXCOLS - 1 do
    begin
      Nibble := 0;
      for Bit := 0 to 3 do
      begin
        CellX := (G * 4) + Bit + 1;
        Nibble := (Nibble * 2) + CellA[CellX, Y];
      end;
      RowStr := RowStr + Copy(HexDigits, Nibble + 1, 1);
    end;
    GotoXY(ScreenX, ScreenY);
    Write(RowStr);
  end;
end;

begin
  HexDigits := '0123456789ABCDEF';

  Write('TYPE A RANDOM NUMBER (1-32767) TO SEED GAME: ');
  ReadLn(SeedVal);
  RandSeed := SeedVal;

  ClrScr;
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
  Write('Stopped at generation ', Gen);
  WriteLn;
end.
