"""
Bounds-checked simulation of the exact PRIME386.PAS algorithm, run against
the exact deterministic value sequence for each real test exponent
(13, 17, 19, 31, 61), not random fuzzing. Any out-of-bounds array access
raises immediately, mirroring what {$R+} would catch that {$R-} currently
lets through silently.
"""

MASK16 = 0xFFFF
NLIMB = 4
NLIMB2 = 8

class BArr:
    """Bounds-checked array mimicking a fixed-size Pascal array."""
    def __init__(self, size, name=""):
        self.size = size
        self.name = name
        self.data = [0]*size
    def __getitem__(self, i):
        if not (0 <= i < self.size):
            raise IndexError(f"OOB READ on {self.name}[{i}] (valid: 0..{self.size-1})")
        return self.data[i]
    def __setitem__(self, i, v):
        if not (0 <= i < self.size):
            raise IndexError(f"OOB WRITE on {self.name}[{i}] (valid: 0..{self.size-1})")
        self.data[i] = v
    def copy_from(self, other):
        for i in range(self.size):
            self[i] = other[i]
    def as_list(self):
        return list(self.data)

def zero_big(name="tmp"):
    return BArr(NLIMB, name)

def zero_big2(name="tmp2"):
    return BArr(NLIMB2, name)

def square_words(a):
    result = zero_big2("sq_result")
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

def add_big_trunc(a, b, result):
    carry = 0
    for i in range(NLIMB):
        s = a[i] + b[i] + carry
        result[i] = s & MASK16
        carry = s >> 16
    return carry

def compare_big(a, b):
    for i in reversed(range(NLIMB)):
        if a[i] > b[i]: return 1
        if a[i] < b[i]: return -1
    return 0

def mod_mersenne_words(x, p):
    full_words = p // 16
    rem_bits = p % 16
    cur = zero_big2("cur")
    cur.copy_from(x)
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

        low = zero_big("low")
        for i in range(full_words):
            low[i] = cur[i]
        if rem_bits != 0:
            low[full_words] = cur[full_words] & ((1 << rem_bits) - 1)

        high = zero_big("high")
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

        summed = zero_big("summed")
        carry_out = add_big_trunc(low, high, summed)
        if carry_out != 0:
            low2 = zero_big("low_fold")
            low2[0] = carry_out
            add_big_trunc(summed, low2, summed)

        cur = zero_big2("cur")
        for i in range(NLIMB):
            cur[i] = summed[i]

        iter_count += 1
        if iter_count > 8:
            raise RuntimeError(f"would not converge for p={p} after 8 iterations")

    result_out = zero_big("result_out")
    for i in range(NLIMB):
        result_out[i] = cur[i]

    all_ones = zero_big("all_ones")
    for i in range(full_words):
        all_ones[i] = 0xFFFF
    if rem_bits != 0:
        all_ones[full_words] = (1 << rem_bits) - 1

    if compare_big(result_out, all_ones) == 0:
        result_out = zero_big("result_out_zeroed")
    return result_out

def sub2mod(s, p):
    two = zero_big("two"); two[0] = 2
    if compare_big(s, two) >= 0:
        news = zero_big("news")
        news.copy_from(s)
        if news[0] >= 2:
            news[0] -= 2
        else:
            news[0] = news[0] + 65536 - 2
            i = 1
            while i < NLIMB:
                if news[i] == 0:
                    news[i] = 65535; i += 1
                else:
                    news[i] -= 1; break
        return news
    else:
        full_words = p // 16
        rem_bits = p % 16
        m = zero_big("m")
        for i in range(full_words): m[i] = 0xFFFF
        if rem_bits != 0: m[full_words] = (1 << rem_bits) - 1
        temp = zero_big("temp")
        temp.copy_from(m)
        need = 2 - s[0]
        if temp[0] >= need:
            temp[0] -= need
        else:
            temp[0] = temp[0] + 65536 - need
            i = 1
            while i < NLIMB:
                if temp[i] == 0:
                    temp[i] = 65535; i += 1
                else:
                    temp[i] -= 1; break
        return temp

def is_zero(b):
    return all(b[i] == 0 for i in range(NLIMB))

def lucas_lehmer_test(p, verbose=False):
    if p == 2:
        return True
    s = zero_big("s")
    s[0] = 4
    for it in range(1, p-1):
        sq = square_words(s)
        reduced = mod_mersenne_words(sq, p)
        s = zero_big("s")
        s.copy_from(reduced)
        s = sub2mod(s, p)
        if verbose:
            print(f"    iter {it}: s = {s.as_list()}")
    return is_zero(s)

for p in [13, 17, 19, 31, 61]:
    try:
        result = lucas_lehmer_test(p)
        print(f"p={p:3d}  -> {'PASS' if result else 'FAIL'}  (no OOB access)")
    except IndexError as e:
        print(f"p={p:3d}  -> *** OUT OF BOUNDS: {e} ***")
    except RuntimeError as e:
        print(f"p={p:3d}  -> *** NON-CONVERGENCE: {e} ***")
