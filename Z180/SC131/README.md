# SC131

Z180-based pocket computer. Development/interaction done over Tera Term using ANSI/VT100 emulation.

## Languages used here

- [Aztec-C](Aztec-C/) — CP/M target, uses direct `bdos()` BDOS calls for I/O
- [BASIC-80](BASIC-80/) — MBASIC (CP/M) programs
- [Turbo-Pascal-3](Turbo-Pascal-3/) — Pascal ports of Tetris/Life plus a dungeon crawler and hex-π displays

Screen control throughout the Aztec-C code uses ANSI escape sequences (`\033[2J`, `\033[H`, `\033[y;xH`), consistent with the Tera Term VT100 setup used on this machine. Game timing loops (e.g. in the Tetris variants) have been tuned specifically for the SC131's execution speed — worth keeping in mind if any of this is ever ported to a different Z180/Z80 board, since delay-loop counts will need re-tuning rather than reuse.
