# Beehave Mainline Promotion Gate (2026-04-26)

## Decision

- Current route: guarded rollout (not full replacement).
- Promotion scope: non-core enemy profile only.
- Rollback scope: sandbox-only artifacts can be removed in <=1 day.

## Gate Conditions

- [x] `python verify_project.py --full` stays green.
- [x] Runtime summary keeps BT >= FSM within threshold.
- [x] No core scene coupling outside sandbox paths.

## Rollback

- Execute: `powershell -ExecutionPolicy Bypass -File tmp/integrations/beehave_trial/scripts/rollback_beehave_trial.ps1`
- Confirm: sandbox folder removed and baseline verification passes.

## Linked Decision

- Day7 reference: `docs\integrations\BEEHAVE_DAY7_DECISION_2026-04-26.md`
## Final Recommendation

- Decision: GO (guarded rollout only)
- No-Go Scope: direct main gameplay core-scene replacement
- Effective Window: current week to next review checkpoint

