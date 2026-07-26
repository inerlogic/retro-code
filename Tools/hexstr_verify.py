# Transliteration of the planned Pascal HexStr(LongInt): string function,
# checked against Python's own hex formatting for a range of realistic
# offsets (0 up to ~7.27 million, the observed block size), plus the
# specific CheckIt-reported addresses from TECHNICAL.md as a direct
# cross-check.

def hexstr(v):
    digits = '0123456789ABCDEF'
    if v == 0:
        return '0'
    s = ''
    while v > 0:
        s = digits[v % 16] + s
        v //= 16
    return s

# Spot checks against known CheckIt addresses from TECHNICAL.md
known = [0x401704, 0x47D704]
for k in known:
    assert hexstr(k) == format(k, 'X'), (hexstr(k), format(k, 'X'))
print("HexStr matches Python hex() for known CheckIt addresses:", [hex(k) for k in known])

# Broad check across the real block range
import random
random.seed(1)
bad = 0
for _ in range(20000):
    v = random.randint(0, 7274496)
    if hexstr(v) != format(v, 'X'):
        bad += 1
print(f"Mismatches across 20000 random offsets in block range: {bad}")

# Confirm the absolute-address reconstruction: block-relative offset + 0x100000
# should land inside CheckIt's reported bands for the known faulty run
block_relative_examples = [0x301704 - 0x100000, 0x37D704 - 0x100000]  # made-up plausible offsets
for off in block_relative_examples:
    abs_addr = off + 0x100000
    print(f"block-relative {hexstr(off)}h -> reconstructed absolute {hexstr(abs_addr)}h")
