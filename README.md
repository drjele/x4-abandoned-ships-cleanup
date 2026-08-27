# Abandoned Ships Cleanup for X4: Foundations

Abandoned ships never go away in X4. Every pilot that bails leaves a hull floating in space
forever, so a long-running game accumulates them without limit — well over a thousand is normal,
most of them combat leftovers, and many of them cluttering the map.

This mod puts an expiry clock on abandoned ships and blows them up when it runs out. Ships that
are supposed to be there — the free ships placed at game start, story and mission derelicts,
wrecks you are salvaging, anything you are currently boarding — are left alone.

**Requires X4: Foundations 9.00.** No DLC required, and no hard dependency on other mods. Works on
an existing savegame. Removing it again takes the script and all of its per-ship bookkeeping with
it; the only trace left in the save is the pair of inert global variables the options menu writes.

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

## Publishing to the Steam Workshop

Egosoft does not publish from inside the game. Uploads go through `WorkshopTool`, shipped in the
**X Tools** package — Steam app 282160, `steam://install/282160`. It is a Windows executable, so on
Linux `publish.sh` runs it through Proton: plain wine cannot reach the native Steam client that
Steamworks needs. Steam has to be running and logged in with an account that owns X4 either way.

```bash
./publish.sh publish                    # first upload
./publish.sh update "what changed"      # every upload after that
```

`X_TOOLS_PATH` and `PROTON_PATH` override the automatic lookup, the same way `X4_PATH` does.

After the first upload the item exists but is **hidden**. Open the URL the script prints, accept
the Steam Workshop Legal Agreement, and set the visibility to public. Title and description come
from `name` and `description` in `content.xml` and can be edited on Steam afterwards.

`version` in `content.xml` is an integer, the version times a hundred — `100` is 1.00, `250` would
be 2.50. Bump it before an update, or pass `-minor` to the tool for a change that does not deserve
a version.

### Why the extension id is not in the repo twice

`WorkshopTool` writes the id Steam hands back into `content.xml`, as `ws_<number>`, because that is
how a later `update` knows which item to touch. Letting that land in the repo would be a bug: a
manual install would then claim the same extension id as a Workshop subscription, and X4 would see
one extension where there are two.

So the repo keeps the readable `drjele_abandoned_ships_cleanup`, the number lives on its own in
`steam/workshop-id`, and `publish.sh` substitutes it only into the copy it stages inside the game —
putting the local install back with `./install.sh` when it is done. Commit `steam/workshop-id`
after the first publish; without it `./publish.sh update` refuses to run.

For the same reason, do not subscribe to your own Workshop item while you have the manual install.

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

### In game

If [SirNukes Mod Support APIs](https://steamcommunity.com/sharedfiles/filedetails/?id=2042901274)
is installed, **Extension Options → Abandoned Ships Cleanup** gets two entries: the ship lifetime
in minutes (5 to 300, in steps of 5) and a debug logging toggle. Changes apply from the next scan
— no reload.

The dependency is optional and declared as such. Without it the mod behaves exactly the same, just
configured by the file below instead. Everything that touches the API lives in its own script,
[`drjele_abandoned_ships_cleanup_options.xml`](extension/md/drjele_abandoned_ships_cleanup_options.xml),
which simply writes the same global variables the file below already honours.

Settings are stored in the savegame, so each save carries its own.

### In the file

The values live at the top of
[`extension/md/drjele_abandoned_ships_cleanup.xml`](extension/md/drjele_abandoned_ships_cleanup.xml).
They are re-read on every savegame load, so editing one and reloading is enough — no new game.

| Value | Default | Meaning |
|---|---|---|
| `$Lifetime` | `5h` | Game time an abandoned ship survives once the mod has seen it. Game time, so SETA speeds it up |
| `$ScanInterval` | `5min` | Game time between two galaxy scans. Automatically shortened to a fifth of the lifetime, never below 30s, so a short lifetime stays accurate |
| `$GameStartGrace` | `60s` | Ships spawned before this point count as game-start placements |
| `$StaleGap` | `15min` | Gap between two sightings after which the clock restarts instead of expiring |
| `$BatchSize` | `100` | Ships evaluated per tick |
| `$DebugChance` | `0` | Set to `100` to log every pass and every destruction |

Two of them can also be overridden at runtime, without editing the file, from a cheat menu or any
other mod. These are the same variables the options menu writes:

```xml
<set_value name="global.$DrJeleAbandonedShipLifetime" exact="30min"/>
<set_value name="global.$DrJeleAbandonedShipDebugChance" exact="100"/>
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

The 122–133s spread is scan granularity: a ship dies on the first scan after its clock expires,
so the scan interval is the error bar on the lifetime. That is why the interval is capped at a
fifth of the lifetime — at the 5h default it stays 5min, and a 5min lifetime scans every minute
instead of turning into "somewhere between 5 and 10 minutes".

Also run unattended for 29 hours straight, with a deliberately short 5 minute lifetime so the
whole cycle repeated constantly:

| Check | Result |
|---|---|
| Scans | 1692, spaced 61.1–62.0s apart (mean 61.34) — the interval never drifted |
| Ships expired | 42, every one of them after 306.3–307.4s against a 300s lifetime; never early |
| Clock table | never held more than 3 entries; 3006 scans held none at all, so nothing leaks |
| Candidates per scan | 6 almost always — the game-start ships — rising to 9 when crews had just bailed |
| Script errors | none |
| Debug log | 0.55 MiB per day at that cadence, and a fifth of that at the default settings |

The 1-second spread on a 61-second scan interval is not luck: a ship's clock starts on the scan
that first sees it, so its lifetime is always a whole number of scan intervals — here five of
them, 306.5s.

If you find a ship it should have spared, that is the interesting bug and I want to hear about
it.

## Legal

MIT, see [`LICENSE`](LICENSE). Non-commercial fan project; X4: Foundations belongs to Egosoft GmbH
and this is not affiliated with or endorsed by them.
