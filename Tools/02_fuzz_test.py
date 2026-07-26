import random
from bignum_sim import (int_to_words, words_to_int, square_words, mod_mersenne_words)

random.seed(12345)

print("=== Fuzzing square_words against Python's native ** for 1..4 limb operands ===")
fail = 0
for trial in range(20000):
    nlimb = random.randint(1, 4)
    maxval = (1 << (16*nlimb)) - 1
    a = random.randint(0, maxval)
    aw = int_to_words(a, nlimb)
    sq = square_words(aw)
    got = words_to_int(sq)
    expected = a * a
    if got != expected:
        fail += 1
        print(f"  MISMATCH trial={trial} nlimb={nlimb} a={a} got={got} expected={expected}")
        if fail > 5:
            break
print(f"square_words: {20000-fail}/20000 passed" if fail==0 else f"square_words: {fail} FAILURES")

print()
print("=== Fuzzing mod_mersenne_words against Python's % for various p, including 16-multiples ===")
fail = 0
trial = 0
test_ps = [3,5,7,11,13,16,17,19,23,29,31,32,37,48,61,64,89]
for p in test_ps:
    nlimb = (p+15)//16
    for _ in range(2000):
        trial += 1
        # simulate the actual use case: x is result of squaring a value < 2^p-1,
        # so x < (2^p-1)^2, needs up to 2*nlimb words
        maxval = (1 << p) - 2
        a = random.randint(0, maxval)
        b = random.randint(0, maxval)
        x = a * b  # not just squares - broader fuzz of the reduction itself
        xw = int_to_words(x, 2*nlimb)
        try:
            result = mod_mersenne_words(xw, p)
        except AssertionError as e:
            fail += 1
            print(f"  MISMATCH trial={trial} p={p} x={x}: {e}")
            continue
        got = words_to_int(result)
        expected = x % ((1<<p)-1)
        if got != expected:
            fail += 1
            print(f"  MISMATCH trial={trial} p={p} x={x} got={got} expected={expected}")
    # also specifically fuzz boundary values: all-ones, all-ones-minus-1, 2^(2p)-1, etc.
    m = (1<<p)-1
    edge_cases = [0, 1, m-1, m, m+1, m*m, m*m - 1, (1<<(2*p))-1, 2**p, 2**p+1]
    for x in edge_cases:
        if x < 0: continue
        xw = int_to_words(x, 2*nlimb) if x < (1<<(16*2*nlimb)) else None
        if xw is None:
            continue
        result = mod_mersenne_words(xw, p)
        got = words_to_int(result)
        expected = x % m
        if got != expected:
            fail += 1
            print(f"  EDGE MISMATCH p={p} x={x} got={got} expected={expected}")

print(f"mod_mersenne_words: {trial} random trials + edge cases, {fail} failures" if fail else f"mod_mersenne_words: {trial} random trials + edge cases, ALL PASSED")
