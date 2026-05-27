# First Playable Release Checklist

Use this before shipping each weekly playable build.

## A. Scope Lock

- [ ] This build has a clear goal (what feedback we want).
- [ ] No new feature enters during final validation day.
- [ ] High-risk optional changes are deferred.

## B. Functional Smoke

- [ ] Game launches to main menu without errors.
- [ ] Start run -> survive -> level up -> pause -> resume works.
- [ ] Player death -> result panel -> restart/main menu works.
- [ ] Save/load critical settings works across restart.
- [ ] Core UI panels open/close with correct focus.

## C. Stability and Performance

- [ ] `python verify_project.py` passes.
- [ ] `python verify_project.py --full` passes for candidate.
- [ ] No obvious frame stutter during high enemy density.
- [ ] No repeated error spam in debugger output.

## D. Telemetry and Diagnostics

- [ ] Crash/exception reporting is enabled for target build.
- [ ] At least run start/end and death events are captured.
- [ ] Build version is visible in changelog or menu.

## E. Packaging and Notes

- [ ] Export preset selected correctly.
- [ ] Build artifact naming is consistent (`shell-survivor-YYYYMMDD`).
- [ ] Changelog contains top gameplay changes.
- [ ] Known issues list is attached.

## F. Final Go/No-Go

- [ ] One full 20+ minute run completed by developer.
- [ ] One external tester run collected.
- [ ] Decision recorded: GO or NO-GO.
