# Turbo Pascal 3 (RomWBW/HBIOS)

**DRVSTAT.PAS** — reports total/used/free space for RomWBW drives `A:`–`N:` (the drive-select loop runs 0–15/A–P, but only drives 0–13/A–N are actually queried and printed; O: and P: are iterated over but skipped entirely). For each queried drive it calls HBIOS via `Bdos`/`BdosHL` to fetch the Disk Parameter Block (DPB) and Allocation Vector (ALV) addresses directly out of memory, then reads block size and total block count from the DPB and counts zero bits in the ALV bitmap to determine free space. Labels the boot/RAM/ROM drives by name (`SD0:0 (Boot)`, `MD0:0 (RAM)`, `MD1:0 (ROM)`) and everything else as `SD0:n`.

**Note for anyone building this on their own system:** the `(Boot)`/`(RAM)`/`(ROM)` labels are hardcoded to drives 0/1/2 (`Drive = 0`, `Drive = 1`, `Drive = 2` in the source) — they're not derived from actually querying HBIOS about what's assigned where. This matches the author's own SC131/RomWBW slice layout, but if your drive assignments differ, edit those hardcoded checks (and the `SD0:n` label numbering) to reflect your own `PROFILE.SUB`/`ASSIGN` setup before relying on the labels.

## Future ideas

- **Column alignment** — the current output isn't consistently padded/aligned across all rows; worth tightening up.
- **Stretch goals** — box-drawing borders around the table, and color-coding entries by free-space percentage (e.g. red/yellow/green thresholds).

Not yet implemented.
