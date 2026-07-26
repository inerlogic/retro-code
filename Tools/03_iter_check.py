import random
from bignum_sim import int_to_words, words_to_int, add_words

def mod_mersenne_count_iters(x_words, p):
    nlimb = (p + 15)//16
    full_words = p // 16
    rem_bits = p % 16
    cur = list(x_words)
    iterations = 0
    while True:
        cur_int = words_to_int(cur)
        if cur_int <= (1 << p) - 1:
            break
        low = cur[:full_words]
        if rem_bits:
            low = low + [cur[full_words] & ((1<<rem_bits)-1)]
        low = low + [0]*(nlimb-len(low))
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
            summed, _ = add_words(summed, [carry_out], nlimb)
        cur = summed
        iterations += 1
    return iterations

random.seed(999)
max_iters = 0
worst = None
for p in [3,5,7,11,13,17,19,23,29,31,37,61,89,127]:
    nlimb = (p+15)//16
    m = (1<<p)-1
    # worst case inputs: product of two values just under m (max possible from squaring in LL)
    candidates = [m*m, m*m-1, (m-1)*(m-1), (1<<(2*p))-1]
    for _ in range(3000):
        a = random.randint(0, m-1)
        b = random.randint(0, m-1)
        candidates.append(a*b)
    for x in candidates:
        xw = int_to_words(x, 2*nlimb)
        it = mod_mersenne_count_iters(xw, p)
        if it > max_iters:
            max_iters = it
            worst = (p, x)
print(f"Max reduction iterations observed across all tests: {max_iters}")
print(f"Worst case: p={worst[0]}")
