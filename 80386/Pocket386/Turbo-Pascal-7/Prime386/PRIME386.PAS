{$D+,L+,Q-,R-}
{ PRIME386.PAS, Lucas-Lehmer CPU self-test + prime search, for the       }
{ Pocket 386 (no FPU). The 386SX/40's own "Prime95": a known-input,      }
{ known-correct-output self-verifying stress test, done in pure integer  }
{ arithmetic via Lucas-Lehmer since there's no FPU for Prime95's usual    }
{ FFT approach.                                                          }
{ See README.md / TECHNICAL.md for design and verification notes.        }
{                                                                          }
{ SCOPE NOTE: this file is deliberately CPU/arithmetic only. An earlier   }
{ phase of this project grew a whole memory-diagnostic subsystem (XMS     }
{ scanner, address-line tests, direct physical-memory access) chasing a   }
{ specific known-faulty unit's hardware defect. That work is real,        }
{ working, and preserved, but it isn't what Prime386 is for: a mature,    }
{ dedicated tool (CheckIt) already covers memory diagnostics on this      }
{ hardware professionally, no need to reinvent it. That code now lives    }
{ in its own project, ../MemTest386/MEMTEST386.PAS, kept for reference.   }
{ See TECHNICAL.md's "Memory diagnostic detour" section for the full      }
{ story of how it started and why it stopped there. }

program Prime386;

uses Dos, Crt;

const
  MaxP   = 61;  { largest exponent supported }
  NLIMB  = 4;  { words per bignum: ceil(61/16) }
  NLIMB2 = 2 * NLIMB;  { width for squaring results }

  { All primes p <= MaxP, paired with whether 2^p-1 is actually prime.   }
  { This is the self-verifying set for the stress loop: any mismatch    }
  { between ExpectPrime and the actual test result means the CPU got    }
  { the arithmetic wrong. }
  NumCandidates = 18;
  CandExp: array[1..NumCandidates] of Byte =
    (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61);
  CandExpectPrime: array[1..NumCandidates] of Boolean =
    (True, True, True, True, False, True, True, True, False, False,
     True, False, False, False, False, False, False, True);

  { Original 5-exponent quick-check set, all known Mersenne primes. }
  NumTestExponents = 5;
  TestExponents: array[1..NumTestExponents] of Byte = (13, 17, 19, 31, 61);

type
  TBigNum  = array[0..NLIMB-1]  of Word;
  TBigNum2 = array[0..NLIMB2-1] of Word;

  { Overlays a LongInt with its two 16-bit halves. x86 is little-endian, }
  { so Lo (declared first, lower offset) is the low word and Hi (second,}
  { higher offset) is the high word, this is memory layout, not       }
  { computation, so it bypasses whatever "X shr 16" actually compiles to.}
  TLongWords = record
    case Boolean of
      True:  (L: LongInt);
      False: (Lo, Hi: Word);
  end;

{ ---------------- bignum / Lucas-Lehmer core (unchanged) ---------------- }

function HiWord(x: LongInt): Word;
var w: TLongWords;
begin
  w.L := x;
  HiWord := w.Hi;
end;

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
      carry := HiWord(prod);
    end;
    k := i + NLIMB;
    while carry <> 0 do
    begin
      prod := LongInt(result[k]) + (carry and $FFFF);
      result[k] := Word(prod and $FFFF);
      carry := LongInt(HiWord(carry)) + LongInt(HiWord(prod));
      Inc(k);
    end;
  end;
end;

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
    carry := HiWord(s);
  end;
  AddBigTrunc := Word(carry);
end;

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

    ZeroBig(low);
    for i := 0 to fullWords-1 do low[i] := cur[i];
    if remBits <> 0 then
      low[fullWords] := cur[fullWords] and ((Word(1) shl remBits) - 1);

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
    if iterCount > 8 then
    begin
      WriteLn;
      WriteLn('*** ModMersenneWords did not converge for p=', p, ' after 8 iterations, logic error ***');
      Halt(1);
    end;
  until False;

  for i := 0 to NLIMB-1 do resultOut[i] := cur[i];

  ZeroBig(allOnes);
  for i := 0 to fullWords-1 do allOnes[i] := $FFFF;
  if remBits <> 0 then allOnes[fullWords] := (Word(1) shl remBits) - 1;

  if CompareBig(resultOut, allOnes) = 0 then ZeroBig(resultOut);
end;

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

{ ---------------------------- menu option 1 ---------------------------- }

procedure RunCPUCheck;
var
  idx: Integer;
  p: Byte;
  ok: Boolean;
begin
  WriteLn;
  WriteLn('--- CPU Check: known Mersenne-prime exponents ---');
  WriteLn;
  for idx := 1 to NumTestExponents do
  begin
    p := TestExponents[idx];
    Write('  p=', p:3, '  2^', p, '-1  ... ');
    ok := LucasLehmerTest(p);
    if ok then
      WriteLn('PASS (s=0, correctly prime)')
    else
      WriteLn('*** FAIL *** (expected PASS, known Mersenne prime)');
  end;
  WriteLn;
  WriteLn('Done. Press any key to return to menu.');
  ReadKey;
end;

{ ---------------------------- menu option 2 ---------------------------- }

{ Stress-test loop: sweeps every prime exponent p <= 61 each pass,      }
{ checking each against its known correct primality result. Loops      }
{ forever (burn-in) until ESC, which stops after the current test      }
{ rather than mid-test. }

procedure RunPrimeCheck;
var
  idx: Integer;
  p: Byte;
  ok, expect, sweepOK: Boolean;
  sweepCount: LongInt;
  faultCount: LongInt;
  stopRequested: Boolean;
begin
  WriteLn;
  WriteLn('--- Prime Check: continuous stress-test loop ---');
  WriteLn('Sweeping all ', NumCandidates, ' candidate exponents (2..', MaxP, ') each pass.');
  WriteLn('Press ESC at any time to stop after the current test.');
  WriteLn;

  sweepCount := 0;
  faultCount := 0;
  stopRequested := False;

  while not stopRequested do
  begin
    Inc(sweepCount);
    sweepOK := True;
    Write('Sweep ', sweepCount, ': ');

    for idx := 1 to NumCandidates do
    begin
      p := CandExp[idx];
      expect := CandExpectPrime[idx];
      ok := LucasLehmerTest(p);

      if ok = expect then
        Write('.')
      else
      begin
        Write('X');
        sweepOK := False;
        Inc(faultCount);
        WriteLn;
        WriteLn('*** MISMATCH: p=', p, ' expected ', expect, ' got ', ok,
                ' (sweep ', sweepCount, ') ***');
      end;

      if KeyPressed then
        if ReadKey = #27 then stopRequested := True;

      if stopRequested then Break;
    end;

    if stopRequested then
      WriteLn(' (interrupted)')
    else if sweepOK then
      WriteLn(' clean')
    else
      WriteLn(', fault(s) this sweep');
  end;

  WriteLn;
  WriteLn('Run stopped by user request.');
  WriteLn('Sweeps completed: ', sweepCount, '   Total faults: ', faultCount);
  WriteLn('Press any key to return to menu.');
  ReadKey;
end;

{ ---------------------------- menu option 3 ---------------------------- }
{ Unlike Prime Check (which cycles a fixed, pre-known self-verifying set  }
{ purely for burn-in), Search scans every integer in range, determines    }
{ whether the EXPONENT itself is prime via trial division (a genuine,    }
{ computed check, not a lookup table), and only then runs Lucas-Lehmer    }
{ on 2^p-1, reporting the result without consulting any known-answer     }
{ table. This is the part of Prime95's own spirit ("GIMPS") that Prime   }
{ Check alone doesn't capture: an open-ended search, not just a fixed    }
{ self-test. Capped at MaxP (61), the same bignum width already hardware-}
{ confirmed; nothing here can find a genuinely NEW Mersenne prime (every  }
{ exponent in this tiny range has been known and verified by others for  }
{ decades), but nothing here is looked up either, every result is        }
{ computed fresh. Extending the range further (toward the next real      }
{ Mersenne exponent, 89) would need a wider bignum (NLIMB > 4) and fresh  }
{ Python verification of the whole stack at that width, a natural future }
{ step, not attempted here. Trial-division design verified in Python     }
{ first (search_verify.py): reproduces the existing CandExp table's      }
{ known-Mersenne set exactly, for every prime <= 61. }

procedure RunSearch;
var
  n: Integer;
  ok: Boolean;
  isPrimeExp: Boolean;
  foundCount: Integer;
  stopRequested: Boolean;

  function IsPrimeSmall(v: Integer): Boolean;
  var
    i: Integer;
  begin
    IsPrimeSmall := True;
    if v < 2 then begin IsPrimeSmall := False; Exit; end;
    if v < 4 then Exit;
    if v mod 2 = 0 then begin IsPrimeSmall := False; Exit; end;
    i := 3;
    while i * i <= v do
    begin
      if v mod i = 0 then
      begin
        IsPrimeSmall := False;
        Exit;
      end;
      Inc(i, 2);
    end;
  end;

begin
  WriteLn;
  WriteLn('--- Search: scan for Mersenne primes, 2 <= p <= ', MaxP, ' ---');
  WriteLn('No known-answer table consulted: each exponent''s primality is');
  WriteLn('computed fresh (trial division), and each candidate 2^p-1 is');
  WriteLn('tested fresh via Lucas-Lehmer. Everything in this range is');
  WriteLn('already known and long verified elsewhere, this hardware cannot');
  WriteLn('reach far enough to find a genuinely new one, but nothing here');
  WriteLn('is looked up.');
  WriteLn('Press ESC at any time to stop.');
  WriteLn;

  foundCount := 0;
  stopRequested := False;
  n := 2;

  while (n <= MaxP) and not stopRequested do
  begin
    isPrimeExp := IsPrimeSmall(n);
    Write('p=', n:3, '  ');
    if not isPrimeExp then
      WriteLn('composite, 2^p-1 cannot be prime, skipping')
    else
    begin
      Write('prime exponent, testing 2^', n, '-1 ... ');
      ok := LucasLehmerTest(n);
      if ok then
      begin
        WriteLn('PRIME');
        Inc(foundCount);
      end
      else
        WriteLn('not prime');
    end;

    if KeyPressed then
      if ReadKey = #27 then stopRequested := True;

    Inc(n);
  end;

  WriteLn;
  if stopRequested then
    WriteLn('Search stopped by user request.')
  else
    WriteLn('Search complete.');
  WriteLn('Mersenne primes found in range: ', foundCount);
  WriteLn('Press any key to return to menu.');
  ReadKey;
end;

{ ------------------------------ main menu ------------------------------ }

procedure ShowMenu;
begin
  ClrScr;
  WriteLn('PRIME386, Pocket 386 self-verifying stress test');
  WriteLn;
  WriteLn('  1) CPU Check');
  WriteLn('  2) Prime Check (continuous stress loop)');
  WriteLn('  3) Search (scan for Mersenne primes, no lookup table)');
  WriteLn('  4) Quit to DOS');
  WriteLn;
  Write('Choice: ');
end;

var
  Choice: Char;
  Done: Boolean;

begin
  Done := False;
  while not Done do
  begin
    ShowMenu;
    Choice := ReadKey;
    WriteLn(Choice);
    case Choice of
      '1': RunCPUCheck;
      '2': RunPrimeCheck;
      '3': RunSearch;
      '4': Done := True;
    end;
  end;
end.
