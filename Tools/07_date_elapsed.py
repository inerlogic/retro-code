"""
Verify a DOS-date/time-based elapsed-time calculator, using
INT 21h AH=2Ah (Get Date: year, month, day) and AH=2Ch (Get Time:
hour, minute, second, hundredths) as the two data points.

Approach: convert (Y,M,D) to a linear day count via a standard,
well-known civil-calendar algorithm (Howard Hinnant's days_from_civil,
proleptic Gregorian, handles leap years correctly), then:

    total_seconds(reading) = days_from_civil(Y,M,D)*86400 + H*3600 + Mi*60 + S
    elapsed = total_seconds(reading2) - total_seconds(reading1)

No manual midnight-rollover detection needed at all -- DOS's own
date advancement handles it, we just linearize both readings the
same way and subtract.
"""

import random
import datetime

def days_from_civil(y, m, d):
    """Howard Hinnant's algorithm: days since 1970-01-01 (can be negative),
    for the proleptic Gregorian calendar. y/m/d integers, m in [1,12]."""
    y -= 1 if m <= 2 else 0
    era = (y if y >= 0 else y - 399) // 400
    yoe = y - era * 400                                   # [0, 399]
    doy = (153 * (m + (9 if m <= 2 else -3)) + 2) // 5 + d - 1  # [0, 365]
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy          # [0, 146096]
    return era * 146097 + doe - 719468

def total_seconds(y, mo, d, h, mi, s):
    return days_from_civil(y, mo, d) * 86400 + h * 3600 + mi * 60 + s

def elapsed_seconds(reading_start, reading_now):
    return total_seconds(*reading_now) - total_seconds(*reading_start)

def format_elapsed(total_secs):
    days = total_secs // 86400
    rem = total_secs % 86400
    hours = rem // 3600
    rem %= 3600
    minutes = rem // 60
    seconds = rem % 60
    return f"{days}d {hours:02d}:{minutes:02d}:{seconds:02d}"

# --- Cross-check days_from_civil against Python's datetime for thousands of dates ---
random.seed(7)
fail = 0
trials = 0
epoch = datetime.date(1970, 1, 1)
for _ in range(50000):
    trials += 1
    y = random.randint(1980, 2040)   # realistic DOS-era-plus-modern range
    mo = random.randint(1, 12)
    # pick a valid day for that month/year using Python's own calendar to get max day
    import calendar
    max_day = calendar.monthrange(y, mo)[1]
    d = random.randint(1, max_day)
    got = days_from_civil(y, mo, d)
    expected = (datetime.date(y, mo, d) - epoch).days
    if got != expected:
        fail += 1
        print(f"  MISMATCH y={y} m={mo} d={d}: got={got} expected={expected}")
        if fail > 5:
            break
print(f"days_from_civil: {trials} trials, {'ALL PASS' if fail==0 else f'{fail} FAILURES'}")

print()
print("=== Fuzzing full elapsed_seconds() against Python datetime, including year/month/leap-year boundaries ===")
fail2 = 0
trials2 = 0
for _ in range(50000):
    trials2 += 1
    y1 = random.randint(1980, 2039)
    mo1 = random.randint(1, 12)
    max_day1 = calendar.monthrange(y1, mo1)[1]
    d1 = random.randint(1, max_day1)
    h1, mi1, s1 = random.randint(0,23), random.randint(0,59), random.randint(0,59)

    # pick a second reading some random duration later (0 sec up to ~10 days later)
    dt1 = datetime.datetime(y1, mo1, d1, h1, mi1, s1)
    delta_secs = random.randint(0, 10*86400)
    dt2 = dt1 + datetime.timedelta(seconds=delta_secs)

    reading1 = (y1, mo1, d1, h1, mi1, s1)
    reading2 = (dt2.year, dt2.month, dt2.day, dt2.hour, dt2.minute, dt2.second)

    got = elapsed_seconds(reading1, reading2)
    if got != delta_secs:
        fail2 += 1
        print(f"  MISMATCH reading1={reading1} reading2={reading2}: got={got} expected={delta_secs}")
        if fail2 > 5:
            break

print(f"elapsed_seconds: {trials2} trials (spanning up to 10 days, crossing months/years/leap-days), "
      f"{'ALL PASS' if fail2==0 else f'{fail2} FAILURES'}")

# --- Specific edge cases: leap day, year boundary, month boundary ---
edge_cases = [
    # (reading1, reading2, expected_seconds)
    ((2024, 2, 28, 23, 59, 59), (2024, 2, 29, 0, 0, 1), 2),      # into a leap day
    ((2024, 2, 29, 12, 0, 0),   (2024, 3, 1, 12, 0, 0), 86400),   # leap day -> March 1
    ((2023, 2, 28, 12, 0, 0),   (2023, 3, 1, 12, 0, 0), 86400),   # non-leap year: Feb 28 -> Mar 1 is 1 day
    ((2025, 12, 31, 23, 59, 0), (2026, 1, 1, 0, 1, 0), 120),       # year boundary
]
print()
print("=== Specific calendar edge cases ===")
for r1, r2, expected in edge_cases:
    got = elapsed_seconds(r1, r2)
    status = "OK" if got == expected else "FAIL <<<"
    print(f"  {r1} -> {r2}: got={got}s expected={expected}s  {status}")
    print(f"    displayed as: {format_elapsed(got)}")
