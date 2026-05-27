# Beehave Keep Route D2 (2026-04-26)

## Execution

- Enabled trial Beehave mode in sandbox config (`use_beehave_in_trial=true`, `behavior_mode=bt`).
- Added non-core enemy BT asset: `tmp\integrations\beehave_trial\trees\non_core_scout_bt.tres`.
- Added sandbox bridge script: `tmp\integrations\beehave_trial\scripts\beehave_non_core_enemy_bridge.gd`.
- Updated trial scene entry script: `tmp\integrations\beehave_trial\scenes\BeehaveTrial.tscn`.

## D2 Gate

- [x] One non-core enemy BT asset exists in sandbox
- [x] Trial scene references sandbox BT bridge script
- [x] Run `python verify_project.py --full`

## Next

- Proceed to Keep-D3: compare BT/FSM deltas and refresh summary/evaluation.
