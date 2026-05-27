# Beehave Day7 Final Decision (2026-04-26)

## Final Verdict

- Decision: keep
- Preferred mode: bt
- Reason: BT mode keeps similar or better FPS with acceptable state diversity.

## Keep Route

- Keep route D1: keep sandbox as trial baseline and lock `behavior_mode=bt`.
- Keep route D2: implement one real Beehave tree for a non-core enemy only.
- Keep route D3: run `python verify_project.py --full` and compare runtime log deltas.

## Drop Route

- Drop route D1: execute rollback script in sandbox.
- Drop route D2: archive summary/evidence in docs and close candidate as dropped.
- Drop route D3: continue with current FSM and revisit next cycle.

## Execution Note

- This decision is generated from Day4 aggregated metrics and can be overridden after real plugin run.
