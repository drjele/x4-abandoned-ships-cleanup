# Abandoned Ships Cleanup for X4: Foundations

Abandoned ships never go away in X4. Every pilot that bails leaves a hull floating in space
forever, so a long-running game accumulates them without limit — well over a thousand is normal,
most of them combat leftovers, and many of them cluttering the map.

This mod puts an expiry clock on abandoned ships and blows them up when it runs out. Ships that
are supposed to be there — the free ships placed at game start, story and mission derelicts,
wrecks you are salvaging, anything you are currently boarding — are left alone.

**Requires X4: Foundations 9.00.** No DLC required, and no dependency on other mods. Works on an
existing savegame, and removing it leaves nothing behind.

## Install

```bash
./install.sh
```

That finds your X4 installation — the usual Steam layouts including extra library folders — and
copies `extension/` into `X4 Foundations/extensions/drjele_abandoned_ships_cleanup`. If it cannot find
the game, or you want a different copy of it, point it there yourself:

```bash
X4_PATH="/path/to/X4 Foundations" ./install.sh
```

**Restart X4** — extensions are only read at startup.

It copies rather than symlinks on purpose: X4 only enumerates real directories under
`extensions/`, and silently ignores a symlink placed there. So re-run `./install.sh` after every
edit. `./install.sh --uninstall` removes it again.

## What it spares

The clock is only ever started on a ship that passes every one of these:

| Rule | What it protects |
|---|---|
| Main galaxy only (`xu_ep2_universe_macro`) | Every Timelines scenario, the Timelines hub, tutorials, the demo universe and the workshop map |
| Not in `global.$IgnoredAbandonedShips` | The game's own do-not-touch list: the nine abandoned ships Timelines places in the main galaxy (Cutlass, Odachi, Sapporo, the three racers, Xenon F/B/H) and every story or mission derelict from the base game, Split, Terran, Boron and Pirate |
| `spawntime` newer than 60s | Anything placed while the universe was generated — the six vanilla claimable ships *and* every DLC static placement, present or future |
| Not a wreck | Tides of Avarice salvage is made of `class.ship` objects in the wreck state; without this the mod would eat your salvage yard |
| Not mission-spawned, not renamed | Scripted content and anything you gave a name to |
| No inbound boarding operation, no salvage claim | Ships you have already sent marines or a tug to |
| Not invulnerable or indestructible | Objects a script has made invincible |
| Not a drone, spacesuit, docked ship or highway traffic | The same filters the game's own derelict detector uses |

Destruction is additionally held off while the ship is visible to the player, so nothing ever
pops out of existence in front of you — it is simply retried on the next pass.

### Why `spawntime` rather than a list of ship macros

Every ship placed during universe generation has `spawntime == 0`, so one numeric comparison
covers the base game and every DLC without hardcoding a single macro name, and keeps working for
DLCs that do not exist yet. Checked against a savegame: of the ownerless ships present, the only
ones under the threshold were the vanilla claimable ships and a Timelines placement — no false
positives, no false negatives.

## Configuration

The values live at the top of
[`extension/md/drjele_abandoned_ships_cleanup.xml`](extension/md/drjele_abandoned_ships_cleanup.xml).
They are re-read on every savegame load, so editing one and reloading is enough — no new game.

| Value | Default | Meaning |
|---|---|---|
| `$Lifetime` | `5h` | Game time an abandoned ship survives once the mod has seen it. Game time, so SETA speeds it up |
| `$GameStartGrace` | `60s` | Ships spawned before this point count as game-start placements |
| `$StaleGap` | `15min` | Gap between two sightings after which the clock restarts instead of expiring |
| `$BatchSize` | `100` | Ships evaluated per tick |
| `$DebugChance` | `0` | Set to `100` to log every pass and every destruction |

The lifetime can also be changed at runtime, without editing the file, from a cheat menu or any
other mod:

```xml
<set_value name="global.$DrJeleAbandonedShipLifetime" exact="30min"/>
```

## How it works

A single cue scans the galaxy every 5 minutes with one `find_ship_by_true_owner` call, then walks
the result 100 ships at a time on a 1-second tick so a thousand derelicts never cost a whole
frame. Each ship carries its own clock in two savegame-persisted variables on the object itself
(`$DrJeleAbandonedSince`, `$DrJeleLastSeen`) — no per-ship cues, no global bookkeeping.

The two-timestamp scheme is what makes the clock self-healing: if the gap between two sightings is
larger than `$StaleGap`, the ship must have been claimed and abandoned again in between, so the
clock restarts instead of expiring the moment it is seen.

## Debugging

Set `$DebugChance` to `100` and add `-debug scripts -logfile debuglog.txt` to the game's launch
options. `scripts` rather than `all`: `debug_text` writes on the `scripts` channel by default, and
`all` buries it under everything else.

The log is written to the X4 user directory, next to your savegames — `Documents/Egosoft/X4/<id>/`
on Windows, `~/.config/EgoSoft/X4/<id>/` on Linux (or under `~/snap/...` for the Steam snap).

## Status

Working, verified in game on 9.00 in a long-running savegame that had accumulated 1157 abandoned
ships.

| Check | Result |
|---|---|
| Ships cleaned | 1151 in a single pass |
| Ships spared | 6 — exactly the vanilla claimable ships, by the `spawntime` rule |
| Timer honoured | destroyed after 122–133s against a 120s test lifetime; never early |
| Steady state | the same 6 keep being scanned and never clocked; a ship that bailed during the test got its own clock and was destroyed 122s later |
| Script errors | none |

The 122–133s spread is just scan granularity: a ship is destroyed on the first pass after its
clock expires, so with the default 5h lifetime and 5min scan interval the real lifetime is 5h to
5h05m.

Not yet proven across a long play session. If you find a ship it should have spared, that is the
interesting bug and I want to hear about it.

## Legal

MIT, see [`LICENSE`](LICENSE). Non-commercial fan project; X4: Foundations belongs to Egosoft GmbH
and this is not affiliated with or endorsed by them.
