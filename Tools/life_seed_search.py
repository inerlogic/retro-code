#!/usr/bin/env python3
"""
life_seed_search.py -- simulate Jon Millen's 1D Life rule on a ring of any
size, to find seed values with interesting (long transient / long cycle)
dynamics before committing to testing them on real hardware.

This is the actual methodology behind the seed choices documented in
Z80/IMSAI/README.md for LIFE8.ASM (seed 27) and LIFE16.ASM (seed 5471) --
not just an assertion, something you can rerun and verify.

The rule (Millen's YYXYY neighborhood, BYTE Magazine, Dec 1978,
"One-Dimensional Life"): for each cell X, look at the 4 surrounding Y
cells (2 on each side, wrapping around the ring). A dead cell is born if
exactly 2 or 3 of those neighbors are alive. A live cell survives if
exactly 2 or 4 of those neighbors are alive. Otherwise the cell dies (or
stays dead). Same rule implemented in MILLIFE.C / MILLIFE.PAS / LIFE8.ASM
/ LIFE16.ASM elsewhere in this repo.

Usage:
    python3 life_seed_search.py 8           # exhaustively search all 2^8 seeds
    python3 life_seed_search.py 16          # exhaustively search all 2^16 seeds
    python3 life_seed_search.py 16 --top 20 # show more results

For ring sizes much bigger than 16, an exhaustive search (2^N seeds) stops
being practical -- you'd want random sampling instead, the same way an
earlier exploratory pass in this file's history used `random.seed()` over
a few thousand samples before the full 16-bit search became worth running.
"""

import argparse


def wrap(i: int, n: int) -> int:
    return i % n


def step(cells: list[int]) -> list[int]:
    """Compute the next generation of a ring under Millen's rule."""
    n = len(cells)
    new = [0] * n
    for i in range(n):
        s = (
            cells[wrap(i - 2, n)]
            + cells[wrap(i - 1, n)]
            + cells[wrap(i + 1, n)]
            + cells[wrap(i + 2, n)]
        )
        if cells[i] == 0:
            new[i] = 1 if s in (2, 3) else 0
        else:
            new[i] = 1 if s in (2, 4) else 0
    return new


def seed_to_cells(seed: int, n: int) -> list[int]:
    """cell[i] = bit i of seed -- matches the UNPACK convention used in
    LIFE8.ASM / LIFE16.ASM (cell0 = bit0 of the low byte, etc.)."""
    return [(seed >> i) & 1 for i in range(n)]


def transient_and_cycle(seed: int, n: int) -> tuple[int, int]:
    """Run a seed forward until its state repeats. Returns
    (transient_length, cycle_length) -- transient_length is how many
    generations pass before the first repeated state, cycle_length is
    how long the repeating loop is once it settles."""
    cells = seed_to_cells(seed, n)
    seen: dict[tuple[int, ...], int] = {}
    gen = 0
    while True:
        key = tuple(cells)
        if key in seen:
            return seen[key], gen - seen[key]
        seen[key] = gen
        cells = step(cells)
        gen += 1


def search_all_seeds(n: int):
    """Exhaustively simulate every possible seed for an n-cell ring.
    Only practical for smallish n (8 or 16 is fine; 2^n grows fast)."""
    results = []
    for seed in range(2**n):
        transient, cyclen = transient_and_cycle(seed, n)
        results.append((seed, transient, cyclen))
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("n", type=int, help="ring size in cells (e.g. 8 or 16)")
    parser.add_argument(
        "--top", type=int, default=10, help="how many top results to show"
    )
    parser.add_argument(
        "--sort-by",
        choices=["combined", "transient", "cycle"],
        default="combined",
        help="what to prioritize when ranking seeds",
    )
    args = parser.parse_args()

    if args.n > 20:
        print(
            f"Warning: exhaustively searching 2^{args.n} seeds may take a "
            f"long time or a lot of memory. Consider random sampling instead "
            f"for large ring sizes."
        )

    results = search_all_seeds(args.n)

    if args.sort_by == "transient":
        results.sort(key=lambda r: (-r[1], -r[2]))
    elif args.sort_by == "cycle":
        results.sort(key=lambda r: (-r[2], -r[1]))
    else:
        # combined: weight cycle length more heavily, since a long cycle
        # is a more sustained visual payoff than a long one-time transient
        results.sort(key=lambda r: -(r[1] + r[2] * 3))

    max_transient = max(r[1] for r in results)
    max_cycle = max(r[2] for r in results)

    print(f"Ring size: {args.n} cells ({2**args.n} possible seeds)")
    print(f"Max transient found: {max_transient}")
    print(f"Max cycle length found: {max_cycle}")
    print()
    print(f"Top {args.top} seeds (sorted by {args.sort_by}):")
    print(f"{'seed':>7} {'hex':>8} {'transient':>10} {'cycle':>8}")
    for seed, transient, cyclen in results[: args.top]:
        print(f"{seed:7d} {seed:#08x} {transient:10d} {cyclen:8d}")


if __name__ == "__main__":
    main()
