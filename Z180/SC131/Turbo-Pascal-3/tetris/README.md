# Tetris (Turbo Pascal 3)

Pascal counterparts to the Aztec-C Tetris versions (see [`../../../Aztec-C/tetris/`](../../../Aztec-C/tetris/)), same A/D/W/S/Q controls.

- **TETRIS.PAS** — the main version: ANSI color per piece type, a persisted high-score table (`SCORES.DAT`), and a short "lock delay" — a couple of frames of grace after a piece touches down before it locks, tuned for the SC131's clock speed, so a last-moment slide or rotate still counts.
- **TET84.PAS** — a monochrome re-skin styled after the original 1984 Tetris look: wireframe walls (`<!` / `!>` sides, `====` floor), no color, and no lock delay — pieces freeze the instant they land.
- **TETGOLF.PAS** — TETGOLF.PAS — "Tetris Golf": built on the same base as TETRIS.PAS, but scoring counts down from a starting maximum instead of up from zero — golf-style, lowest final score wins. High scores are kept in a separate file (`GOLF.DAT`) and sorted lowest-first.
The original idea was to start the score at the max value an 8-bit Z80 integer could hold and count down from there, tying the "ceiling" to the hardware itself. That reasoning doesn't actually hold — Pascal has ways around the 8-bit limit (larger integer types), so there's no hard hardware ceiling forcing the starting value. The countdown-scoring concept was worth keeping anyway just because it's a fun twist on normal Tetris scoring; the starting value and per-line point deductions are currently placeholders and still need real playtesting to tune for playability (not done yet).

All three use fixed-length `string[n]` types throughout (e.g. `string[10]` for score names) to avoid Turbo Pascal 3's Error 8, which occurs when an unsized `string` is used somewhere that needs a definite length.
