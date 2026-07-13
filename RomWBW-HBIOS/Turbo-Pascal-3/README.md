# Turbo Pascal 3 (RomWBW/HBIOS)

**DRVSTAT.PAS** — reports total/used/free space for RomWBW drives. For each drive it calls HBIOS via `Bdos`/`BdosHL` to select the disk, fetch the Disk Parameter Block (DPB) and Allocation Vector (ALV) addresses directly out of memory, then reads block size and total block count from the DPB and counts zero bits in the ALV bitmap to determine free space. Labels the boot/RAM/ROM drives by name (`SD0:0 (Boot)`, `MD0:0 (RAM)`, `MD1:0 (ROM)`) and everything else as `SD0:n`.

**Update 1 — dynamic drive detection instead of a hardcoded cutoff.** The original version hardcoded `if Drive < 14` to skip drives O:/P: entirely. Investigation (with real boot-log evidence, not just guessing) confirmed this wasn't any kind of RomWBW/CBIOS architectural limit — `ASSIGN` works identically whether run automatically at boot or manually afterward, with no timing sensitivity at all. The real reason O:/P: were never reachable is simply that this machine's SD card was only ever formatted with 12 CP/M slices, exactly enough to cover A–N alongside the RAM/ROM drives — there was nothing to assign those two letters *to* in the first place. The hardcoded `14` just reflected this one machine's card, not a universal constant.

The fix: standard CP/M BDOS function 14 (Select Disk) is documented to return the drive's DPH address on success, or 0 if the drive was never assigned — the code now checks that return value directly (via `BdosHL`) instead of ignoring it, and loops across all 16 possible drive letters, naturally skipping whichever ones a given system doesn't have configured. This should make the program adapt automatically to any RomWBW system's actual drive count, rather than needing the cutoff number edited per-machine.

**Not fully solved:** the `(Boot)`/`(RAM)`/`(ROM)` labels are still a manual mapping — there's no verified way (yet) to query HBIOS for the real unit name string behind a drive letter, so matching your own boot layout still means editing the `BOOT_DRIVE`/`RAM_DRIVE`/`ROM_DRIVE`/`SD_SLICE_OFFSET` constants at the top of the file (previously scattered hardcoded checks in the print logic, now at least isolated and commented). Also worth noting: the dynamic drive-count fix hasn't been exhaustively tested against every possible RomWBW configuration — it relies on this CBIOS build's Select Disk returning a clean 0 for a never-assigned drive, matching standard documented CP/M behavior, but hasn't been proven universal.

![DRVSTAT output](screenshot-drvstat-output.png)

## Future ideas

- **Column alignment** — the current output isn't consistently padded/aligned across all rows; worth tightening up.
- **Stretch goals** — box-drawing borders around the table, and color-coding entries by free-space percentage (e.g. red/yellow/green thresholds).
- **Fully automatic labels** — if a verified HBIOS call for querying the real unit name string behind a drive letter is ever found, the `BOOT_DRIVE`/`RAM_DRIVE`/`ROM_DRIVE` constants could be replaced with genuine auto-detection instead of a manual mapping. Not yet researched.

Not yet implemented.
