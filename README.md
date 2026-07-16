```
/******************************************************************
 * File Name:    README.md
 * Description:  Core execution logic for the multiverse.
 * Author:       git blame
 * Date:         see: git log
 * Compiler:     Yes.
 ******************************************************************/
```

# Retro Code

Source code for games and utilities written for my retro computers, organized by processor, then by machine, then by language.

## Currently active machines

| Processor | Machine | Notes |
|---|---|---|
| Z180 | [SC131](Z180/SC131/) | Pocket computer, used via Tera Term (ANSI/VT100) |
| Z80 | [RetroBrew-SBC](Z80/RetroBrew-SBC/) | Z80 SBC + PROP/IO board (SD card access), formerly known as N8VEM |
| Z80 | [IMSAI](Z80/IMSAI/) | The High Nibble IMSAI 8080 clone |
| 80386 | [Pocket-386](80386/Pocket386/) | Pocket 386 mini-Laptop |

## Other machines (not currently active)

| Processor | Machine |
|---|---|
| Z80 | [RC2014](Z80/RC2014/) (ROMWBW) |
| Z80 | [Lee-Z80-MC](Z80/Lee-Z80-MC/) — Lee Hart's Z80 Membership Card |
| 1802 | [RCA1802-Membership-Card](1802/RCA1802-Membership-Card/) — Lee Hart's 1802 Membership Card |
| 1802 | [RCA1802-STG-ELF2K](1802/RCA1802-STG-ELF2K/) — Spare Time Gizmos ELF 2000 |
| 6502 | [Commodore-Ultimate-C64](6502/Commodore-Ultimate-C64/) |
| 9900 | [TI99-4a](9900/TI99-4a/) |

## Cross-machine tools

Some tools target a firmware layer rather than one specific machine, so they live outside the processor tree:

- [RomWBW-HBIOS](RomWBW-HBIOS/) — tools that talk directly to RomWBW's HBIOS layer and should run on any RomWBW-based board (SC131, and RetroBrew-SBC/RC2014 once back in use)

## Development tools (modern, not retro)

- [tools/](tools/) — modern Python scripts used to help develop the retro code above (e.g. simulating a cellular automaton rule to pick good seed values before testing on real hardware) — not retro code themselves, so kept separate from everything above.

## Structure

```
<processor>/<machine>/<language>/<project>/
```

Each project folder has its own README with build/run notes where known. See [docs/](docs/) for the GitHub Pages version of this documentation.

## A note on the code

I learned C on ANSI-C in the mid-1990s. Aztec-C for CP/M, decades later, is a middle-age distraction — and it shows. Some of the Aztec-C programs in here (see the Tetris folder under [Z180/SC131/Aztec-C](Z180/SC131/Aztec-C/) especially) have real, confirmed bugs that I never fully solved — things like a top-of-field detection bug that survived two attempted fixes. I'm leaving those versions in rather than cleaning them up or deleting them.

Partly that's just honesty about how the development actually went — struggling with a platform is normal, not something to hide. But it's also an open invitation: if you know Aztec-C|CP/M better than I do and want a fun, bounded debugging exercise, digging into why TETRIS3.C still hangs at the top of the field despite three targeted fixes is a genuinely interesting little puzzle. Pull requests, or just an email telling me what you found, are equally welcome.
