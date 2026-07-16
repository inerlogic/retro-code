program HexLifeLog386;
uses Crt;

{ OPTIMIZED VERSION -- speed-optimized sibling to HL386_Brent.pas 
  which usually skips most of the replay by starting from a previous 
  checkpoint instead, when provably safe to -- see the FindMu comment 
  for the full reasoning and validation. Both files are otherwise identical.

  Version history for both files lives in this folder's README. }

{ 244x38 grid (9,272 cells) in VGA's 80x50 text mode (8x8 font), centered
  with margin on all sides, plus a status line on row 1 (Seed/Generation/
  Elapsed). Grid dimensions are sized for the physical screen's aspect
  ratio -- see the GRIDW/GRIDH const comment for the derivation.

  Gen and the checksum are LongInt (32-bit), not Integer (16-bit): Gen
  needs the range for long-running seeds, and a 32-bit checksum keeps
  the odds of a false cycle match (a checksum collision mistaken for a
  real repeat) negligible even over tens of thousands of generations --
  a 16-bit checksum's collision odds scale with run length (roughly
  N/65536 cumulative chance over N generations) and become uncomfortably
  high well before that.

  The seed LFSR generator (RandSeedVal/GetRnd) stays 16-bit deliberately
  -- it's a proven generator and 65,536 possible seeds is already more
  diversity than needed; widening it properly would mean designing a new
  32-bit tap constant from scratch, not just relabeling the variable.

  Cycle detection is Brent's algorithm: a single saved checkpoint,
  doubling in spacing (1, 2, 4, 8, 16, ...), catches a cycle of any
  period using bounded memory. Because it's only comparing 32-bit
  CHECKSUMS, not actual grid states, a checksum match is treated as a
  CANDIDATE, not a confirmed cycle -- it's verified against a real
  snapshot of the full grid (byte-for-byte) taken at the same checkpoint
  before being accepted. That verification is what actually eliminates
  false positives, rather than just making them less likely.

  CSV logs elapsed SECONDS via the BIOS timer-tick counter at 0040:006C,
  not a wall-clock timestamp, accumulated incrementally once per
  generation so it stays correct even across multiple midnight
  rollovers -- see AccumulateElapsedTicks/TicksToSeconds below for why
  (short version: this machine's RTC isn't trustworthy).

  CSV format is Seed,Mu,EstimatedMuSeconds,Period. Phase-1 detection
  alone only tells you WHEN a cycle was confirmed, which overshoots the
  TRUE convergence point (mu) by an amount that depends on checkpoint-
  schedule luck, not on the pattern. FindMu (Brent's standard second
  phase, below) recovers the true mu exactly. Period is exact (Lam-1 at
  match time); EstimatedMuSeconds is a proportional ESTIMATE scaled from
  the real measured detection-time, not a direct timing, since FindMu's
  replay happens after the fact at a different real-world moment -- see
  the logging block's comment for the full reasoning. }

const
  { GRIDW/GRIDH: Sized to ~9,000-10,000 cells (erring smaller), proportioned to the
    physical screen's real 6.125" x 3.5" aspect ratio (1.75:1) -- NOT by
    setting GRIDW:GRIDH to 1.75 directly, since a Life cell isn't square
    on this display. Four cells pack into one character horizontally but
    only one per character vertically, so each individual cell is about
    3.66x taller than wide (character cell ~0.0766" x 0.07", divided by
    4 horizontally). To make the DISPLAYED rectangle actually come out
    at 1.75:1 in real inches, the cell-count ratio has to undo that
    compression first: 1.75 x 3.66 =~ 6.4:1 (GRIDW:GRIDH), not 1.75:1.
    244x38 = 9,272 cells lands close to that (244/38 = 6.42) and checks
    out physically: (244/4 hex-cols * 6.125/80") x (38 rows * 3.5/50")
    = 4.67" x 2.66" = 1.755:1, within 0.3% of the real 1.75. }
  HEXCOLS = 61;   { GRIDW/4 hex-digit columns }
  GRIDW   = 244;
  GRIDH   = 38;

  { Centered in the 80x50 screen, below the row-1 status line: 9 spare
    columns left / 10 right, 5 spare rows above the grid / 6 below --
    rows 45-50 stay untouched, same scroll-bug safety margin as before. }
  GRIDLEFT = 10;
  GRIDTOP  = 7;

type
  THexDigits = string;
  TGrid = array[1..GRIDW, 1..GRIDH] of Byte;

var
  CellA, CellB, Snapshot: TGrid;   { Snapshot: full-state checkpoint for
                                      verifying a Brent's candidate match }
  PrevSnapshot: TGrid;             { the checkpoint BEFORE Snapshot's current
                                      one -- lets FindMu often skip most of
                                      its replay; see FindMu's comment }
  TortoiseScratch: TGrid;          { extra scratch grid for FindMu's second
                                      phase -- see FindMu's comment for why
                                      only 1 new array is needed, not 4 }
  Gen: LongInt;
  Ch: Char;
  KeepRunning: Boolean;
  HexDigits: THexDigits;
  RandSeedVal: Integer;    { LFSR stays 16-bit -- see note above }
  SeedVal: LongInt;
  LastChecksum: LongInt;
  LogFile: Text;
  ElapsedTicksAccum: LongInt; { running elapsed-tick total for the current seed's run }
  PriorTickSample: LongInt;   { last tick reading, for detecting a rollover between checks }

  { Brent's cycle-detection state }
  TortoiseChecksum: LongInt;
  Power, Lam: LongInt;
  CallCounter: LongInt;      { dedicated absolute-generation counter, kept
                               separate from Gen deliberately -- Gen isn't
                               incremented until AFTER CycleCandidate runs
                               each generation, so it's off by one relative
                               to what CycleCandidate is actually evaluating }
  TortoiseGen: LongInt;      { generation the CURRENT checkpoint (Snapshot)
                               was taken at }
  PrevCheckpointGen: LongInt; { generation PrevSnapshot was taken at -- 0
                                means "no previous checkpoint yet this seed" }
  FoundPeriod: LongInt;      { true period, extracted as Lam-1 at match time }
  Mu: LongInt;               { true convergence generation, from FindMu }
  DetectionGen: LongInt;     { Gen at the moment phase 1 detected a match }
  DetectionSeconds: LongInt; { real measured seconds at DetectionGen }
  EstimatedMuSeconds: LongInt; { proportionally-scaled estimate of real
                                 seconds at Mu -- see the logging block's
                                 comment for why this is an estimate, not
                                 a direct measurement }

function GetRnd: Integer;
begin
  if (RandSeedVal and 1) <> 0 then
    RandSeedVal := (RandSeedVal shr 1) xor $A1A1
  else
    RandSeedVal := RandSeedVal shr 1;
  GetRnd := RandSeedVal and 1;
end;

function GetRndPct: Boolean;
var
  I, V: Integer;
begin
  V := 0;
  for I := 1 to 7 do
    V := (V * 2) + GetRnd;
  GetRndPct := (V < 45);
end;

procedure SeedGrid;
var
  X, Y: Integer;
begin
  for X := 1 to GRIDW do
    for Y := 1 to GRIDH do
      if GetRndPct then CellA[X, Y] := 1 else CellA[X, Y] := 0;
end;

{ Shared by the initial-state checksum, the per-generation checksum, and
  (implicitly, via StatesMatch below) the full-state verification step --
  works on whichever grid array is passed in rather than assuming CellB. }
function ComputeChecksum(var G: TGrid): LongInt;
var
  X, Y: Integer;
  Sum: LongInt;
begin
  Sum := 0;
  for X := 1 to GRIDW do
    for Y := 1 to GRIDH do
      Sum := (Sum * 3) + G[X, Y];
  ComputeChecksum := Sum;
end;

procedure CopyGrid(var Src, Dst: TGrid);
var
  X, Y: Integer;
begin
  for X := 1 to GRIDW do
    for Y := 1 to GRIDH do
      Dst[X, Y] := Src[X, Y];
end;

{ Byte-for-byte comparison -- this is what actually confirms a Brent's
  checksum candidate is a real cycle and not a collision. Only ever runs
  when a checksum match has already fired, so the O(GRIDW*GRIDH) cost is
  paid rarely, not every generation. }
function StatesMatch(var G1, G2: TGrid): Boolean;
var
  X, Y: Integer;
begin
  StatesMatch := True;
  for X := 1 to GRIDW do
    for Y := 1 to GRIDH do
      if G1[X, Y] <> G2[X, Y] then
      begin
        StatesMatch := False;
        Exit;
      end;
end;

{ Parameterized so both the main loop AND FindMu (below) can reuse the
  exact same rule logic on whichever pair of grids they're advancing --
  the main loop still calls this as StepGrid(CellA, CellB), same as
  plain Step always did; FindMu needs it on its own separate scratch
  grids for the tortoise/hare replay. }
procedure StepGrid(var Src, Dst: TGrid);
var
  X, Y, S, CellCounter: Integer;
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

      S := Src[XM, YM] + Src[XM, Y] + Src[XM, YP] +
           Src[X, YM]                + Src[X, YP]  +
           Src[XP, YM] + Src[XP, Y] + Src[XP, YP];

      if Src[X, Y] = 1 then
      begin
        if (S = 2) or (S = 3) then Dst[X, Y] := 1 else Dst[X, Y] := 0;
      end
      else
      begin
        if S = 3 then Dst[X, Y] := 1 else Dst[X, Y] := 0;
      end;

      CellCounter := CellCounter + 1;
      if CellCounter >= 200 then
      begin
        CellCounter := 0;
        if KeyPressed then
        begin
          Ch := ReadKey;
          if Ch = #27 then KeepRunning := False;
        end;
      end;
    end;
  end;
end;

{ Brent's cycle detection. Compares the current checksum against the
  PREVIOUS checkpoint before conditionally refreshing the checkpoint --
  order matters here: refreshing the checkpoint and then immediately
  comparing against it would trivially "match" itself every time,
  producing a false trigger on every single doubling boundary. Comparing
  first, then refreshing for next time, avoids that.

  Also preserves the checkpoint being REPLACED (into PrevSnapshot/
  PrevCheckpointGen) before overwriting it -- this is what lets FindMu
  often skip most of its replay; see FindMu's comment for the full
  reasoning. }
function CycleCandidate(Checksum: LongInt): Boolean;
begin
  CallCounter := CallCounter + 1;
  CycleCandidate := (Checksum = TortoiseChecksum);
  if Lam = Power then
  begin
    PrevCheckpointGen := TortoiseGen;
    CopyGrid(Snapshot, PrevSnapshot);
    TortoiseChecksum := Checksum;
    TortoiseGen := CallCounter;
    CopyGrid(CellB, Snapshot);
    Power := Power * 2;
    Lam := 0;
  end;
  Lam := Lam + 1;
end;

procedure CopyBToA;
begin
  CopyGrid(CellB, CellA);
end;

{ Distinct from DrawStatus on purpose -- reusing DrawStatus here would
  show a stale, non-updating Gen/Elapsed pair (those aren't tracked
  during FindMu's replay), which could read as "the counter's frozen"
  rather than "this is a different phase." Updated every 10 steps, not
  every single one -- frequent enough to prove it's alive, cheap enough
  not to meaningfully slow the replay down. The 4-frame hourglass cycles
  based on StepNum, purely so a glance at the screen shows motion, not
  just a changing number. }
procedure DrawMuProgress(StepNum: LongInt);
const
  HourglassFrames: array[0..3] of string[6] =
    ('|', '/', '-', '\');
var
  FrameIndex: Integer;
begin
  FrameIndex := (StepNum div 10) mod 4;
  GotoXY(GRIDLEFT, 3);
  TextColor(7);
  Write('Seed: ', SeedVal, '  Recalculating... ', HourglassFrames[FrameIndex],
        '  step ', StepNum);
  ClrEol;
end;

{ FindMu: Brent's phase 1 (CycleCandidate, above) only finds a 
  candidate PERIOD cheaply -- it deliberately never learns WHERE 
  in the run the actual repeating cycle started, called "mu" in the 
  standard algorithm. The logged "Generation" from phase 1 alone is 
  the DETECTION point, which overshoots the true convergence point by 
  an amount that depends purely on checkpoint-schedule luck, not on 
  the pattern itself. 
  This function is Brent's standard second phase: advance a "hare" pointer 
  exactly FoundPeriod steps ahead of a "tortoise" pointer, then advance 
  both one step at a time together until they match -- the number of 
  generations counted in THIS phase is mu, the true convergence generation, 
  exactly (not an estimate).

  SHORTCUT, checked first: rather than always starting both pointers from
  the seed's true generation-0 grid, this tries starting from the
  PREVIOUS checkpoint (PrevSnapshot/PrevCheckpointGen, preserved by
  CycleCandidate) instead. That's only valid if PrevCheckpointGen is
  provably before Mu -- confirmed by stepping a copy of PrevSnapshot
  forward exactly FoundPeriod generations and checking whether it returns
  to itself. If it does NOT, that proves PrevCheckpointGen < Mu (forward-
  determinism: if a state recurs after exactly one true period, every
  generation from that point on is already inside the cycle, so the
  checkpoint can't be in the pre-cycle tail) -- safe to start the real
  search there instead of from 0. If it DOES return to itself, the
  checkpoint is already past Mu and can't be used -- falls back to the
  original, always-correct generation-0 replay. The verification itself
  only costs FoundPeriod steps regardless of outcome, so it's cheap even
  when it doesn't pay off, and cheaper still whenever Period itself is
  small. See the README for this shortcut's validation results.

  Cost: without the shortcut, this requires re-simulating up to
  (mu + FoundPeriod) additional generations from scratch -- worst case,
  comparable in size to the original detection generation, i.e. roughly
  DOUBLING total computation time for a seed's convergence. The shortcut
  usually avoids most of that; the generation-0 fallback is the original,
  unavoidable cost for the rare cases it can't.

  Memory: needs 4 grids in principle (tortoise-current/next,
  hare-current/next), but only 2 new ones are actually declared
  (PrevSnapshot, TortoiseScratch) -- CellA, CellB, and Snapshot are all
  safely reusable as scratch here, since by the time this runs, the
  CURRENT seed's real simulation has already concluded (we're between
  detecting convergence and moving to the next seed), and the outer loop
  reseeds CellA fresh for the next seed regardless of what this leaves
  behind in it. }
function FindMu(FoundPeriod: LongInt): LongInt;
var
  I: LongInt;
  Mu: LongInt;
  StartGen: LongInt;
begin
  StartGen := 0;

  if PrevCheckpointGen > 0 then
  begin
    CopyGrid(PrevSnapshot, CellA);
    for I := 1 to FoundPeriod do
    begin
      StepGrid(CellA, CellB);
      CopyGrid(CellB, CellA);
    end;
    if not StatesMatch(CellA, PrevSnapshot) then
      StartGen := PrevCheckpointGen;
  end;

  if StartGen = 0 then
  begin
    { Reconstruct x0 -- this seed's exact starting grid -- by re-seeding
      identically to how the outer loop originally did it. }
    RandSeedVal := Integer(SeedVal and $FFFF);
    SeedGrid;
  end
  else
    CopyGrid(PrevSnapshot, CellA);   { known state at StartGen, no re-seed needed }

  CopyGrid(CellA, CellB);   { hare starts alongside the tortoise, for now }

  { Advance the hare FoundPeriod steps ahead of the tortoise, ping-ponging
    between CellB (hare-current) and Snapshot (hare-next) }
  for I := 1 to FoundPeriod do
  begin
    if not KeepRunning then Break;
    StepGrid(CellB, Snapshot);
    CopyGrid(Snapshot, CellB);
    if (I mod 10) = 0 then DrawMuProgress(I);
  end;

  { Now advance both one step at a time until they match -- tortoise
    ping-pongs CellA/TortoiseScratch, hare continues on CellB/Snapshot }
  Mu := StartGen;
  while KeepRunning and (not StatesMatch(CellA, CellB)) do
  begin
    StepGrid(CellA, TortoiseScratch);
    StepGrid(CellB, Snapshot);
    CopyGrid(TortoiseScratch, CellA);
    CopyGrid(Snapshot, CellB);
    Mu := Mu + 1;
    if (Mu mod 10) = 0 then DrawMuProgress(Mu);
  end;

  FindMu := Mu;
end;

procedure SetHeatColor(Nibble: Integer);
begin
  case Nibble of
    0:  TextColor(8);  { Dark Gray }
    1:  TextColor(1);  { Blue }
    2:  TextColor(9);  { Light Blue }
    3:  TextColor(3);  { Cyan }
    4:  TextColor(11); { Light Cyan }
    5:  TextColor(2);  { Green }
    6:  TextColor(10); { Light Green }
    7:  TextColor(5);  { Magenta }
    8:  TextColor(13); { Light Magenta }
    9:  TextColor(6);  { Brown }
    10: TextColor(14); { Yellow }
    11: TextColor(4);  { Red }
    12: TextColor(12); { Light Red }
    13: TextColor(7);  { Light Gray }
    14: TextColor(15); { White }
    15: TextColor(15); { White -- one unavoidable repeat, only 15 usable
                          non-black colors exist for 16 nibble values }
  end;
end;

{ Draws only the grid, centered at GRIDLEFT/GRIDTOP -- row 1 is reserved
  for the status line (DrawStatus below), and the margins around the
  grid (columns 1-9/71-80, rows 2-6/45-50) are deliberately left
  untouched, not just narrowly avoided.

  Why any margin at all, not just enough to dodge the last row/column
  specifically: Crt's Write() tracks the cursor and auto-wraps/scrolls
  when a write would advance past the active window's bottom-right
  corner. As long as the grid's own last-drawn row/column isn't the
  screen's actual last row/column, that can't happen -- centering with
  margin all around keeps that true regardless of grid size changes
  later. }
procedure DrawGrid;
var
  X, Y, G, Bit, Nibble, CellX, LastNibble: Integer;
  DigitChar: Char;
begin
  LastNibble := -1;
  for Y := 1 to GRIDH do
  begin
    GotoXY(GRIDLEFT, GRIDTOP + Y - 1);
    for G := 0 to HEXCOLS - 1 do
    begin
      Nibble := 0;
      for Bit := 0 to 3 do
      begin
        CellX := (G * 4) + Bit + 1;
        Nibble := (Nibble * 2) + CellA[CellX, Y];
      end;

      DigitChar := HexDigits[Nibble + 1];

      if Nibble <> LastNibble then
      begin
        SetHeatColor(Nibble);
        LastNibble := Nibble;
      end;
      Write(DigitChar);
    end;
  end;
  TextColor(7);
end;

{ Elapsed time via the BIOS timer-tick counter at 0040:006C, NOT the
  RTC/calendar clock (GetTime/GetDate) -- this machine's CMOS clock isn't
  trustworthy, so any wall-clock reading would just be recording
  nonsense. The BIOS tick counter is different: it's incremented by the
  motherboard's timer chip firing an interrupt about 18.2065 times a
  second, entirely independent of the CMOS battery, so it stays accurate
  for measuring elapsed durations even when the calendar date is garbage.

  Ticks are ACCUMULATED incrementally, once per generation, rather than
  measured as a single before/after subtraction at the start and end of
  a seed's run. This is what makes it correct for a seed that takes
  several days to converge, not just one that crosses a single midnight:
  since the check below runs once a generation -- far more often than
  once every 24 hours -- it's not possible to miss a rollover, no matter
  how many midnights a single seed's run happens to span. }
const
  SECONDS_PER_TICK = 65536.0 / 1193182.0;
  TICKS_PER_DAY = 1573040;

procedure AccumulateElapsedTicks;
var
  NowTicks: LongInt;
begin
  NowTicks := MemL[$0040:$006C];
  if NowTicks < PriorTickSample then
    ElapsedTicksAccum := ElapsedTicksAccum + (NowTicks + TICKS_PER_DAY - PriorTickSample)
  else
    ElapsedTicksAccum := ElapsedTicksAccum + (NowTicks - PriorTickSample);
  PriorTickSample := NowTicks;
end;

function TicksToSeconds(Ticks: LongInt): LongInt;
begin
  TicksToSeconds := Round(Ticks * SECONDS_PER_TICK);
end;

{ Starts at the grid's own left edge (GRIDLEFT), not column 1 of the
  screen or centered over the grid -- lines up visually with the grid
  below it rather than sitting off to its left. ClrEol after writing
  (rather than manual space-padding) clears any leftover digits from a
  previous, longer value -- e.g. Generation shrinking from 6 digits back
  down to 5 on a fresh reseed wouldn't otherwise erase the stray leading
  digit left behind. Since the start column is fixed (not recalculated
  per-frame the way a centered version would need), a simple post-write
  ClrEol is enough -- no need to clear the whole line first. }
procedure DrawStatus;
begin
  GotoXY(GRIDLEFT, 3);
  TextColor(7);
  Write('Seed: ', SeedVal, '  Generation: ', Gen, '  Elapsed: ',
        TicksToSeconds(ElapsedTicksAccum), 's');
  ClrEol;
end;

begin
  HexDigits := '0123456789ABCDEF';

  Write('ENTER STARTING SEED NUMBER: ');
  ReadLn(SeedVal);

  Assign(LogFile, 'LIFELOG.CSV');
  {$I-}
  Append(LogFile);
  if IOResult <> 0 then
    ReWrite(LogFile);
  {$I+}

  TextMode(CO80 + Font8x8);   { switch to 80x50 for the grid + status line }

  KeepRunning := True;

  while KeepRunning do
  begin
    { RandSeedVal (the 16-bit LFSR) is intentionally fed only the low 16
      bits of SeedVal (now a LongInt) -- it doesn't need the full range,
      just a differing starting bit pattern each time SeedVal increments,
      which truncation still provides even once SeedVal grows past 65535. }
    RandSeedVal := Integer(SeedVal and $FFFF);
    PriorTickSample := MemL[$0040:$006C];
    ElapsedTicksAccum := 0;
    ClrScr;
    SeedGrid;
    Gen := 0;
    Power := 1;
    Lam := 0;
    CallCounter := 0;
    TortoiseGen := 0;
    PrevCheckpointGen := 0;
    TortoiseChecksum := ComputeChecksum(CellA);
    CopyGrid(CellA, Snapshot);

    while KeepRunning do
    begin
      DrawStatus;
      DrawGrid;
      StepGrid(CellA, CellB);
      AccumulateElapsedTicks;

      if KeepRunning then
      begin
        LastChecksum := ComputeChecksum(CellB);

        if CycleCandidate(LastChecksum) and StatesMatch(CellB, Snapshot) then
        begin
          { Lam has already been incremented once (unconditionally, inside
            CycleCandidate) beyond the value that produced this match, so
            subtracting 1 recovers the exact true period -- see FindMu's
            comment for the full derivation. }
          FoundPeriod := Lam - 1;
          DetectionGen := Gen;
          DetectionSeconds := TicksToSeconds(ElapsedTicksAccum);

          Mu := FindMu(FoundPeriod);

          if KeepRunning then
          begin
            { Logging block: EstimatedMuSeconds is a proportional ESTIMATE, not a direct
              measurement -- FindMu's replay happens after the fact and at
              a different real-world time than the original run, so there's
              no wall-clock reading to take AT generation Mu directly. The
              scaling assumes a roughly constant generations/second rate,
              which holds here because StepGrid/DrawGrid/ComputeChecksum
              all do the same fixed amount of work every generation
              (a full pass over the grid) regardless of what's actually
              alive on it -- worth knowing it's interpolated, not timed. }
            if DetectionGen > 0 then
              EstimatedMuSeconds := Round((Mu / DetectionGen) * DetectionSeconds)
            else
              EstimatedMuSeconds := 0;

            WriteLn(LogFile, SeedVal, ',', Mu, ',', EstimatedMuSeconds, ',', FoundPeriod);
            Flush(LogFile);

            { Tied to a successful log write deliberately: SeedVal, at any
              point the program might stop, always reflects "the seed
              currently in progress, not yet logged" -- never a seed
              that's already been counted past. That's what makes
              "SeedVal - 1" reliable in the exit message below, regardless
              of whether the interruption happens during the main loop or
              during FindMu. }
            SeedVal := SeedVal + 1;
          end;

          Break;
        end
        else
        begin
          CopyBToA;
          Gen := Gen + 1;
        end;
      end;
    end;
  end;

  Close(LogFile);
  TextMode(CO80);   { back to normal 80x25 so the exit message is readable }
  ClrScr;
  WriteLn('Run stopped by user request.');
  WriteLn('Seed ', SeedVal, ' was interrupted -- not logged.');
  WriteLn('Last completed seed: ', SeedVal - 1);
end.
