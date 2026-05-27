# Beehave 7-Day Trial Plan (2026-04-26)

## Scope

- Trial target: `beehave` (https://github.com/bitbrain/beehave)
- Mode: isolated sandbox only (no main gameplay path replacement yet)

## Day-by-Day

- Day1: import plugin into sandbox and verify editor load
- Day2: build one enemy behavior tree demo scene
- Day3: connect one existing enemy archetype in sandbox
- Day4: measure CPU/frame impact versus current logic
- Day5: verify rollback by removing plugin from sandbox
- Day6: document integration risk and migration cost
- Day7: keep/drop decision with evidence

## Exit Criteria

- Keep only if behavior readability improves and frame time does not regress.
- Drop if rollback takes > 1 day or causes core dependency coupling.
