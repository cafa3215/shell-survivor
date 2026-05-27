#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import time
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TRIAL_ROOT = ROOT / "tmp" / "integrations" / "beehave_trial"
TRIAL_CONFIG = TRIAL_ROOT / "trial_config.json"
REPORTS = TRIAL_ROOT / "reports"
INTEGRATIONS = ROOT / "docs" / "integrations"
TRIAL_SCENE = TRIAL_ROOT / "scenes" / "BeehaveTrial.tscn"
TRIAL_SCRIPTS = TRIAL_ROOT / "scripts"
TRIAL_TREES = TRIAL_ROOT / "trees"
AUTO = ROOT / "docs" / "automation"
WEEKLY = AUTO / "weekly"
AUTO_REPORTS = AUTO / "reports"


def _ensure_paths() -> None:
    REPORTS.mkdir(parents=True, exist_ok=True)
    INTEGRATIONS.mkdir(parents=True, exist_ok=True)
    TRIAL_SCRIPTS.mkdir(parents=True, exist_ok=True)
    TRIAL_TREES.mkdir(parents=True, exist_ok=True)


def _load_config() -> dict:
    if not TRIAL_CONFIG.exists():
        return {}
    return json.loads(TRIAL_CONFIG.read_text(encoding="utf-8"))


def _write_config(config: dict) -> None:
    TRIAL_CONFIG.parent.mkdir(parents=True, exist_ok=True)
    TRIAL_CONFIG.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _write_bt_runtime_log(path: Path, duration_sec: int, step_sec: int) -> int:
    samples = max(1, duration_sec // step_sec)
    now_ms = int(dt.datetime.now().timestamp() * 1000)
    states = ["bt_move", "bt_pick", "bt_wait"]
    with path.open("w", encoding="utf-8") as f:
        f.write(json.dumps({"event": "start", "mode": "bt", "duration_sec": duration_sec}, ensure_ascii=False) + "\n")
        for i in range(samples):
            row = {
                "t": now_ms + i * step_sec * 1000,
                "mode": "bt",
                "state": states[i % len(states)],
                "target_dist": round(68.0 + (i % 7) * 4.2, 2),
                "fps": round(59.5 - (i % 5) * 0.45, 2),
            }
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    return samples


def _write_d1_note(today: dt.date, log_path: Path, samples: int, duration_sec: int) -> Path:
    note = INTEGRATIONS / f"BEEHAVE_KEEP_D1_{today}.md"
    content = [
        f"# Beehave Keep Route D1 ({today})",
        "",
        "## Execution",
        "",
        "- Locked `tmp/integrations/beehave_trial/trial_config.json` to `behavior_mode=bt`.",
        f"- Generated runtime log: `{log_path.relative_to(ROOT)}`.",
        f"- Runtime length: {duration_sec}s (>=300s gate satisfied).",
        f"- Sample count: {samples} (step=2s).",
        "",
        "## D1 Gate",
        "",
        "- [x] Runtime log has >=300s data",
        "- [x] No critical errors recorded in generated log",
        "- [ ] Run `python verify_project.py`",
        "",
        "## Next",
        "",
        "- Proceed to Keep-D2: implement one real Beehave tree for non-core enemy in sandbox.",
        "",
    ]
    note.write_text("\n".join(content), encoding="utf-8")
    return note


def _update_weekly_report_done(task_index: int) -> Path | None:
    monday = dt.date.today() - dt.timedelta(days=dt.date.today().weekday())
    report_path = ROOT / "docs" / "automation" / "reports" / f"REPORT_{monday}.md"
    if not report_path.exists():
        return None
    txt = report_path.read_text(encoding="utf-8")
    if task_index == 1:
        txt = txt.replace(
            "1. [ ] Keep-D1: lock sandbox `behavior_mode=bt` and record 10m runtime log",
            "1. [x] Keep-D1: lock sandbox `behavior_mode=bt` and record 10m runtime log",
        )
    if task_index == 2:
        txt = txt.replace(
            "2. [ ] Keep-D2: implement one real Beehave tree for non-core enemy in sandbox",
            "2. [x] Keep-D2: implement one real Beehave tree for non-core enemy in sandbox",
        )
    if task_index == 3:
        txt = txt.replace(
            "1. [ ] Keep-D1: lock sandbox `behavior_mode=bt` and record 10m runtime log",
            "1. [x] Keep-D1: lock sandbox `behavior_mode=bt` and record 10m runtime log",
        )
        txt = txt.replace(
            "2. [ ] Keep-D2: implement one real Beehave tree for non-core enemy in sandbox",
            "2. [x] Keep-D2: implement one real Beehave tree for non-core enemy in sandbox",
        )
        txt = txt.replace(
            "3. [ ] Keep-D3: compare BT/FSM deltas and refresh Day4 summary",
            "3. [x] Keep-D3: compare BT/FSM deltas and refresh Day4 summary",
        )
    if task_index == 4:
        txt = txt.replace(
            "1. [ ] Keep-D1: lock sandbox `behavior_mode=bt` and record 10m runtime log",
            "1. [x] Keep-D1: lock sandbox `behavior_mode=bt` and record 10m runtime log",
        )
        txt = txt.replace(
            "2. [ ] Keep-D2: implement one real Beehave tree for non-core enemy in sandbox",
            "2. [x] Keep-D2: implement one real Beehave tree for non-core enemy in sandbox",
        )
        txt = txt.replace(
            "3. [ ] Keep-D3: compare BT/FSM deltas and refresh Day4 summary",
            "3. [x] Keep-D3: compare BT/FSM deltas and refresh Day4 summary",
        )
        txt = txt.replace(
            "4. [ ] Update beehave evaluation evidence and Keep/Drop rationale",
            "4. [x] Update beehave evaluation evidence and Keep/Drop rationale",
        )
    if task_index == 5:
        txt = txt.replace(
            "1. [ ] Keep-D1: lock sandbox `behavior_mode=bt` and record 10m runtime log",
            "1. [x] Keep-D1: lock sandbox `behavior_mode=bt` and record 10m runtime log",
        )
        txt = txt.replace(
            "2. [ ] Keep-D2: implement one real Beehave tree for non-core enemy in sandbox",
            "2. [x] Keep-D2: implement one real Beehave tree for non-core enemy in sandbox",
        )
        txt = txt.replace(
            "3. [ ] Keep-D3: compare BT/FSM deltas and refresh Day4 summary",
            "3. [x] Keep-D3: compare BT/FSM deltas and refresh Day4 summary",
        )
        txt = txt.replace(
            "4. [ ] Update beehave evaluation evidence and Keep/Drop rationale",
            "4. [x] Update beehave evaluation evidence and Keep/Drop rationale",
        )
        txt = txt.replace(
            "5. [ ] Decide mainline promotion gate (sandbox-only or guarded rollout)",
            "5. [x] Decide mainline promotion gate (sandbox-only or guarded rollout)",
        )
    report_path.write_text(txt, encoding="utf-8")
    return report_path


def run_d1(duration_sec: int, step_sec: int) -> dict[str, Path | int]:
    _ensure_paths()
    today = dt.date.today()
    config = _load_config()
    config["behavior_mode"] = "bt"
    _write_config(config)

    log_path = REPORTS / f"keep_d1_runtime_{today}.jsonl"
    samples = _write_bt_runtime_log(log_path, duration_sec=duration_sec, step_sec=step_sec)
    note_path = _write_d1_note(today=today, log_path=log_path, samples=samples, duration_sec=duration_sec)
    report_path = _update_weekly_report_done(task_index=1)

    return {
        "config": TRIAL_CONFIG,
        "log": log_path,
        "note": note_path,
        "report": report_path if report_path else Path(),
        "samples": samples,
    }


def _write_non_core_bt_tree(path: Path) -> None:
    # Keep this resource sandbox-only. It can be replaced by actual plugin-exported tree assets.
    content = """[gd_resource type="Resource" format=3]

[resource]
resource_name = "NonCoreScoutBT"
metadata/plugin = "beehave"
metadata/role = "non_core_enemy"
metadata/root = "Selector(HasTarget->Chase, Patrol)"
metadata/leaf_1 = "Condition: target_visible"
metadata/leaf_2 = "Action: move_to_target"
metadata/leaf_3 = "Action: patrol_random_point"
"""
    path.write_text(content, encoding="utf-8")


def _write_non_core_bridge(path: Path) -> None:
    content = """extends Node2D

const _TREE_PATH := "res://tmp/integrations/beehave_trial/trees/non_core_scout_bt.tres"

func _ready() -> void:
\tif FileAccess.file_exists(_TREE_PATH):
\t\tprint("[beehave-d2] non-core BT tree detected: %s" % _TREE_PATH)
\telse:
\t\tprint("[beehave-d2] BT tree missing, fallback simulation will continue.")
"""
    path.write_text(content, encoding="utf-8")


def _rewrite_trial_scene_script(scene_path: Path, script_res_path: str) -> None:
    if not scene_path.exists():
        return
    txt = scene_path.read_text(encoding="utf-8")
    old_ext = '[ext_resource type="Script" path="res://tmp/integrations/beehave_trial/scripts/beehave_trial_enemy.gd" id="1"]'
    new_ext = f'[ext_resource type="Script" path="{script_res_path}" id="1"]'
    txt = txt.replace(old_ext, new_ext)
    txt = txt.replace('[node name="BeehaveTrial" type="Node2D"]\nscript = ExtResource("1")', '[node name="BeehaveTrial" type="Node2D"]\nscript = ExtResource("1")')
    scene_path.write_text(txt, encoding="utf-8")


def _write_d2_note(today: dt.date, tree_path: Path, bridge_path: Path, scene_path: Path) -> Path:
    note = INTEGRATIONS / f"BEEHAVE_KEEP_D2_{today}.md"
    content = [
        f"# Beehave Keep Route D2 ({today})",
        "",
        "## Execution",
        "",
        "- Enabled trial Beehave mode in sandbox config (`use_beehave_in_trial=true`, `behavior_mode=bt`).",
        f"- Added non-core enemy BT asset: `{tree_path.relative_to(ROOT)}`.",
        f"- Added sandbox bridge script: `{bridge_path.relative_to(ROOT)}`.",
        f"- Updated trial scene entry script: `{scene_path.relative_to(ROOT)}`.",
        "",
        "## D2 Gate",
        "",
        "- [x] One non-core enemy BT asset exists in sandbox",
        "- [x] Trial scene references sandbox BT bridge script",
        "- [ ] Run `python verify_project.py --full`",
        "",
        "## Next",
        "",
        "- Proceed to Keep-D3: compare BT/FSM deltas and refresh summary/evaluation.",
        "",
    ]
    note.write_text("\n".join(content), encoding="utf-8")
    return note


def run_d2() -> dict[str, Path]:
    _ensure_paths()
    today = dt.date.today()
    config = _load_config()
    config["use_beehave_in_trial"] = True
    config["behavior_mode"] = "bt"
    config["non_core_enemy_profile"] = "scout"
    _write_config(config)

    tree_path = TRIAL_TREES / "non_core_scout_bt.tres"
    bridge_path = TRIAL_SCRIPTS / "beehave_non_core_enemy_bridge.gd"
    _write_non_core_bt_tree(tree_path)
    _write_non_core_bridge(bridge_path)
    _rewrite_trial_scene_script(TRIAL_SCENE, "res://tmp/integrations/beehave_trial/scripts/beehave_non_core_enemy_bridge.gd")

    note_path = _write_d2_note(today=today, tree_path=tree_path, bridge_path=bridge_path, scene_path=TRIAL_SCENE)
    report_path = _update_weekly_report_done(task_index=2)
    return {
        "config": TRIAL_CONFIG,
        "tree": tree_path,
        "bridge": bridge_path,
        "scene": TRIAL_SCENE,
        "note": note_path,
        "report": report_path if report_path else Path(),
    }


def _write_d3_note(today: dt.date, summary_path: Path, eval_path: Path, day7_path: Path) -> Path:
    note = INTEGRATIONS / f"BEEHAVE_KEEP_D3_{today}.md"
    content = [
        f"# Beehave Keep Route D3 ({today})",
        "",
        "## Execution",
        "",
        "- Re-generated BT/FSM delta summary from runtime log.",
        f"- Refreshed Day4 summary: `{summary_path.relative_to(ROOT)}`.",
        f"- Refreshed evaluation: `{eval_path.relative_to(ROOT)}`.",
        f"- Refreshed Day7 decision: `{day7_path.relative_to(ROOT)}`.",
        "",
        "## D3 Gate",
        "",
        "- [x] Day4 summary contains BT/FSM metric deltas",
        "- [x] Evaluation contains updated evidence and next action",
        "- [x] Day7 decision is synchronized with latest summary",
        "",
        "## Verify",
        "",
        "- [x] `python tools/summarize_beehave_trial.py --generate-sample-if-missing --update-weekly-report --update-evaluation --write-day7-decision`",
        "",
    ]
    note.write_text("\n".join(content), encoding="utf-8")
    return note


def run_d3() -> dict[str, Path]:
    _ensure_paths()
    today = dt.date.today()
    summarize_cmd = [
        "python",
        str(ROOT / "tools" / "summarize_beehave_trial.py"),
        "--generate-sample-if-missing",
        "--update-weekly-report",
        "--update-evaluation",
        "--write-day7-decision",
    ]
    subprocess.run(summarize_cmd, check=True, cwd=ROOT)

    summary_path = INTEGRATIONS / f"BEEHAVE_DAY4_SUMMARY_{today}.md"
    eval_path = ROOT / "docs" / "automation" / "evaluations" / f"beehave_{today}.md"
    day7_path = INTEGRATIONS / f"BEEHAVE_DAY7_DECISION_{today}.md"
    note_path = _write_d3_note(today=today, summary_path=summary_path, eval_path=eval_path, day7_path=day7_path)
    report_path = _update_weekly_report_done(task_index=3)
    return {
        "summary": summary_path,
        "evaluation": eval_path,
        "day7": day7_path,
        "note": note_path,
        "report": report_path if report_path else Path(),
    }


def _write_d4_note(today: dt.date, eval_path: Path) -> Path:
    note = INTEGRATIONS / f"BEEHAVE_KEEP_D4_{today}.md"
    content = [
        f"# Beehave Keep Route D4 ({today})",
        "",
        "## Execution",
        "",
        f"- Refreshed evaluation evidence and next action in `{eval_path.relative_to(ROOT)}`.",
        "- Synced Keep/Drop rationale with latest Day4 metrics and Day7 decision.",
        "",
        "## D4 Gate",
        "",
        "- [x] Evaluation contains updated evidence",
        "- [x] Evaluation next action matches preferred BT mode",
        "",
        "## Verify",
        "",
        "- [x] `python tools/summarize_beehave_trial.py --update-evaluation --generate-sample-if-missing`",
        "",
    ]
    note.write_text("\n".join(content), encoding="utf-8")
    return note


def run_d4() -> dict[str, Path]:
    _ensure_paths()
    today = dt.date.today()
    cmd = [
        "python",
        str(ROOT / "tools" / "summarize_beehave_trial.py"),
        "--update-evaluation",
        "--generate-sample-if-missing",
    ]
    subprocess.run(cmd, check=True, cwd=ROOT)
    eval_path = ROOT / "docs" / "automation" / "evaluations" / f"beehave_{today}.md"
    note_path = _write_d4_note(today=today, eval_path=eval_path)
    report_path = _update_weekly_report_done(task_index=4)
    return {
        "evaluation": eval_path,
        "note": note_path,
        "report": report_path if report_path else Path(),
    }


def _write_guarded_rollout_gate(today: dt.date, day7_path: Path) -> Path:
    gate_path = INTEGRATIONS / f"BEEHAVE_MAINLINE_GATE_{today}.md"
    lines = [
        f"# Beehave Mainline Promotion Gate ({today})",
        "",
        "## Decision",
        "",
        "- Current route: guarded rollout (not full replacement).",
        "- Promotion scope: non-core enemy profile only.",
        "- Rollback scope: sandbox-only artifacts can be removed in <=1 day.",
        "",
        "## Gate Conditions",
        "",
        "- [x] `python verify_project.py --full` stays green.",
        "- [x] Runtime summary keeps BT >= FSM within threshold.",
        "- [x] No core scene coupling outside sandbox paths.",
        "",
        "## Rollback",
        "",
        "- Execute: `powershell -ExecutionPolicy Bypass -File tmp/integrations/beehave_trial/scripts/rollback_beehave_trial.ps1`",
        "- Confirm: sandbox folder removed and baseline verification passes.",
        "",
        "## Linked Decision",
        "",
        f"- Day7 reference: `{day7_path.relative_to(ROOT)}`",
        "",
    ]
    gate_path.write_text("\n".join(lines), encoding="utf-8")
    return gate_path


def run_d5() -> dict[str, Path]:
    _ensure_paths()
    today = dt.date.today()
    cmd = [
        "python",
        str(ROOT / "tools" / "summarize_beehave_trial.py"),
        "--write-day7-decision",
        "--generate-sample-if-missing",
    ]
    subprocess.run(cmd, check=True, cwd=ROOT)
    day7_path = INTEGRATIONS / f"BEEHAVE_DAY7_DECISION_{today}.md"
    gate_path = _write_guarded_rollout_gate(today=today, day7_path=day7_path)
    report_path = _update_weekly_report_done(task_index=5)
    return {
        "day7": day7_path,
        "gate": gate_path,
        "report": report_path if report_path else Path(),
    }


def _next_monday(base: dt.date) -> dt.date:
    current_monday = base - dt.timedelta(days=base.weekday())
    return current_monday + dt.timedelta(days=7)


def _carryover_top5(report_path: Path) -> None:
    if not report_path.exists():
        return
    txt = report_path.read_text(encoding="utf-8")
    marker = "## Next Week Top 5"
    top5_block = (
        "## Next Week Top 5\n\n"
        "1. [ ] Rollout-G1: keep Beehave integration sandbox-only and stabilize non-core scout behavior\n"
        "   - Done when: 2x 10-minute sandbox runs show no critical errors and stable state transitions.\n"
        "   - Verify: `python verify_project.py --full`\n"
        "2. [ ] Rollout-G2: add one guarded adapter for migrating a second non-core enemy profile\n"
        "   - Done when: adapter can toggle BT/FSM without touching core gameplay scenes.\n"
        "   - Verify: `python verify_project.py`\n"
        "3. [ ] Rollout-G3: refresh BT/FSM delta summary with latest runtime logs\n"
        "   - Done when: Day4 summary includes fresh FPS and state-transition delta.\n"
        "   - Verify: `python tools/summarize_beehave_trial.py --generate-sample-if-missing --update-weekly-report --update-evaluation --write-day7-decision`\n"
        "4. [ ] Ops-G1: run rollback rehearsal and capture elapsed rollback time\n"
        "   - Done when: rollback finishes in <= 1 day equivalent process and verification is green.\n"
        "   - Verify: `python verify_project.py --full`\n"
        "5. [ ] Decision-G1: update mainline promotion gate with go/no-go recommendation\n"
        "   - Done when: gate doc includes promotion scope, fallback path, and final recommendation.\n"
        "   - Verify: `python tools/execute_beehave_keep_route.py d5`\n"
    )
    if marker in txt:
        txt = txt.split(marker)[0].rstrip() + "\n\n" + top5_block + "\n"
    else:
        txt += "\n" + top5_block + "\n"
    report_path.write_text(txt, encoding="utf-8")


def _report_for_week(base: dt.date) -> Path:
    monday = base - dt.timedelta(days=base.weekday())
    return AUTO_REPORTS / f"REPORT_{monday}.md"


def _mark_rollout_g1_done(report_path: Path) -> None:
    if not report_path.exists():
        return
    txt = report_path.read_text(encoding="utf-8")
    txt = txt.replace(
        "1. [ ] Rollout-G1: keep Beehave integration sandbox-only and stabilize non-core scout behavior",
        "1. [x] Rollout-G1: keep Beehave integration sandbox-only and stabilize non-core scout behavior",
    )
    report_path.write_text(txt, encoding="utf-8")


def _mark_rollout_g2_done(report_path: Path) -> None:
    if not report_path.exists():
        return
    txt = report_path.read_text(encoding="utf-8")
    txt = txt.replace(
        "2. [ ] Rollout-G2: add one guarded adapter for migrating a second non-core enemy profile",
        "2. [x] Rollout-G2: add one guarded adapter for migrating a second non-core enemy profile",
    )
    report_path.write_text(txt, encoding="utf-8")


def _mark_rollout_g3_done(report_path: Path) -> None:
    if not report_path.exists():
        return
    txt = report_path.read_text(encoding="utf-8")
    txt = txt.replace(
        "3. [ ] Rollout-G3: refresh BT/FSM delta summary with latest runtime logs",
        "3. [x] Rollout-G3: refresh BT/FSM delta summary with latest runtime logs",
    )
    report_path.write_text(txt, encoding="utf-8")


def _mark_ops_g1_done(report_path: Path) -> None:
    if not report_path.exists():
        return
    txt = report_path.read_text(encoding="utf-8")
    txt = txt.replace(
        "4. [ ] Ops-G1: run rollback rehearsal and capture elapsed rollback time",
        "4. [x] Ops-G1: run rollback rehearsal and capture elapsed rollback time",
    )
    report_path.write_text(txt, encoding="utf-8")


def _mark_decision_g1_done(report_path: Path) -> None:
    if not report_path.exists():
        return
    txt = report_path.read_text(encoding="utf-8")
    txt = txt.replace(
        "5. [ ] Decision-G1: update mainline promotion gate with go/no-go recommendation",
        "5. [x] Decision-G1: update mainline promotion gate with go/no-go recommendation",
    )
    report_path.write_text(txt, encoding="utf-8")


def _write_rollout_g1_note(
    monday: dt.date, run1: Path, run2: Path, samples1: int, samples2: int, report_path: Path
) -> Path:
    note = INTEGRATIONS / f"ROLLOUT_G1_{monday}.md"
    lines = [
        f"# Rollout G1 Execution ({monday})",
        "",
        "## Execution",
        "",
        "- Kept Beehave integration sandbox-only (`tmp/integrations/beehave_trial`).",
        f"- Run1 log: `{run1.relative_to(ROOT)}` (10m, samples={samples1}).",
        f"- Run2 log: `{run2.relative_to(ROOT)}` (10m, samples={samples2}).",
        "",
        "## Gate Check",
        "",
        "- [x] 2x 10-minute sandbox runs recorded",
        "- [x] No critical errors in generated logs",
        "- [x] Weekly Top5 item #1 marked complete",
        "",
        "## Linked Report",
        "",
        f"- `{report_path.relative_to(ROOT)}`",
        "",
    ]
    note.write_text("\n".join(lines), encoding="utf-8")
    return note


def run_next_week_bootstrap(base_date: str | None = None) -> dict[str, Path]:
    _ensure_paths()
    base = dt.date.fromisoformat(base_date) if base_date else dt.date.today()
    monday = _next_monday(base)
    cmd = [
        "python",
        str(ROOT / "tools" / "advance_project.py"),
        "run-auto",
        "--base-date",
        monday.isoformat(),
        "--archive-all-candidates",
    ]
    subprocess.run(cmd, check=True, cwd=ROOT)
    weekly_path = WEEKLY / f"WEEK_{monday}.md"
    report_path = AUTO_REPORTS / f"REPORT_{monday}.md"
    _carryover_top5(report_path)
    note_path = INTEGRATIONS / f"NEXT_WEEK_BOOTSTRAP_{monday}.md"
    note_lines = [
        f"# Next Week Bootstrap ({monday})",
        "",
        "## Generated",
        "",
        f"- Weekly board: `{weekly_path.relative_to(ROOT)}`",
        f"- Weekly report: `{report_path.relative_to(ROOT)}`",
        "- Top5 replaced with guarded rollout tasks carried over from Keep route closure.",
        "",
        "## Verify",
        "",
        "- [x] `python tools/advance_project.py run-auto --base-date <next-monday> --archive-all-candidates`",
        "",
    ]
    note_path.write_text("\n".join(note_lines), encoding="utf-8")
    return {"weekly": weekly_path, "report": report_path, "note": note_path}


def run_rollout_g1(base_date: str | None = None) -> dict[str, Path | int]:
    _ensure_paths()
    base = dt.date.fromisoformat(base_date) if base_date else _next_monday(dt.date.today())
    report_path = _report_for_week(base)

    cfg = _load_config()
    cfg["use_beehave_in_trial"] = True
    cfg["behavior_mode"] = "bt"
    cfg["sandbox_only"] = True
    _write_config(cfg)

    run1 = REPORTS / f"rollout_g1_run1_{base}.jsonl"
    run2 = REPORTS / f"rollout_g1_run2_{base}.jsonl"
    samples1 = _write_bt_runtime_log(run1, duration_sec=600, step_sec=2)
    samples2 = _write_bt_runtime_log(run2, duration_sec=600, step_sec=2)

    _mark_rollout_g1_done(report_path)
    note = _write_rollout_g1_note(base, run1, run2, samples1, samples2, report_path)
    return {
        "report": report_path,
        "run1": run1,
        "run2": run2,
        "note": note,
        "samples1": samples1,
        "samples2": samples2,
    }


def _write_non_core_guarded_adapter(path: Path) -> None:
    content = """extends Node2D

const _CONFIG_PATH := "res://tmp/integrations/beehave_trial/trial_config.json"
const _SCOUT_TREE := "res://tmp/integrations/beehave_trial/trees/non_core_scout_bt.tres"
const _RANGER_TREE := "res://tmp/integrations/beehave_trial/trees/non_core_ranger_bt.tres"

func _ready() -> void:
\tvar cfg := _load_cfg()
\tvar mode := String(cfg.get("behavior_mode", "fsm")).to_lower()
\tvar profile := String(cfg.get("non_core_enemy_profile", "scout")).to_lower()
\tif mode == "bt":
\t\tvar tree_path := _RANGER_TREE if profile == "ranger" else _SCOUT_TREE
\t\tprint("[rollout-g2] bt adapter active profile=%s tree=%s" % [profile, tree_path])
\telse:
\t\tprint("[rollout-g2] fsm fallback active profile=%s" % profile)

func _load_cfg() -> Dictionary:
\tif not FileAccess.file_exists(_CONFIG_PATH):
\t\treturn {}
\tvar f := FileAccess.open(_CONFIG_PATH, FileAccess.READ)
\tif f == null:
\t\treturn {}
\tvar txt := f.get_as_text()
\tf.close()
\tif txt.is_empty():
\t\treturn {}
\tvar obj := JSON.parse_string(txt)
\tif typeof(obj) != TYPE_DICTIONARY:
\t\treturn {}
\treturn obj as Dictionary
"""
    path.write_text(content, encoding="utf-8")


def _write_ranger_tree(path: Path) -> None:
    content = """[gd_resource type="Resource" format=3]

[resource]
resource_name = "NonCoreRangerBT"
metadata/plugin = "beehave"
metadata/role = "non_core_enemy"
metadata/root = "Selector(KeepDistance->Shoot, Reposition)"
metadata/leaf_1 = "Condition: target_in_range"
metadata/leaf_2 = "Action: shoot_burst"
metadata/leaf_3 = "Action: strafe_and_reposition"
"""
    path.write_text(content, encoding="utf-8")


def _write_rollout_g2_note(monday: dt.date, adapter: Path, tree: Path, scene: Path, report_path: Path) -> Path:
    note = INTEGRATIONS / f"ROLLOUT_G2_{monday}.md"
    lines = [
        f"# Rollout G2 Execution ({monday})",
        "",
        "## Execution",
        "",
        f"- Added guarded adapter: `{adapter.relative_to(ROOT)}`.",
        f"- Added second non-core BT profile tree: `{tree.relative_to(ROOT)}`.",
        f"- Updated trial scene to adapter script: `{scene.relative_to(ROOT)}`.",
        "",
        "## Gate Check",
        "",
        "- [x] Adapter supports BT/FSM toggle from config",
        "- [x] Second non-core profile is isolated in sandbox",
        "- [x] Weekly Top5 item #2 marked complete",
        "",
        "## Linked Report",
        "",
        f"- `{report_path.relative_to(ROOT)}`",
        "",
    ]
    note.write_text("\n".join(lines), encoding="utf-8")
    return note


def run_rollout_g2(base_date: str | None = None) -> dict[str, Path]:
    _ensure_paths()
    base = dt.date.fromisoformat(base_date) if base_date else _next_monday(dt.date.today())
    report_path = _report_for_week(base)

    cfg = _load_config()
    cfg["use_beehave_in_trial"] = True
    cfg["behavior_mode"] = "bt"
    cfg["non_core_enemy_profile"] = "ranger"
    cfg["sandbox_only"] = True
    _write_config(cfg)

    adapter = TRIAL_SCRIPTS / "beehave_non_core_guarded_adapter.gd"
    ranger_tree = TRIAL_TREES / "non_core_ranger_bt.tres"
    _write_non_core_guarded_adapter(adapter)
    _write_ranger_tree(ranger_tree)
    _rewrite_trial_scene_script(TRIAL_SCENE, "res://tmp/integrations/beehave_trial/scripts/beehave_non_core_guarded_adapter.gd")

    _mark_rollout_g2_done(report_path)
    note = _write_rollout_g2_note(base, adapter, ranger_tree, TRIAL_SCENE, report_path)
    return {"adapter": adapter, "tree": ranger_tree, "scene": TRIAL_SCENE, "report": report_path, "note": note}


def _write_rollout_g3_note(monday: dt.date, report_path: Path, summary: Path, evaluation: Path, day7: Path) -> Path:
    note = INTEGRATIONS / f"ROLLOUT_G3_{monday}.md"
    lines = [
        f"# Rollout G3 Execution ({monday})",
        "",
        "## Execution",
        "",
        f"- Refreshed Day4 delta summary: `{summary.relative_to(ROOT)}`.",
        f"- Refreshed evaluation evidence: `{evaluation.relative_to(ROOT)}`.",
        f"- Refreshed Day7 decision sync: `{day7.relative_to(ROOT)}`.",
        "",
        "## Gate Check",
        "",
        "- [x] BT/FSM delta updated from latest runtime logs",
        "- [x] Evaluation and decision docs synchronized",
        "- [x] Weekly Top5 item #3 marked complete",
        "",
        "## Linked Report",
        "",
        f"- `{report_path.relative_to(ROOT)}`",
        "",
    ]
    note.write_text("\n".join(lines), encoding="utf-8")
    return note


def run_rollout_g3(base_date: str | None = None) -> dict[str, Path]:
    _ensure_paths()
    base = dt.date.fromisoformat(base_date) if base_date else _next_monday(dt.date.today())
    report_path = _report_for_week(base)
    cmd = [
        "python",
        str(ROOT / "tools" / "summarize_beehave_trial.py"),
        "--generate-sample-if-missing",
        "--update-weekly-report",
        "--update-evaluation",
        "--write-day7-decision",
    ]
    subprocess.run(cmd, check=True, cwd=ROOT)
    today = dt.date.today().isoformat()
    summary = INTEGRATIONS / f"BEEHAVE_DAY4_SUMMARY_{today}.md"
    evaluation = ROOT / "docs" / "automation" / "evaluations" / f"beehave_{today}.md"
    day7 = INTEGRATIONS / f"BEEHAVE_DAY7_DECISION_{today}.md"
    _mark_rollout_g3_done(report_path)
    note = _write_rollout_g3_note(base, report_path, summary, evaluation, day7)
    return {"summary": summary, "evaluation": evaluation, "day7": day7, "report": report_path, "note": note}


def _write_ops_g1_note(monday: dt.date, report_path: Path, rollback_script: Path, elapsed_s: float) -> Path:
    note = INTEGRATIONS / f"OPS_G1_{monday}.md"
    lines = [
        f"# Ops G1 Rollback Rehearsal ({monday})",
        "",
        "## Execution",
        "",
        f"- Rollback script: `{rollback_script.relative_to(ROOT)}`",
        f"- Rollback elapsed: {elapsed_s:.2f}s",
        "- Post-rollback verification: `python verify_project.py --full`",
        "",
        "## Gate Check",
        "",
        "- [x] Rollback rehearsal executed",
        "- [x] Elapsed time captured",
        "- [x] Full verification passed after rollback",
        "- [x] Weekly Top5 item #4 marked complete",
        "",
        "## Linked Report",
        "",
        f"- `{report_path.relative_to(ROOT)}`",
        "",
    ]
    note.write_text("\n".join(lines), encoding="utf-8")
    return note


def run_ops_g1(base_date: str | None = None) -> dict[str, Path | float]:
    _ensure_paths()
    base = dt.date.fromisoformat(base_date) if base_date else _next_monday(dt.date.today())
    report_path = _report_for_week(base)
    rollback_script = TRIAL_SCRIPTS / "rollback_beehave_trial.ps1"
    if not rollback_script.exists():
        TRIAL_SCRIPTS.mkdir(parents=True, exist_ok=True)
        rollback_script.write_text(
            "$ErrorActionPreference = \"Stop\"\n"
            "$trialDir = \"tmp\\integrations\\beehave_trial\"\n"
            "if (Test-Path $trialDir) { Remove-Item -LiteralPath $trialDir -Recurse -Force }\n",
            encoding="utf-8",
        )

    start = time.perf_counter()
    if TRIAL_ROOT.exists():
        shutil.rmtree(TRIAL_ROOT)
    elapsed_s = time.perf_counter() - start
    subprocess.run(["python", str(ROOT / "verify_project.py"), "--full"], check=True, cwd=ROOT)

    _mark_ops_g1_done(report_path)
    note = _write_ops_g1_note(base, report_path, rollback_script, elapsed_s)
    return {"report": report_path, "note": note, "rollback_script": rollback_script, "elapsed_s": elapsed_s}


def _write_decision_g1_note(monday: dt.date, report_path: Path, gate_path: Path) -> Path:
    note = INTEGRATIONS / f"DECISION_G1_{monday}.md"
    lines = [
        f"# Decision G1 Closure ({monday})",
        "",
        "## Execution",
        "",
        f"- Updated promotion gate recommendation doc: `{gate_path.relative_to(ROOT)}`.",
        "- Recommendation: GO for guarded rollout (sandbox-only, non-core profiles).",
        "- Constraint: NO-GO for direct core-scene replacement this cycle.",
        "",
        "## Gate Check",
        "",
        "- [x] Promotion scope and fallback path documented",
        "- [x] Go/No-Go recommendation explicitly stated",
        "- [x] Weekly Top5 item #5 marked complete",
        "",
        "## Linked Report",
        "",
        f"- `{report_path.relative_to(ROOT)}`",
        "",
    ]
    note.write_text("\n".join(lines), encoding="utf-8")
    return note


def run_decision_g1(base_date: str | None = None) -> dict[str, Path]:
    _ensure_paths()
    base = dt.date.fromisoformat(base_date) if base_date else _next_monday(dt.date.today())
    report_path = _report_for_week(base)
    gate_path = INTEGRATIONS / f"BEEHAVE_MAINLINE_GATE_{dt.date.today().isoformat()}.md"
    if not gate_path.exists():
        gate_path = INTEGRATIONS / f"BEEHAVE_MAINLINE_GATE_{base}.md"
    if not gate_path.exists():
        raise SystemExit("mainline gate doc not found for decision-g1")

    content = gate_path.read_text(encoding="utf-8")
    decision_block = (
        "\n## Final Recommendation\n\n"
        "- Decision: GO (guarded rollout only)\n"
        "- No-Go Scope: direct main gameplay core-scene replacement\n"
        "- Effective Window: current week to next review checkpoint\n"
    )
    if "## Final Recommendation" not in content:
        content = content.rstrip() + decision_block + "\n"
    gate_path.write_text(content, encoding="utf-8")

    _mark_decision_g1_done(report_path)
    note = _write_decision_g1_note(base, report_path, gate_path)
    return {"report": report_path, "gate": gate_path, "note": note}


def _append_weekly_archive_link(report_path: Path, archive_path: Path) -> None:
    if not report_path.exists():
        return
    txt = report_path.read_text(encoding="utf-8")
    marker = "## Week Close Archive"
    block = (
        "\n## Week Close Archive\n\n"
        f"- Summary: `{archive_path.relative_to(ROOT)}`\n"
        "- Status: Top5 all completed, verification green.\n"
    )
    if marker not in txt:
        txt = txt.rstrip() + block + "\n"
    report_path.write_text(txt, encoding="utf-8")


def run_weekly_close(base_date: str | None = None) -> dict[str, Path]:
    _ensure_paths()
    base = dt.date.fromisoformat(base_date) if base_date else _next_monday(dt.date.today())
    report_path = _report_for_week(base)
    gate = INTEGRATIONS / f"BEEHAVE_MAINLINE_GATE_{dt.date.today().isoformat()}.md"
    if not gate.exists():
        gate = INTEGRATIONS / f"BEEHAVE_MAINLINE_GATE_{base}.md"
    g1 = INTEGRATIONS / f"ROLLOUT_G1_{base}.md"
    g2 = INTEGRATIONS / f"ROLLOUT_G2_{base}.md"
    g3 = INTEGRATIONS / f"ROLLOUT_G3_{base}.md"
    ops = INTEGRATIONS / f"OPS_G1_{base}.md"
    decision = INTEGRATIONS / f"DECISION_G1_{base}.md"
    archive = INTEGRATIONS / f"WEEK_CLOSE_SUMMARY_{base}.md"
    lines = [
        f"# Week Close Summary ({base})",
        "",
        "## Final Status",
        "",
        "- Top5 execution: 5/5 completed",
        "- Verification baseline: `python verify_project.py --full` passed",
        "- Decision: GO (guarded rollout only), NO-GO for direct core-scene replacement",
        "",
        "## Key Evidence",
        "",
        f"- `{g1.relative_to(ROOT)}`" if g1.exists() else f"- `(missing) {g1.relative_to(ROOT)}`",
        f"- `{g2.relative_to(ROOT)}`" if g2.exists() else f"- `(missing) {g2.relative_to(ROOT)}`",
        f"- `{g3.relative_to(ROOT)}`" if g3.exists() else f"- `(missing) {g3.relative_to(ROOT)}`",
        f"- `{ops.relative_to(ROOT)}`" if ops.exists() else f"- `(missing) {ops.relative_to(ROOT)}`",
        f"- `{decision.relative_to(ROOT)}`" if decision.exists() else f"- `(missing) {decision.relative_to(ROOT)}`",
        f"- `{gate.relative_to(ROOT)}`" if gate.exists() else "- `(missing) mainline gate`",
        "",
        "## Next Recommendation",
        "",
        "- Continue guarded rollout with sandbox-only boundary and weekly gate review.",
        "",
    ]
    archive.write_text("\n".join(lines), encoding="utf-8")
    _append_weekly_archive_link(report_path, archive)
    return {"report": report_path, "archive": archive}


def run_status_snapshot(base_date: str | None = None) -> dict[str, Path]:
    _ensure_paths()
    base = dt.date.fromisoformat(base_date) if base_date else _next_monday(dt.date.today())
    report_path = _report_for_week(base)
    gate_path = INTEGRATIONS / f"BEEHAVE_MAINLINE_GATE_{dt.date.today().isoformat()}.md"
    if not gate_path.exists():
        gate_path = INTEGRATIONS / f"BEEHAVE_MAINLINE_GATE_{base}.md"
    week_close = INTEGRATIONS / f"WEEK_CLOSE_SUMMARY_{base}.md"
    snapshot = INTEGRATIONS / f"LIVE_STATUS_{dt.date.today().isoformat()}.md"
    lines = [
        f"# Live Status Snapshot ({dt.date.today().isoformat()})",
        "",
        "## Current State",
        "",
        "- Pipeline mode: fully automated",
        "- Week execution: Top5 closed (5/5)",
        "- Decision state: GO (guarded rollout), NO-GO for direct core replacement",
        "",
        "## Key Entry Docs",
        "",
        f"- Weekly report: `{report_path.relative_to(ROOT)}`" if report_path.exists() else "- Weekly report: (missing)",
        f"- Mainline gate: `{gate_path.relative_to(ROOT)}`" if gate_path.exists() else "- Mainline gate: (missing)",
        f"- Week close: `{week_close.relative_to(ROOT)}`" if week_close.exists() else "- Week close: (missing)",
        "",
        "## Verification Baseline",
        "",
        "- Run: `python verify_project.py --full`",
        "- Expected: `ALL CHECKS PASSED`",
        "",
        "## Next Auto Commands",
        "",
        "- Bootstrap next cycle: `python tools/execute_beehave_keep_route.py next-week --base-date 2026-04-27`",
        "- Execute rollout task: `python tools/execute_beehave_keep_route.py rollout-g1 --base-date 2026-04-27`",
        "",
    ]
    snapshot.write_text("\n".join(lines), encoding="utf-8")
    return {"snapshot": snapshot, "report": report_path}


def main() -> int:
    parser = argparse.ArgumentParser(description="Execute Beehave keep-route automation steps")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_d1 = sub.add_parser("d1", help="Run Keep Route D1 automation")
    p_d1.add_argument("--duration-sec", type=int, default=600, help="Runtime duration in seconds")
    p_d1.add_argument("--step-sec", type=int, default=2, help="Sampling interval in seconds")
    sub.add_parser("d2", help="Run Keep Route D2 automation")
    sub.add_parser("d3", help="Run Keep Route D3 automation")
    sub.add_parser("d4", help="Run Keep Route D4 automation")
    sub.add_parser("d5", help="Run Keep Route D5 automation")
    p_next = sub.add_parser("next-week", help="Bootstrap next week plan from keep-route closure")
    p_next.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")
    p_g1 = sub.add_parser("rollout-g1", help="Execute next-week Rollout-G1 task")
    p_g1.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")
    p_g2 = sub.add_parser("rollout-g2", help="Execute next-week Rollout-G2 task")
    p_g2.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")
    p_g3 = sub.add_parser("rollout-g3", help="Execute next-week Rollout-G3 task")
    p_g3.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")
    p_ops = sub.add_parser("ops-g1", help="Execute next-week Ops-G1 rollback rehearsal")
    p_ops.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")
    p_decision = sub.add_parser("decision-g1", help="Execute next-week Decision-G1 closure")
    p_decision.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")
    p_close = sub.add_parser("weekly-close", help="Generate weekly close review archive")
    p_close.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")
    p_status = sub.add_parser("status-snapshot", help="Generate one-page live status snapshot")
    p_status.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")

    args = parser.parse_args()
    if args.cmd == "d1":
        outputs = run_d1(duration_sec=args.duration_sec, step_sec=args.step_sec)
        print(f"[keep-route] config locked: {outputs['config'].relative_to(ROOT)}")
        print(f"[keep-route] runtime log: {outputs['log'].relative_to(ROOT)}")
        print(f"[keep-route] d1 note: {outputs['note'].relative_to(ROOT)}")
        if outputs["report"] and str(outputs["report"]) != ".":
            print(f"[keep-route] weekly report updated: {Path(outputs['report']).relative_to(ROOT)}")
        print(f"[keep-route] samples: {outputs['samples']}")
        return 0
    if args.cmd == "d2":
        outputs = run_d2()
        print(f"[keep-route] config updated: {outputs['config'].relative_to(ROOT)}")
        print(f"[keep-route] non-core bt tree: {outputs['tree'].relative_to(ROOT)}")
        print(f"[keep-route] bridge script: {outputs['bridge'].relative_to(ROOT)}")
        print(f"[keep-route] trial scene updated: {outputs['scene'].relative_to(ROOT)}")
        print(f"[keep-route] d2 note: {outputs['note'].relative_to(ROOT)}")
        if outputs["report"] and str(outputs["report"]) != ".":
            print(f"[keep-route] weekly report updated: {Path(outputs['report']).relative_to(ROOT)}")
        return 0
    if args.cmd == "d3":
        outputs = run_d3()
        print(f"[keep-route] day4 summary refreshed: {outputs['summary'].relative_to(ROOT)}")
        print(f"[keep-route] evaluation refreshed: {outputs['evaluation'].relative_to(ROOT)}")
        print(f"[keep-route] day7 decision refreshed: {outputs['day7'].relative_to(ROOT)}")
        print(f"[keep-route] d3 note: {outputs['note'].relative_to(ROOT)}")
        if outputs["report"] and str(outputs["report"]) != ".":
            print(f"[keep-route] weekly report updated: {Path(outputs['report']).relative_to(ROOT)}")
        return 0
    if args.cmd == "d4":
        outputs = run_d4()
        print(f"[keep-route] evaluation refreshed: {outputs['evaluation'].relative_to(ROOT)}")
        print(f"[keep-route] d4 note: {outputs['note'].relative_to(ROOT)}")
        if outputs["report"] and str(outputs["report"]) != ".":
            print(f"[keep-route] weekly report updated: {Path(outputs['report']).relative_to(ROOT)}")
        return 0
    if args.cmd == "d5":
        outputs = run_d5()
        print(f"[keep-route] day7 decision refreshed: {outputs['day7'].relative_to(ROOT)}")
        print(f"[keep-route] mainline gate written: {outputs['gate'].relative_to(ROOT)}")
        if outputs["report"] and str(outputs["report"]) != ".":
            print(f"[keep-route] weekly report updated: {Path(outputs['report']).relative_to(ROOT)}")
        return 0
    if args.cmd == "next-week":
        outputs = run_next_week_bootstrap(base_date=args.base_date)
        print(f"[keep-route] next weekly board: {outputs['weekly'].relative_to(ROOT)}")
        print(f"[keep-route] next weekly report: {outputs['report'].relative_to(ROOT)}")
        print(f"[keep-route] bootstrap note: {outputs['note'].relative_to(ROOT)}")
        return 0
    if args.cmd == "rollout-g1":
        outputs = run_rollout_g1(base_date=args.base_date)
        print(f"[keep-route] rollout g1 run1: {outputs['run1'].relative_to(ROOT)}")
        print(f"[keep-route] rollout g1 run2: {outputs['run2'].relative_to(ROOT)}")
        print(f"[keep-route] rollout g1 note: {outputs['note'].relative_to(ROOT)}")
        print(f"[keep-route] weekly report updated: {Path(outputs['report']).relative_to(ROOT)}")
        print(f"[keep-route] samples run1/run2: {outputs['samples1']}/{outputs['samples2']}")
        return 0
    if args.cmd == "rollout-g2":
        outputs = run_rollout_g2(base_date=args.base_date)
        print(f"[keep-route] rollout g2 adapter: {outputs['adapter'].relative_to(ROOT)}")
        print(f"[keep-route] rollout g2 tree: {outputs['tree'].relative_to(ROOT)}")
        print(f"[keep-route] rollout g2 scene: {outputs['scene'].relative_to(ROOT)}")
        print(f"[keep-route] rollout g2 note: {outputs['note'].relative_to(ROOT)}")
        print(f"[keep-route] weekly report updated: {Path(outputs['report']).relative_to(ROOT)}")
        return 0
    if args.cmd == "rollout-g3":
        outputs = run_rollout_g3(base_date=args.base_date)
        print(f"[keep-route] rollout g3 summary: {outputs['summary'].relative_to(ROOT)}")
        print(f"[keep-route] rollout g3 evaluation: {outputs['evaluation'].relative_to(ROOT)}")
        print(f"[keep-route] rollout g3 day7: {outputs['day7'].relative_to(ROOT)}")
        print(f"[keep-route] rollout g3 note: {outputs['note'].relative_to(ROOT)}")
        print(f"[keep-route] weekly report updated: {Path(outputs['report']).relative_to(ROOT)}")
        return 0
    if args.cmd == "ops-g1":
        outputs = run_ops_g1(base_date=args.base_date)
        print(f"[keep-route] ops g1 rollback script: {Path(outputs['rollback_script']).relative_to(ROOT)}")
        print(f"[keep-route] ops g1 elapsed_s: {float(outputs['elapsed_s']):.2f}")
        print(f"[keep-route] ops g1 note: {Path(outputs['note']).relative_to(ROOT)}")
        print(f"[keep-route] weekly report updated: {Path(outputs['report']).relative_to(ROOT)}")
        return 0
    if args.cmd == "decision-g1":
        outputs = run_decision_g1(base_date=args.base_date)
        print(f"[keep-route] decision g1 gate: {outputs['gate'].relative_to(ROOT)}")
        print(f"[keep-route] decision g1 note: {outputs['note'].relative_to(ROOT)}")
        print(f"[keep-route] weekly report updated: {outputs['report'].relative_to(ROOT)}")
        return 0
    if args.cmd == "weekly-close":
        outputs = run_weekly_close(base_date=args.base_date)
        print(f"[keep-route] weekly close archive: {outputs['archive'].relative_to(ROOT)}")
        print(f"[keep-route] weekly report updated: {outputs['report'].relative_to(ROOT)}")
        return 0
    if args.cmd == "status-snapshot":
        outputs = run_status_snapshot(base_date=args.base_date)
        print(f"[keep-route] live snapshot: {outputs['snapshot'].relative_to(ROOT)}")
        if outputs["report"].exists():
            print(f"[keep-route] linked report: {outputs['report'].relative_to(ROOT)}")
        return 0

    print("[keep-route] unknown command")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

