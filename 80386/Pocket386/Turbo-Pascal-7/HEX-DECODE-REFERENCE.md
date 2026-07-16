# Reading Life patterns off the hex grid

A cheat sheet for decoding what's actually happening on the board from the
packed hex-digit display, instead of re-deriving it by eye every time.
Standard [Conway's Game of Life](https://conwaylife.com/wiki/Conway%27s_Game_of_Life)
rules throughout; pattern names below follow [LifeWiki](https://conwaylife.com/wiki/)
convention.

## The encoding

Every 4 consecutive cells in a row pack into one hex digit. Bit order is
**left-to-right = most-significant-to-least-significant**: the leftmost of
the 4 cells is worth 8, then 4, then 2, then 1 (rightmost). So a hex digit
is just "which of these 4 cells are alive," read as a 4-bit binary number.

## Full lookup table

| Hex | Binary | Alive cells (L→R) |
|---|---|---|
| 0 | 0000 | none |
| 1 | 0001 | ...X (rightmost only) |
| 2 | 0010 | ..X. |
| 3 | 0011 | ..XX (right two) |
| 4 | 0100 | .X.. |
| 5 | 0101 | .X.X |
| 6 | 0110 | .XX. (middle two) |
| 7 | 0111 | .XXX (right three) |
| 8 | 1000 | X... (leftmost only) |
| 9 | 1001 | X..X (outer two) |
| A | 1010 | X.X. |
| B | 1011 | X.XX |
| C | 1100 | XX.. (left two) |
| D | 1101 | XX.X |
| E | 1110 | XXX. (left three) |
| F | 1111 | XXXX (all four) |

## Worked example: the blinker

A [blinker](https://conwaylife.com/wiki/Blinker) is the simplest oscillator
in the game: 3 cells in a row, flipping between a horizontal and a vertical
orientation every generation, period 2. It's also the pattern you'll run
into constantly, because it's small and common -- worth knowing cold.

The 3 cells can land in one of four ways relative to the 4-cell packing
boundary, and each way looks completely different on screen despite being
the exact same oscillator:

| Horizontal phase | Straddles a<br>digit boundary? | Vertical phase (repeated 3 rows) |
|---|---|---|
| **E** (`XXX.`) | No -- fits in one digit, left-aligned | **444** -- center cell sits at sub-position 2 (value 4) |
| **7** (`.XXX`) | No -- fits in one digit, right-aligned | **222** -- center cell sits at sub-position 3 (value 2) |
| **38** | Yes -- `..XX` + `X...` across two digits | **1_0** -- center cell is the rightmost sub-position of the left digit (1); the right digit shows 0 |
| **1C** | Yes -- `...X` + `XX..` across two digits | **08** -- center cell is the leftmost sub-position of the right digit (8); the left digit shows 0 |

**The "invisible partner digit" catch:** in the two straddling cases, the
vertical phase is really a *two-character* column each row (e.g. `1` next
to a `0`), not a single repeated digit -- but `0` renders as the darkest,
dimmest color in the heat-map palette, so it tends to visually disappear
against the background at a glance. That's almost certainly why `38`
read back as a clean `111` column and `1C` as a clean `888` column rather
than `10`/`08` -- the zero was there, just easy to miss.

**Bottom line:** `E`/`444`, `7`/`222`, `38`/`111`(really `1`+`0`), and
`1C`/`888`(really `0`+`8`) are four costumes for the exact same oscillator,
not four different things to memorize. If you can recognize any one of
these transitioning to any other, you've found a blinker.

## Other patterns -- add as found

This section's deliberately sparse -- fill it in as you spot and confirm
new ones on screen, the same way the blinker case above got worked out.
Good next candidates, given what's already turned up on this grid:

- **The traffic light** (already spotted, live) -- four blinkers arranged
  around a shared center, alternating between a hollow diamond and a solid
  plus shape every generation. Worth writing up its own hex-digit
  before/after pair once you catch it again with a clean screenshot.
- **Block** (2x2 still life) -- two adjacent live cells in each of 2
  consecutive rows. Never moves, never changes -- if you see the same two
  hex digits repeating unchanged generation after generation in two
  adjacent rows, this is almost certainly it.
- **Glider** -- the 5-cell diagonal traveler already confirmed loose on
  this board (it's what ate the traffic light). Worth documenting its 4
  rotation phases and packing alignments the next time one's caught mid-flight
  in a screenshot with enough surrounding context to trace it across a
  few generations.
