import random

# Simulate a "memory" of N cells (chunk-granularity, mirrors the real design:
# each XMS 1KB chunk is treated as one march "cell" holding a uniform value,
# since that's the granularity the XMS move interface actually gives us).
#
# We inject each classic fault type one at a time and confirm March C-
# (w0; up(r0,w1); up(r1,w0); down(r0,w1); down(r1,w0); r0)
# actually detects it, before trusting the same sequence in Pascal.

class Mem:
    def __init__(self, n, fault=None):
        self.n = n
        self.cells = [0]*n
        self.fault = fault  # (kind, params)

    def write(self, addr, val):
        if self.fault:
            kind = self.fault[0]
            if kind == 'stuck_at' and addr == self.fault[1]:
                self.cells[addr] = self.fault[2]  # ignores the write
                return
            if kind == 'coupling' and addr == self.fault[1]:
                # writing the aggressor cell also forces the victim to a fixed value
                self.cells[self.fault[2]] = self.fault[3]
        self.cells[addr] = val
        if self.fault and self.fault[0] == 'addr_alias' and addr == self.fault[1]:
            # decode fault: this address actually writes to a different physical cell too
            self.cells[self.fault[2]] = val

    def read(self, addr):
        return self.cells[addr]

def march_c_minus(mem, n):
    faults = []
    for a in range(n):
        mem.write(a, 0)
    for a in range(n):
        if mem.read(a) != 0: faults.append(('M1-read0', a))
        mem.write(a, 1)
    for a in range(n):
        if mem.read(a) != 1: faults.append(('M2-read1', a))
        mem.write(a, 0)
    for a in range(n-1, -1, -1):
        if mem.read(a) != 0: faults.append(('M3-read0', a))
        mem.write(a, 1)
    for a in range(n-1, -1, -1):
        if mem.read(a) != 1: faults.append(('M4-read1', a))
        mem.write(a, 0)
    for a in range(n):
        if mem.read(a) != 0: faults.append(('M5-read0', a))
    return faults

N = 20
tests = [
    ("stuck_at bit stuck at 1 on cell 7", ('stuck_at', 7, 1)),
    ("stuck_at bit stuck at 0 on cell 12", ('stuck_at', 12, 0)),
    ("coupling: writing cell 5 forces cell 6 to 1", ('coupling', 5, 6, 1)),
    ("coupling: writing cell 15 forces cell 3 to 0", ('coupling', 15, 3, 0)),
    ("address alias: writes to cell 4 also land on cell 17", ('addr_alias', 4, 17)),
    (None, None),  # no fault, sanity check: must be clean
]

for desc, fault in tests:
    mem = Mem(N, fault)
    faults = march_c_minus(mem, N)
    print(f"{desc or 'NO FAULT (sanity check)'}: {'DETECTED' if faults else 'clean'} "
          f"({len(faults)} flagged ops)")
