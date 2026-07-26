# Design under test: pattern(byteOffset) = low 16 bits of byteOffset (word-for-word,
# i.e. each word in a chunk gets written with its own byte offset, truncated to 16 bits).
# Question: within realistic XMS block sizes (grabbed blocks were up to ~7104 KB in the
# actual overnight run), how often do two DIFFERENT word addresses produce the SAME
# expected pattern (a 64KB-period collision), and does that weaken detection?

def pattern(byte_offset):
    return byte_offset & 0xFFFF

# Real observed block size from the TECHNICAL.md log
BLOCK_KB = 7104
BLOCK_BYTES = BLOCK_KB * 1024

seen = {}
collisions = 0
for off in range(0, BLOCK_BYTES, 2):
    p = pattern(off)
    if p in seen:
        collisions += 1
    else:
        seen[p] = off

print(f"Block size: {BLOCK_KB} KB ({BLOCK_BYTES} bytes, {BLOCK_BYTES//2} words)")
print(f"Distinct pattern values possible: 65536")
print(f"Collisions (different address, same expected pattern): {collisions}")
print(f"Collision period: every 65536 bytes (64 KB), confirmed by construction")

# Confirm: within any single 64KB-aligned window, is it a bijection (no internal collision)?
window = range(0, 65536, 2)
vals = set(pattern(o) for o in window)
print(f"Within one 64KB window: {len(vals)} distinct values for {len(list(window))} words "
      f"(bijective: {len(vals) == len(list(window))})")
