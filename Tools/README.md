# Tools

Modern helper scripts used to develop the retro code in this repo, not
retro code themselves, so they live outside the
`<processor>/<machine>/<language>` tree.

The working style throughout this repo is to verify logic in Python
against ground truth before committing to Pascal, since there's no
Turbo Pascal compiler available in the development sandbox and TP7's
own arithmetic semantics (shift direction, overflow-check defaults)
have a documented history of surprises. These scripts are that
verification, not just assertions in a README, each one is runnable
and checkable. All of them run standalone with a plain
`python3 <script>.py`. 

Requires Python 3.9+ overall, though that's only because of life_seed_search.py's use of built-in generic type hints (list[int], tuple[int, int]); the other 13 scripts only need 3.6+ for f-strings.

## Bignum & Lucas-Lehmer algorithm verification

The core Prime386 arithmetic, verified at the algorithm level before
any Pascal was written.

- **`bignum_sim.py`**, base word-array (base 2^16) bignum
  implementation: squaring, the Mersenne shift-add mod-reduction
  trick, and a full Lucas-Lehmer simulation, all at word granularity
  rather than relying on Python's native bigints, to validate carry
  propagation and iteration counts the way Pascal will actually have
  to do it.
- **`fuzz_test.py`**, fuzzes `square_words` (20,000 trials) and
  `mod_mersenne_words` (34,000+ trials across p=3..89, including both
  16-bit-aligned and non-aligned p) against Python's native `**` and
  `%`. Runs standalone.
- **`iter_check.py`**, checks how many iterations
  `mod_mersenne_words`' reduction loop actually needs across a range
  of p, to confirm the "2 iterations is the worst case" assumption
  baked into the Pascal source. Runs standalone.
- **`bignum_sim2_lucas_lehmer.py`**, the full Lucas-Lehmer loop
  including the mod-2 subtraction step, checked against every exponent
  in the real test set plus known-composite exponents (11, 23, 29, 37,
  41, 53), to confirm it correctly rejects non-Mersenne-primes too,
  not just passes the primes. Runs standalone.
- **`pascal_structure_check.py`**, a faithful line-by-line
  transliteration of `PRIME386.PAS`'s actual helper breakdown
  (`SquareWords`, `AddBigTrunc`, `CompareBig`, `ModMersenneWords`,
  `Sub2Mod`, `LucasLehmerTest`), not just the underlying algorithm
  from `bignum_sim.py`, to catch transcription bugs specifically.
  Runs standalone.
- **`strict_trace_bounds_checked.py`**, bounds-checked simulation
  (any out-of-bounds array access raises immediately) run against the
  exact deterministic value sequence for the five real test exponents,
  mirroring what Pascal's `{$R+}` would catch that `{$R-}` currently
  lets through silently. Runs standalone.

## Turbo Pascal 7.00 SHR16 bug investigation

Reconstructs and verifies the actual runtime-library bug and its fix,
see [the Prime386 saga](../80386/Pocket386/Turbo-Pascal-7/Prime386/README.md)
for the full story.

- **`shr16_bug_reconstruction.py`**, reconstructs `SquareWords`'
  first pass under the hypothesis that TP 7.00's buggy `shr 16` was
  returning the low word instead of the high word, and checks the
  result against what was actually observed live in Turbo Debugger on
  the physical hardware (`carry=16`, `prod=16`, and the exact runaway
  array state). Exact match confirmed the hypothesis before trusting
  it as the explanation. Runs standalone.
- **`hiword_equivalence.py`**, verifies the fix (`TLongWords`/
  `HiWord`, a variant-record memory overlay) is bit-identical to a
  correct `x shr 16` across the full 32-bit range (20,000 random
  trials), before trusting it as a replacement for the broken runtime
  call. Runs standalone.

## Timing design (elapsed-time display for burn-in runs)

Verification for the not-yet-implemented elapsed-time feature, design
decided but still on the "Next steps" list in TECHNICAL.md.

- **`tick_accumulator.py`**, verifies a midnight-rollover-safe
  elapsed-time accumulator based on the raw BIOS tick counter,
  detecting rollover by watching for a decrease in consecutive raw
  readings rather than trusting `INT 1Ah`'s midnight flag (known
  unreliable across BIOS vendors). Documents a known limitation: a
  polling gap over 24 hours silently under-counts by exactly one day's
  worth of ticks per missed rollover. This approach was ultimately not
  used, superseded by the DOS-date approach below. Runs standalone.
- **`date_elapsed.py`**, verifies the approach actually used
  instead: linearizing DOS `GetDate`/`GetTime` readings via Howard
  Hinnant's `days_from_civil` algorithm and subtracting, checked
  against Python's `datetime` across 100,000+ fuzzed date/time pairs
  spanning leap years and month/year boundaries. No manual
  midnight-rollover handling needed at all, DOS's own date advancement
  handles it. Runs standalone.

## XMS memory-test pattern design

Work toward the current top "Next steps" item in TECHNICAL.md: adding
walking-bit, address-in-address, and march-algorithm coverage to the
XMS Scanner, since a confirmed hardware fault on one test unit sat
inside fully-covered fill/read-back testing and still came back clean.

- **`march_verify.py`**, injects each classic memory-fault type
  (stuck-at, coupling, address-aliasing) one at a time into a
  simulated memory and confirms the March C- algorithm actually
  detects each one, before trusting the same sequence in Pascal.
- **`addr_pattern_verify.py`**, checks the collision behavior of a
  simple `pattern = low16(byteOffset)` address-in-address scheme
  against the real block size seen in the overnight burn-in run
  (7104 KB). Finding: this naive scheme collides every 64KB (only
  65,536 distinct pattern values exist, so most of a multi-megabyte
  block reuses the same expected value at many different addresses),
  bijective only within a single 64KB window. Worth resolving before
  implementing address-in-address in Pascal, a per-64KB-window varying
  pattern (or similar) would be needed for full-block coverage.
- **`pascal_translit_verify.py`**, transliterates the planned new
  Pascal logic (`InitPatterns`, `TestChunkAddr`'s expected-value
  formula, `RunMarchBlock`'s phase structure) into Python and runs it
  against a simulated XMS block with injected faults, to catch
  transcription bugs in the Pascal itself rather than just the
  algorithm concept already checked in `march_verify.py`. Runs
  standalone.

## Game of Life seed search

- **`life_seed_search.py`**, simulates Jon Millen's 1D Life rule on a
  ring of any size, to find seed values with interesting dynamics
  (long transient before settling, long repeating cycle once settled)
  before committing to testing them on real hardware. This is the
  actual methodology behind the seed choices documented for
  `LIFE8.ASM` (seed 27) and `LIFE16.ASM` (seed 5471) in
  [Z80/IMSAI/README.md](../Z80/IMSAI/README.md), not just an
  assertion, something you can rerun and verify. Requires Python
  3.9+ (uses `list[int]`-style type hints). Takes a required `n`
  argument (ring size); run with `-h` for the full option list.

