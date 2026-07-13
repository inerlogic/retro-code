# Dungeon Crawler (Turbo Pascal 3)

A roguelike-lite for CP/M. WASD to move, Q to retire.

## Inspiration

This started as a personal experiment after playing *Paper App DUNGEON* by [Gladden Design](https://gladdendesign.com/) (designed by Tom Brinton) — a pencil-and-paper dungeon crawler played out on grid paper with a single die. Wanted to see what a similar idea would look like as a small digital program instead: a single procedurally generated floor, CP/M-native, roughly in the spirit of NetHack but drastically scaled down — the Z180/Z80 machines this runs on almost certainly don't have anywhere near the RAM a real NetHack-scale game would need.

## Features

- Dungeon layout is generated with a random-walk "miner" that carves floor tiles out of solid rock for a fixed number of steps, then places coins (`$`), chests (`C`), monsters (`M`), and a single stairway down (`>`).
- Fog of war: tiles are only revealed within a radius around the player as they move; once every reachable non-wall tile on a floor has been revealed, the whole map is auto-illuminated.
- Combat is dice-based: each monster gets a random "tier" (1–5), and fighting rolls 1–6 — meet or beat the tier to win a coin, otherwise take a point of damage. You can also retreat back to your previous tile instead of fighting.
- Stairs are locked until every monster on the floor has been cleared; stepping on them first visits a traveling merchant (potions cost 10 coins, heal 2 HP) before generating the next floor down.
- High scores (by coin total) persist to `DUNGEON.DAT` as a binary file of fixed-size records, with the standard placeholder table (Knight/Rogue/Wizard/Paladin/Peasant) used the first time the game runs and no file exists yet.

Game ends either by death (HP reaches 0) or by voluntarily retiring with Q, either way followed by the scoreboard.

## Known issues

*(See the [repo root README](../../../../README.md) for why bugs are left documented here.)*

- **Fixed (Update 3):** the traveling merchant screen was displaying a stray `[F] Fight (Roll 1-6 Die)` prompt that made no sense in a shop context. Root cause: `ProcessMerchant` is called immediately after combat resolves, with no `ClrScr` in between, and it never wrote to the screen row `ResolveMonsterCombat` uses for that prompt — so the leftover text from the fight just before it stayed on screen. Fixed by explicitly clearing that row in `ProcessMerchant`.
