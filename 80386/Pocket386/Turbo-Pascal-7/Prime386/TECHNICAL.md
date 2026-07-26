# Prime386

A "Prime95-like" CPU stress test for the Pocket 386 (ALi M6117 SoC,
386SX/40, no FPU, DOS 6.22, Turbo Pascal 7.0).

## Why

Prime95 stress-tests a PC by running a computation with a known correct
answer, repeatedly, a single bit-flip from bad RAM or a flaky ALU
produces a detectably wrong result rather than silently corrupting
something unnoticed. It does this via the [Lucas-Lehmer primality test](https://en.wikipedia.org/wiki/Lucas%E2%80%93Lehmer_primality_test)
for Mersenne primes, using FFT-based multiplication that leans on
modern floating-point hardware. Prime95 is also, at its core, GIMPS'
(the Great Internet Mersenne Prime Search) actual search tool, not
just a self-test, it looks for new Mersenne primes as a side effect of
verifying hardware.

The 386SX in the Pocket 386 has no FPU. Prime386 applies the same
self-verifying principle, known exponent in, known correct answer
out, using pure integer/bignum arithmetic instead.

**Scope note.** Prime386 is deliberately CPU/arithmetic only. A large
side project grew out of it for a while, chasing a specific known-
faulty unit's memory defect with custom-built diagnostic tooling. That
work was real and is preserved, but it isn't what this project is for:
a mature, dedicated tool (CheckIt) already covers memory diagnostics
on this hardware professionally, there was no need to reinvent it.
See "Memory diagnostic detour" below for the summary, and
[MemTest386](../MemTest386/) for where that code now lives.

## Files

- **`PRIME386.PAS`** — the current program. Menu-driven: CPU Check,
  Prime Check, Search, plus quit.
- **`Prime386-alpha.PAS`** — a frozen snapshot of the original
  single-purpose CPU-test core, preserved as-is because it's the
  specific version [THE-SHR16-SAGA.md](README.md) is about. Not
  maintained going forward; `PRIME386.PAS` is where active work
  happens.
- **`701TEST.PAS`** — a standalone diagnostic, deliberately reintroduces
  the historical SHR-16 bug (see "Resolved" below) so anyone running
  Turbo/Borland Pascal on real 386+ hardware can check whether their
  own compiler has it. All five tests should read PASS if the compiler
  is 7.01 or otherwise unaffected; corruption or failure suggests 7.00
  or earlier. Must be run on real hardware, not an emulator, see the
  file's own header for details.

## Menu design

- **CPU Check**: Lucas-Lehmer, run once against the 5 exponents for
  which `2^p - 1` is a *known* Mersenne prime (13, 17, 19, 31, 61).
  Any run that doesn't end at s=0 indicates an ALU/arithmetic fault.
  Confirmed working on real hardware.
- **Prime Check**: a continuous stress loop, not a search for new
  primes, a fixed, pre-known self-verifying set run purely for burn-in.
  Sweeps all 18 primes <= 61 each pass, checking each against its
  already-known correct answer (9 expected prime, 9 expected
  composite); any mismatch either direction means a hardware fault.
  Loops until ESC. Confirmed working on real hardware: over 105,590
  sweeps, clean the whole way through, zero mismatches.
- **Search**: the part of Prime95's own spirit ("GIMPS") that Prime
  Check alone doesn't capture, an open-ended search rather than a
  fixed self-test. Scans every integer from 2 to `MaxP` (61), checks
  whether the exponent itself is prime via trial division (a genuine
  computed check, not a lookup table), and only then runs Lucas-Lehmer
  on `2^p-1`, reporting the result without consulting any known-answer
  table. Nothing here can find a genuinely *new* Mersenne prime, this
  hardware's bignum width (4 words, 64 bits) caps it at exactly the
  same small range Prime Check already covers, and every exponent in
  that range has been known and independently verified by others for
  decades. But nothing here is looked up either, every result is
  computed fresh, which is the actual distinction from Prime Check.
  Design verified in Python first (`search_verify.py`): the trial-
  division-derived set of Mersenne-prime exponents matches the
  existing `CandExp` table exactly, for every prime <= 61. Extending
  the range further (toward the next real Mersenne exponent, 89) would
  need a wider bignum (`NLIMB` > 4) and fresh Python verification of
  the whole arithmetic stack at that width, a natural future step, not
  attempted yet. Not yet run on real hardware.

Menu-driven, with the ability to stop a running test (ESC) and return
to the menu to pick another mode.

## Bignum design

- Base 2^16 (`Word`), little-endian limb arrays. `NLIMB=4` (64 bits),
  sized for the largest test exponent (p=61); `NLIMB2=8` for squaring
  results before reduction.
- **Mersenne mod-reduction trick**: since `2^p == 1 (mod 2^p-1)`,
  reducing a value modulo a Mersenne number is shifts-and-adds, not
  true division,split the value into high/low p-bit halves and add
  them, repeating until it fits (2 iterations observed as the worst
  case), then map the all-ones case (exactly `2^p-1`) to 0.
- **Signed-`LongInt` risk**: squaring two `Word`s can reach
  65535*65535 ~= 4.29 billion, which exceeds signed 32-bit's positive
  range (~2.147 billion) but is still under 2^32. This is safe in TP7
  specifically because (a) Pascal's `shr`/`shl` are logical shifts
  regardless of sign, and (b) `$Q-` (no overflow-check trap) is the
  compiler default.

## Timing (for burn-in runs)

Originally planned around the raw BIOS tick counter, with manual
midnight-rollover detection (verified in Python against a simulated
5-day burn-in with irregular polling). Switched to DOS's own
`GetDate`/`GetTime` instead, DOS's date-keeping already handles
midnight rollover correctly (same underlying timer interrupt chain),
so hand-rolled rollover logic isn't needed. The day-number
linearization this requires was verified against Python's `datetime`
across 100,000+ fuzzed date/time pairs spanning leap years and
month/year boundaries.

That raised a real question before settling on it for good: could an
RTC-level Daylight-Savings-Enable bit silently jump the clock by an
hour mid-run, independent of DOS? (DOS 6.22 itself has no DST logic,
that was a Windows Control Panel feature, but the RTC hardware could,
in principle, regardless of the OS.) Checked directly on the actual
hardware via `DEBUG` (`O 70 0B` / `I 71`) rather than assuming: reads
back `02`, meaning bit 0 (DSE) is 0, disabled. With that confirmed,
`GetDate`/`GetTime`-based elapsed timing is safe on this machine, and
is the final approach used, no tick-counting fallback needed. Not yet
wired into the CPU Check/Prime Check/Search UI.

## Verification methodology

Algorithmic logic was fuzz-tested in Python against ground truth before
any Pascal was written:
- Squaring: 20,000+ random cases vs. Python's native multiplication.
- Mersenne mod-reduction: 34,000+ random cases across p=3..89
  (including 16-bit-aligned and non-aligned p) vs. Python's `%`.
- Full Lucas-Lehmer loop: checked against every exponent in the test
  set, plus known-composite exponents (11, 23, 29, 37, 41, 53) to
  confirm it correctly rejects non-Mersenne-primes too.
- The exact Pascal code structure (not just the underlying algorithm)
  was separately transliterated to Python and re-run against the same
  known-answer set, to catch transcription bugs specifically.

TP7-specific arithmetic semantics (shift direction, overflow-check
default) were checked against actual Pascal language documentation,
not assumed from general programming experience.

## Resolved: a bug in Turbo Pascal's own runtime library, not the hardware

*(For the long-form version of this story, see [README.md](README.md).)*

While bringing up the CPU-test core on real hardware, a diagnostic
build (temporarily printing internal state inside `ModMersenneWords`)
showed `p`, a plain `Byte` parameter that should only ever be 13,
17, 19, 31, or 61, reading as a garbage value partway through a
run: 145 in one build, 53 in another, 41 in a third, each time
internally self-consistent (the derived `fullWords`/`remBits` always
matched the garbage `p` exactly) but never matching any actual
test-set exponent.

Cross-checked the identical source across three independent
compilations:
- **Real Turbo Pascal 7.0 on the physical Pocket 386**: corruption
  reproduced reliably for a given build, but the specific wrong value
  shifted whenever the surrounding code changed (145 -> 53 -> 41 across
  three diagnostic revisions).
- **Free Pascal** (`fpc -Mtp`, native Linux target): sanity check with
  a known-good compiler, compiled clean, all five test cases pass,
  zero corruption.
- **Real Turbo Pascal 7.0 under DOSBox** (the actual TP7 compiler,
  emulated hardware): four separate runs, zero corruption, all five
  tests pass every time.

The turning point: recompiling the identical source from scratch on a
*second, physically different* Pocket 386 unit produced byte-for-byte
identical wrong output to the first machine's most recent build. Two
independent physical RAM chips producing the exact same "random"
corruption isn't something bad hardware does, that result is the
signature of something fully deterministic, and ruled out a hardware
fault as the cause.

An independent memory diagnostic (CheckIt) did separately confirm a
real, unrelated extended-memory fault on the first unit (see "Memory
diagnostic detour" below), a genuine hardware issue, just not the one
causing this bug.

Turbo Debugger (once actually located, it had been present the whole
time) made the real cause visible directly: a loop counter (`k`) that
should never exceed 7 was observed climbing past 130 in real time,
because a `carry` variable held **16** at a point where hand-verified
arithmetic said it should be exactly **0**. Disassembling the
responsible line, `carry := prod shr 16`, showed it wasn't a shift
instruction at all, but a far call into Turbo Pascal's own
(unsymboled, precompiled) runtime library at `455C:08B8`. That routine
appears to return the wrong 16-bit half of a 32-bit value on this
specific compiler/hardware combination, for a plain 32-bit
shift-by-16, an operation used constantly throughout the bignum code.

**The fix**: bypass the runtime call entirely using a variant record
(`TLongWords`) to read a `LongInt`'s high word directly via memory
layout instead of via `shr 16`. Verified bit-identical to the correct
`shr 16` result across 20,000 random 32-bit values in Python, then
confirmed on real hardware: a full run (all five test exponents,
1,352 lines of diagnostic trace) came back completely clean, with
every intermediate value matching hand-verified math from earlier in
this investigation.

**Independent confirmation, months later, against the actual 7.01
build.** Located a copy of Turbo Pascal 7.01 itself (the "silent
maintenance release" that fixed this, per emsps.com/oldtools/borpasv.htm,
timestamped 03/03/93, 07:01:00, matching the documented signature) and
tested it directly: a scratch build with the `HiWord` fix deliberately
reverted back to the plain, historically-buggy `carry := prod shr 16`
line, compiled and run on real Pocket 386 hardware under genuine 7.01.
Came back clean, bug-free, no corruption. That's a real reproduction
of a 33-year-old documented compiler bug and its fix, on the actual
hardware class it affected, using the actual compiler that fixed it,
not just a workaround that happens to sidestep the question. That
scratch build is preserved as `701TEST.PAS` in this folder (see
"Files" above) so anyone else running old Borland compilers on real
386+ hardware can run the same check.

## Memory diagnostic detour (concluded)

**Where it started.** While confirming CPU Check/Prime Check on the
first Pocket 386 unit, an independent, period-appropriate DOS
diagnostic (CheckIt) found a genuine, reproducible extended-memory
fault, initially read as bit 3 stuck at specific addresses sharing an
identical low-order offset (`xxx704h`). Not related to the SHR16
compiler bug above (that lived in conventional memory, on the stack),
a separate, real hardware issue on that one unit. The second unit's
CheckIt run came back clean.

**What got built chasing it.** What started as "does the existing XMS
Scanner also catch this" grew into its own substantial diagnostic
project: v1 fill/read-back patterns, then v2 (walking-bit, address-
in-address, March C-) after v1 came back clean inside the fault's own
address range, then AddrGallop (a purpose-built address-line test)
after analyzing CheckIt's actual reported addresses revealed the real
signature: every failing address shared the identical remainder
modulo 8192 bytes (bit 13 of the address), the fingerprint of an
unreliable address line, not a stuck data bit, matching CheckIt's own
"Address Lines" failure classification. When AddrGallop came back
clean too, the project went a level lower still: Direct Physical
Test, using `INT 15h/AH=87h` to read and write literal physical
addresses directly, bypassing XMS and HIMEM entirely, first as a
single hardcoded pair, then a bulk chunk transfer, then generalized
into full sweeps of the whole grabbed block.

**What was actually learned.** The address-line fault is real and
reproduced independently by both CheckIt (3.0 and v4) and, on one
occasion, this project's own XMS Scanner (test 20, walk-0 bit 1,
caught it twice). But every attempt to pin it down further ran into
diminishing returns: single-word tests (AddrGallop, Direct Physical
Test) stayed clean across the exact address CheckIt flagged and its
bit-13 sibling, while only a full 1 KB bulk transfer ever caught it,
suggesting either a genuinely intermittent fault or a bulk/sustained-
access sensitivity that isolated single-word tests can't provoke. The
final full-block mapping-verification sweep, built to settle whether
this project's own "does the XMS block start at physical `0x100000`"
assumption was even correct, failed at essentially every sampled
point across the whole ~7 MB range, including regions CPU Check,
Prime Check, and dozens of earlier XMS Scanner patterns had all
independently confirmed clean. That pattern (uniform, total failure,
everywhere) points at a bug in this project's own offset assumption,
most likely HIMEM reserving some space before the first allocatable
XMS byte, rather than newly-discovered widespread hardware corruption.
That question was never resolved before the project was deliberately
stopped here.

**Decision.** Concluded. A mature, dedicated tool (CheckIt) already
does this job well and remains the recommended way to diagnose memory
on this hardware; reinventing it wasn't the point, and each fix raised
a new, deeper question rather than converging on an answer. All of
that code (XMS Scanner, AddrGallop, Direct Physical Test, and every
supporting Python verification script) is preserved, working, and
documented in its own project, [MemTest386](../MemTest386/), in case
it's useful for reference or picked back up later as its own thing.
Prime386 itself returns to its original, narrower scope: the CPU
self-verifying stress test, plus the new Search feature.

## Status

**Stage 1 (CPU test), complete and confirmed.** The CPU Check menu
option runs the known exponent set, compiles and runs clean on the
physical Pocket 386, all five test cases pass, verified against a
full diagnostic trace.

**Stage 2 (Prime Check), complete and confirmed.** Zero mismatches
across 105,590+ sweeps of all 18 candidate exponents on real hardware.

**Stage 3 (Search), written and Python-verified, not yet run on real
hardware.** Trial-division-derived Mersenne-exponent set matches the
existing, hardware-confirmed `CandExp` table exactly.

**The SHR16 compiler-bug investigation, independently confirmed
closed.** Tracked down a genuine copy of Turbo Pascal 7.01 (verified by
its file timestamp, `03/03/93, 07:01:00`, matching the documented
signature) and ran a scratch build reverting the `HiWord` fix back to
the original buggy `shr 16` line, on real Pocket 386 hardware. Came
back clean. That's a real reproduction of both the original bug and
Borland's fix, on the same hardware class and against the actual
historical compiler, not just a workaround that sidesteps the
question. Preserved as `701TEST.PAS` for anyone else in the same
situation.

**The memory diagnostic detour is concluded**, see above for the
summary; full detail lives in [MemTest386](../MemTest386/).

## Next steps

- Run Search on real hardware.
- Consider extending Search's range beyond `MaxP` (61) toward the next
  real Mersenne exponent (89), which needs a wider bignum (`NLIMB` > 4)
  and fresh Python verification of the whole arithmetic stack at that
  width before touching Pascal, a natural future step, not urgent.
- Add the tick/date-based elapsed-time display for burn-in runs.
- Add exit-summary logging (final results only, no periodic writes,
  out of respect for the CF card).

## Version history

- Initial CPU-test core written, verified in Python, and confirmed
  syntactically clean after fixing a premature-comment-closure bug
  found via a real compile attempt on hardware.
- First real-hardware run surfaced unexplained corruption of a simple
  parameter value. Ruled out the algorithm and the source (Python
  re-verification, Free Pascal, and DOSBox-hosted real TP7 all run it
  correctly), left open as a likely physical hardware fault pending
  a same-binary test on the second unit.
- Second unit produced byte-identical corruption to the first, ruling
  out a hardware cause. Turbo Debugger traced the actual root cause to
  Turbo Pascal's own runtime library returning the wrong half of a
  32-bit value for `shr 16`. Fixed by bypassing the runtime call
  entirely with a variant-record memory overlay (`TLongWords`/
  `HiWord`). Confirmed clean: all five test exponents pass, full
  diagnostic trace matches hand-verified arithmetic throughout. Stage
  1 complete. See "Resolved" above, or
  [README.md](README.md) for the full story.
- Expanded into a menu-driven program: CPU Check (the original
  single-purpose core), Prime Check (a continuous stress loop over
  all 18 primes <= 61, checking each against its known correct
  primality result), and an XMS Scanner (extended-memory fill/read-back
  test). The original single-purpose CPU-test source was frozen as
  `Prime386-alpha.PAS` to preserve the exact version the SHR16 saga is
  about.
- CheckIt (an independent, period-appropriate DOS diagnostic) found a
  genuine, reproducible extended-memory fault on the first Pocket 386
  unit. Confirmed the SHR16 compiler bug and this fault are unrelated.
- Tracked down an actual copy of Turbo Pascal 7.01, confirmed genuine
  by its file timestamp (03/03/93, 07:01:00, matching the documented
  signature for the disk-mastering batch). Built a scratch diagnostic
  reverting the `HiWord` fix back to the original buggy `shr 16` line,
  compiled and ran it on real Pocket 386 hardware under 7.01: clean,
  no corruption. Independent, real-hardware confirmation of both the
  original bug and Borland's fix, using the actual historical compiler
  rather than a workaround. Preserved as `701TEST.PAS` so anyone else
  running old Borland compilers on real 386+ hardware can check their
  own.
- Began a memory-diagnostic detour chasing the CheckIt-found fault
  further than the original XMS Scanner could: v2 fill patterns
  (walking-bit, address-in-address, March C-), AddrGallop (an
  address-line-specific test after analyzing CheckIt's own reported
  addresses revealed a bit-13 signature), and Direct Physical Test
  (bypassing XMS/HIMEM entirely via raw BIOS physical-address access,
  single-word then bulk then full-block sweeps). Extensive real-
  hardware testing across all of these reproduced the fault
  inconsistently and raised an unresolved question about this
  project's own offset-mapping assumptions, without ever fully
  characterizing the fault. See "Memory diagnostic detour" above for
  the summary.
- **Scope refocus.** Decided the memory-diagnostic direction was
  feature creep relative to Prime386's actual purpose (a Prime95
  analogue, not a general memory diagnostic suite, a job CheckIt
  already does well). Extracted all of that code, working and intact,
  into its own project, `MemTest386`, preserved for reference. Added
  **Search**, a genuine open-ended scan (trial-division-checked
  exponents, no lookup table) rather than Prime Check's fixed self-
  verifying set, closer to what GIMPS' own search actually does, even
  though this hardware's bignum width means it can only ever rediscover
  already-long-known results. `PRIME386.PAS` returns to CPU/arithmetic-
  only scope: CPU Check, Prime Check, Search.
