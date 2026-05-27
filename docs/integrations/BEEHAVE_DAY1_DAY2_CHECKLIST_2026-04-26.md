# Beehave Day1-Day2 Checklist (2026-04-26)

## Day1 - Isolated Import

- [ ] Keep all files under `tmp/integrations/beehave_trial`
- [ ] Confirm plugin files can be loaded without touching `scenes/Game.tscn`
- [ ] Open trial scene in editor and verify no critical errors
- [ ] Record startup time and baseline FPS note

## Day2 - Minimal Behavior Demo

- [ ] Build one demo enemy behavior tree in sandbox only
- [ ] Run one 10-minute smoke play in sandbox context
- [ ] Compare readability vs current enemy logic
- [ ] Record frame-time impact and error logs

## Verification Gate

- [ ] Run `python verify_project.py`
- [ ] Run `python verify_project.py --full`
