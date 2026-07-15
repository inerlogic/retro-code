# Tools

Modern helper scripts used to develop the retro code in this repo — not retro code themselves, so they live outside the `<processor>/<machine>/<language>` tree.

- [life_seed_search.py](life_seed_search.py) — simulates Jon Millen's 1D Life rule on a ring of any size, to find seed values with interesting dynamics (long transient before settling, long repeating cycle once settled) before committing to testing them on real hardware. This is the actual methodology behind the seed choices documented for `LIFE8.ASM` (seed 27) and `LIFE16.ASM` (seed 5471) in [Z80/IMSAI/README.md](../Z80/IMSAI/README.md) — not just an assertion, something you can rerun and verify. Requires Python 3.9+ (uses `list[int]`-style type hints). I thought this script might interest curious viewers.
