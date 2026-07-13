{$C-}
program FastIntPiGrid;
{ High-speed 16-bit Integer Bounded Spigot for SC131/Z180 }
{ Uses strictly native 16-bit integers for blazing speed  }

const
  COLUMNS = 80;
  ARRAY_SIZE = 140; { Fits within 16-bit integer math limits }

var
  StartBlock: Integer;
  Ch: Char;

procedure Render80Blocks(start: Integer);
var
  j, k: Integer;
  carry, sum: Integer; { Strictly native 16-bit integers }
  arr: array[1..ARRAY_SIZE] of Integer;
  val: Integer;
begin
  { Initialize workspace for this 80-digit segment }
  for j := 1 to ARRAY_SIZE do
    arr[j] := 2;

  { Localized base-16 spigot transformation }
  for j := 1 to (start + COLUMNS) do
  begin
    carry := 0;
    for k := ARRAY_SIZE downto 1 do
    begin
      { Safe within 16-bit bounds: max possible value fits inside Integer }
      sum := arr[k] * 16 + carry;
      carry := sum div (2 * k - 1);
      arr[k] := sum mod (2 * k - 1);
    end;
    
    { If this digit belongs in our active row window, print its color code }
    if j > start then
    begin
      val := carry mod 16;
      if val < 0 then val := val + 16; { Keep it strictly positive }
      
      case val of
        0: Write(#27, '[40m ');   1: Write(#27, '[44m ');
        2: Write(#27, '[1;44m '); 3: Write(#27, '[1;46m ');
        4: Write(#27, '[42m ');   5: Write(#27, '[1;42m ');
        6: Write(#27, '[43m ');   7: Write(#27, '[1;43m ');
        8: Write(#27, '[41m ');   9: Write(#27, '[1;41m ');
        10: Write(#27, '[45m ');  11: Write(#27, '[1;45m ');
        12: Write(#27, '[46m ');  13: Write(#27, '[47m ');
        14: Write(#27, '[1;40m '); 15: Write(#27, '[1;47m ');
      end;
    end;
  end;
end;

begin
  ClrScr;
  Write(#27, '[?25l'); { Hide flashing text cursor }
  
  StartBlock := 0;
  
  while True do
  begin
    { Intercept ESC key to stop cleanly }
    if KeyPressed then
    begin
      Read(Kbd, Ch);
      if Ch = #27 then 
      begin
        Write(#27, '[0m', #27, '[?25h');
        ClrScr;
        WriteLn('Stream stopped by user.');
        Exit;
      end;
    end;

    { Draw an entire 80-column line instantly }
    Render80Blocks(StartBlock);
    
    { Prevent screen edge bleeding and drop down a line }
    Write(#27, '[0m');
    WriteLn;
    
    { Advance window directly to the next row }
    StartBlock := StartBlock + COLUMNS;
  end;
end.
