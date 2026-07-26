"""
Faithful line-by-line transliteration of PRIME386.PAS's exact logic
(same helper breakdown: SquareWords, AddBigTrunc, CompareBig,
ModMersenneWords, Sub2Mod, LucasLehmerTest), NOT the earlier, more
direct bignum_sim.py, to catch transcription bugs introduced while
writing the actual Pascal source, before it goes anywhere near a
compiler.
"""

NLIMB = 4
NLIMB2 = 8
MASK16 = 0xFFFF

def zero_big():
    return [0]*NLIMB

def zero_big2():
    return [0]*NLIMB2

def square_words(a):
    result = zero_big2()
    for i in range(NLIMB):
        carry = 0
        for j in range(NLIMB):
            prod = a[i]*a[j] + result[i+j] + carry
            result[i+j] = prod & MASK16
            carry = prod >> 16
        k = i + NLIMB
        while carry != 0:
            prod = result[k] + (carry & MASK16)
            result[k] = prod & MASK16
            carry = (carry >> 16) + (prod >> 16)
            k += 1
    return result

def add_big_trunc(a, b):
    result = zero_big()
    carry = 0
    for i in range(NLIMB):
        s = a[i] + b[i] + carry
        result[i] = s & MASK16
        carry = s >> 16
    return result, carry

def compare_big(a, b):
    for i in reversed(range(NLIMB)):
        if a[i] > b[i]: return 1
        if a[i] < b[i]: return -1
    return 0

def is_zero(b):
    return all(x == 0 for x in b)

def mod_mersenne_words(x, p):
    full_words = p // 16
    rem_bits = p % 16
    cur = list(x)
    iter_count = 0
    while True:
        still_too_big = False
        for i in reversed(range(full_words, NLIMB2)):
            if i == full_words:
                if rem_bits == 0:
                    if cur[i] != 0: still_too_big = True
                elif (cur[i] >> rem_bits) != 0:
                    still_too_big = True
            elif cur[i] != 0:
                still_too_big = True
        if not still_too_big:
            break

        low = zero_big()
        for i in range(full_words):
            low[i] = cur[i]
        if rem_bits != 0:
            low[full_words] = cur[full_words] & ((1 << rem_bits) - 1)

        high = zero_big()
        if rem_bits == 0:
            for i in range(NLIMB2 - full_words):
                if i < NLIMB:
                    high[i] = cur[i+full_words]
        else:
            carry_bits = 0
            for i in reversed(range(full_words, NLIMB2)):
                val = cur[i]
                if (i - full_words) < NLIMB:
                    high[i-full_words] = (val >> rem_bits) | carry_bits
                carry_bits = (val & ((1 << rem_bits)-1)) << (16-rem_bits)

        summed, carry_out = add_big_trunc(low, high)
        if carry_out != 0:
            low2 = zero_big()
            low2[0] = carry_out
            summed, _ = add_big_trunc(summed, low2)

        cur = zero_big2()
        for i in range(NLIMB):
            cur[i] = summed[i]

        iter_count += 1
        if iter_count > 8:
            raise RuntimeError("exceeded safety cap - logic bug")

    result_out = [cur[i] for i in range(NLIMB)]

    all_ones = zero_big()
    for i in range(full_words):
        all_ones[i] = 0xFFFF
    if rem_bits != 0:
        all_ones[full_words] = (1 << rem_bits) - 1

    if compare_big(result_out, all_ones) == 0:
        result_out = zero_big()

    return result_out

def sub2mod(s, p):
    two = zero_big(); two[0] = 2
    if compare_big(s, two) >= 0:
        s = list(s)
        if s[0] >= 2:
            s[0] -= 2
        else:
            s[0] = s[0] + 65536 - 2
            i = 1
            while i < NLIMB:
                if s[i] == 0:
                    s[i] = 65535
                    i += 1
                else:
                    s[i] -= 1
                    break
        return s
    else:
        full_words = p // 16
        rem_bits = p % 16
        m = zero_big()
        for i in range(full_words): m[i] = 0xFFFF
        if rem_bits != 0: m[full_words] = (1 << rem_bits) - 1
        temp = list(m)
        need = 2 - s[0]
        if temp[0] >= need:
            temp[0] -= need
        else:
            temp[0] = temp[0] + 65536 - need
            i = 1
            while i < NLIMB:
                if temp[i] == 0:
                    temp[i] = 65535
                    i += 1
                else:
                    temp[i] -= 1
                    break
        return temp

def lucas_lehmer_test(p):
    if p == 2:
        return True
    s = zero_big()
    s[0] = 4
    for _ in range(1, p-1):   # Pascal: for i := 1 to p-2  => (p-2) iterations
        sq = square_words(s)
        reduced = mod_mersenne_words(sq, p)
        s = reduced
        s = sub2mod(s, p)
    return is_zero(s)   # using the FIXED version (IsZero), not the buggy tautology

# --- run against the same known test set ---
print("Known Mersenne prime exponents (expect True):")
for p in [2,3,5,7,13,17,19,31,61]:
    ok = lucas_lehmer_test(p)
    print(f"  p={p:3d}  -> {ok}  {'OK' if ok else 'FAIL <<<'}")

print()
print("Known composite exponents (expect False):")
for p in [11,23,29,37,41,53]:
    ok = lucas_lehmer_test(p)
    print(f"  p={p:3d}  -> {ok}  {'OK (correctly not prime)' if not ok else 'FAIL <<<'}")
