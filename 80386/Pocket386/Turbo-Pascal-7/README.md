# HL386.pas

A [Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) screensaver for the Pocket 386, written in Turbo
Pascal 7.0 -- part of the same Life-family of screensavers found elsewhere
in this repository, but with a data-logging component alongside
the visuals rather than just running for its own sake.

## Two versions

- **`HL386.pas`** -- the speed-improved version. Identical behavior and
  output to `HL386_Brent.pas` below, but `FindMu` (see "What it does")
  usually skips most of its replay by starting from a previously-saved
  checkpoint instead of generation 0, when provably safe to do so.
  This is the one to use.
- **`HL386_Brent.pas`** -- the reference version: straightforward,
  textbook two-phase Brent's algorithm, no shortcut. `FindMu` always
  replays from generation 0. Kept alongside the optimized version as a
  known-simple baseline for comparison, and as a fallback if the
  shortcut in `HL386.pas` is ever suspected of misbehaving.

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
working directory, with four fields:

```
Seed,Mu,EstimatedMuSeconds,Period
```

- **Seed** -- the starting seed value for that run
- **Mu** -- the exact generation at which the pattern first entered its
  repeating cycle
- **EstimatedMuSeconds** -- an estimate (not a direct measurement) of real
  elapsed seconds at generation Mu, scaled proportionally from measured
  timing elsewhere in the run
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

`HL386.pas`: compiled and running on the actual Pocket 386. The
previous-checkpoint shortcut in `FindMu` is confirmed working -- no long
silent wait on convergence, and the CSV output matches
`HL386_Brent.pas`'s `Mu` and `Period` exactly for the same seeds (only
`EstimatedMuSeconds` differs slightly between runs, as expected for a
wall-clock estimate). The corrected interrupted-seed exit message is
also confirmed:

```
Run stopped by user request.
Seed 3 was interrupted -- not logged.
Last completed seed: 2
```

## Next Steps

Add tick counter variable to better track actual seed time.

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

