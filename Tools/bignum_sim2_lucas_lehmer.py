from bignum_sim import (BASE, MASK16, int_to_words, words_to_int, add_words,
                          square_words, mod_mersenne_words)

def sub2_mod_words(s_words, p):
    """Compute (s - 2) mod (2^p - 1) at word level. Since s is already in
    [0, 2^p-1) range coming out of mod_mersenne_words, s-2 can only go
    negative when s is 0 or 1, in which case wrap by adding m = 2^p-1."""
    nlimb = len(s_words)
    s_int = words_to_int(s_words)
    m = (1 << p) - 1
    if s_int >= 2:
        result_int = s_int - 2
    else:
        result_int = s_int - 2 + m   # wrap around (only s=0 or s=1 can occur)
    return int_to_words(result_int, nlimb)

def lucas_lehmer_wordsim(p, verbose=False):
    nlimb = (p + 15)//16
    if p == 2:
        # standard LL formula is only defined/meaningful for p>2;
        # M2 = 3 is prime by inspection, handled as a base case
        return True
    s = int_to_words(4, nlimb)
    for it in range(p - 2):
        sq = square_words(s)                       # 2*nlimb words, s*s
        reduced = mod_mersenne_words(sq, p, verbose=(verbose and it < 2))
        s = sub2_mod_words(reduced, p)              # (s*s - 2) mod (2^p-1)
    return words_to_int(s) == 0

if __name__ == "__main__":
    print("Known Mersenne prime exponents (expect PASS / s=0):")
    for p in [2,3,5,7,13,17,19,31]:
        ok = lucas_lehmer_wordsim(p, verbose=True)
        status = "OK" if ok else "FAIL <<<"
        print(f"  p={p:3d}  ->  {'PRIME (s=0)' if ok else 'NOT PRIME'}   {status}")

    print()
    print("Known composite exponents (expect FAIL / s!=0):")
    for p in [11, 23, 29]:
        ok = lucas_lehmer_wordsim(p)
        status = "OK (correctly not prime)" if not ok else "FAIL <<<"
        print(f"  p={p:3d}  ->  {'PRIME (s=0)' if ok else 'NOT PRIME'}   {status}")
