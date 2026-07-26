"""
Reconstruction of the actual shr-16 bug found via Turbo Debugger.

Hypothesis: "X shr 16" on a 32-bit value was returning the LOW 16 bits
instead of the HIGH 16 bits -- i.e. behaving as if the shift never
happened at all (since for small values, the low word IS the value).

This script reconstructs SquareWords' i=0 pass for s=4 under that exact
hypothesis and checks it against the real values observed live in
Turbo Debugger on the physical Pocket 386:
  - carry == 16 at the "k := i + NLIMB" breakpoint (confirmed on hardware)
  - prod == 16 one step later, inside the runaway while-loop (confirmed)
  - result == 16,16,16,16,16,32,64,128 after i=0 (matches the earlier
    WriteLn diagnostic trace exactly)
"""

a = [4, 0, 0, 0]
result = [0] * 8

def broken_shr16(x):
    """The hypothesis: returns the low word instead of x >> 16."""
    return x & 0xFFFF

carry = 0
i = 0
for j in range(4):
    prod = a[i]*a[j] + result[i+j] + carry
    result[i+j] = prod & 0xFFFF
    carry = broken_shr16(prod)   # <-- the bugged operation

print(f"After j-loop (i=0): result={result}, carry={carry}")
print(f"  Matches observed carry=16 at 'k:=i+NLIMB' breakpoint? {carry == 16}")

k = i + 4
iterations = 0
try:
    while carry != 0 and iterations < 6:
        prod = result[k] + (carry & 0xFFFF)
        result[k] = prod & 0xFFFF
        carry = broken_shr16(carry) + broken_shr16(prod)
        print(f"  k={k}: result[{k}]={result[k]}, new carry={carry}"
              + ("  <-- matches observed prod=16 at this exact point" if k == 4 else ""))
        k += 1
        iterations += 1
except IndexError:
    print(f"  k={k}: IndexError -- exactly the runaway Pascal's {{$R-}} let through")
    print(f"  silently (k kept climbing past the array's real bound of 7 on real")
    print(f"  hardware, observed reaching 131 before the session ended)")

print(f"\nReconstructed result after i=0 (before the runaway exceeds bounds): {result}")
print("Observed from WriteLn diagnostic: [16, 16, 16, 16, 16, 32, 64, 128]")
print(f"Exact match: {result == [16, 16, 16, 16, 16, 32, 64, 128]}")
