{$D+,L+,Q-,R-}
{ PRIME386.PAS, Lucas-Lehmer CPU self-test + prime-search stress loop  }
{ + XMS extended-memory scanner, for the Pocket 386 (no FPU).           }
{ See README.md / TECHNICAL.md for design and verification notes.       }
{ NOTE: the XMS Scanner (menu option 3) is new and NOT yet confirmed    }
{ on real hardware, see the caveats in RunXMSScanner's header.        }

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

  { 16-byte XMS move-structure, per the XMS 3.0 spec. }
  TXMSMove = record
    Length:       LongInt;
    SourceHandle: Word;
    SourceOffset: LongInt;
    DestHandle:   Word;
    DestOffset:   LongInt;
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
{ XMS extended-memory scanner. UNTESTED ON REAL HARDWARE, there is no  }
{ TP7 compiler available to build/run this before hand-off, so treat    }
{ every AH function number, register convention, and the far-call       }
{ mechanics below as reasoned-through, not confirmed. Likeliest places   }
{ to look first if it misbehaves: the exact XMS AH codes, and whether   }
{ the CALL DWORD PTR XMSEntry far-call mechanics actually match what    }
{ this specific driver/BIOS expects. }

var
  XMSEntry: Pointer;          { far entry point of the XMS driver }
  MoveRec:  TXMSMove;         { global so the move asm block below can  }
                              { address it via plain DS-relative LEA,   }
                              { with no segment-override juggling.      }

function XMSPresent: Boolean;
var Regs: Registers;
begin
  Regs.AX := $4300;
  Intr($2F, Regs);
  XMSPresent := (Regs.AL = $80);
end;

procedure GetXMSEntry;
var Regs: Registers;
begin
  Regs.AX := $4310;
  Intr($2F, Regs);
  XMSEntry := Ptr(Regs.ES, Regs.BX);
end;

{ Register-only XMS calls (query/allocate/free, no memory structure). }
function XMSQueryLargestKB: Word;
var
  AXOut: Word;
begin
  asm
    push bx
    push dx
    mov  ah, $08
    call dword ptr XMSEntry
    mov  AXOut, ax
    pop  dx
    pop  bx
  end;
  XMSQueryLargestKB := AXOut;
end;

{ AllocHandle is set here rather than passed as a var parameter, }
{ same reasoning as MoveRec above: a var parameter is itself a   }
{ pointer, so writing to it from inline asm needs an extra level }
{ of indirection that "mov Handle, dx" can't generate in one step}
{ (this is what error 155 was flagging). A global sidesteps that.}
var
  AllocHandle: Word;

function XMSAllocate(KB: Word): Boolean;
var
  AXOut: Word;
begin
  asm
    push bx
    push dx
    mov  ah, $09
    mov  dx, KB
    call dword ptr XMSEntry
    mov  AXOut, ax
    mov  AllocHandle, dx
    pop  dx
    pop  bx
  end;
  XMSAllocate := (AXOut = 1);
end;

procedure XMSFree(Handle: Word);
var
  AXOut: Word;
begin
  asm
    push dx
    mov  ah, $0A
    mov  dx, Handle
    call dword ptr XMSEntry
    mov  AXOut, ax
    pop  dx
  end;
end;

{ Fills a 1KB conventional buffer, moves it up to extended memory at    }
{ ByteOffset via MoveRec (global, see note above), reads it back into a }
{ second buffer, and compares. }
const
  ChunkWords = 512;  { 1 KB per chunk }
type
  TChunkBuf = array[0..ChunkWords-1] of Word;
var
  ChunkBuf: TChunkBuf;

function TestChunk(Handle: Word; ByteOffset: LongInt; Pattern: Word): Boolean;
var
  i: Integer;
  Check: TChunkBuf;
  MoveAX: Word;
  okWrite, okRead, okCompare: Boolean;
begin
  for i := 0 to ChunkWords-1 do ChunkBuf[i] := Pattern;

  { conventional -> XMS }
  MoveRec.Length       := ChunkWords * 2;
  MoveRec.SourceHandle := 0;
  MoveRec.SourceOffset := LongInt(Seg(ChunkBuf)) shl 16 + Ofs(ChunkBuf);
  MoveRec.DestHandle   := Handle;
  MoveRec.DestOffset   := ByteOffset;
  asm
    push si
    lea  si, MoveRec
    mov  ah, $0B
    call dword ptr XMSEntry
    mov  MoveAX, ax
    pop  si
  end;
  okWrite := (MoveAX = 1);

  { XMS -> conventional (read back) }
  for i := 0 to ChunkWords-1 do Check[i] := 0;
  MoveRec.Length       := ChunkWords * 2;
  MoveRec.SourceHandle := Handle;
  MoveRec.SourceOffset := ByteOffset;
  MoveRec.DestHandle   := 0;
  MoveRec.DestOffset   := LongInt(Seg(Check)) shl 16 + Ofs(Check);
  asm
    push si
    lea  si, MoveRec
    mov  ah, $0B
    call dword ptr XMSEntry
    mov  MoveAX, ax
    pop  si
  end;
  okRead := (MoveAX = 1);

  okCompare := True;
  for i := 0 to ChunkWords-1 do
    if Check[i] <> Pattern then okCompare := False;

  TestChunk := okWrite and okRead and okCompare;
end;

const
  MaxXMSBlocks = 32;  { safety cap in case free XMS is heavily fragmented }

procedure RunXMSScanner;
var
  BlockHandle: array[1..MaxXMSBlocks] of Word;
  BlockKB:     array[1..MaxXMSBlocks] of Word;
  NumBlocks:   Integer;
  TotalKBGrabbed: LongInt;
  LargestKB: Word;
  chunk, numChunks: LongInt;
  faults: LongInt;
  patternIdx: Integer;
  patterns: array[1..2] of Word;
  patName: array[1..2] of string[12];
  ok, stopRequested, allocFailed: Boolean;
  b: Integer;
begin
  WriteLn;
  WriteLn('--- XMS Scanner (v1: fill/read-back patterns) ---');
  WriteLn('NOTE: not yet confirmed on real hardware, report any oddities.');
  WriteLn;

  if not XMSPresent then
  begin
    WriteLn('No XMS driver detected (INT 2Fh, AX=4300h did not return AL=80h).');
    WriteLn('Load HIMEM.SYS or an equivalent XMS driver and try again.');
    WriteLn('Press any key to return to menu.');
    ReadKey;
    Exit;
  end;

  GetXMSEntry;

  { Grab every free block, largest-first, until nothing's left or the }
  { safety cap is hit. This covers fragmented free memory, not just   }
  { the single largest contiguous block, since each allocation removes}
  { that block from what the next query reports as largest. }
  NumBlocks := 0;
  TotalKBGrabbed := 0;
  allocFailed := False;

  repeat
    LargestKB := XMSQueryLargestKB;
    if LargestKB < 1 then Break;
    if NumBlocks >= MaxXMSBlocks then Break;

    if not XMSAllocate(LargestKB) then
    begin
      allocFailed := True;
      Break;
    end;

    Inc(NumBlocks);
    BlockHandle[NumBlocks] := AllocHandle;
    BlockKB[NumBlocks]     := LargestKB;
    Inc(TotalKBGrabbed, LargestKB);
  until False;

  if NumBlocks = 0 then
  begin
    WriteLn('Nothing usable to test.');
    WriteLn('Press any key to return to menu.');
    ReadKey;
    Exit;
  end;

  WriteLn('Grabbed ', NumBlocks, ' block(s), ', TotalKBGrabbed, ' KB total.');
  if allocFailed then
    WriteLn('(Stopped grabbing after an allocate failure, testing what was already grabbed.)');
  WriteLn;

  patterns[1] := $AAAA; patName[1] := '0xAA fill';
  patterns[2] := $5555; patName[2] := '0x55 fill';

  faults := 0;
  stopRequested := False;

  for b := 1 to NumBlocks do
  begin
    if stopRequested then Break;
    WriteLn('Block ', b, ' of ', NumBlocks, ' (', BlockKB[b], ' KB, handle=',
            BlockHandle[b], '):');
    numChunks := BlockKB[b];   { 1 KB per chunk }

    for patternIdx := 1 to 2 do
    begin
      if stopRequested then Break;
      Write('  ', patName[patternIdx], ': ');
      for chunk := 0 to numChunks - 1 do
      begin
        ok := TestChunk(BlockHandle[b], chunk * 1024, patterns[patternIdx]);
        if ok then Write('.')
        else
        begin
          Write('X');
          Inc(faults);
        end;

        if KeyPressed then
          if ReadKey = #27 then stopRequested := True;

        if stopRequested then Break;
      end;
      WriteLn;
    end;
  end;

  WriteLn;
  if stopRequested then
    WriteLn('Run stopped by user request.')
  else
    WriteLn('Walking-bit and address-in-address patterns: not yet implemented (planned v2).');
  WriteLn('Blocks tested: ', NumBlocks, '   Total KB tested: ', TotalKBGrabbed,
          '   Total faults: ', faults);

  { Always free everything grabbed, regardless of how we got here. }
  for b := 1 to NumBlocks do
    XMSFree(BlockHandle[b]);

  WriteLn;
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
  WriteLn('  3) XMS Scanner');
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
      '3': RunXMSScanner;
      '4': Done := True;
    end;
  end;
end.
