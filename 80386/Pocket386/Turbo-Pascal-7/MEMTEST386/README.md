# MemTest386

Extended-memory diagnostic experiments for the Pocket 386 (ALi M6117
SoC, 386SX/40, no FPU, DOS 6.22, Turbo Pascal 7.0).

**Status: parked, not actively maintained.**

This grew out of [Prime386](../Prime386/) (its own separate project)
while chasing a specific known-faulty unit's CheckIt-confirmed
"Address Lines" fault. CheckIt itself already does this job well and
is the recommended tool for real memory diagnosis on this hardware,
there was no need to reinvent it, and this project's own investigation
ended inconclusively: a full-block mapping-verification sweep, the
last thing built here, failed at essentially every sampled point,
most likely revealing an unverified assumption in this code's own
offset math (probably HIMEM reserving space before the first
allocatable XMS byte) rather than genuine widespread hardware
corruption, since CPU Check, Prime Check, and most of this project's
own earlier passes remained clean throughout.

See [Prime386's TECHNICAL.md](../Prime386/TECHNICAL.md), "Memory
diagnostic detour" section, for the full writeup of how this started,
what was learned, and why it stopped here.

Kept here, working code and all, in case it's useful for reference or
ever picked back up as its own project.

## Files

- **`MEMTEST386.PAS`** — the program. Menu-driven: XMS Scanner,
  AddrGallop Scanner, Direct Physical Test (single-word), Direct
  Physical Test (BULK), plus quit.

## Menu design

- **XMS Scanner**: extended-memory scan through HIMEM/XMS. v1
  (0xAA/0x55 fill/read-back) is confirmed clean on real hardware,
  including coverage of the known fault's address range. v2 (walking-
  bit, address-in-address, March C-) and the fault-logging/timestamped
  on-disk log (`XMSFAULT.LOG`) have also run on real hardware, and
  caught the fault once (test 20, walk-0 bit 1).
- **AddrGallop Scanner**: a purpose-built address-line test after
  analyzing CheckIt's own reported addresses revealed a bit-13
  signature (every failing address shares the same remainder modulo
  8192 bytes). Ran clean on real hardware across bits 11-15, including
  bit 13 itself.
- **Direct Physical Test**: bypasses XMS/HIMEM entirely via
  `INT 15h, AH=87h`, direct 24-bit physical addressing. Single-word
  and bulk (1 KB) variants, each generalized from a single hardcoded
  point into a full sweep of the grabbed block, cross-checking XMS-
  path writes against BIOS-direct-physical reads. **RISK**: this BIOS
  call switches the CPU into protected mode and back, with interrupts
  disabled, a malformed request hangs the machine, requiring a power
  cycle. Read each procedure's own header comment before running.

Python verification scripts referenced in the Pascal source and in
[Prime386's TECHNICAL.md](../Prime386/TECHNICAL.md) (`march_verify.py`,
`addr_pattern_verify.py`, `pascal_translit_verify.py`,
`checkit_full_analysis.py`, `addrgallop_verify.py`,
`addrgallop_pascal_translit.py`, `gdt_layout_verify.py`,
`mapping_verify.py`, and others) were written during this project's
development; whichever of them are worth keeping for reference live
in the repo's [Tools](../../../../Tools/) folder alongside the rest of
the project's verification scripts, not all of them necessarily are,
some were narrow, single-use checks not worth a permanent home there.
