{$Q-,R-}
{ PRIME386.PAS -- Lucas-Lehmer CPU self-test for the Pocket 386 (no FPU) }
{ Stage 1 of 2: CPU-test core only. See README.md for design/verification notes. }

program Prime386;

const
  MaxP   = 61;  { largest exponent supported }
  NLIMB  = 4;  { words per bignum: ceil(61/16) }
  NLIMB2 = 2 * NLIMB;  { width for squaring results }

  NumTestExponents = 5;
  TestExponents: array[1..NumTestExponents] of Byte = (13, 17, 19, 31, 61);

type
  TBigNum  = array[0..NLIMB-1]  of Word;
  TBigNum2 = array[0..NLIMB2-1] of Word;

{ --- small helpers --- }

procedure ZeroBig(var b: TBigNum);
var i: Integer;
begin
  for i := 0 to NLIMB-1 do b[i] := 0;
end;

procedure ZeroBig2(var b: TBigNum2);
var i: Integer;
begin
  for i := 0 to NLIMB2-1 do b[i] := 0;
end;

{ Schoolbook squaring, NLIMB words -> NLIMB2 words. }
{ a[i]*a[j] can exceed signed 32-bit range but stays < 2^32; shr/and }
{ still extract the correct bits (Pascal shr is logical, not arithmetic). }
procedure SquareWords(const a: TBigNum; var result: TBigNum2);
var
  i, j, k: Integer;
  prod: LongInt;
  carry: LongInt;
begin
  ZeroBig2(result);
  for i := 0 to NLIMB-1 do
  begin
    carry := 0;
    for j := 0 to NLIMB-1 do
    begin
      prod := LongInt(a[i]) * LongInt(a[j]) + LongInt(result[i+j]) + carry;
      result[i+j] := Word(prod and $FFFF);
      carry := prod shr 16;
    end;
    k := i + NLIMB;
    while carry <> 0 do
    begin
      prod := LongInt(result[k]) + (carry and $FFFF);
      result[k] := Word(prod and $FFFF);
      carry := (carry shr 16) + (prod shr 16);
      Inc(k);
    end;
  end;
end;

{ Add two bignums, truncated to NLIMB words; returns carry-out. }
function AddBigTrunc(const a, b: TBigNum; var result: TBigNum): Word;
var
  i: Integer;
  s: LongInt;
  carry: LongInt;
begin
  carry := 0;
  for i := 0 to NLIMB-1 do
  begin
    s := LongInt(a[i]) + LongInt(b[i]) + carry;
    result[i] := Word(s and $FFFF);
    carry := s shr 16;
  end;
  AddBigTrunc := Word(carry);
end;

{ Unsigned compare: -1, 0, or 1. }
function CompareBig(const a, b: TBigNum): Integer;
var i: Integer;
begin
  CompareBig := 0;
  for i := NLIMB-1 downto 0 do
  begin
    if a[i] > b[i] then begin CompareBig := 1; Exit; end;
    if a[i] < b[i] then begin CompareBig := -1; Exit; end;
  end;
end;

{ Mersenne mod-reduction: shift-and-add trick, x mod (2^p - 1). }
{ Converges in at most ~2 iterations (verified); safety cap at 8. }
procedure ModMersenneWords(const x: TBigNum2; p: Byte; var resultOut: TBigNum);
var
  fullWords, remBits: Byte;
  cur: TBigNum2;
  low, high, summed: TBigNum;
  allOnes: TBigNum;
  i, iterCount: Integer;
  carryBits, val: Word;
  carryOut: Word;
  stillTooBig: Boolean;
begin
  fullWords := p div 16;
  remBits   := p mod 16;

  cur := x;
  iterCount := 0;

  repeat
{ does cur already fit in p bits? }
    stillTooBig := False;
    for i := NLIMB2-1 downto fullWords do
    begin
      if i = fullWords then
      begin
        if remBits = 0 then
        begin
          if cur[i] <> 0 then stillTooBig := True;
        end
        else if (cur[i] shr remBits) <> 0 then stillTooBig := True;
      end
      else if cur[i] <> 0 then stillTooBig := True;
    end;
    if not stillTooBig then Break;

{ low := cur mod 2^p }
    ZeroBig(low);
    for i := 0 to fullWords-1 do low[i] := cur[i];
    if remBits <> 0 then
      low[fullWords] := cur[fullWords] and ((Word(1) shl remBits) - 1);

{ high := cur div 2^p }
    ZeroBig(high);
    if remBits = 0 then
    begin
      for i := 0 to NLIMB2-1-fullWords do
        if i < NLIMB then high[i] := cur[i+fullWords];
    end
    else
    begin
      carryBits := 0;
      for i := NLIMB2-1 downto fullWords do
      begin
        val := cur[i];
        if (i - fullWords) < NLIMB then
          high[i-fullWords] := (val shr remBits) or carryBits;
        carryBits := (val and ((Word(1) shl remBits) - 1)) shl (16-remBits);
      end;
    end;

    carryOut := AddBigTrunc(low, high, summed);
    if carryOut <> 0 then
    begin
      ZeroBig(low);
      low[0] := carryOut;
      AddBigTrunc(summed, low, summed);
    end;

    ZeroBig2(cur);
    for i := 0 to NLIMB-1 do cur[i] := summed[i];

    Inc(iterCount);
    if iterCount > 8 then Halt(1);  { logic-error safety net }
  until False;

  for i := 0 to NLIMB-1 do resultOut[i] := cur[i];

{ all-ones (2^p - 1) maps to 0 }
  ZeroBig(allOnes);
  for i := 0 to fullWords-1 do allOnes[i] := $FFFF;
  if remBits <> 0 then allOnes[fullWords] := (Word(1) shl remBits) - 1;

  if CompareBig(resultOut, allOnes) = 0 then ZeroBig(resultOut);
end;

{ (s - 2) mod (2^p - 1). s in [0,2)  wraps by adding m = 2^p-1. }
procedure Sub2Mod(var s: TBigNum; p: Byte);
var
  two, m, temp: TBigNum;
  fullWords, remBits: Byte;
  i: Integer;
begin
  ZeroBig(two);
  two[0] := 2;

  if CompareBig(s, two) >= 0 then
  begin
    if (s[0] >= 2) then
      s[0] := s[0] - 2
    else
    begin
      s[0] := s[0] + 65536 - 2;
      i := 1;
      while (i < NLIMB) do
      begin
        if s[i] = 0 then begin s[i] := 65535; Inc(i); end
        else begin s[i] := s[i] - 1; Break; end;
      end;
    end;
  end
  else
  begin
    fullWords := p div 16;
    remBits   := p mod 16;
    ZeroBig(m);
    for i := 0 to fullWords-1 do m[i] := $FFFF;
    if remBits <> 0 then m[fullWords] := (Word(1) shl remBits) - 1;

    temp := m;
    if temp[0] >= (2 - s[0]) then
      temp[0] := temp[0] - (2 - s[0])
    else
    begin
      temp[0] := temp[0] + 65536 - (2 - s[0]);
      i := 1;
      while (i < NLIMB) do
      begin
        if temp[i] = 0 then begin temp[i] := 65535; Inc(i); end
        else begin temp[i] := temp[i] - 1; Break; end;
      end;
    end;
    s := temp;
  end;
end;

function IsZero(const b: TBigNum): Boolean;
var i: Integer;
begin
  IsZero := True;
  for i := 0 to NLIMB-1 do
    if b[i] <> 0 then begin IsZero := False; Exit; end;
end;

{ The self-verifying core: True if 2^p - 1 tests prime. }
function LucasLehmerTest(p: Byte): Boolean;
var
  s: TBigNum;
  sq: TBigNum2;
  reduced: TBigNum;
  i: Integer;
begin
  if p = 2 then begin LucasLehmerTest := True; Exit; end;

  ZeroBig(s);
  s[0] := 4;

  for i := 1 to p - 2 do
  begin
    SquareWords(s, sq);
    ModMersenneWords(sq, p, reduced);
    s := reduced;
    Sub2Mod(s, p);
  end;

  LucasLehmerTest := IsZero(s);
end;

{ --- test harness: run known Mersenne-prime exponents, print PASS/FAIL --- }
var
  idx: Integer;
  p: Byte;
  ok: Boolean;

begin
  WriteLn('PRIME386 -- Lucas-Lehmer CPU self-verification test');
  WriteLn;

  for idx := 1 to NumTestExponents do
  begin
    p := TestExponents[idx];
    Write('  p=', p:3, '  2^', p, '-1  ... ');
    ok := LucasLehmerTest(p);
    if ok then
      WriteLn('PASS (s=0, correctly prime)')
    else
      WriteLn('*** FAIL *** (expected PASS -- known Mersenne prime)');
  end;
end.
