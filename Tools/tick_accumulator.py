"""
Verify a midnight-rollover-safe elapsed-time accumulator for a BIOS
tick-count-based burn-in timer, using the "detect a decrease in
consecutive raw readings" technique rather than trusting the AL
midnight flag from INT 1Ah (which is known to be unreliable across
BIOS vendors).

Raw BIOS tick counter: increments at ~18.2065 Hz, resets to 0 at
local midnight. TICKS_PER_DAY below is the commonly cited constant;
flagged as approximate / needs hardware confirmation.
"""

TICKS_PER_DAY = 1573040   # commonly cited constant; NOT yet hardware-verified
TICKS_PER_SEC = TICKS_PER_DAY / 86400.0  # ~18.2065

class TickAccumulator:
    """Mirrors what AccumulateTicksInto will need to do each poll:
    take the latest raw BIOS tick reading, and maintain a running
    total of elapsed ticks since the test started, correctly handling
    any number of midnight rollovers between polls."""
    def __init__(self, first_raw_reading):
        self.prev_raw = first_raw_reading
        self.total_elapsed_ticks = 0

    def poll(self, new_raw):
        if new_raw >= self.prev_raw:
            delta = new_raw - self.prev_raw
        else:
            # rollover(s) occurred since last poll.
            # First rollover: from prev_raw up to the day boundary, then 0 to new_raw.
            delta = (TICKS_PER_DAY - self.prev_raw) + new_raw
        self.total_elapsed_ticks += delta
        self.prev_raw = new_raw
        return self.total_elapsed_ticks

def format_elapsed(total_ticks):
    total_seconds = total_ticks / TICKS_PER_SEC
    days = int(total_seconds // 86400)
    rem = total_seconds - days*86400
    hours = int(rem // 3600)
    rem -= hours*3600
    minutes = int(rem // 60)
    seconds = int(rem - minutes*60)
    return f"{days}d {hours:02d}:{minutes:02d}:{seconds:02d}"

# --- Test 1: simple case, no rollover, frequent polling ---
acc = TickAccumulator(first_raw_reading=0)
readings = [0, 1000, 5000, 10000, 50000]
results = [acc.poll(r) for r in readings]
assert results == readings, f"simple case failed: {results}"
print("Test 1 (no rollover): PASS ->", results)

# --- Test 2: single midnight rollover between two polls ---
acc = TickAccumulator(first_raw_reading=TICKS_PER_DAY - 500)  # 500 ticks before midnight
total = acc.poll(200)  # 200 ticks after midnight
expected = 500 + 200
assert total == expected, f"single rollover failed: got {total}, expected {expected}"
print(f"Test 2 (single rollover): PASS -> elapsed={total} ticks ({format_elapsed(total)})")

# --- Test 3: multi-day simulated burn-in, polling every ~1000 ticks, verify monotonic + correct total ---
acc = TickAccumulator(first_raw_reading=0)
simulated_raw = 0
total_real_elapsed = 0
poll_count = 0
import random
random.seed(42)
prev_total = 0
DAYS_TO_SIMULATE = 5
target_total_ticks = DAYS_TO_SIMULATE * TICKS_PER_DAY
while total_real_elapsed < target_total_ticks:
    step = random.randint(500, 3000)   # irregular polling interval, but always << 1 day
    simulated_raw += step
    total_real_elapsed += step
    if simulated_raw >= TICKS_PER_DAY:
        simulated_raw -= TICKS_PER_DAY   # BIOS resets to 0 at midnight
    reported = acc.poll(simulated_raw)
    assert reported >= prev_total, f"NON-MONOTONIC elapsed time at poll {poll_count}: {reported} < {prev_total}"
    prev_total = reported
    poll_count += 1

# after loop, compare accumulator's total against ground truth
diff = abs(acc.total_elapsed_ticks - total_real_elapsed)
print(f"Test 3 (5-day burn-in, {poll_count} polls, irregular intervals):")
print(f"  ground truth elapsed ticks: {total_real_elapsed}")
print(f"  accumulator elapsed ticks:  {acc.total_elapsed_ticks}")
print(f"  difference: {diff} ticks  ->  {'PASS' if diff == 0 else 'FAIL <<<'}")
print(f"  displayed as: {format_elapsed(acc.total_elapsed_ticks)}")

# --- Test 4: edge case - poll lands EXACTLY at TICKS_PER_DAY-1 then wraps to 0 ---
acc = TickAccumulator(first_raw_reading=TICKS_PER_DAY - 1)
total = acc.poll(0)
assert total == 1, f"exact-boundary rollover failed: got {total}, expected 1"
print("Test 4 (exact boundary rollover): PASS")

# --- Test 5: what if two rollovers happen between polls (polling stopped for >48h)? ---
# Our current logic assumes at most ONE rollover between polls. Verify it detects
# the failure mode rather than silently giving a wrong-but-plausible answer.
acc = TickAccumulator(first_raw_reading=100)
raw_after_2_rollovers = 50  # two midnights passed, ended up at tick 50
reported = acc.poll(raw_after_2_rollovers)
naive_expected_one_rollover = (TICKS_PER_DAY - 100) + 50
actual_two_rollovers = (TICKS_PER_DAY - 100) + TICKS_PER_DAY + 50
print(f"Test 5 (double rollover, polling gap > 24h - KNOWN LIMITATION):")
print(f"  accumulator assumes single rollover, reports: {reported}")
print(f"  true elapsed if 2 rollovers occurred: {actual_two_rollovers}")
print(f"  -> silently WRONG by exactly {TICKS_PER_DAY} ticks (1 day) if polling gap exceeds 24h")
