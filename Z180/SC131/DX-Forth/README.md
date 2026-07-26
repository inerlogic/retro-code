# DX-Forth

Forth programs for the SC131, written for DX-Forth.

## cat.fth

A paged file viewer, same purpose as the Aztec-C [`VIEW.C`](../Aztec-C/utilities/)
utility elsewhere in this repo, in Forth instead of C. Loads with
`INCLUDE CAT.FTH`, then `CAT <filename>` prints the file a page (20
lines) at a time, pausing with a `-- more (any key, q to quit) --`
prompt between pages. Any key continues; `q` or Esc quits early.
