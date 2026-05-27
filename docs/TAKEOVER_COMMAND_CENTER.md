# TAKEOVER COMMAND CENTER

Owner: 本人（单人项目）  
Project: Shell Survivor (Godot 4.6)  
Mode: Quality-gated solo delivery  
**状态总览（唯一入口）：** `docs/PROJECT_STATUS.md`

## 0) Current Baseline (checked)

- `python verify_project.py` -> PASS
- `python verify_project.py --full` -> PASS
- Core scenes/modules/contracts are currently healthy
- `python tools/advance_project.py validate-auto` -> PASS

## 1) Operating Rules (effective now)

- Every substantive change must keep `verify_project.py` green.
- Combat, progression, and scene-chain changes require `--full` before sign-off.
- New feature work is merged only with:
  - brief impact note in changelog
  - rollback path (feature flag, config gate, or isolated script)

## 2) Priority Queue (P0 -> P2)

### P0 (stability + release confidence)

1. [DONE] Harden run pipeline and daily automation outputs consistency.
2. [DONE] Add targeted guard checks for high-risk gameplay paths:
   - boss spawn chain
3. [DONE] Add targeted guard checks for high-risk gameplay paths:
   - [DONE] active skill trigger path
   - [DONE] reward/result persistence
4. [DONE] Normalize docs status to avoid drift between plan and shipped state.
5. [DONE] Single status page + risk register + README dead-link repair (solo PM baseline).

### P1 (experience quality)

1. Mid-game readability pass (telegraph clarity, HUD noise budget).
2. Difficulty pacing tune around minute 8-14 and 20+.
3. Failure/recovery loop polish (post-death recommendation fidelity).

### P2 (scalability)

1. Add integration trial cadence templates for external modules.
2. Expand analytics sampling policy for stable weekly comparisons.

## 3) Execution Rhythm

- Daily loop:
  1. Implement smallest high-impact slice.
  2. Run gate checks.
  3. Update changelog + command center deltas.
- Weekly loop:
  1. Consolidate reports.
  2. Rank next week backlog by risk-adjusted impact.
  3. Freeze release candidate scope.

## 4) Immediate Next Slice

1. Keep changelog + command center synced after each gate addition.
2. Start P1: mid-game readability pass (telegraph clarity + HUD noise budget).

---

This file is the active control panel for autonomous project takeover.
