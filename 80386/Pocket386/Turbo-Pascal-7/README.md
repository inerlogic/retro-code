# HL386T.pas

A [Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) screensaver for the Pocket 386, written in Turbo
Pascal 7.0 -- part of the same Life-family of screensavers found elsewhere
in this repository, but with a data-logging component alongside
the visuals rather than just running for its own sake.

## Two versions

- **`HL386T.pas`** -- the one to use. Same previous-checkpoint shortcut
  in `FindMu` as the earlier `HL386.pas` (now retired), plus real
  measured timing: `CycleCandidate` preserves the actual BIOS-tick count
  alongside each checkpoint's state, and `FindMu` accumulates real
  elapsed ticks during its own replay rather than estimating from the
  original detection run's timing. CSV's third column is `MuSeconds` --
  a genuine measurement, not an estimate.
- **`HL386_Brent.pas`** -- the reference version: straightforward,
  textbook two-phase Brent's algorithm, no shortcut, and still the
  original proportional-estimate timing (`EstimatedMuSeconds`), left
  unchanged deliberately to preserve a known-simple baseline that
  doesn't need re-testing every time the optimized version changes.
  Kept alongside `HL386T.pas` as a comparison point and a fallback if
  the shortcut is ever suspected of misbehaving.

## What it does

The screen fills with a continuously-evolving cellular automaton on a
244x38 toroidal grid (9,272 cells), packed 4 cells per hex digit for a
dense, colorful full-screen display in VGA's 80x50 text mode. Rather than
seeding once and running forever, the program works through consecutive
starting seeds automatically: it seeds a grid, runs it until the pattern
provably settles into a repeating cycle, logs data about that seed to a
CSV file, then moves on to the next seed and repeats -- a continuous,
unattended sweep across seed space.

Detecting "provably settled" on bounded memory, for a cycle of *any*
length rather than only short ones, uses [Brent's cycle-detection algorithm](https://en.wikipedia.org/wiki/Cycle_detection#Brent's_algorithm).
When a candidate cycle is found, the program briefly pauses
the visible simulation to calculate the *exact* generation at which the
pattern actually converged (rather than just the generation at which
convergence was confirmed, which can overshoot the true point) -- shown
on screen as a small animated ASCII hourglass and step counter, since this
calculation can itself take a little while and would otherwise look like
the program was hung.

## CSV output

Each convergence appends a row to `LIFELOG.CSV`, in the program's own
working directory, with four fields. The first three fields mean the
same thing in both files; the fourth column's name and meaning differs
between them:

```
HL386T.pas:       Seed,Mu,MuSeconds,Period
HL386_Brent.pas:  Seed,Mu,EstimatedMuSeconds,Period
```

- **Seed** -- the starting seed value for that run
- **Mu** -- the exact generation at which the pattern first entered its
  repeating cycle
- **MuSeconds** (`HL386T.pas`) -- real elapsed seconds at generation Mu,
  accumulated tick-by-tick during `FindMu`'s own replay
- **EstimatedMuSeconds** (`HL386_Brent.pas`) -- an estimate, not a direct
  measurement, scaled proportionally from timing measured elsewhere in
  the run
- **Period** -- the exact length of the repeating cycle, in generations

Elapsed time is tracked via the BIOS timer-tick counter rather than the
system clock, since this machine's CMOS clock isn't reliable.

## Oscillating structures

Because each hex digit is just 4 packed bits, the actual Life patterns on
screen -- blinkers, traffic lights, and gliders among them -- are
decodable directly from the displayed hex values, without needing a
graphical rendering. Several have been confirmed this way on live runs,
including multiple traffic lights and at least one glider caught in the
act of consuming one. See [HEX-DECODE-REFERENCE.md](HEX-DECODE-REFERENCE.md)
for the full decoding reference and worked examples.

## Stopping the program

Pressing ESC stops the sweep (checked periodically during both the main
simulation and the convergence calculation, not just between seeds). On
exit, the program reports which seed was interrupted and which one was
actually last completed and logged -- these are deliberately not the
same number:

```
Run stopped by user request.
Seed 31 was interrupted -- not logged.
Last completed seed: 30
```

Resuming later means typing the next seed number in by hand at the
starting prompt -- the program doesn't read the CSV to figure out where
it left off automatically.

## Hardware & software

- **Hardware:** Pocket 386, an ALi M6117-based 386SX-compatible mini
  laptop. No official product page exists beyond its AliExpress
  storefront; for an overview, see
  [Liliputing's write-up](https://liliputing.com/pocket-386-is-a-mini-laptop-for-retro-computing-with-support-for-dos-and-windows-95/).
- **Software:** Turbo Pascal 7.0, sourced from
  [WinWorld](https://winworldpc.com/product/turbo-pascal/7x).

## Status

Confirmed on real hardware, both files, in full.

`HL386_Brent.pas`: compiled and running on the actual Pocket 386. The
hourglass progress indicator animates correctly, and the CSV output
format (`Seed,Mu,EstimatedMuSeconds,Period`) is correct.

`HL386T.pas`: compiled and running on the actual Pocket 386, and
validated far beyond a first smoke test. The previous-checkpoint
shortcut in `FindMu` is confirmed working -- no long silent wait on
convergence -- and the real tick-based `MuSeconds` has been cross-checked
against `HL386_Brent.pas`'s `Mu` and `Period` (which match exactly for
the same seeds, as expected from a deterministic simulation). Beyond
that: run continuously across two separate Pocket 386 units in parallel
over several days, covering seeds 1-570 with zero gaps and zero
duplicates in the combined log, including multiple unattended stretches
of 20+ hours each. One logging anomaly turned up early in this process
and never recurred -- see "Version history" for what happened and how it
was chased down. The corrected interrupted-seed exit message is also
confirmed:

```
Run stopped by user request.
Seed 3 was interrupted -- not logged.
Last completed seed: 2
```

## Version history

- **Rewritten from the Z80/CP/M source for the 386SX specifically.**
  Earlier Life screensavers in this repository target Z80/Z180 hardware
  under CP/M; this one is a ground-up rewrite for the 386SX/ALi M6117
  box, not a direct port, so several 8-bit-era compromises got dropped
  along the way (see below).
- **Grid size and layout went through three stages.** First attempt was
  a fully borderless 320x50 grid -- filling the screen's literal last
  row/column every generation triggered Crt's own end-of-window
  auto-scroll on every redraw, creeping the whole display upward by one
  line per generation. Fixed by shrinking to 320x44 with a margin, which
  worked but ran noticeably slower with no real benefit (more cells
  costs more, roughly in proportion, since Step/DrawGrid/ComputeChecksum
  are each a full pass over the grid every generation). Settled on the
  current 244x38 (9,272 cells), sized to match the physical screen's
  real aspect ratio while landing in a faster cell-count range.
- **Gen and the checksum were originally 16-bit Integer, not LongInt.**
  Gen was observed overflowing a 16-bit counter after ~52,000
  generations on a single stable seed. Separately, a 16-bit checksum
  was calculated to have an uncomfortably high chance of a false cycle
  match once run lengths reach into the tens of thousands of
  generations (roughly 79% cumulative chance of a spurious collision by
  generation 52,064). Both were widened to LongInt (32-bit).
- **Cycle detection was originally an 8-deep checksum history, not
  Brent's algorithm.** That approach could only ever detect cycles of
  period <= 8, no matter how long it ran -- a lone glider circumnavigating
  a torus this size has a true period in the thousands of generations,
  which an 8-deep window would never catch. Replaced with Brent's
  algorithm, which catches a cycle of any period using a single
  checkpoint that doubles in spacing instead of a fixed window.
- **Checksum matches were originally trusted directly.** Since Brent's
  only compares 32-bit checksums, not actual grid states, a checksum
  match is now treated as a candidate and verified against a real
  snapshot of the full grid before being accepted -- this is what
  actually eliminates false positives, not just makes them less likely.
- **CSV format was originally Seed,Generation,ElapsedSeconds.** Phase-1
  detection alone only tells you when a cycle was *confirmed*, which
  overshoots the true convergence point by an amount that depends on
  checkpoint-schedule luck, not on the pattern -- observed directly: two
  different seeds, having genuinely settled at different points, both
  logged an identical detection generation of 2049 (= 2048 + 1) purely
  because the checkpoint doubling happened to catch both in the same
  window. FindMu (Brent's standard second phase) was added to recover
  the true convergence point (Mu) and exact Period instead.
- **Elapsed time was originally read from GetTime/GetDate (the RTC).**
  `LIFELOG.CSV`'s own file creation date came back as 12/31/1979
  11:00:00 PM -- the classic no-working-RTC default, one minute before
  DOS's own epoch of 1/1/1980 -- confirming this machine's CMOS clock
  isn't trustworthy. Switched to the BIOS timer-tick counter instead,
  which is independent of the CMOS battery.
- **A real bug: SeedVal used to advance unconditionally.** An ESC during
  FindMu (a candidate found, but interrupted before the log write) would
  still advance SeedVal past a seed that was never actually logged --
  meaning the exit message could report the wrong seed as "last
  completed." Fixed by tying the increment to a successful log write.
  The exit message itself was also reworded at the same time, from
  "Run paused... last processed seed state was: N" to explicitly
  distinguishing the interrupted seed from the last completed one.
- **The FindMu progress indicator was added, then tuned twice.** It
  didn't exist originally -- a long FindMu replay looked identical to a
  hang, with zero on-screen feedback. Added an animated indicator, then
  sped up its update cadence roughly 10x (every 10 steps instead of
  every 100, since the original cadence was slow enough to still look
  stuck), the animation uses a classic four-frame spinner (`| / - \`).
- **The FindMu previous-checkpoint shortcut (`HL386.pas` only) is the
  newest change.** Validated against 5,000+ synthetic (mu, period) test
  cases with zero incorrect results; usable in over 99% of them, saving
  ~1,150 generations on average when it was. `HL386_Brent.pas` was kept
  as-is at this point specifically to preserve a known-simple reference
  implementation -- see "Two versions" above for what the shortcut does
  and why it's believed correct.
- **`HL386T.pas` replaced `HL386.pas` as the primary version.** The old
  `EstimatedMuSeconds` proportional estimate was always an approximation
  -- accurate enough to be useful, but not a real measurement. `HL386T`
  adds genuine tick-based timing: `CycleCandidate` now preserves the
  real BIOS-tick count alongside each checkpoint's saved state (mirroring
  how it already preserved the checkpoint's generation number and grid),
  and `FindMu` accumulates real elapsed ticks during its own replay,
  starting from that preserved value when the shortcut is used rather
  than from zero. `HL386_Brent.pas` was deliberately left on the old
  estimate -- changing it means re-testing it, and its whole purpose is
  being a stable, known-simple baseline that doesn't move.
- **A logging anomaly, chased down but never conclusively explained.**
  Early in `HL386T`'s first extended run, a session that visibly
  progressed through dozens of seeds (confirmed by the seed number
  advancing on screen) produced no new rows in `LIFELOG.CSV` at all --
  not appended, not a fresh file either. Code review turned up nothing:
  the file-open, write, and flush logic was byte-for-byte identical to
  the already-confirmed-working `HL386.pas`. Two direct hardware tests
  afterward -- creating a fresh file, then appending to an existing one
  -- both worked correctly. No write-protection on the card, a clean
  compile, and every subsequent run since (spanning a combined ~570
  seeds across two separate machines, including several unattended
  stretches of 20+ hours each) logged with zero recurrence. Leading
  theories: a stray gamma ray flipping a bit in memory, or an unknown
  time traveler suppressing vital data to protect the outcome of the
  temporal cold war. Practical takeaway: long unattended runs appear to
  be reliable, especially for casual blinkenlights-screensaver use; if
  data collection matters more, deleting `LIFELOG.CSV` before each run
  costs nothing and sidesteps whatever this was entirely.
- **Two-machine parallel validation.** Since each seed's outcome is
  fully independent and deterministic, two Pocket 386 units were run
  simultaneously on disjoint seed ranges (one climbing from a low
  starting point, the other from a high one) specifically to build
  confidence in long unattended runs faster, and to accumulate a larger
  dataset than a single machine could in the same time. The combined
  result: seeds 1-570, zero gaps, zero duplicates, confirmed by direct
  inspection of the merged log.
