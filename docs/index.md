---
layout: default
---

# Retro Code

Games and utilities written for retro computers I own, organized by processor, then machine, then language.

## Active machines

### SC131 (Z180)
Pocket computer, used over Tera Term with ANSI/VT100 emulation.
- [Aztec-C: Tetris](../Z180/SC131/Aztec-C/tetris/) — three versions, timing tuned for the SC131
- [Aztec-C: Game of Life screensavers](../Z180/SC131/Aztec-C/life/) — 1D cellular automata
- [Aztec-C: Utilities](../Z180/SC131/Aztec-C/utilities/) — cleanup + file paging tools
- [BASIC-80](../Z180/SC131/BASIC-80/) — tokenized MBASIC, including the classic 2D Conway's Life
- [Turbo Pascal 3](../Z180/SC131/Turbo-Pascal-3/) — Tetris variants, a dungeon crawler, color Life, hex-π displays

### RetroBrew SBC (Z80)
Currently used with the PROP/IO board for SD card access. Formerly known as N8VEM.
- Nothing uploaded yet

### The High Nibble IMSAI 8080 Clone (Z80)
- Nothing uploaded yet

### Pocket 386 (80386)
40 MHz 386SX SoC (ALi M6117), DOS 6.22, no FPU.
- [Turbo Pascal 7: HL386](../80386/Pocket386/Turbo-Pascal-7/HL386/) — Conway's Game of Life screensaver with a data-logging component, Brent's-algorithm cycle detection, and real BIOS-tick timing
- [Turbo Pascal 7: Prime386](../80386/Pocket386/Turbo-Pascal-7/Prime386/) — a "Prime95-like" CPU/memory stress test using Lucas-Lehmer primality testing in pure integer/bignum arithmetic, since this machine has no FPU

## Cross-machine tools

- [RomWBW-HBIOS](../RomWBW-HBIOS/) — tools that talk to RomWBW's HBIOS layer directly, portable across any RomWBW board

## Other machines (not currently active)

- RC2014 (Z80, ROMWBW)
- Lee Hart's Z80 Membership Card
- Lee Hart's RCA1802 Membership Card
- Commodore's Ultimate C64 (6502)
- TI-99/4A (9900)

---

Full source lives in the repo root, organized as `<processor>/<machine>/<language>/<project>/`.
