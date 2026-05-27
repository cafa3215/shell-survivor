# Changelog

## v2.2.2 (unreleased)

### Project Management (solo)
- Added single source of truth: `docs/PROJECT_STATUS.md` and `docs/RISK_REGISTER.md`.
- Restored README-linked docs (`CONTRIBUTING.md`, backlog, P0 map, release checklists, analytics stubs).
- `advance_project.py` now syncs week links into `PROJECT_STATUS.md` on `bootstrap-week` / `weekly-report` / `run-auto`.

## v2.2.1

### Pipeline / Reliability
- Added automation artifact guard: `python tools/advance_project.py validate-auto` now checks expected weekly/report/evaluation/log outputs, log-path consistency, and freshness window.
- Hardened Windows automation entry scripts to run generation + validation in sequence:
  - `tools/run_auto_pipeline.ps1`
  - `run_auto_pipeline.bat`
- Pipeline log now includes `generated_at` for stronger traceability.

### Verification Gates
- Added high-risk boss chain guard: `tools/validate_boss_chain.gd`.
- Added active-skill trigger chain guard: `tools/validate_active_skill_chain.gd`.
- Added reward/result persistence chain guard: `tools/validate_reward_result_chain.gd`.
- Wired `validate_boss_chain` into `verify_project.py` default gate stack.
- Wired `validate_active_skill_chain` into `verify_project.py` default gate stack.
- Wired `validate_reward_result_chain` into `verify_project.py` default gate stack.
- Re-ran fast/full verification after integration:
  - `python verify_project.py`
  - `python verify_project.py --full`

## v2.2

### Gameplay / Feel
- Weapon VFX upgraded: unified palette, added impact shockwave layer, and clearer Lv4 “mature” vs evolution visual hierarchy.
- Mid-run pacing improved: explicit director “gear shifts” (enemy composition changes) with short callouts.
- Threat feedback loop: consistent low-noise feedback for hitting/killing high-threat enemies (spitter/summoner/charger/elite).
- “Stabilize the fight” system: clearing threats grants short pressure relief (reduced spawn pressure), with HUD/audio/postprocess calming to make it feel tangible.
- Upgrade decision assist: context hint before upgrade panel (pressure vs relief) to guide safer picks.

### UI / UX
- Threat edge indicators refined: boss/priority-first filtering, cleaner visuals, and automatic de-noise when pressure relief is active.
- Results panel: added a pacing recap line aligning in-run hints with end-of-run feedback.
- Main menu: added “next run hint” one-liner; now persists across restarts.

### Tech / Stability
- RunStats history persistence with save version + sanitization.
- Added release verification tooling: `verify_project.py` and `tools/validate_release.gd`.

