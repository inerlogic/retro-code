# Pocket 386

80386-based pocket computer. Technically an 80386 family computer, specifically, it is a highly integrated System-on-a-Chip (SoC) that contains a 40 MHz 386SX core along with built-in chipset functions, like memory and peripheral controllers.

## Languages used here

- [Turbo-Pascal-7.0](Turbo-Pascal-7/) — Game of Life screensaver/logger and a "Prime95-like" CPU/memory stress test

## Hardware notes

- **No reliable CMOS-backed clock.** This unit's RTC isn't backed by a
  persistent CMOS battery (only the main battery), so the date/time
  resets to an arbitrary epoch on cold boot rather than holding a real
  wall-clock value -- confirmed directly by a file timestamp coming back
  as `12/31/1979 11:00:00 PM`, one minute before DOS's own epoch. Any
  project needing elapsed-time tracking across a boot should account
  for this; the BIOS timer-tick counter is unaffected by it, and
  `GetDate`/`GetTime` are fine *within* a single session once the clock
  is running, just not trustworthy as an absolute date/time.
- **Daylight-Savings-Enable (DSE) bit confirmed disabled.** Checked
  directly via `DEBUG` (`O 70 0B` / `I 71` against the RTC's Status
  Register B): reads back `02`, meaning bit 0 (DSE) is off. Combined
  with DOS 6.22 having no DST logic of its own (that was a Windows
  Control Panel feature), this machine's clock has no seasonal
  auto-adjustment to worry about during a long unattended run.
