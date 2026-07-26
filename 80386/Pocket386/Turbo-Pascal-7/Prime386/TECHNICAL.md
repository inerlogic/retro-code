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

## Two-mode design

- **CPU test**: Lucas-Lehmer, run against exponents p for which
  `2^p - 1` is a *known* Mersenne prime (13, 17, 19, 31, 61). Any run
  that doesn't end at s=0 indicates an ALU/arithmetic fault.
- **Memory test** (not yet written,planned next): an XMS-based scan
  of extended memory using simple fill/read-back patterns (0xAA/0x55,
  walking bit, address-in-address), separate from the CPU test since
  the tiny bignum footprint here does essentially nothing to stress
  RAM on its own. A proper march algorithm (to catch coupling faults,
  not just stuck-at faults) is planned as a v2 once this v1 pattern
  set is confirmed working.

Menu-driven, two independent modes, with the ability to stop a running
test and switch modes.

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
The second unit's quick CheckIt test came back clean; a full test on
it, for a fair comparison, is still outstanding.

## Status

**Stage 1 of 2, complete and confirmed.** `PRIME386.PAS` contains the
bignum/Lucas-Lehmer engine and a test harness running the known
exponent set. Compiles and runs clean on the physical Pocket 386 --
all five test cases pass, verified against a full diagnostic trace.
No XMS module, menu, elapsed-time display, or exit-summary logging
yet,those are next.

## Next steps

- Add the XMS extended-memory scanner module.
- Add the tick/date-based elapsed-time display for burn-in runs.
- Add the two-mode menu with stop/switch, and exit-summary logging
  (final results only, no periodic writes, out of respect for the
  CF card).
- v2: march-algorithm memory patterns, for coupling-fault coverage.
- Optional: full CheckIt test on the second unit, for a fair
  comparison against the first unit's confirmed extended-memory fault.

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
