{$C-}
program HexPiColor;
{ Endless Thermal-Gradient Hexadecimal Pi Matrix for CP/M & Z180/SC131 }
{ Memory Footprint: O(1) Constant. Absolute zero RAM growth.          }

const
  LOOKAHEAD = 10;

var
  CurrentDigit: Integer;
  ResultChar: Char;
  Ch: Char;

{ Fast modular exponentiation: (16^p) mod b using Real numbers }
{ This avoids 16-bit integer overflow issues in Turbo Pascal 3 }
function ExplMod(p, b: Integer): Integer;
var
  r, base: Real;
begin
  r := 1.0;
  base := 16.0;
  while p > 0 do
  begin
    if (p mod 2) = 1 then
    begin
      r := r * base;
      r := r - (Int(r / b) * b); { Emulated floating point Modulo }
    end;
    base := base * base;
    base := base - (Int(base / b) * b);  { Emulated floating point Modulo }
    p := p div 2;
  end;
  ExplMod := Trunc(r);
end;

{ Evaluates individual fraction series component }
function SeriesSum(n, j: Integer): Real;
var
  k: Integer;
  s, term: Real;
begin
  s := 0.0;
  
  { Left side of target fractional position }
  for k := 0 to n do
  begin
    term := ExplMod(n - k, 8 * k + j) / (8 * k + j);
    s := s + (term - Int(term)); { Strip integer portion }
  end;
  
  { Right side fraction approximation }
  for k := n + 1 to n + LOOKAHEAD do
  begin
    term := 1.0; 
    s := s + term; 
  end;
  
  SeriesSum := s - Int(s);
end;

{ Extracts a single Base-16 character at index position 'n' }
function GetHexDigit(n: Integer): Char;
var
  pidat: Real;
  digit: Integer;
  { Using an array of Char instead of 'string' to maintain full }
  { compatibility with standard Turbo Pascal 3 type matching }
  hexArray: array[0..15] of Char;
begin
  hexArray[0]:='0'; hexArray[1]:='1'; hexArray[2]:='2'; hexArray[3]:='3';
  hexArray[4]:='4'; hexArray[5]:='5'; hexArray[6]:='6'; hexArray[7]:='7';
  hexArray[8]:='8'; hexArray[9]:='9'; hexArray[10]:='A'; hexArray[11]:='B';
  hexArray[12]:='C'; hexArray[13]:='D'; hexArray[14]:='E'; hexArray[15]:='F';

  { Core BBP formula math }
  pidat := 4.0 * SeriesSum(n, 1) - 2.0 * SeriesSum(n, 4) - 
           SeriesSum(n, 5) - SeriesSum(n, 6);
           
  pidat := pidat - Int(pidat);
  if pidat < 0 then pidat := pidat + 1.0;
  
  digit := Trunc(pidat * 16.0);
  
  { Safety bounds checking for index protection }
  if (digit < 0) then digit := 0;
  if (digit > 15) then digit := 15;
  
  GetHexDigit := hexArray[digit];
end;

begin
  ClrScr;
  { Turn off the blinking text cursor using raw ANSI sequence }
  Write(#27, '[?25l'); 
  
  CurrentDigit := 0;
  
  while True do
  begin
    { Asynchronous keypress check to exit cleanly without freeze }
    if KeyPressed then
    begin
      Read(Kbd, Ch);
      if Ch = #27 then 
      begin
        Write(#27, '[0m');    { Reset terminal styles }
        Write(#27, '[?25h');   { Re-enable standard flashing text cursor }
        ClrScr;
        WriteLn('Visual stream stopped.');
        Exit;
      end;
    end;

    { Calculate the target digit value }
    ResultChar := GetHexDigit(CurrentDigit);
    
    { Map Hex Digit (0-F) to a Hot/Cold Thermal Gradient }
    case ResultChar of
      { COLD ZONE: Blacks, Blues, Cyans }
      '0': Write(#27, '[40m ');    { Absolute Zero: Black }
      '1': Write(#27, '[44m ');    { Deep Freeze: Dark Blue }
      '2': Write(#27, '[1;44m ');  { Chilled: Bright Blue }
      '3': Write(#27, '[1;46m ');  { Cool: Bright Cyan }
      
      { TEMPERATE ZONE: Greens }
      '4': Write(#27, '[42m ');    { Mild: Dark Green }
      '5': Write(#27, '[1;42m ');  { Warm Green: Bright Green }
      
      { WARM ZONE: Yellows, Oranges }
      '6': Write(#27, '[43m ');    { Lukewarm: Brown/Dark Yellow }
      '7': Write(#27, '[1;43m ');  { Warm: Bright Yellow }
      
      { HOT ZONE: Reds, Pinks }
      '8': Write(#27, '[41m ');    { Heating Up: Dark Red }
      '9': Write(#27, '[1;41m ');  { Hot: Bright Red }
      'A': Write(#27, '[45m ');    { Very Hot: Dark Magenta }
      'B': Write(#27, '[1;45m ');  { Scorching: Bright Magenta }
      
      { WHITE HOT: Grays to Pure White }
      'C': Write(#27, '[46m ');    { Incandescent: Dark Cyan }
      'D': Write(#27, '[47m ');    { Bright Gray }
      'E': Write(#27, '[1;40m ');  { High Intensity Gray }
      'F': Write(#27, '[1;47m ');  { Fusion: Pure Bright White }
    end;
    
    { Enforce strict 80-column boundaries with no spaces }
    if (CurrentDigit mod 80 = 79) then 
    begin
      Write(#27, '[0m'); { Temporarily reset color to prevent screen-edge bleeding }
      WriteLn;
    end;
    
    CurrentDigit := CurrentDigit + 1;
  end;
end.
