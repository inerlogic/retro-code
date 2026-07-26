# Prime386

A "Prime95-like" CPU/memory stress test for the Pocket 386 (ALi M6117
SoC, 386SX/40, no FPU, DOS 6.22, Turbo Pascal 7.0).

## Why

Prime95 stress-tests a PC by running a computation with a known correct
answer, repeatedly, a single bit-flip from bad RAM or a flaky ALU
produces a detectably wrong result rather than silently corrupting
something unnoticed. It does this via the [Lucas-Lehmer primality test](https://en.wikipedia.org/wiki/Lucas%E2%80%93Lehmer_primality_test)
for Mersenne primes, using FFT-based multiplication that leans on
modern floating-point hardware.

The 386SX in the Pocket 386 has no FPU. Prime386 applies the same
self-verifying principle, known exponent in, known correct answer
out, using pure integer/bignum arithmetic instead.

## Files

- **`PRIME386.PAS`** — the current program. Menu-driven, three test
  modes plus quit.
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
  primes (the 4-word bignum tops out at p=61, so there's nothing left
  to discover in range). Sweeps all 18 primes <= 61 each pass, checking
  each against its already-known correct answer (9 expected prime, 9
  expected composite); any mismatch either direction means a hardware
  fault. Loops until ESC. Confirmed working on real hardware: over
  100 sweeps, clean the whole way through, zero mismatches.
- **XMS Scanner**: extended-memory scan using simple fill/read-back
  patterns (0xAA/0x55), separate from the CPU tests since the tiny
  bignum footprint does essentially nothing to stress RAM on its own.
  One compile-time bug found and fixed along the way (a `var`
  parameter written to from inline asm needed an extra level of
  indirection that the compiler couldn't generate in one step;
  replaced with a global variable instead). Confirmed working on real
  hardware: a full run across the largest available XMS block came
  back with zero faults on both patterns. Reworked to grab every free
  block, largest-first, until none remain, rather than only the
  single largest one, so fragmented free memory gets covered too;
  confirmed functionally correct on non-fragmented single-block cases,
  the actual multi-block aggregation path hasn't been exercised on
  real fragmented memory yet. Walking-bit and address-in-address
  patterns, plus a proper march algorithm for coupling faults, are
  deferred to v2.

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

## Timing (for the memory-scan burn-in mode)

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
is the final approach used, no tick-counting fallback needed.

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
17, 19, 31, or 61,reading as a garbage value partway through a
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
- **Free Pascal** (`fpc -Mtp`, native Linux target): Sanity check with a known, known.
  compiled clean, all five test cases pass, zero corruption.
- **Real Turbo Pascal 7.0 under DOSBox** (the actual TP7 compiler,
  emulated hardware): four separate runs, zero corruption, all five
  tests pass every time. WTF?

The turning point: recompiling the identical source from scratch on a
*second, physically different* Pocket 386 unit produced byte-for-byte
identical wrong output to the first machine's most recent build. Two
independent physical RAM chips producing the exact same "random"
corruption isn't something bad hardware does, that result is the
signature of something fully deterministic, and ruled out a hardware
fault as the cause.

An independent memory diagnostic (CheckIt) did separately confirm a
real, unrelated extended-memory parity fault on the first unit (see
below), a genuine hardware issue, just not the one causing this bug.

Turbo Debugger (once actually located,it had been present the whole
time) made the real cause visible directly: a loop counter (`k`) that
should never exceed 7 was observed climbing past 130 in real time,
because a `carry` variable held **16** at a point where hand-verified
arithmetic said it should be exactly **0**. Disassembling the
responsible line,`carry := prod shr 16`,showed it wasn't a shift
instruction at all, but a far call into Turbo Pascal's own
(unsymboled, precompiled) runtime library at `455C:08B8`. That routine
appears to return the wrong 16-bit half of a 32-bit value on this
specific compiler/hardware combination, for a plain 32-bit
shift-by-16,an operation used constantly throughout the bignum code.

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

## Hardware finding, independent of the above (still worth knowing)

CheckIt (the real, period-appropriate DOS diagnostic, not the
unrelated modern Windows product of the same name) found a genuine,
reproducible extended-memory parity fault on the first Pocket 386
unit,consistently on bit 3, at addresses sharing an identical
low-order offset (`xxx704h`), across dozens of hits in a full test
pass. This is unrelated to the bug above (which lived in conventional
memory, in the stack) but is a real, separate hardware issue on that
specific unit, worth factoring in if that machine is used for
anything that touches extended memory (Windows, XMS-using software).
The second unit's full CheckIt test came back clean.

## Status

**Stage 1 (CPU test), complete and confirmed.** The CPU Check menu
option runs the known exponent set, compiles and runs clean on the
physical Pocket 386, all five test cases pass, verified against a
full diagnostic trace.

**Stage 2 (menu, Prime Check, XMS Scanner), core testing complete
and confirmed.** The menu and all three modes exist in `PRIME386.PAS`.
XMS Scanner and Prime Check are both confirmed working on real
hardware, zero faults on XMS Scanner's full-block run, zero mismatches
across 3000+ Prime Check sweeps. XMS Scanner now grabs every free
block rather than only the single largest one (handles fragmented
free memory), confirmed functionally correct on non-fragmented single-
block cases; the actual multi-block aggregation path hasn't been
exercised on real fragmented memory yet. No elapsed-time display or
exit-summary logging yet.

**Faulty-unit test (all three modes), passed, and coverage is now
confirmed, not just assumed.** All three modes were run on the first
Pocket 386 unit, the one CheckIt found a genuine extended-memory
parity fault on (see "Hardware finding" above). CPU Check, Prime
Check, and XMS Scanner all came back clean.

That result needed a real coverage check before it could be trusted,
since the XMS Scanner grabs the largest free block reported and there
was no guarantee that block actually reached the address CheckIt
flagged. Working it out: CheckIt's full test found 27 failing
addresses (`401704h` through `47D704h`), all sharing the same low-order
offset (`xxx704h`) and all failing on bit 3, clustering into two bands
around 4.00 to 4.11 MB and 4.44 to 4.51 MB physical. Subtracting the
1 MB start of extended memory (`100000h`) puts that fault band at
roughly **3078 KB to 3574 KB into extended memory**. The scanner's
run on that unit grabbed **7104 KB** in one contiguous block, which
comfortably covers the fault band with over 3500 KB of margin on top.
Assuming the handle's offset 0 lines up with the start of usable
extended memory (the normal case for a single free block reported by
the driver), the scan's address range did include the exact region
CheckIt flagged.

So this is a real result: the specific offset range is confirmed
tested, not just assumed, and it still came back clean. That's worth
sitting with rather than either dismissing or over-trusting. A
hardware fault that CheckIt catches but a flat 0xAA/0x55 fill/
read-back doesn't isn't a contradiction, it's a plausible sign that
this fault needs a different test pattern to expose (see "Next steps"
below), or that it's intermittent/marginal rather than consistently
present. It doesn't mean the XMS Scanner's fill/read-back logic is
broken, both the CPU Check and Prime Check paths are independently
confirmed working, and the XMS Scanner's move/compare mechanics were
separately confirmed clean on the known-good second unit.

## Next steps

- Add the tick/date-based elapsed-time display for burn-in runs.
- Add exit-summary logging (final results only, no periodic writes,
  out of respect for the CF card).
- Walking-bit and address-in-address XMS patterns, plus a proper march
  algorithm for coupling faults: bumped up in priority given the
  faulty-unit result above. A confirmed hardware fault sat inside a
  fully-covered fill/read-back test and still came back clean, which
  suggests the simple pattern may not be catching what CheckIt catches
  on this specific chip.

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
  primality result), and XMS Scanner (extended-memory fill/read-back
  test, v1 patterns only). The original single-purpose CPU-test
  source was frozen as `Prime386-alpha.PAS` to preserve the exact
  version the SHR16 saga is about. One compile error found and fixed
  in the XMS Scanner (a `var` parameter can't be written to directly
  from inline asm without an extra indirection step; replaced with a
  global variable). XMS Scanner confirmed clean on real hardware
  (zero faults across the largest available block, both patterns).
  Prime Check confirmed clean on real hardware (100+ sweeps, zero
  mismatches).
- XMS Scanner reworked to grab every free block, largest-first, until
  none remain (up to a 32-block safety cap), instead of only the
  single largest block, so fragmented free memory gets covered too.
  Tested on both Pocket 386 units and under Windows specifically to
  try to force fragmentation; free XMS came back as one contiguous
  block every time, so the loop's no-fragmentation path (grab one
  block, next query returns 0, stop) is confirmed, but the actual
  multi-block aggregation logic remains unexercised on real hardware.
- Worked out the address math on the original faulty-unit clean run:
  CheckIt's 27 failing addresses convert to roughly 3078 to 3574 KB
  into extended memory, which the 7104 KB block that run grabbed
  fully covers. So that clean result reflects genuine coverage of the
  known fault's address range, not a coverage gap, raising walking-bit
  and march-algorithm patterns from planned-but-unscheduled to a
  priority next step, since a flat fill/read-back may not be
  sufficient to expose this specific fault.
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
