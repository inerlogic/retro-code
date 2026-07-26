# Transliteration check of the fault-log additions: ResetFaultLog/LogFault/
# PrintFaultLog logic, run against a simulated test pass with several
# faulty offsets, including one run that exceeds MaxLoggedFaults (40) to
# confirm the overflow flag behaves.

MaxLoggedFaults = 40

class FaultLog:
    def __init__(self):
        self.offsets = []
        self.overflow = False
    def reset(self):
        self.offsets = []
        self.overflow = False
    def log(self, offset):
        if len(self.offsets) < MaxLoggedFaults:
            self.offsets.append(offset)
        else:
            self.overflow = True

def hexstr(v):
    return format(v, 'X') if v else '0'

def print_fault_log(fl):
    lines = []
    if not fl.offsets:
        lines.append("  0 faults")
        return lines
    lines.append(f"  {len(fl.offsets)}{'+' if fl.overflow else ''} fault(s):")
    for off in fl.offsets:
        lines.append(f"    offset {off} bytes ({off // 1024} KB into block)  "
                      f"est. abs. addr {hexstr(off + 0x100000)}h")
    if fl.overflow:
        lines.append(f"    ({MaxLoggedFaults}+ faults, list capped, more occurred)")
    return lines

# Scenario matching what was just seen: a walk-0 pattern test with a
# handful of faults scattered through a ~7104 KB block
fl = FaultLog()
fl.reset()
for chunk in [3080, 3200, 3570, 4460, 4500]:  # KB offsets roughly in CheckIt's bands
    fl.log(chunk * 1024)
for line in print_fault_log(fl):
    print(line)

print()
# Overflow scenario: more than 40 faults in one test
fl.reset()
for chunk in range(0, 60):
    fl.log(chunk * 1024)
out = print_fault_log(fl)
print(out[0])
print(out[-1])
print(f"(total lines for offsets: {len(out) - 2}, expect {MaxLoggedFaults})")
