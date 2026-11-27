# Headless duel harness (dev tool)

Runs card effect code against a real duel state without a phone or UI. Lives in `tests/`, which
`export_presets.cfg` already excludes from the APK. It needs the original game data on disk; that data
is never committed.

## Run

```
godot --headless --path game res://tests/duel_harness/duel_harness.tscn -- \
    --data=/path/to/data \
    --scenarios=res://tests/duel_harness/redeyes.json \
    [--only=<text in scenario name>] [--game=yugi|joey]
```

`--data` is the folder that holds `common/bin/card_id.bin`, `card_intid.bin`, `card_prop.bin`,
`card_pack.bin` and `common/duel/yugi_image.bin` (in the bundled pack these live under `res://data/`).
Exit code is 1 if any `expect` check fails.

## Scenario JSON

`hand`, `grave`, `deck_top`, `banish`, `fusion`: `[[player0 cards], [player1 cards]]`.
`field`: `[[{"card":..,"zone":0,"c":0}], []]` (zone 0-4 monsters, 5-9 spells/traps, 10 field; `c` as in DuelScenario).
Cards are numeric internal ids or the English name of an extra card (ids 2500+). Original cards need ids.
`act`: `{"p":0,"card":..,"loc":"hand|field|st|grave|deck|banish","z":..,"kind":"activate|special_summon","ctx":{}}`.
`expect_can`: expected result of `can_activate` (or `can_special_summon`).
`expect`: queries such as `p1.lp`, `p0.field.0` (card id in zone), `p0.grave.has:81`, `p0.hand.count`.
Duels start in Main Phase 1, turn 1; override with `"phase"`.

## What it covers

- `CustomCardEffects.can_activate`, `resolve_chain_link`, `can_special_summon`, `special_summon` on the Core engine,
  with real card tables, hands, field, GY, banish, LP, once-per-turn flags.
- The state after resolution (piles, zones, LP).

## What it does not cover

- The engine's own activation flow: chain building, chain responses, timing windows, triggers firing from real
  summons or battles, UI prompts and animations. Optional prompts are auto-answered by the Core engine.
- The activated card itself is not moved to the GY by the harness (the engine does that in a real duel).
- Joey native engine: `--game=joey` starts a duel and `can_activate` runs, but its scenario loader only applies hand
  and LP, and `summon_post`/`gy_post` did not move cards there either, so field-dependent tests do not work on Joey yet.
- `summon_post` / `gy_post` (`[[p0],[p1]]`): cards put on the field / in the GY after the deal through the effect ops.
