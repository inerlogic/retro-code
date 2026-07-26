# Sanity-check the TimestampStr format and confirm the log-writing logic
# (as transliterated) only ever produces output on faulty tests, matching
# "don't log good results, just errors."

def pad2(v):
    s = str(v)
    return s if len(s) >= 2 else '0' + s

def timestamp_str(h, m, s, yy, mo, dd):
    return f"{pad2(mo)}/{pad2(dd)}/{yy} {pad2(h)}:{pad2(m)}:{pad2(s)}"

print(timestamp_str(9, 5, 3, 2026, 7, 26))   # expect 07/26/2026 09:05:03
print(timestamp_str(23, 59, 9, 2026, 12, 31))  # expect 12/31/2026 23:59:09

# Simulate a scanner run: some clean tests, some faulty, confirm log
# only gets lines for the faulty ones.
log_lines = []

def print_fault_log(block, test_num, total, desc, fault_offsets):
    if not fault_offsets:
        return  # nothing written to disk, matches "0 faults" on-screen-only case
    log_lines.append(f"TIMESTAMP  block {block}, test {test_num}/{total} ({desc}): "
                      f"{len(fault_offsets)} fault(s)")
    for off in fault_offsets:
        log_lines.append(f"    offset {off} bytes ({off//1024} KB into block)")

# clean tests
for t, d in [(1, '0xAA fill'), (2, '0x55 fill'), (3, 'walk-1 bit 0')]:
    print_fault_log(1, t, 41, d, [])
# one faulty test
print_fault_log(1, 20, 41, 'walk-0 bit 1', [3072*1024, 3200*1024])
# more clean tests after
print_fault_log(1, 21, 41, 'walk-0 bit 2', [])

print()
print(f"Total log lines written: {len(log_lines)} (expect 3: 1 header + 2 offsets)")
for l in log_lines:
    print(l)
