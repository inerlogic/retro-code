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
{ XMS extended-memory scanner. The v1 fill/read-back path (0xAA/0x55)   }
{ is confirmed clean on real hardware, including coverage of the first  }
{ unit's known CheckIt-confirmed parity fault, see TECHNICAL.md. The v2 }
{ patterns added below (walking-bit, address-in-address, March C-) are  }
{ NOT yet run on real hardware, there is no TP7 compiler available in   }
{ this sandbox, so treat their register conventions and far-call        }
{ mechanics as reasoned-through and Python-verified at the algorithm    }
{ level, not hardware-confirmed. Likeliest places to look first if they }
{ misbehave: the exact XMS AH codes, and whether the CALL DWORD PTR     }
{ XMSEntry far-call mechanics match what this specific driver expects,  }
{ same caveat that applied to v1 before its own hardware confirmation. }

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

{ Chunk-level test functions below all move data through a 1 KB         }
{ conventional buffer to/from extended memory at ByteOffset via MoveRec }
{ (global, see note above), then compare. XMSMoveUp/XMSMoveDown do the  }
{ raw move in each direction; everything else is built on top of them. }
const
  ChunkWords = 512;  { 1 KB per chunk }
type
  TChunkBuf = array[0..ChunkWords-1] of Word;
var
  ChunkBuf: TChunkBuf;  { source buffer for conventional -> XMS moves }
  CheckBuf: TChunkBuf;  { destination buffer for XMS -> conventional moves }
                        { both global for the same reason as MoveRec/     }
                        { AllocHandle above: inline asm needs a plain      }
                        { DS-relative address, not a var-parameter's extra }
                        { level of indirection. }

{ Raw one-chunk XMS moves, factored out of the v1 TestChunk so the v2   }
{ patterns below (which need read-then-write, not just write-then-read)}
{ can reuse the same two move directions instead of duplicating the asm.}
function XMSMoveUp(Handle: Word; ByteOffset: LongInt): Boolean;
var
  MoveAX: Word;
begin
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
  XMSMoveUp := (MoveAX = 1);
end;

function XMSMoveDown(Handle: Word; ByteOffset: LongInt): Boolean;
var
  MoveAX: Word;
begin
  MoveRec.Length       := ChunkWords * 2;
  MoveRec.SourceHandle := Handle;
  MoveRec.SourceOffset := ByteOffset;
  MoveRec.DestHandle   := 0;
  MoveRec.DestOffset   := LongInt(Seg(CheckBuf)) shl 16 + Ofs(CheckBuf);
  asm
    push si
    lea  si, MoveRec
    mov  ah, $0B
    call dword ptr XMSEntry
    mov  MoveAX, ax
    pop  si
  end;
  XMSMoveDown := (MoveAX = 1);
end;

{ Single-word (2-byte) XMS moves, for the address-line test below, which  }
{ needs to touch specific individual addresses, not whole 1 KB chunks.    }
{ Same global-buffer reasoning as ChunkBuf/CheckBuf: inline asm needs a   }
{ plain DS-relative address. }
var
  WordSrcBuf: Word;
  WordDstBuf: Word;

function XMSMoveWordUp(Handle: Word; ByteOffset: LongInt; Value: Word): Boolean;
var
  MoveAX: Word;
begin
  WordSrcBuf := Value;
  MoveRec.Length       := 2;
  MoveRec.SourceHandle := 0;
  MoveRec.SourceOffset := LongInt(Seg(WordSrcBuf)) shl 16 + Ofs(WordSrcBuf);
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
  XMSMoveWordUp := (MoveAX = 1);
end;

function XMSMoveWordDown(Handle: Word; ByteOffset: LongInt; var Value: Word): Boolean;
var
  MoveAX: Word;
begin
  WordDstBuf := 0;
  MoveRec.Length       := 2;
  MoveRec.SourceHandle := Handle;
  MoveRec.SourceOffset := ByteOffset;
  MoveRec.DestHandle   := 0;
  MoveRec.DestOffset   := LongInt(Seg(WordDstBuf)) shl 16 + Ofs(WordDstBuf);
  asm
    push si
    lea  si, MoveRec
    mov  ah, $0B
    call dword ptr XMSEntry
    mov  MoveAX, ax
    pop  si
  end;
  XMSMoveWordDown := (MoveAX = 1);
  Value := WordDstBuf;
end;

{ AddrGallop: address-line test, added after CheckIt 3.0/v4 both flagged  }
{ this hardware's fault as Failure Class "Address Lines," and the actual  }
{ reported addresses (see TECHNICAL.md) all share the identical low-order}
{ remainder mod 8192 bytes (0x2000 = bit 13 of the byte address), with    }
{ every gap between failing addresses a multiple of 8192. That's the      }
{ signature of address bit 13 being unreliable: two addresses differing   }
{ only in that bit alias to the same physical cell, at least in the       }
{ affected bands. TestAddrPair (which implements the actual check) is     }
{ defined further down, after the fault-logging helpers it uses. }

{ v1: write Pattern to every word in the chunk, read it back, compare. }
function TestChunkConst(Handle: Word; ByteOffset: LongInt; Pattern: Word): Boolean;
var
  i: Integer;
  okWrite, okRead, okCompare: Boolean;
begin
  for i := 0 to ChunkWords-1 do ChunkBuf[i] := Pattern;
  okWrite := XMSMoveUp(Handle, ByteOffset);

  for i := 0 to ChunkWords-1 do CheckBuf[i] := 0;
  okRead := XMSMoveDown(Handle, ByteOffset);

  okCompare := True;
  for i := 0 to ChunkWords-1 do
    if CheckBuf[i] <> Pattern then okCompare := False;

  TestChunkConst := okWrite and okRead and okCompare;
end;

{ v2: address-in-address. Each word gets its own byte offset (low 16   }
{ bits) as data, instead of a chunk-wide constant, so a decode fault    }
{ that silently redirects one word's write to a different word within  }
{ the SAME chunk becomes visible on readback, something a uniform fill  }
{ pattern can't distinguish from a correct write since every word looks }
{ the same either way. Caveat, confirmed in Python before writing this  }
{ (addr_pattern_verify.py): the low-16-bits truncation repeats every    }
{ 64 KB, so it can't tell apart two words exactly a 64 KB-multiple      }
{ apart, fine here since CheckIt's fault bands were under 100 KB wide,  }
{ well inside one 64 KB window where the pattern is a true bijection.   }
{ Bigger caveat, also confirmed in Python (pascal_translit_verify.py):  }
{ because this test writes-then-immediately-reads each chunk exactly    }
{ once and never revisits it, it CANNOT catch coupling between two      }
{ different chunks, in either aggressor/victim order, since there is no}
{ second pass left to expose a corruption written after a chunk's own   }
{ check already passed. That gap is real, not hypothetical, injecting   }
{ the fault caught it clean both directions. March C- below is what     }
{ actually covers cross-chunk coupling, via its repeated read-before-   }
{ write sweeps; this test's real job is address/decode integrity within}
{ a chunk, not coupling between chunks. }
function TestChunkAddr(Handle: Word; ByteOffset: LongInt): Boolean;
var
  i: Integer;
  okWrite, okRead, okCompare: Boolean;
  expected: Word;
begin
  for i := 0 to ChunkWords-1 do
    ChunkBuf[i] := Word(ByteOffset + LongInt(i) * 2);
  okWrite := XMSMoveUp(Handle, ByteOffset);

  for i := 0 to ChunkWords-1 do CheckBuf[i] := 0;
  okRead := XMSMoveDown(Handle, ByteOffset);

  okCompare := True;
  for i := 0 to ChunkWords-1 do
  begin
    expected := Word(ByteOffset + LongInt(i) * 2);
    if CheckBuf[i] <> expected then okCompare := False;
  end;

  TestChunkAddr := okWrite and okRead and okCompare;
end;

{ v2: March C- primitives, chunk-granularity. A true cell-level march   }
{ would need one XMS move per word, impractically slow for a multi-MB   }
{ block on a 386SX/40 with no FPU, so each 1 KB chunk stands in as one  }
{ march "cell." This can't catch coupling between two words inside the  }
{ same chunk (they're always written/read together in bulk), but it     }
{ does exercise the ordered read-verify-then-write sweeps across chunks }
{ and addresses that a static fill/read-back pass never does, which is  }
{ exactly the class of test March C- is verified against in             }
{ march_verify.py (stuck-at, coupling, and address-alias faults all     }
{ detected there before this was written). }
function MarchWrite(Handle: Word; ByteOffset: LongInt; WriteVal: Word): Boolean;
var
  i: Integer;
begin
  for i := 0 to ChunkWords-1 do ChunkBuf[i] := WriteVal;
  MarchWrite := XMSMoveUp(Handle, ByteOffset);
end;

function MarchReadWrite(Handle: Word; ByteOffset: LongInt; ExpectBefore, WriteAfter: Word): Boolean;
var
  i: Integer;
  okRead, okCompare: Boolean;
begin
  for i := 0 to ChunkWords-1 do CheckBuf[i] := 0;
  okRead := XMSMoveDown(Handle, ByteOffset);

  okCompare := True;
  for i := 0 to ChunkWords-1 do
    if CheckBuf[i] <> ExpectBefore then okCompare := False;

  for i := 0 to ChunkWords-1 do ChunkBuf[i] := WriteAfter;
  MarchReadWrite := okRead and okCompare and XMSMoveUp(Handle, ByteOffset);
end;

function MarchRead(Handle: Word; ByteOffset: LongInt; ExpectVal: Word): Boolean;
var
  i: Integer;
  okRead, okCompare: Boolean;
begin
  for i := 0 to ChunkWords-1 do CheckBuf[i] := 0;
  okRead := XMSMoveDown(Handle, ByteOffset);

  okCompare := True;
  for i := 0 to ChunkWords-1 do
    if CheckBuf[i] <> ExpectVal then okCompare := False;

  MarchRead := okRead and okCompare;
end;

{ Centers "test N/Total: <desc>" on its own 80-column line. Used between  }
{ every fill pattern, the addr-in-addr pass, and each March phase, so a   }
{ long overnight run always shows which of the 41 steps per block is     }
{ running, not just a pattern name buried in a wall of dots. }
const
  ScreenWidth = 80;

function Spaces(n: Integer): string;
var
  s: string;
  i: Integer;
begin
  s := '';
  for i := 1 to n do s := s + ' ';
  Spaces := s;
end;

procedure PrintTestHeader(testNum, totalTests: Integer; desc: string);
var
  numStr, totalStr, hdr: string;
  padLen: Integer;
begin
  Str(testNum, numStr);
  Str(totalTests, totalStr);
  hdr := 'test ' + numStr + '/' + totalStr + ': ' + desc;
  padLen := (ScreenWidth - Length(hdr)) div 2;
  if padLen < 0 then padLen := 0;
  WriteLn;
  WriteLn(Spaces(padLen) + hdr);
end;

{ LongInt -> hex string, no leading zeros, no '0x'/'h' (caller adds that). }
{ Used so fault addresses print in the same hex style CheckIt itself uses  }
{ (e.g. "401704h"), letting a fault reported here be compared directly to  }
{ TECHNICAL.md's known bands without doing the conversion by hand.        }
function HexStr(v: LongInt): string;
const
  digits: array[0..15] of Char = '0123456789ABCDEF';
var
  s: string;
  rem: LongInt;
begin
  if v = 0 then s := '0'
  else
  begin
    s := '';
    while v > 0 do
    begin
      rem := v mod 16;
      s := digits[rem] + s;
      v := v div 16;
    end;
  end;
  HexStr := s;
end;

{ Per-test fault log: which chunk offsets failed, not just a dot/X count.  }
{ Capped at MaxLoggedFaults so a badly-faulty run can't blow past however  }
{ much string-building the screen can usefully show; FaultOverflow flags   }
{ when that cap was hit so the printout says so rather than silently      }
{ dropping faults. Offsets are block-relative (0 = start of the grabbed   }
{ XMS block); PrintFaultLog also shows offset + 100000h as an ESTIMATED    }
{ absolute physical address, valid only under the same assumption already }
{ noted in TECHNICAL.md: that the block's offset 0 lines up with the start}
{ of usable extended memory, i.e. this is the normal single-block case,   }
{ not a guarantee once real fragmentation is in play. }
const
  MaxLoggedFaults = 40;
var
  FaultOffsets:  array[1..MaxLoggedFaults] of LongInt;
  FaultLogCount: Integer;
  FaultOverflow: Boolean;

procedure ResetFaultLog;
begin
  FaultLogCount := 0;
  FaultOverflow := False;
end;

procedure LogFault(ByteOffset: LongInt);
begin
  if FaultLogCount < MaxLoggedFaults then
  begin
    Inc(FaultLogCount);
    FaultOffsets[FaultLogCount] := ByteOffset;
  end
  else
    FaultOverflow := True;
end;

{ AddrGallop: address-line test, added after CheckIt 3.0/v4 both flagged  }
{ this hardware's fault as Failure Class "Address Lines," and the actual  }
{ reported addresses (see TECHNICAL.md) all share the identical low-order}
{ remainder mod 8192 bytes (0x2000 = bit 13 of the byte address), with    }
{ every gap between failing addresses a multiple of 8192. That's the      }
{ signature of address bit 13 being unreliable: two addresses differing   }
{ only in that bit alias to the same physical cell, at least in the       }
{ affected bands. Verified in Python first (addrgallop_verify.py): a      }
{ simulated bit-13 fault localized to a band is caught cleanly, clean     }
{ memory gives zero false positives, and a stride of 8192 bytes lands     }
{ exactly on all of the real reported addresses checked. }
{                                                                          }
{ Method: pick a reference word address, write a marker to it and to the  }
{ SAME address with one bit toggled, then read both back and confirm      }
{ neither corrupted the other. This needs single-word XMS moves rather    }
{ than the bulk chunk moves everything else in this file uses, so it's   }
{ far slower per byte covered, which is why it's its own menu option      }
{ rather than folded into the XMS Scanner's 41-step sequence. Bits 11-15  }
{ are tested (2 KB-32 KB spacing) rather than only bit 13, as cheap        }
{ insurance in case the exact bit differs on another run or another unit. }
{ Known minor inefficiency, not worth the complexity to special-case:     }
{ for the bit matching the reference stride itself (13, since stride is   }
{ also 8192), each aliased pair gets tested twice, once from each side.   }
const
  AddrGallopTagRef = $A5A5;
  AddrGallopTagTgt = $5A5A;

function TestAddrPair(Handle: Word; RefOffset: LongInt; BitPos: Integer): Boolean;
var
  delta, tgtOffset: LongInt;
  readBack: Word;
  refOK, tgtOK: Boolean;
begin
  delta := LongInt(1) shl BitPos;
  tgtOffset := RefOffset xor delta;

  XMSMoveWordUp(Handle, RefOffset, AddrGallopTagRef);
  XMSMoveWordUp(Handle, tgtOffset, AddrGallopTagTgt);

  XMSMoveWordDown(Handle, RefOffset, readBack);
  refOK := (readBack = AddrGallopTagRef);
  if not refOK then LogFault(RefOffset);

  XMSMoveWordDown(Handle, tgtOffset, readBack);
  tgtOK := (readBack = AddrGallopTagTgt);
  if not tgtOK then LogFault(tgtOffset);

  TestAddrPair := refOK and tgtOK;
end;

{ Zero-pads a Word to 2 digits for timestamp formatting (e.g. 9 -> '09'). }
function Pad2(v: Word): string;
var
  t: string;
begin
  Str(v, t);
  if Length(t) < 2 then t := '0' + t;
  Pad2 := t;
end;

{ MM/DD/YYYY HH:MM:SS, via DOS's own clock (Dos unit, already in uses). }
function TimestampStr: string;
var
  h, m, s, hund: Word;
  yy, mo, dd, dow: Word;
  yyStr: string;
begin
  GetTime(h, m, s, hund);
  GetDate(yy, mo, dd, dow);
  Str(yy, yyStr);
  TimestampStr := Pad2(mo) + '/' + Pad2(dd) + '/' + yyStr + ' ' +
                  Pad2(h) + ':' + Pad2(m) + ':' + Pad2(s);
end;

{ On-disk fault log. Appends across runs so a multi-day sweep builds one  }
{ running history rather than overwriting itself; errors only, nothing   }
{ is ever written for a clean pass, so a long overnight run that finds    }
{ nothing leaves the log untouched, no periodic writes to wear out a CF   }
{ card described elsewhere as "of dubious origin." If the file can't be   }
{ opened or a write ever fails, logging is silently disabled for the rest }
{ of the run rather than crashing the scan over a logging problem, the    }
{ on-screen output already carries the same information either way. }
const
  LogFileName = 'XMSFAULT.LOG';
var
  LogFile: Text;
  LogAvailable: Boolean;

procedure OpenFaultLog;
begin
  Assign(LogFile, LogFileName);
  {$I-}
  Append(LogFile);
  {$I+}
  if IOResult <> 0 then
  begin
    {$I-}
    Rewrite(LogFile);
    {$I+}
    LogAvailable := (IOResult = 0);
  end
  else
    LogAvailable := True;
end;

procedure CloseFaultLog;
begin
  if LogAvailable then
  begin
    {$I-}
    Close(LogFile);
    {$I+}
  end;
end;

procedure PrintFaultLog(BlockNum, TestNum, TotalTests: Integer; Desc: string);
var
  i: Integer;
  overflowMark: string;
begin
  if FaultLogCount = 0 then
  begin
    WriteLn('  0 faults');
    Exit;
  end;

  Write('  ', FaultLogCount);
  if FaultOverflow then Write('+');
  WriteLn(' fault(s):');
  for i := 1 to FaultLogCount do
  begin
    WriteLn('    offset ', FaultOffsets[i], ' bytes (', FaultOffsets[i] div 1024,
            ' KB into block)  est. abs. addr ', HexStr(FaultOffsets[i] + $100000), 'h');
  end;
  if FaultOverflow then
    WriteLn('    (', MaxLoggedFaults, '+ faults, list capped, more occurred)');

  { Mirror to disk, errors only, never called when FaultLogCount = 0 above. }
  if LogAvailable then
  begin
    if FaultOverflow then overflowMark := '+' else overflowMark := '';
    {$I-}
    WriteLn(LogFile, TimestampStr, '  block ', BlockNum, ', test ', TestNum, '/',
            TotalTests, ' (', Desc, '): ', FaultLogCount, overflowMark, ' fault(s)');
    for i := 1 to FaultLogCount do
      WriteLn(LogFile, '    offset ', FaultOffsets[i], ' bytes (',
              FaultOffsets[i] div 1024, ' KB into block)  est. abs. addr ',
              HexStr(FaultOffsets[i] + $100000), 'h');
    if FaultOverflow then
      WriteLn(LogFile, '    (', MaxLoggedFaults, '+ faults, list capped, more occurred)');
    {$I+}
    if IOResult <> 0 then LogAvailable := False;
  end;
end;

{ March C-: w0; asc(r0,w1); asc(r1,w0); desc(r0,w1); desc(r1,w0); r0.   }
{ Standard 6-element sequence, catches address faults, stuck-at faults, }
{ transition faults, and (some) coupling faults. Progress is printed    }
{ per phase rather than one running line, since a fault caught in, say, }
{ M3 but not M1 is itself diagnostic information, worth keeping visible }
{ rather than folding into a single pass/fail count. }
procedure RunMarchBlock(Handle: Word; NumChunks: LongInt; var faults: LongInt;
                         var stopRequested: Boolean; var testNum: Integer;
                         totalTests: Integer; BlockNum: Integer);
var
  c: LongInt;
  addr: LongInt;
  f: LongInt;

  procedure PollESC;
  begin
    if KeyPressed then
      if ReadKey = #27 then stopRequested := True;
  end;

begin
  Inc(testNum);
  PrintTestHeader(testNum, totalTests, 'March C- M0 (w0) asc');
  ResetFaultLog;
  f := 0; c := 0;
  while (c < NumChunks) and not stopRequested do
  begin
    addr := c * 1024;
    if MarchWrite(Handle, addr, 0) then Write('.')
    else begin Write('X'); Inc(f); LogFault(addr); end;
    PollESC;
    Inc(c);
  end;
  WriteLn; Inc(faults, f); PrintFaultLog(BlockNum, testNum, totalTests, 'March C- M0 (w0) asc');

  Inc(testNum);
  PrintTestHeader(testNum, totalTests, 'March C- M1 (r0,w1) asc');
  ResetFaultLog;
  f := 0; c := 0;
  while (c < NumChunks) and not stopRequested do
  begin
    addr := c * 1024;
    if MarchReadWrite(Handle, addr, 0, 1) then Write('.')
    else begin Write('X'); Inc(f); LogFault(addr); end;
    PollESC;
    Inc(c);
  end;
  WriteLn; Inc(faults, f); PrintFaultLog(BlockNum, testNum, totalTests, 'March C- M1 (r0,w1) asc');

  Inc(testNum);
  PrintTestHeader(testNum, totalTests, 'March C- M2 (r1,w0) asc');
  ResetFaultLog;
  f := 0; c := 0;
  while (c < NumChunks) and not stopRequested do
  begin
    addr := c * 1024;
    if MarchReadWrite(Handle, addr, 1, 0) then Write('.')
    else begin Write('X'); Inc(f); LogFault(addr); end;
    PollESC;
    Inc(c);
  end;
  WriteLn; Inc(faults, f); PrintFaultLog(BlockNum, testNum, totalTests, 'March C- M2 (r1,w0) asc');

  Inc(testNum);
  PrintTestHeader(testNum, totalTests, 'March C- M3 (r0,w1) desc');
  ResetFaultLog;
  f := 0; c := NumChunks - 1;
  while (c >= 0) and not stopRequested do
  begin
    addr := c * 1024;
    if MarchReadWrite(Handle, addr, 0, 1) then Write('.')
    else begin Write('X'); Inc(f); LogFault(addr); end;
    PollESC;
    Dec(c);
  end;
  WriteLn; Inc(faults, f); PrintFaultLog(BlockNum, testNum, totalTests, 'March C- M3 (r0,w1) desc');

  Inc(testNum);
  PrintTestHeader(testNum, totalTests, 'March C- M4 (r1,w0) desc');
  ResetFaultLog;
  f := 0; c := NumChunks - 1;
  while (c >= 0) and not stopRequested do
  begin
    addr := c * 1024;
    if MarchReadWrite(Handle, addr, 1, 0) then Write('.')
    else begin Write('X'); Inc(f); LogFault(addr); end;
    PollESC;
    Dec(c);
  end;
  WriteLn; Inc(faults, f); PrintFaultLog(BlockNum, testNum, totalTests, 'March C- M4 (r1,w0) desc');

  Inc(testNum);
  PrintTestHeader(testNum, totalTests, 'March C- M5 (r0) asc');
  ResetFaultLog;
  f := 0; c := 0;
  while (c < NumChunks) and not stopRequested do
  begin
    addr := c * 1024;
    if MarchRead(Handle, addr, 0) then Write('.')
    else begin Write('X'); Inc(f); LogFault(addr); end;
    PollESC;
    Inc(c);
  end;
  WriteLn; Inc(faults, f); PrintFaultLog(BlockNum, testNum, totalTests, 'March C- M5 (r0) asc');
end;

const
  MaxXMSBlocks = 32;  { safety cap in case free XMS is heavily fragmented }
  MaxPatterns  = 34;  { 0xAA, 0x55, 16 walking-1, 16 walking-0 }
  TotalTestSteps = MaxPatterns + 7;  { + addr-in-addr + March C-'s 6 phases }

var
  patterns:   array[1..MaxPatterns] of Word;
  patName:    array[1..MaxPatterns] of string[16];
  numPatterns: Integer;

{ Builds the const-fill pattern set. A loop rather than 34 literal      }
{ entries, both easier to check by eye and easier to extend if another  }
{ pattern class gets added later. }
procedure InitPatterns;
var
  bit: Integer;
  bs:  string[4];
begin
  numPatterns := 0;

  Inc(numPatterns); patterns[numPatterns] := $AAAA; patName[numPatterns] := '0xAA fill';
  Inc(numPatterns); patterns[numPatterns] := $5555; patName[numPatterns] := '0x55 fill';

  for bit := 0 to 15 do
  begin
    Inc(numPatterns);
    patterns[numPatterns] := Word(1) shl bit;
    Str(bit, bs);
    patName[numPatterns] := 'walk-1 bit ' + bs;
  end;

  for bit := 0 to 15 do
  begin
    Inc(numPatterns);
    patterns[numPatterns] := $FFFF xor (Word(1) shl bit);
    Str(bit, bs);
    patName[numPatterns] := 'walk-0 bit ' + bs;
  end;
end;

const
  AddrGallopStride = 8192;  { bytes; matches the confirmed 8 KB/bit-13    }
                             { periodicity, so every reference point lands}
                             { on a fresh instance of the suspect pattern }
  AddrGallopMinBit = 11;
  AddrGallopMaxBit = 15;     { tests bits 11..15 (2 KB-32 KB spacing);    }
                             { bit 13 (8 KB) is the one CheckIt's own      }
                             { reported addresses confirm, the neighbors  }
                             { are cheap insurance in case the exact bit  }
                             { differs on another run or another unit.   }

{ Address-line test, its own menu option rather than folded into the XMS  }
{ Scanner's 41-step sequence, since word-level XMS moves are far slower   }
{ per byte covered than the bulk chunk moves everything else uses; this   }
{ is meant to be run and re-run on its own, not as part of an overnight   }
{ sweep. Grabs XMS blocks the same way RunXMSScanner does (duplicated     }
{ rather than factored out, so a change here can't risk the already      }
{ hardware-confirmed block-grabbing logic there). }
procedure RunAddrGallopScanner;
var
  BlockHandle: array[1..MaxXMSBlocks] of Word;
  BlockKB:     array[1..MaxXMSBlocks] of Word;
  NumBlocks:   Integer;
  TotalKBGrabbed: LongInt;
  LargestKB: Word;
  faults: LongInt;
  ok, stopRequested, allocFailed: Boolean;
  b, bit, totalTests, testNum: Integer;
  blockBytes, refOffset, tgtOffset: LongInt;
  bs: string[4];
  desc: string;
begin
  WriteLn;
  WriteLn('--- AddrGallop Scanner (address-line test) ---');
  WriteLn('Tests bits ', AddrGallopMinBit, '-', AddrGallopMaxBit,
          ' at an ', AddrGallopStride, '-byte stride. Not yet run on real');
  WriteLn('hardware; faults (only faults) are also logged to ', LogFileName, '.');
  WriteLn;

  OpenFaultLog;
  if not LogAvailable then
    WriteLn('(Could not open ', LogFileName, ', continuing without file logging.)');

  if not XMSPresent then
  begin
    WriteLn('No XMS driver detected (INT 2Fh, AX=4300h did not return AL=80h).');
    WriteLn('Load HIMEM.SYS or an equivalent XMS driver and try again.');
    WriteLn('Press any key to return to menu.');
    ReadKey;
    CloseFaultLog;
    Exit;
  end;

  GetXMSEntry;

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
    CloseFaultLog;
    Exit;
  end;

  WriteLn('Grabbed ', NumBlocks, ' block(s), ', TotalKBGrabbed, ' KB total.');
  if allocFailed then
    WriteLn('(Stopped grabbing after an allocate failure, testing what was already grabbed.)');
  WriteLn;

  faults := 0;
  stopRequested := False;
  totalTests := AddrGallopMaxBit - AddrGallopMinBit + 1;

  for b := 1 to NumBlocks do
  begin
    if stopRequested then Break;
    WriteLn('Block ', b, ' of ', NumBlocks, ' (', BlockKB[b], ' KB, handle=',
            BlockHandle[b], '):');
    blockBytes := LongInt(BlockKB[b]) * 1024;
    testNum := 0;

    for bit := AddrGallopMinBit to AddrGallopMaxBit do
    begin
      if stopRequested then Break;
      Inc(testNum);
      Str(bit, bs);
      desc := 'AddrGallop bit ' + bs;
      PrintTestHeader(testNum, totalTests, desc);
      ResetFaultLog;

      refOffset := 0;
      while (refOffset < blockBytes) and not stopRequested do
      begin
        tgtOffset := refOffset xor (LongInt(1) shl bit);
        if (tgtOffset >= 0) and (tgtOffset < blockBytes) then
        begin
          ok := TestAddrPair(BlockHandle[b], refOffset, bit);
          if ok then Write('.')
          else
          begin
            Write('X');
            Inc(faults);
          end;
        end;

        if KeyPressed then
          if ReadKey = #27 then stopRequested := True;

        Inc(refOffset, AddrGallopStride);
      end;
      WriteLn;
      PrintFaultLog(b, testNum, totalTests, desc);
    end;
  end;

  WriteLn;
  if stopRequested then
    WriteLn('Run stopped by user request.')
  else
    WriteLn('AddrGallop complete (bits ', AddrGallopMinBit, '-', AddrGallopMaxBit, ').');
  WriteLn('Blocks tested: ', NumBlocks, '   Total KB tested: ', TotalKBGrabbed,
          '   Total faults: ', faults);

  for b := 1 to NumBlocks do
    XMSFree(BlockHandle[b]);
  CloseFaultLog;

  WriteLn;
  WriteLn('Press any key to return to menu.');
  ReadKey;
end;

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
  testNum: Integer;
  ok, stopRequested, allocFailed: Boolean;
  b: Integer;
begin
  WriteLn;
  WriteLn('--- XMS Scanner (v2: fill/read-back, walking-bit, addr-in-addr, March C-) ---');
  WriteLn('NOTE: only the v1 fill/read-back patterns (0xAA/0x55) are confirmed on');
  WriteLn('real hardware so far. The rest are new, report any oddities.');
  WriteLn('Faults (only faults, never clean passes) are also logged to ', LogFileName, '.');
  WriteLn;

  OpenFaultLog;
  if not LogAvailable then
    WriteLn('(Could not open ', LogFileName, ', continuing without file logging.)');

  if not XMSPresent then
  begin
    WriteLn('No XMS driver detected (INT 2Fh, AX=4300h did not return AL=80h).');
    WriteLn('Load HIMEM.SYS or an equivalent XMS driver and try again.');
    WriteLn('Press any key to return to menu.');
    ReadKey;
    CloseFaultLog;
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
    CloseFaultLog;
    Exit;
  end;

  WriteLn('Grabbed ', NumBlocks, ' block(s), ', TotalKBGrabbed, ' KB total.');
  if allocFailed then
    WriteLn('(Stopped grabbing after an allocate failure, testing what was already grabbed.)');
  WriteLn;

  InitPatterns;

  faults := 0;
  stopRequested := False;

  for b := 1 to NumBlocks do
  begin
    if stopRequested then Break;
    WriteLn('Block ', b, ' of ', NumBlocks, ' (', BlockKB[b], ' KB, handle=',
            BlockHandle[b], '):');
    numChunks := BlockKB[b];   { 1 KB per chunk }
    testNum := 0;

    { v1 + walking-bit: constant fill per pass, checked against itself. }
    for patternIdx := 1 to numPatterns do
    begin
      if stopRequested then Break;
      Inc(testNum);
      PrintTestHeader(testNum, TotalTestSteps, patName[patternIdx]);
      ResetFaultLog;
      for chunk := 0 to numChunks - 1 do
      begin
        ok := TestChunkConst(BlockHandle[b], chunk * 1024, patterns[patternIdx]);
        if ok then Write('.')
        else
        begin
          Write('X');
          Inc(faults);
          LogFault(chunk * 1024);
        end;

        if KeyPressed then
          if ReadKey = #27 then stopRequested := True;

        if stopRequested then Break;
      end;
      WriteLn;
      PrintFaultLog(b, testNum, TotalTestSteps, patName[patternIdx]);
    end;

    { v2: address-in-address, each word carries its own offset as data. }
    if not stopRequested then
    begin
      Inc(testNum);
      PrintTestHeader(testNum, TotalTestSteps, 'addr-in-addr');
      ResetFaultLog;
      for chunk := 0 to numChunks - 1 do
      begin
        ok := TestChunkAddr(BlockHandle[b], chunk * 1024);
        if ok then Write('.')
        else
        begin
          Write('X');
          Inc(faults);
          LogFault(chunk * 1024);
        end;

        if KeyPressed then
          if ReadKey = #27 then stopRequested := True;

        if stopRequested then Break;
      end;
      WriteLn;
      PrintFaultLog(b, testNum, TotalTestSteps, 'addr-in-addr');
    end;

    { v2: March C-, ordered read/write sweeps for coupling and address faults. }
    if not stopRequested then
      RunMarchBlock(BlockHandle[b], numChunks, faults, stopRequested, testNum,
                    TotalTestSteps, b);
  end;

  WriteLn;
  if stopRequested then
    WriteLn('Run stopped by user request.')
  else
    WriteLn('All v1 and v2 patterns complete: fill/read-back, walking-bit,');
  if not stopRequested then
    WriteLn('address-in-address, and March C-.');
  WriteLn('Blocks tested: ', NumBlocks, '   Total KB tested: ', TotalKBGrabbed,
          '   Total faults: ', faults);

  { Always free everything grabbed, regardless of how we got here. }
  for b := 1 to NumBlocks do
    XMSFree(BlockHandle[b]);
  CloseFaultLog;

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
  WriteLn('  4) AddrGallop Scanner (address-line test)');
  WriteLn('  5) Quit to DOS');
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
      '4': RunAddrGallopScanner;
      '5': Done := True;
    end;
  end;
end.
