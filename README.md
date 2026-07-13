# Retro Code

Source code for games and utilities written for my retro computers, organized by processor, then by machine, then by language.

## Currently active machines

| Processor | Machine | Notes |
|---|---|---|
| Z180 | [SC131](Z180/SC131/) | Pocket computer, used via Tera Term (ANSI/VT100) |
| Z80 | [RetroBrew-SBC](Z80/RetroBrew-SBC/) | Z80 SBC + PROP/IO board (SD card access), formerly known as N8VEM |
| Z80 | [IMSAI](Z80/IMSAI/) | The High Nibble IMSAI 8080 clone |

## Other machines (not currently active)

| Processor | Machine |
|---|---|
| Z80 | [RC2014](Z80/RC2014/) (ROMWBW) |
| Z80 | [Lee-Z80-MC](Z80/Lee-Z80-MC/) — Lee Hart's Z80 Membership Card |
| 1802 | [RCA1802-Membership-Card](1802/RCA1802-Membership-Card/) — Lee Hart's 1802 Membership Card |
| 1802 | [RCA1802-STG-ELF2K] (Spare Time Gizmos ELF 2000)
| 6502 | [Commodore-Ultimate-C64](6502/Commodore-Ultimate-C64/) |
| 9900 | [TI99-4a](9900/TI99-4a/) |

## Cross-machine tools

Some tools target a firmware layer rather than one specific machine, so they live outside the processor tree:

- [RomWBW-HBIOS](RomWBW-HBIOS/) — tools that talk directly to RomWBW's HBIOS layer and should run on any RomWBW-based board (SC131, and RetroBrew-SBC/RC2014 once back in use)

## Structure

```
<processor>/<machine>/<language>/<project>/
```

Each project folder has its own README with build/run notes where known. See [docs/](docs/) for the GitHub Pages version of this documentation.
