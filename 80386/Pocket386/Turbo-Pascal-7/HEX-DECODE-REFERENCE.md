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

## Worked example: the traffic light

The [traffic light](https://conwaylife.com/wiki/Traffic_light) is four
blinkers arranged around a shared center, all in phase with each other --
period 2, alternating between a compact hollow diamond ("ring") and a
spread-out plus shape ("plus") every generation. Two separate instances
confirmed live on this grid so far, at different screen positions.

### Capture 1

Ring phase, as read (`38`/`00`/`82`/`82`/`82`/`00`/`38`), decodes to:

```
. . X X X . .
. . . . . . .
X . . . . . X
X . . . . . X
X . . . . . X
. . . . . . .
. . X X X . .
```

Plus phase, as read (`010`/`010`/`010`/`000`/`1C7`/`000`/`010`/`010`/`010`),
decodes to:

```
. . . X . . . . . . .
. . . X . . . . . . .
. . . X . . . . . . .
. . . . . . . . . . .
X X X . X X X . . . .
. . . . . . . . . . .
. . . X . . . . . . .
. . . X . . . . . . .
. . . X . . . . . . .
```

Each blinker has rotated 90° in place -- top/bottom are now vertical,
left/right are now horizontal, all radiating straight out from the shared
center. Same 12 live cells both phases (3+3+2+2+2 in the ring, 3+3+3+3 in
the plus) -- the plus phase just has a noticeably larger bounding box,
since a blinker pointing radially outward from the center reaches further
than one lying tangent to it.

### Capture 2 (the original, from the earlier blurry screenshots)

Ring phase, as read (`0E0`/`000`/`208`/`208`/`208`/`000`/`0E0`), decodes to:

```
. . . . X X X . . . . .
. . . . . . . . . . . .
. . X . . . . . X . . .
. . X . . . . . X . . .
. . X . . . . . X . . .
. . . . . . . . . . . .
. . . . X X X . . . . .
```

Plus phase, as read (`040`/`040`/`040`/`000`/`71C`/`000`/`040`/`040`/`040`),
decodes to:

```
. . . . . X . . . . .
. . . . . X . . . . .
. . . . . X . . . . .
. . . . . . . . . . .
. X X X . . X X X . .
. . . . . . . . . . .
. . . . . X . . . . .
. . . . . X . . . . .
. . . . . X . . . . .
```

Same shape and behavior as Capture 1, just sitting at a different column
offset relative to the hex-digit packing grid -- which is exactly why the
horizontal blinkers in the middle row read differently here: the left one
(`7`) fits cleanly inside one digit, while the right one (`1C`) straddles
a digit boundary. Both alignments from the blinker table above, showing
up side by side in the same row of the same pattern.

## Worked example: the boat

The [boat](https://conwaylife.com/wiki/Boat) is a common 5-cell still
life: two adjacent cells, a row below with a gap in the middle, and one
cell centered under that gap. Recognized by its still-life status
(genuinely stationary across generations) as much as by shape.

Two confirmed captures so far, both decoding to the same structure in
different rotations:

`C`/`A`/`4` decodes to:
```
X X . .
X . X .
. X . .
```

`6`/`5`/`2` decodes to:
```
. X X .
. X . X
. . X .
```

In binary, that's `0110` / `0101` / `0010` -- three rows, worth writing out
in full since this particular boat isn't just another catalog entry:
`6`/`5``2` was my dad's birthday, numbers he used everywhere. Not
something I was looking for -- just what happened to be on screen when I
looked. /he also used to work on my uncle's lobster boat, 
and he used to take me sailing.

Because this whole simulation is fully deterministic -- same seed, same
starting grid, same everything, forever -- this isn't a one-time sighting.
Seed 38, re-run from scratch, will produce the exact same boat at the
exact same generation, every time -- something to go back to on purpose,
not just wait to stumble across again.

Both show the same signature: 2 adjacent cells, then a row with a gap,
then 1 cell closing the gap from the opposite side -- just reflected/
rotated relative to each other. A third catch (`4`/`A`/`6`) is very
likely a further rotation of the same shape, though less certain without
having confirmed its stillness directly.

## Worked example: the glider

The [glider](https://conwaylife.com/wiki/Glider) is the smallest and most
common spaceship in the game: 5 cells that translate diagonally by one
cell every generation, cycling through 4 distinct phases as it moves.
Confirmed here via a 7-frame capture, seed 40, around generation 970-980.

**Methodology note, worth keeping for next time:** a static single frame
can't distinguish a glider from a stationary 5-cell still life like the
boat -- motion across generations is the actual test. But comparing raw
positions across separate phone screenshots doesn't work directly either,
because the crop/framing shifts slightly between captures. The fix:
anchor every frame to a nearby object that's *guaranteed* stationary --
a block (2x2 still life) is ideal, since real Life blocks never move by
definition -- and express every other live cell's position *relative to
the block's own position in that frame*, not relative to the raw frame
edges. That normalizes out any camera/crop drift entirely, since it's the
block's true immobility doing the work, not a steady hand.

Seven consecutive frames, decoded (`.` = dead, `X` = live):

```
Frame 1                              Frame 5
. . . X X . . . . . . . X X . .      . . . . X X . . . . . . . . . .
. . . . X X . . . . . . X X . .      . . . . . X X . . . . . X X . .
. . . X . . . . . . . . . . . .      . . . . X . . . . . . . X X . .

Frame 2                              Frame 6
. . . X X X . . . . . . X X . .      . . . . X X X . . . . . . . . .
. . . . . X . . . . . . X X . .      . . . . . . X . . . . . X X . .
. . . . X . . . . . . . . . . .      . . . . . X . . . . . . X X . .

Frame 3                              Frame 7
. . . . X . . . . . . . . . . .      . . . . . X . . . . . . . . . .
. . . . X X . . . . . . X X . .      . . . . . X X . . . . . . . . .
. . . X . X . . . . . . X X . .      . . . . X . X . . . . . X X . .
                                     . . . . . . . . . . . . X X . .

Frame 4
. . . . X X . . . . . . . . . .
. . . X . X . . . . . . X X . .
. . . . . X . . . . . . X X . .
```

**Every single frame is a real, verified glider phase -- checked against
actual Life-rule simulation, not recalled from memory.** Re-anchoring
each frame to the block and comparing the remaining 5 cells against all
16 possible glider phase/direction shapes (computed by stepping a real
glider forward, not guessed) gives an exact match, every time, all in
the same direction:

| Frame | Matches |
|---|---|
| 1 | up-right, phase 3 |
| 2 | up-right, phase 0 |
| 3 | up-right, phase 1 |
| 4 | up-right, phase 2 |
| 5 | up-right, phase 3 |
| 6 | up-right, phase 0 |
| 7 | up-right, phase 1 |

That sequence -- 3, 0, 1, 2, 3, 0, 1 -- is a clean +1 phase advance every
single step, with no skips. That's strong evidence these seven frames are
genuinely **consecutive generations**, not occasional samples: the phase
math only lines up this cleanly if nothing was missed between shots.
The block's own reported row position drifting slightly across the
frames (crop/camera movement, not the block itself moving -- blocks
can't move) is exactly why anchoring to it rather than trusting raw
frame position was the right call; the phase-match staying perfect
throughout is a good sign the anchoring is doing its job correctly.

Deterministic reproduction: seed 40, generation ~970-980, same result
every time it's re-run.



## Other still lifes confirmed

A running list, decoded and confirmed live on this grid -- will add to this
directly as more catch my eye.

**Beehive** ([6-cell still life](https://conwaylife.com/wiki/Beehive)) --
confirmed in three different alignments, a nice demonstration that the
blinker's "same object, different packing alignment" phenomenon applies
to still lifes too, not just oscillators:
- `6`/`9`/`6` -- standard horizontal orientation, fits cleanly in one digit
  per row:
  ```
  . X X .
  X . . X
  . X X .
  ```
- `10`/`28`/`28`/`10` -- same shape rotated 90°:
  ```
  . X .
  X . X
  X . X
  . X .
  ```
- `30`/`48`/`30` -- horizontal orientation again, but straddling a digit
  boundary rather than sitting inside one:
  ```
  . . X X . . . .
  . X . . X . . .
  . . X X . . . .
  ```

**Block** ([2x2 still life](https://conwaylife.com/wiki/Block)) -- two
adjacent live cells in each of 2 consecutive rows, unchanging generation
after generation. Confirmed in all three non-straddling alignments:
`C`/`C` (`1100`, left pair), `6`/`6` (`0110`, middle pair), `3`/`3`
(`0011`, right pair). A fourth, straddling alignment (crossing a digit
boundary the way the blinker's `38`/`1C` does) hasn't been confirmed yet
-- would show as two adjacent single-bit digits instead of one repeated
digit.

**Loaf** ([7-cell still life](https://conwaylife.com/wiki/Loaf)) --
confirmed as `6`/`9`/`5`/`2`, verified by actually stepping it forward
one generation and checking the result is identical (a genuine still
life, not just a plausible-looking shape), decoding to:
```
. X X .
X . . X
. X . X
. . X .
```

**Pond** ([8-cell still life](https://conwaylife.com/wiki/Pond)) -- a
hollow diamond, symmetric under 90° rotation and reflection. Confirmed as
`0C`/`12`/`12`/`0C`, decoding to:
```
. X X .
X . . X
X . . X
. X X .
```

**Tub** ([4-cell still life](https://conwaylife.com/wiki/Tub)) -- the
smallest member of the same hollow-diamond family as the pond, one ring
smaller. Confirmed as `2`/`5`/`2`, decoding to:
```
. . X .
. X . X
. . X .
```
## Patterns straddling the grid's own wraparound seam

A different gotcha from the hex-digit packing boundary above -- this one's
about the *whole grid's* edges, not a boundary between two adjacent hex
digits within a row.

The simulation is a genuine torus: `Step`'s neighbor calculations
explicitly wrap `X=GRIDW` back to `X=1`, and `Y=GRIDH` back to `Y=1`, so a
pattern straddling either seam is exactly as valid as one sitting
comfortably in the middle of the board -- the underlying physics doesn't
care where the seam is. But the *display* has no choice but to cut the
torus open somewhere to lay it out as flat rows and columns, and that cut
sits exactly at those same two boundaries. A pattern straddling the real
seam gets shown split across the two *opposite* edges of the visible
screen, even though on the actual torus those two edges are directly
adjacent -- the two halves are each other's immediate neighbor, not
strangers on opposite sides of the board.

Two confirmed examples, one per axis:

- **X-wrap (left/right edges):** a blinker's straddling horizontal phase
  (the `3`+`8` two-digit case from the table above) with the `8` half
  wrapping around to reappear at the far *left* edge of the grid, while
  its `3` half sat at the far right -- on the actual torus these two
  digits are directly adjacent columns, not opposite ends of the board.
- **Y-wrap (top/bottom edges):** an `E`/`444` blinker's vertical phase,
  where two of its three stacked `4`s sat in the bottom two rows and the
  third appeared instead at the very *top* row -- again, immediate
  physical neighbors on the torus, just cut apart by where the display
  has to open the loop into a flat rectangle.

Same underlying idea as the packing-boundary case, one level up: a
continuous thing can appear discontinuous on screen purely because of
where the layout has to draw an artificial line through a shape that, on
the actual torus, has no line running through it at all.

## Other patterns -- will add as found


