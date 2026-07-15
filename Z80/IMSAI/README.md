# The High Nibble IMSAI 8080 Clone

*(The High Nibble IMSAI 8080 Clone is an ESP32-based emulator of the IMSAI 8080 — not physical period hardware. It's configured to emulate a Z80 at 4MHz (rather than a real 8080 — the emulated clock speed is itself a configurable setting, not a fixed physical crystal, so this could change if reconfigured later. Even "IMSAI Guy" got rid of his real one, so this is probably how most people encounter this machine if at all.)*

- [LIFE8.ASM](LIFE8.ASM) — 1D Game of Life on the front panel, 8-cell ring
- [LIFE8.PRN](LIFE8.PRN) — assembler listing for LIFE8.ASM (addresses + opcode bytes + source, side by side) — the reference to use if you ever want to toggle this in by hand like a sick person.
- [LIFE16.ASM](LIFE16.ASM) — same, but a 16-cell ring, shown as two duplexed 8-bit halves

**Neither program has any keyboard exit** — both loop forever by design (no CP/M, no BDOS keyboard polling, unlike the console-based programs elsewhere in this repo). To stop either one, toggle **RESET** on the front panel — this ends the program and drops back to the CP/M prompt.

## LIFE8.ASM

A 1D cellular automaton, same rule as [MILLIFE.C](../../Z180/SC131/Aztec-C/life/MILLIFE.C)/[MILLIFE.PAS](../../Z180/SC131/Turbo-Pascal-3/life/MILLIFE.PAS), but shrunk to an 8-cell ring and displayed on the IMSAI's Programmed Output LEDs instead of a terminal. No CP/M, no BDOS — pure bare-metal 8080 assembly that loops forever writing each generation directly to a port.

Credit to **Jon Millen**, author of "One-Dimensional Life" in BYTE Magazine, Vol 3 No 12, December 1978 — the five-cell YYXYY neighborhood rule this program implements. See [jonmillen.com/1dlife](https://jonmillen.com/1dlife).

**Status: confirmed working on real (fake) hardware.** Written in classic Intel 8080 mnemonics, assembled successfully with the stock CP/M 2.2 `ASM.COM` ("CP/M Assembler - VER 2.0"), loaded, and run. Port `0FFH` is active-low hence the `CMA` before `OUT`, and the whole Millen-rule/wraparound neighbor computation all confirmed correct by matching the live LED pattern against a from-scratch simulation of the original test seed (`10110100B`): a 2-generation transient, then a permanent 4-cell oscillation (cells 0, 1, 2, 7 flashing; cells 3, 4, 5, 6 settling dark) — matched exactly, transient blip included. 

First confirmed-working program in this folder.

**Known limitation, confirmed on real hardware, not a bug:** simulating all 256 possible seed values exhaustively shows **every seed settles into a repeating cycle within 2 generations** — the ring is simply too small for a longer chaotic transient, so no seed choice can fix "settles too fast" directly. What *does* vary meaningfully between seeds is the length/variety of the cycle it settles **into**: the original test seed (`10110100B` = 180) settles into a boring 2-generation back-and-forth (shared by 108 of the 256 seeds); the current seed (`00011011B` = 27) settles into a 5-generation cycle instead (shared by 80 of the 256 seeds) — same fast settling, meaningfully more visual variety once it locks in. (Simulated with [tools/life_seed_search.py](../../tools/life_seed_search.py) — rerun it yourself if you want to verify or search for different criteria.) Full distribution: 20 seeds give cycle length 1 (static), 108 give length 2, 48 give length 4, 80 give length 5 — no seed produces anything longer than 5.

**Delay is a triple-nested loop** (`DELAY1`/`DELAY2`/`DELAY3`) instead of double, giving a much wider tunable range without needing anything bigger than 8-bit counters. Tuned and confirmed on hardware (see Known unknowns below) — `DELAY3=4` is the settled value.

**Known unknowns, still open:**
- ~~Exact real-world timing~~ **Resolved and confirmed on hardware:** `DELAY3=16` (the originally tuned value) gave ~4-5 seconds per generation — correct/stable but slower than ideal. Lowered to `DELAY3=4`, confirmed on hardware simulating a z80 at 4MHz to give a much better pace ("great blinkenlight display") — this is now the settled value.

**Fun fact this program setup makes literally true:** at 8 cells and this length, it actually could be toggled in by hand via the front panel switches — probably worth doing exactly once, purely for the experience, even though typing it in is obviously easier for anything past a first try. [LIFE8.PRN](LIFE8.PRN) is the actual reference for that — 371 bytes total (`0100H` through `0272H`), with each subroutine's `RET` a natural checkpoint to verify progress against (e.g. `UNPACK` ends at `0148H`, `PACK` at `0156H`) rather than only discovering a mistake after all 371 bytes are in.

## LIFE16.ASM

Same rule, same overall structure as `LIFE8.ASM` (kept as a separate file rather than replacing it, for continuity) — but a 16-cell ring instead of 8. Since the panel only has 8 physical LEDs, each generation is shown as two sequential halves: cells 0-7 displayed, a shorter pause, then cells 8-15 displayed, then the normal (longer) pause before computing the next generation — "duplexing" a 16-bit-wide colony onto an 8-bit port, one 8080/Z80 register-pair's worth of cells at a time, without literally packing live simulation state into a register pair itself (HL is still just used as a pointer, same as everywhere else in this program; the colony itself lives in a 16-byte memory array, same approach as `LIFE8.ASM`'s 8-byte one).

**This is a genuine, confirmed-by-simulation improvement, not just "a bigger number."** Exhaustively simulating all 256 possible 8-cell seeds (see above) showed every one settles into a repeating cycle within 2 generations, capping out at a 5-generation cycle at best. Exhaustively simulating all 65,536 possible 16-cell seeds tells a very different story: transients up to 8 generations, and cycle lengths up to **48 generations** — a real qualitative jump, matching the original observation that 8 cells was just too small a system for sustained interesting dynamics.

**Default seed: 5471** (low byte `05FH`, high byte `015H`) — found by that exhaustive search specifically because it hits the best combination found: an 8-generation transient, then the maximum possible 48-generation cycle.

**Status: confirmed working on real (fake) hardware, including timing.** Assembled with classic Digital Research `ASM.COM` (CP/M ASSEMBLER VER 2.0) — `LIFE8.ASM` has since confirmed the same assembler works for it too, so both files are now confirmed compatible with ASM. Display and duplexing logic correct, the overall rhythm reads clearly as intended: a quick LO-HI pair, then a longer pause, repeating — "1-2---1-2---1-2." `DELAY3=4` carries over cleanly from `LIFE8.ASM` even with the added `HALFDELAY` overhead on top; no further tuning needed.
