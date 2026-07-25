# Prime386

A "Prime95-like" CPU/memory stress test for the Pocket 386 (ALi M6117
SoC, 386SX/40, no FPU, DOS 6.22, Turbo Pascal 7.0).

## Why

Prime95 stress-tests a PC by running a computation with a known correct
answer, repeatedly -- a single bit-flip from bad RAM or a flaky ALU
produces a detectably wrong result rather than silently corrupting
something unnoticed. It does this via the Lucas-Lehmer primality test
for Mersenne primes, using FFT-based multiplication that leans on
modern floating-point hardware.

The 386SX in the Pocket 386 has no FPU. Prime386 applies the same
self-verifying principle -- known exponent in, known correct answer
out -- using pure integer/bignum arithmetic instead.

## Two-mode design

- **CPU test**: Lucas-Lehmer, run against exponents p for which
  `2^p - 1` is a *known* Mersenne prime (13, 17, 19, 31, 61). Any run
  that doesn't end at s=0 indicates an ALU/arithmetic fault.
- **Memory test** (not yet written -- planned next): an XMS-based scan
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
  true division -- split the value into high/low p-bit halves and add
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
`GetDate`/`GetTime` instead -- DOS's date-keeping already handles
midnight rollover correctly (same underlying timer interrupt chain),
so hand-rolled rollover logic isn't needed. The day-number
linearization this requires was verified against Python's `datetime`
across 100,000+ fuzzed date/time pairs spanning leap years and
month/year boundaries.

That raised a real question before settling on it for good: could an
RTC-level Daylight-Savings-Enable bit silently jump the clock by an
hour mid-run, independent of DOS? (DOS 6.22 itself has no DST logic --
that was a Windows Control Panel feature -- but the RTC hardware could,
in principle, regardless of the OS.) Checked directly on the actual
hardware via `DEBUG` (`O 70 0B` / `I 71`) rather than assuming: reads
back `02`, meaning bit 0 (DSE) is 0 -- disabled. With that confirmed,
`GetDate`/`GetTime`-based elapsed timing is safe on this machine, and
is the final approach used -- no tick-counting fallback needed.

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

## Status

**Stage 1 of 2**, CPU-test core only -- `PRIME386.PAS` currently
contains just the bignum/Lucas-Lehmer engine and a test harness that
runs the known exponent set and prints PASS/FAIL. Not yet compiled
successfully on real hardware (in progress). No XMS module, menu,
elapsed-time display, or exit-summary logging yet -- those are next,
once this core is confirmed clean on both Pocket 386 units.

## Next steps

- Get `PRIME386.PAS` compiling and running clean.
- Add the XMS extended-memory scanner module.
- Add the tick/date-based elapsed-time display for burn-in runs.
- Add the two-mode menu with stop/switch, and exit-summary logging
  (final results only -- no periodic writes, out of respect for the
  CF card).
- v2: march-algorithm memory patterns, for coupling-fault coverage.

## Version history

- Initial CPU-test core written, verified in Python, and confirmed
  syntactically clean after fixing a premature-comment-closure bug
  found via a real compile attempt on hardware.
