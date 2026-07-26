# Transliteration of the new Pascal logic (InitPatterns, TestChunkAddr's
# expected-value formula, and the RunMarchBlock phase structure) into
# Python, run against a simulated XMS block with injected faults, to
# catch transcription bugs in the Pascal itself, not just the algorithm
# concept (already checked separately in march_verify.py).

WORD_MASK = 0xFFFF

def init_patterns():
    patterns = []
    names = []
    patterns.append(0xAAAA); names.append('0xAA fill')
    patterns.append(0x5555); names.append('0x55 fill')
    for bit in range(16):
        patterns.append((1 << bit) & WORD_MASK); names.append(f'walk-1 bit {bit}')
    for bit in range(16):
        patterns.append((0xFFFF ^ (1 << bit)) & WORD_MASK); names.append(f'walk-0 bit {bit}')
    assert len(patterns) == 34
    return patterns, names

def addr_expected(byte_offset, i):
    return (byte_offset + i * 2) & WORD_MASK

class XMSBlockSim:
    """Simulates one grabbed XMS block as a flat word array, with an
    injectable fault. chunk = 512 words (1KB), matching ChunkWords."""
    def __init__(self, kb, fault=None):
        self.words = [0] * (kb * 512)
        self.fault = fault  # (kind, *params), addressed in WORD indices

    def write_chunk(self, chunk, vals):
        base = chunk * 512
        for i, v in enumerate(vals):
            addr_word = base + i
            if self.fault and self.fault[0] == 'stuck_at' and addr_word == self.fault[1]:
                self.words[addr_word] = self.fault[2]
                continue
            self.words[addr_word] = v
            if self.fault and self.fault[0] == 'coupling' and addr_word == self.fault[1]:
                self.words[self.fault[2]] = self.fault[3]

    def read_chunk(self, chunk):
        base = chunk * 512
        return self.words[base:base+512]

def test_chunk_const(mem, chunk, pattern):
    mem.write_chunk(chunk, [pattern]*512)
    vals = mem.read_chunk(chunk)
    return all(v == pattern for v in vals)

def test_chunk_addr(mem, chunk):
    base_off = chunk * 1024
    vals_to_write = [addr_expected(base_off, i) for i in range(512)]
    mem.write_chunk(chunk, vals_to_write)
    vals = mem.read_chunk(chunk)
    return all(vals[i] == addr_expected(base_off, i) for i in range(512))

def march_write(mem, chunk, val):
    mem.write_chunk(chunk, [val]*512)
    return True

def march_read_write(mem, chunk, expect_before, write_after):
    vals = mem.read_chunk(chunk)
    ok = all(v == expect_before for v in vals)
    mem.write_chunk(chunk, [write_after]*512)
    return ok

def march_read(mem, chunk, expect_val):
    vals = mem.read_chunk(chunk)
    return all(v == expect_val for v in vals)

def run_march_block(mem, num_chunks):
    faults = 0
    for c in range(num_chunks):
        if not march_write(mem, c, 0): faults += 1
    for c in range(num_chunks):
        if not march_read_write(mem, c, 0, 1): faults += 1
    for c in range(num_chunks):
        if not march_read_write(mem, c, 1, 0): faults += 1
    for c in range(num_chunks-1, -1, -1):
        if not march_read_write(mem, c, 0, 1): faults += 1
    for c in range(num_chunks-1, -1, -1):
        if not march_read_write(mem, c, 1, 0): faults += 1
    for c in range(num_chunks):
        if not march_read(mem, c, 0): faults += 1
    return faults

# --- Sanity check 1: pattern table matches expectations ---
patterns, names = init_patterns()
assert patterns[0] == 0xAAAA and patterns[1] == 0x5555
assert patterns[2] == 1 and names[2] == 'walk-1 bit 0'
assert patterns[17] == 0x8000 and names[17] == 'walk-1 bit 15'
assert patterns[18] == 0xFFFE and names[18] == 'walk-0 bit 0'
assert patterns[33] == 0x7FFF and names[33] == 'walk-0 bit 15'
print("InitPatterns transliteration: OK (34 patterns, spot-checked endpoints)")

# --- Sanity check 2: const-pattern test clean on unfaulted memory ---
mem = XMSBlockSim(kb=4)
ok_all = all(test_chunk_const(mem, c, 0xAAAA) for c in range(4))
print(f"TestChunkConst on clean memory: {'clean' if ok_all else 'FALSE POSITIVE FAULT'}")

# --- Sanity check 3: addr-in-addr test clean on unfaulted memory ---
mem = XMSBlockSim(kb=4)
ok_all = all(test_chunk_addr(mem, c) for c in range(4))
print(f"TestChunkAddr on clean memory: {'clean' if ok_all else 'FALSE POSITIVE FAULT'}")

# --- Sanity check 4: addr-in-addr test catches an addr-decode fault ---
# fault: writes meant for word 300 in chunk 2 (word index 2*512+300=1324)
# actually land on word index 5000 too (simulating a decode fault)
mem = XMSBlockSim(kb=16, fault=('coupling', 1324, 5000, 0xDEAD))
results = [test_chunk_addr(mem, c) for c in range(16)]
print(f"TestChunkAddr catches injected coupling/decode fault: "
      f"{'DETECTED' if not all(results) else 'MISSED'} "
      f"(chunk 2 result={results[2]}, chunk for word 5000={5000//512} result={results[5000//512]})")

# --- Sanity check 5: March C- (Pascal-structure version) on clean memory ---
mem = XMSBlockSim(kb=8)
faults = run_march_block(mem, 8)
print(f"RunMarchBlock on clean memory: {faults} faults (expect 0)")

# --- Sanity check 6: March C- catches a stuck-at fault mid-block ---
mem = XMSBlockSim(kb=8, fault=('stuck_at', 3*512+10, 1))  # word stuck at 1
faults = run_march_block(mem, 8)
print(f"RunMarchBlock catches stuck-at fault: {'DETECTED' if faults > 0 else 'MISSED'} ({faults} flagged)")

# --- Sanity check 7: March C- catches a coupling fault between two chunks ---
mem = XMSBlockSim(kb=8, fault=('coupling', 1*512+0, 6*512+0, 1))
faults = run_march_block(mem, 8)
print(f"RunMarchBlock catches cross-chunk coupling fault: {'DETECTED' if faults > 0 else 'MISSED'} ({faults} flagged)")

# --- Follow-up: confirm this is specifically about visit ORDER, not a ---
# --- general weakness, by injecting the same coupling fault backwards ---
# (aggressor chunk visited AFTER victim in ascending order): does
# TestChunkAddr's isolated per-chunk write+read still miss it, and does
# March C- still catch it via M3/M4 (the descending sweep)?
print()
mem = XMSBlockSim(kb=8, fault=('coupling', 6*512+0, 1*512+0, 1))  # aggressor=chunk6, victim=chunk1
results = [test_chunk_addr(mem, c) for c in range(8)]
print(f"TestChunkAddr, aggressor-after-victim in scan order: "
      f"{'DETECTED' if not all(results) else 'MISSED'} "
      f"(victim chunk1 result={results[1]})")

mem = XMSBlockSim(kb=8, fault=('coupling', 6*512+0, 1*512+0, 1))
faults = run_march_block(mem, 8)
print(f"RunMarchBlock, same fault: {'DETECTED' if faults > 0 else 'MISSED'} ({faults} flagged)")
