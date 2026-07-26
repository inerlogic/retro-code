"""
Simulate word-based (base 2^16) bignum arithmetic exactly as it will be
implemented in Turbo Pascal 7 on the 386SX target: fixed-size arrays of
16-bit words, schoolbook squaring, and the Mersenne shift-add mod trick
done at word granularity (not just relying on Python's native bigints).

Goal: validate the ALGORITHM (carry propagation, iteration counts, edge
cases) before writing a line of Pascal.
"""

BASE = 1 << 16
MASK16 = BASE - 1

def int_to_words(x, nwords):
    """Little-endian word array, fixed length nwords, zero padded."""
    w = []
    for _ in range(nwords):
        w.append(x & MASK16)
        x >>= 16
    assert x == 0, f"value did not fit in {nwords} words"
    return w

def words_to_int(w):
    x = 0
    for i in reversed(range(len(w))):
        x = (x << 16) | w[i]
    return x

def add_words(a, b, nwords):
    """Add two word arrays of possibly different lengths, result padded/truncated
    to nwords, return (result_words, final_carry_out)."""
    result = [0]*nwords
    carry = 0
    for i in range(nwords):
        av = a[i] if i < len(a) else 0
        bv = b[i] if i < len(b) else 0
        s = av + bv + carry
        result[i] = s & MASK16
        carry = s >> 16
    return result, carry

def square_words(a):
    """Schoolbook squaring of word array a (length n), produces 2n-word result.
    Simulates the 16x16->32 multiply-accumulate loop TP7 will need to do with
    LongInt intermediate (since 16x16 bit multiply can overflow 16 bits, needs
    32-bit accumulation - TP7 LongInt is fine for that single-limb product)."""
    n = len(a)
    result = [0]*(2*n)
    for i in range(n):
        carry = 0
        for j in range(n):
            # 16x16 -> up to 32 bit product, plus existing result word, plus carry
            prod = a[i]*a[j] + result[i+j] + carry
            result[i+j] = prod & MASK16
            carry = prod >> 16
        k = i + n
        while carry:
            s = result[k] + (carry & MASK16)
            result[k] = s & MASK16
            carry = (carry >> 16) + (s >> 16)
            k += 1
    return result

def mod_mersenne_words(x_words, p, verbose=False):
    """Reduce x (given as word array, possibly 2n words from a squaring) mod
    (2^p - 1) using the shift-and-add trick, entirely via word-array slicing
    and add_words, mirroring what the Pascal version will do:

        x = high*2^p + low   (low = x mod 2^p, high = x div 2^p)
        x mod (2^p-1) = (high + low) mod (2^p-1)

    Repeat while the value still exceeds p bits. Finally, if value == 2^p-1
    (all p bits set), it must map to 0.
    """
    nlimb = (p + 15)//16       # words needed to hold a p-bit value
    x = words_to_int(x_words)  # only used to cross-check against word-level path
    total_bits = len(x_words)*16

    # word-level split: p bits -> p//16 full words + a partial word of (p%16) bits
    full_words = p // 16
    rem_bits = p % 16

    cur = list(x_words)
    iterations = 0
    while True:
        cur_int = words_to_int(cur)
        if cur_int <= (1 << p) - 1:
            break
        # split cur into low (p bits) and high (rest)
        low = cur[:full_words]
        if rem_bits:
            low = low + [cur[full_words] & ((1<<rem_bits)-1)]
        # pad low to nlimb
        low = low + [0]*(nlimb-len(low))

        # high = cur >> p  (shift right by full_words whole words, then rem_bits bits)
        shifted = cur[full_words:]
        if rem_bits:
            high = [0]*len(shifted)
            carry_bits = 0
            for i in reversed(range(len(shifted))):
                val = shifted[i]
                high[i] = (val >> rem_bits) | carry_bits
                carry_bits = (val & ((1<<rem_bits)-1)) << (16-rem_bits)
        else:
            high = shifted

        summed, carry_out = add_words(low, high, nlimb)
        if carry_out:
            # extremely rare (only when high itself needs another limb); fold it back
            summed, _ = add_words(summed, [carry_out], nlimb)
        cur = summed
        iterations += 1
        if iterations > 10:
            raise RuntimeError("mod reduction not converging - logic bug")

    result_int = words_to_int(cur)
    if result_int == (1 << p) - 1:
        cur = [0]*nlimb
        result_int = 0

    if verbose:
        print(f"  reduction iterations: {iterations}, result: {result_int}")

    # cross-check against pure Python bigint mod as ground truth
    expected = words_to_int(x_words) % ((1<<p) - 1)
    assert result_int == expected, f"MISMATCH word-path={result_int} vs python-mod={expected}"

    return cur[:nlimb]

def lucas_lehmer_wordsim(p, verbose=False):
    nlimb = (p + 15)//16
    s = int_to_words(4, nlimb)
    m = (1<<p) - 1
    for it in range(p-2):
        sq = square_words(s)              # 2*nlimb words
        s = mod_mersenne_words(sq, p, verbose=verbose and it < 2)
    return words_to_int(s) == 0

if __name__ == "__main__":
    print("Known Mersenne prime exponents (expect PASS / s=0):")
    for p in [2,3,5,7,13,17,19,31]:
        ok = lucas_lehmer_wordsim(p, verbose=True)
        print(f"  p={p:3d}  2^p-1={'2^'+str(p)+'-1':>10}  LL result -> {'PRIME (s=0)' if ok else 'NOT PRIME'}  {'OK' if ok else 'FAIL <<<'}")

    print()
    print("Known composite exponents / composite 2^p-1 (expect FAIL / s!=0):")
    for p in [11, 23, 29]:
        ok = lucas_lehmer_wordsim(p)
        print(f"  p={p:3d}  LL result -> {'PRIME (s=0)' if ok else 'NOT PRIME'}  {'OK (correctly not prime)' if not ok else 'FAIL <<<'}")
