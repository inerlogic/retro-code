# Turbo Pascal 3 (SC131)

- [tetris/](tetris/) — three Tetris variants (color, 1984-homage monochrome, and a "golf scoring" variant)
- [dungeon-crawler/](dungeon-crawler/) — procedurally generated roguelike-lite
- [life/](life/) — color Game of Life screensaver
- [hexpi/](hexpi/) — endless hex-digit-of-π color displays

All programs use `ClrScr`/`GotoXY`/ANSI escape codes and read input via `Kbd`, consistent with the SC131's Tera Term ANSI/VT100 setup. Several source comments explicitly note workarounds for Turbo Pascal 3 quirks — most notably **TP3's Error 8**, which requires every `string` type to be declared with an explicit maximum length (e.g. `string[20]`) rather than using an unsized `string`.

See [`../../../RomWBW-HBIOS/Turbo-Pascal-3/`](../../../RomWBW-HBIOS/Turbo-Pascal-3/) for `DRVSTAT.PAS`, a disk-status utility that reads RomWBW/HBIOS structures directly and so isn't specific to this machine — it's filed under a shared RomWBW-HBIOS location instead, since it would run on any RomWBW-based board (SC131, RetroBrew-SBC, RC2014).
