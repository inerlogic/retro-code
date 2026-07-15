program HexLife;
{ HEXLIFE.PAS -- 2D Conway's Life, toroidal (wraps all 4 sides) 

  Same toroidal 2D Conway's Life, same 160x18 grid, same seedable LFSR, 
  same silent checksum-based reseed, same confirmed-working ESC fix 
  (frequent KeyPressed checks inside Step's loop) 

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
  concern a screensaver was originally meant to help with anyway).}


const 
  SHOW_CHROME = True; { set False + recompile for the borderless look }
  HIDE_CURSOR = True; { Added to fix the "begin expected" compilation error }
  HEXCOLS = 40;       { playing-field width in hex digits }
  GRIDW = 160;        { HEXCOLS * 4 -- cell width }
  GRIDH = 18;         { cell height }
  HISTLEN = 8;        { checksum history length, matches MILLIF2.C }
  BOXLEFT = 19;
  BOXTOP = 2;
  SEEDCOL = 25;
  GENLABELCOL = 33;
  GENNUMCOL = 45;
  CHKLABELCOL = 52;
  CHKNUMCOL = 62;

type
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

function GetRnd: Integer;
begin
  if (RandSeed and 1) <> 0 then
    RandSeed := (RandSeed shr 1) xor $A1A1
  else
    RandSeed := RandSeed shr 1;
  GetRnd := RandSeed and 1;
end;

function GetRndPct: Boolean;
var I, V: Integer;
begin
  V := 0;
  for I := 1 to 7 do V := (V * 2) + GetRnd;
  GetRndPct := (V < 45);
end;

procedure SeedGrid;
var X, Y: Integer;
begin
  for X := 1 to GRIDW do
    for Y := 1 to GRIDH do
      if GetRndPct then CellA[X, Y] := 1 else CellA[X, Y] := 0;
end;

procedure ClearHistory;
var I: Integer;
begin
  for I := 1 to HISTLEN do History[I] := 0;
end;

procedure Step;
var X, Y, S, CellCounter: Integer;
    XM, XP, YM, YP: Integer;
begin
  CellCounter := 0;
  for X := 1 to GRIDW do
  begin
    if X = 1 then XM := GRIDW else XM := X - 1;
    if X = GRIDW then XP := 1 else XP := X + 1;
    for Y := 1 to GRIDH do
    begin
      if Y = 1 then YM := GRIDH else YM := Y - 1;
      if Y = GRIDH then YP := 1 else YP := Y + 1;
      
      S := CellA[XM, YM] + CellA[XM, Y] + CellA[XM, YP] +
           CellA[X, YM]  + CellA[X, YP] +
           CellA[XP, YM] + CellA[XP, Y] + CellA[XP, YP];
           
      if CellA[X, Y] = 1 then
      begin
        if (S = 2) or (S = 3) then CellB[X, Y] := 1 else CellB[X, Y] := 0;
      end
      else
      begin
        if S = 3 then CellB[X, Y] := 1 else CellB[X, Y] := 0;
      end;

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
var X, Y: Integer;
    Sum: Integer;
begin
  Sum := 0;
  for X := 1 to GRIDW do
    for Y := 1 to GRIDH do
      Sum := (Sum * 3) + CellB[X, Y];
  ComputeChecksum := Sum;
end;

function LoopDetected(Checksum: Integer): Boolean;
var I: Integer;
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
var X, Y: Integer;
begin
  for X := 1 to GRIDW do
    for Y := 1 to GRIDH do
      CellA[X, Y] := CellB[X, Y];
end;

procedure DrawChrome;
var Y: Integer;
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

procedure DrawHeaderNumbers;
var S: TNumStr;
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
var X, Y, G, Bit, Nibble, CellX, ScreenX, ScreenY: Integer;
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
        SeedVal := ((SeedVal shl 1) or (SeedVal shr 14)) + 1;
        RandSeed := SeedVal;
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
  Write(#27, '[?25h');
  Write('Stopped at generation ', Gen);
  WriteLn;
end.
