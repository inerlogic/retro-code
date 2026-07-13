program Lif84Col;

const
  ARRAY_SIZE = 84;
  START_IDX  = 2;
  END_IDX    = 81;

type
  { Fixed for TP3 compiler: Bounded string sizes prevent Error 8 }
  TString    = string[20]; 
  TCellArray = array[0..ARRAY_SIZE] of Integer;
  THashHist  = array[0..7] of Integer;
  
 var
  CellA, CellB: TCellArray;
  HashHist: THashHist;
  RandSeed: Integer;
  X, I, ActiveCount, YSum, LoopFlag: Integer;
  Checksum, AliveSum, NewColor: Integer;
    Ch: Char;
  
procedure AnsiCmd(Cmd: TString);
begin
  Write(Chr(27), '[', Cmd);
end;

{ Added the missing ClearScreen routine }
procedure ClearScreen;
begin
  ClrScr;
end;

procedure SetColor(ColorCode: Integer);
var
  S: string[4]; { Bounded string size fixes Error 8 }
begin
  Str(ColorCode, S);
  AnsiCmd(S + 'm');
end;

{ Pure Z80 bitwise implementation of your original 16-bit C LFSR }
function GetRnd: Integer;
begin
  if (RandSeed and 1) <> 0 then
    RandSeed := (RandSeed shr 1) xor $A1A1
  else
    RandSeed := RandSeed shr 1;
  GetRnd := RandSeed and 1;
end;

procedure Initialize;
begin
  ClrScr;
  RandSeed := 1234;
  Randomize; { Initializes TP3 random numbers floating point generator }
  
  { Seed cell_a with random cells and colors }
  for X := START_IDX to END_IDX do
  begin
    if GetRnd = 1 then
      CellA[X] := 41 + Trunc(Random * 7) { TP3 compatible: Random float mapped to 0..6 }
    else
      CellA[X] := 0;
  end;
  
  for I := 0 to 7 do HashHist[I] := 0;
  
  Write('Press ANY KEY to start the Color Screensaver...');
  repeat until KeyPressed;
  Read(Kbd, Ch);
  ClrScr;
end;

begin
  Initialize;
  
  while True do
  begin
    if KeyPressed then
    begin
      Read(Kbd, Ch);
      AnsiCmd('0m');
      Exit;
    end;

    ActiveCount := 0;
    
    for X := START_IDX to END_IDX do
    begin
      if CellA[X] > 0 then
      begin
        SetColor(CellA[X]);
        Write(' '); 
        ActiveCount := ActiveCount + 1;
      end
      else
      begin
        AnsiCmd('0m');
        Write(' '); 
      end;
    end;
    AnsiCmd('0m');
    WriteLn;
    
    if (ActiveCount = 0) or (ActiveCount = 80) then
    begin
      for X := START_IDX to END_IDX do
      begin
        if GetRnd = 1 then CellB[X] := 41 + Trunc(Random * 7) else CellB[X] := 0;
      end;
    end;
    
    { Map radius-2 boundary wrapping rows into the margins exactly like your C code }
    CellA[0]  := CellA[80];
    CellA[1]  := CellA[81];
    CellA[82] := CellA[2];
    CellA[83] := CellA[3];

    for X := START_IDX to END_IDX do
    begin
      YSum := 0;
      if CellA[X-2] > 0 then YSum := YSum + 1;
      if CellA[X-1] > 0 then YSum := YSum + 1;
      if CellA[X+1] > 0 then YSum := YSum + 1;
      if CellA[X+2] > 0 then YSum := YSum + 1;

      AliveSum := 0;
      if CellA[X-2] > 0 then AliveSum := AliveSum + CellA[X-2];
      if CellA[X-1] > 0 then AliveSum := AliveSum + CellA[X-1];
      if CellA[X+1] > 0 then AliveSum := AliveSum + CellA[X+1];
      if CellA[X+2] > 0 then AliveSum := AliveSum + CellA[X+2];
      if CellA[X]   > 0 then AliveSum := AliveSum + CellA[X];

      { Flipped logic to exactly mirror your C ruleset }
      if (CellA[X] = 0) and ((YSum = 2) or (YSum = 3)) then
      begin
        NewColor := AliveSum div YSum;
        if Random < 0.05 then CellB[X] := 41 + Trunc(Random * 7) else CellB[X] := NewColor;
      end
      else if (CellA[X] > 0) and ((YSum = 2) or (YSum = 4)) then
      begin
        NewColor := AliveSum div (YSum + 1);
        if Random < 0.05 then CellB[X] := 41 + Trunc(Random * 7) else CellB[X] := NewColor;
      end
      else
      begin
        CellB[X] := 0;
      end;
    end;

    Checksum := 0;
    for X := START_IDX to END_IDX do
    begin
      Checksum := (Checksum * 3) + CellB[X];
      CellA[X] := CellB[X];
    end;

    LoopFlag := 0;
    for I := 0 to 7 do
    begin
      if Checksum = HashHist[I] then LoopFlag := 1;
    end;

    for I := 7 downto 1 do HashHist[I] := HashHist[I-1];
    HashHist[0] := Checksum; 

    if LoopFlag = 1 then
    begin
      for X := START_IDX to END_IDX do
      begin
        if GetRnd = 1 then CellA[X] := 41 + Trunc(Random * 7) else CellA[X] := 0;
      end;
      for I := 0 to 7 do HashHist[I] := 0;
    end;

    Delay(30);
  end;
end.
