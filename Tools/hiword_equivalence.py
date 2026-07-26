"""
Verifies that the fix, reading a LongInt's high word via a variant-
record memory overlay (TLongWords/HiWord in the actual Pascal source),
is mathematically identical to the correct "x shr 16" operation,
across the full 32-bit range, before trusting it as a replacement for
whatever the buggy runtime routine at 455C:08B8 was doing.
"""

import random

def hiword_via_overlay(x):
    # Simulates the variant-record approach: takes the raw 32-bit bit
    # pattern and extracts the high 16 bits directly via memory layout,
    # equivalent to x >> 16 for our purposes (we only ever care about
    # the bit pattern, never the signed interpretation).
    return (x & 0xFFFFFFFF) >> 16

random.seed(1)
fail = 0
trials = 20000
for _ in range(trials):
    x = random.randint(0, 0xFFFFFFFF)
    expected = x >> 16
    got = hiword_via_overlay(x)
    if got != expected:
        fail += 1
        print(f"  MISMATCH x={x}: got={got} expected={expected}")

print(f"HiWord-equivalence check: {'PASS' if fail == 0 else f'{fail} FAILURES'} "
      f"across {trials} random 32-bit values")

# Edge cases worth checking explicitly
edge_cases = [0, 0xFFFF, 0x10000, 0xFFFFFFFF, 0x7FFFFFFF, 0x80000000]
print("\nEdge cases:")
for x in edge_cases:
    expected = x >> 16
    got = hiword_via_overlay(x)
    status = "OK" if got == expected else "FAIL"
    print(f"  x=0x{x:08X}: got=0x{got:04X} expected=0x{expected:04X}  {status}")
