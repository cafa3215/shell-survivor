#!/usr/bin/env python3
"""
Automate weekly project advancement artifacts.

Features:
- Generate a weekly execution board markdown from backlog items
- Create candidate evaluation forms for external tools/open-source repos
- Produce a weekly report draft
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
AUTO = DOCS / "automation"
WEEKLY = AUTO / "weekly"
EVAL = AUTO / "evaluations"
REPORTS = AUTO / "reports"
LOGS = AUTO / "logs"
CONFIG = AUTO / "pipeline_config.json"
PROJECT_STATUS = DOCS / "PROJECT_STATUS.md"
INTEGRATIONS = DOCS / "integrations"
BEHAVE_TRIAL = ROOT / "tmp" / "integrations" / "beehave_trial"
BEHAVE_TRIAL_SCRIPTS = BEHAVE_TRIAL / "scripts"
BEHAVE_TRIAL_SCENES = BEHAVE_TRIAL / "scenes"
BEHAVE_TRIAL_REPORTS = BEHAVE_TRIAL / "reports"


DEFAULT_BACKLOG = [
    ("Tune mid-game enemy pressure curve", "Run one 20-minute playtest and capture curve notes"),
    ("Refine upgrade pick readability", "Reduce hesitation moments in 3 test runs"),
    ("Optimize heavy combat frame spikes", "No visible spike during elite + boss overlap"),
    ("Wire minimal analytics event set", "Export one weekly metrics snapshot"),
    ("Finalize one external integration trial", "Complete 7-day keep/drop decision"),
    ("Polish one high-impact weapon feedback", "Before/after feel comparison captured"),
    ("Ship one quality-of-life UI fix", "Player can complete flow with zero confusion"),
]

DEFAULT_CANDIDATES = [
    {
        "name": "beehave",
        "repo": "https://github.com/bitbrain/beehave",
    },
    {
        "name": "limboai",
        "repo": "https://github.com/limbonaut/limboai",
    },
    {
        "name": "savemadeeasy",
        "repo": "https://github.com/AdamKormos/SaveMadeEasy",
    },
]


def ensure_dirs() -> None:
    for path in (
        AUTO,
        WEEKLY,
        EVAL,
        REPORTS,
        LOGS,
        INTEGRATIONS,
        BEHAVE_TRIAL,
        BEHAVE_TRIAL_SCRIPTS,
        BEHAVE_TRIAL_SCENES,
        BEHAVE_TRIAL_REPORTS,
    ):
        path.mkdir(parents=True, exist_ok=True)


def week_range(base: dt.date) -> tuple[dt.date, dt.date]:
    weekday = base.weekday()
    monday = base - dt.timedelta(days=weekday)
    sunday = monday + dt.timedelta(days=6)
    return monday, sunday


def build_weekly_board(hours: int, focus: str, out_file: Path, base_date: dt.date | None = None) -> None:
    monday, sunday = week_range(base_date or dt.date.today())
    gameplay_h = round(hours * 0.7, 1)
    process_h = round(hours * 0.2, 1)
    experiment_h = round(hours * 0.1, 1)

    lines: list[str] = []
    lines.append(f"# Weekly Execution Board ({monday} ~ {sunday})")
    lines.append("")
    lines.append(f"- Weekly capacity: {hours}h")
    lines.append(f"- Allocation: gameplay {gameplay_h}h / process {process_h}h / experiment {experiment_h}h")
    lines.append(f"- Focus: {focus}")
    lines.append("")
    lines.append("## This Week (5-7 tasks)")
    lines.append("")
    for idx, (task, done) in enumerate(DEFAULT_BACKLOG, start=1):
        lines.append(f"{idx}. [ ] {task}")
        lines.append(f"   - Done when: {done}")
    lines.append("")
    lines.append("## Daily Rhythm")
    lines.append("")
    lines.append("- Day1: Plan + complete one highest-value task")
    lines.append("- Day2: Core gameplay tuning + metrics notes")
    lines.append("- Day3: One external trial + evaluation form")
    lines.append("- Day4: Stability pass + full verification when needed")
    lines.append("- Day5: Playtest review + next-week pre-plan")
    lines.append("")
    lines.append("## Verification Commands")
    lines.append("")
    lines.append("- `python verify_project.py`")
    lines.append("- `python verify_project.py --full` (combat/level changes)")
    lines.append("")
    lines.append("## End-of-Week Review")
    lines.append("")
    lines.append("- [ ] What shipped (only measurable outcomes)")
    lines.append("- [ ] Biggest blocker and root cause")
    lines.append("- [ ] Keep/drop decision for external trial")
    lines.append("- [ ] Next week top 5-7 tasks")
    lines.append("")

    out_file.write_text("\n".join(lines), encoding="utf-8")


def create_candidate_form(name: str, repo_url: str, out_file: Path) -> None:
    content = f"""# Candidate Evaluation: {name}

- Repo: {repo_url}
- Date: {dt.date.today()}
- Type: Tool / OSS / Asset

## Gate Check (all required)

- [ ] License is compatible
- [ ] Active in last 3-6 months
- [ ] Integration docs are clear
- [ ] Reversible within 1-2 days
- [ ] Can prove measurable value in 7 days

## Scoring (1-5)

- Stack compatibility:
- Coupling risk (high score = low risk):
- Performance safety:
- Learning cost (high score = low cost):
- Replaceability:

Total:

## 7-Day Trial Plan

- Day1-2: isolated demo integration
- Day3-4: limited main-path trial
- Day5: performance and stability compare
- Day6: rollback rehearsal
- Day7: keep/drop decision

## Result

- Keep or drop:
- Evidence:
- Next action:
"""
    out_file.write_text(content, encoding="utf-8")


def archive_all_candidates(candidates: list[dict], today: dt.date) -> tuple[list[Path], Path]:
    generated: list[Path] = []
    summary = REPORTS / f"CANDIDATE_ARCHIVE_{today}.md"
    lines: list[str] = []
    lines.append(f"# Candidate Archive ({today})")
    lines.append("")
    lines.append("## Generated Forms")
    lines.append("")
    for item in candidates:
        name = str(item.get("name", "")).strip()
        repo = str(item.get("repo", "")).strip()
        if not name or not repo:
            continue
        safe_name = name.replace(" ", "_").replace("/", "_")
        path = EVAL / f"{safe_name}_{today}.md"
        create_candidate_form(name=name, repo_url=repo, out_file=path)
        generated.append(path)
        lines.append(f"- {name}: `{path.relative_to(ROOT)}`")
    lines.append("")
    lines.append("## Next Action")
    lines.append("")
    lines.append("- Pick one candidate for 7-day trial using the generated form.")
    summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return generated, summary


def scaffold_beehave_trial(today: dt.date) -> tuple[Path, Path, Path, Path, Path, Path, Path, Path, Path]:
    integration_doc = INTEGRATIONS / f"BEEHAVE_TRIAL_PLAN_{today}.md"
    checklist_doc = INTEGRATIONS / f"BEEHAVE_DAY1_DAY2_CHECKLIST_{today}.md"
    sandbox_readme = BEHAVE_TRIAL / "README.md"
    rollback_script = BEHAVE_TRIAL_SCRIPTS / "rollback_beehave_trial.ps1"
    trial_config = BEHAVE_TRIAL / "trial_config.json"
    trial_scene = BEHAVE_TRIAL_SCENES / "BeehaveTrial.tscn"
    trial_enemy_script = BEHAVE_TRIAL_SCRIPTS / "beehave_trial_enemy.gd"
    compare_template = INTEGRATIONS / f"BEEHAVE_DAY2_COMPARE_{today}.md"
    sample_report = BEHAVE_TRIAL_REPORTS / f"DAY3_RUNTIME_SAMPLE_{today}.md"
    day4_summary = INTEGRATIONS / f"BEEHAVE_DAY4_SUMMARY_{today}.md"

    integration_doc.write_text(
        f"""# Beehave 7-Day Trial Plan ({today})

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
""",
        encoding="utf-8",
    )

    sandbox_readme.write_text(
        """# Beehave Trial Sandbox

Purpose: isolated plugin trial workspace.

Rules:
- Do not wire this sandbox directly into `scenes/Game.tscn`.
- All experiments must stay under `tmp/integrations/beehave_trial`.
- If trial is dropped, remove this folder without affecting core gameplay.
""",
        encoding="utf-8",
    )

    checklist_doc.write_text(
        f"""# Beehave Day1-Day2 Checklist ({today})

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
""",
        encoding="utf-8",
    )

    rollback_script.write_text(
        """$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$trialDir = Join-Path $root "tmp\\integrations\\beehave_trial"

Write-Host "[rollback] removing beehave trial sandbox..."
if (Test-Path $trialDir) {
    Remove-Item -LiteralPath $trialDir -Recurse -Force
    Write-Host "[rollback] done."
} else {
    Write-Host "[rollback] sandbox not found, nothing to remove."
}
""",
        encoding="utf-8",
    )
    trial_config.write_text(
        json.dumps(
            {
                "use_beehave_in_trial": False,
                "behavior_mode": "fsm",
                "move_speed": 85.0,
                "patrol_radius": 120.0,
                "notes": "Toggle only inside trial sandbox. Keep false until plugin import succeeds.",
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    trial_scene.write_text(
        """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tmp/integrations/beehave_trial/scripts/beehave_trial_enemy.gd" id="1"]

[node name="BeehaveTrial" type="Node2D"]
script = ExtResource("1")

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="Panel" type="PanelContainer" parent="CanvasLayer"]
offset_left = 16.0
offset_top = 16.0
offset_right = 560.0
offset_bottom = 190.0

[node name="VBox" type="VBoxContainer" parent="CanvasLayer/Panel"]
theme_override_constants/separation = 4

[node name="Title" type="Label" parent="CanvasLayer/Panel/VBox"]
text = "Beehave Trial Runtime Monitor"

[node name="Mode" type="Label" parent="CanvasLayer/Panel/VBox"]
text = "mode: -"

[node name="State" type="Label" parent="CanvasLayer/Panel/VBox"]
text = "state: -"

[node name="TargetDist" type="Label" parent="CanvasLayer/Panel/VBox"]
text = "target_distance: -"

[node name="FPS" type="Label" parent="CanvasLayer/Panel/VBox"]
text = "fps: -"
""",
        encoding="utf-8",
    )
    trial_enemy_script.write_text(
        """extends Node2D

const _CONFIG_PATH := "res://tmp/integrations/beehave_trial/trial_config.json"
var _mode := "fsm"
var _speed := 85.0
var _radius := 120.0
var _origin := Vector2.ZERO
var _target := Vector2.ZERO
var _state := "patrol"
var _state_tick := 0.0
var _stats_tick := 0.0
var _log_tick := 0.0
var _log_path := "user://beehave_trial_runtime_log.jsonl"
@onready var _mode_label := get_node_or_null("CanvasLayer/Panel/VBox/Mode") as Label
@onready var _state_label := get_node_or_null("CanvasLayer/Panel/VBox/State") as Label
@onready var _dist_label := get_node_or_null("CanvasLayer/Panel/VBox/TargetDist") as Label
@onready var _fps_label := get_node_or_null("CanvasLayer/Panel/VBox/FPS") as Label

func _ready() -> void:
\tvar cfg := _load_trial_config()
\tvar use_beehave := bool(cfg.get("use_beehave_in_trial", false))
\t_mode = String(cfg.get("behavior_mode", "fsm")).to_lower()
\t_speed = float(cfg.get("move_speed", 85.0))
\t_radius = float(cfg.get("patrol_radius", 120.0))
\t_origin = global_position
\t_target = _pick_target()
\tif use_beehave:
\t\tprint("[beehave-trial] placeholder tree runner active, mode=%s" % _mode)
\telse:
\t\tprint("[beehave-trial] fallback runner active, mode=%s" % _mode)
\t_reset_runtime_log()
\tset_process(true)

func _process(delta: float) -> void:
\t_state_tick += delta
\t_stats_tick += delta
\t_log_tick += delta
\tif _mode == "bt":
\t\t_step_bt(delta)
\telse:
\t\t_step_fsm(delta)
\tif _stats_tick >= 0.15:
\t\t_stats_tick = 0.0
\t\t_refresh_runtime_labels()
\tif _log_tick >= 2.0:
\t\t_log_tick = 0.0
\t\t_append_runtime_log()

func _step_fsm(delta: float) -> void:
\tif _state == "idle":
\t\tif _state_tick > 0.8:
\t\t\t_state_tick = 0.0
\t\t\t_state = "patrol"
\t\t\t_target = _pick_target()
\t\treturn
\tvar dir := _target - global_position
\tif dir.length() < 8.0:
\t\t_state = "idle"
\t\t_state_tick = 0.0
\t\treturn
\tglobal_position += dir.normalized() * _speed * delta

func _step_bt(delta: float) -> void:
\t# Minimal BT-like flow: Selector(HasTarget->Move, Wait->PickTarget)
\tvar dir := _target - global_position
\tif dir.length() > 10.0:
\t\t_state = "bt_move"
\t\tglobal_position += dir.normalized() * (_speed * 0.92) * delta
\t\treturn
\t_state = "bt_pick"
\tif _state_tick > 0.35:
\t\t_state_tick = 0.0
\t\t_target = _pick_target()

func _pick_target() -> Vector2:
\tvar a := randf() * TAU
\tvar r := randf_range(_radius * 0.45, _radius)
\treturn _origin + Vector2(cos(a), sin(a)) * r

func _load_trial_config() -> Dictionary:
\tif not FileAccess.file_exists(_CONFIG_PATH):
\t\treturn {}
\tvar f := FileAccess.open(_CONFIG_PATH, FileAccess.READ)
\tif f == null:
\t\treturn {}
\tvar txt := f.get_as_text()
\tf.close()
\tif txt.is_empty():
\t\treturn {}
\tvar parsed := JSON.parse_string(txt)
\tif typeof(parsed) != TYPE_DICTIONARY:
\t\treturn {}
\treturn parsed as Dictionary

func _refresh_runtime_labels() -> void:
\tvar d := global_position.distance_to(_target)
\tif _mode_label:
\t\t_mode_label.text = "mode: %s" % _mode
\tif _state_label:
\t\t_state_label.text = "state: %s" % _state
\tif _dist_label:
\t\t_dist_label.text = "target_distance: %.1f" % d
\tif _fps_label:
\t\t_fps_label.text = "fps: %.1f" % Performance.get_monitor(Performance.TIME_FPS)

func _reset_runtime_log() -> void:
\tvar f := FileAccess.open(_log_path, FileAccess.WRITE)
\tif f == null:
\t\treturn
\tf.store_line("{\\"event\\":\\"start\\",\\"mode\\":\\"%s\\"}" % _mode)
\tf.close()

func _append_runtime_log() -> void:
\tvar d := global_position.distance_to(_target)
\tvar fps := float(Performance.get_monitor(Performance.TIME_FPS))
\tvar line := "{\\"t\\":%d,\\"mode\\":\\"%s\\",\\"state\\":\\"%s\\",\\"target_dist\\":%.2f,\\"fps\\":%.2f}" % [
\t\tTime.get_ticks_msec(),
\t\t_mode,
\t\t_state,
\t\td,
\t\tfps
\t]
\tvar f := FileAccess.open(_log_path, FileAccess.READ_WRITE)
\tif f == null:
\t\treturn
\tf.seek_end()
\tf.store_line(line)
\tf.close()
""",
        encoding="utf-8",
    )
    compare_template.write_text(
        f"""# Beehave Day2 Compare Template ({today})

## Trial Setup

- Scene: `tmp/integrations/beehave_trial/scenes/BeehaveTrial.tscn`
- Config: `tmp/integrations/beehave_trial/trial_config.json`
- Mode A: `behavior_mode = "fsm"`
- Mode B: `behavior_mode = "bt"`

## Observation Sheet

- FPS avg (FSM):
- FPS avg (BT):
- Frame-time spikes (FSM):
- Frame-time spikes (BT):
- Behavior readability (FSM):
- Behavior readability (BT):
- Error count (FSM):
- Error count (BT):

## Decision

- Keep/Drop:
- Why:
- Next action:
""",
        encoding="utf-8",
    )
    sample_report.write_text(
        f"""# Day3 Runtime Sample ({today})

## Trial Context

- Scene: `tmp/integrations/beehave_trial/scenes/BeehaveTrial.tscn`
- Script: `tmp/integrations/beehave_trial/scripts/beehave_trial_enemy.gd`
- Runtime HUD: mode/state/target_distance/fps

## Snapshot A (FSM)

- mode:
- state:
- target_distance:
- fps_avg_30s:

## Snapshot B (BT-style)

- mode:
- state:
- target_distance:
- fps_avg_30s:

## Delta

- readability_change:
- fps_change:
- risk_note:
""",
        encoding="utf-8",
    )
    day4_summary.write_text(
        f"""# Beehave Day4 Summary Draft ({today})

## Runtime Log Source

- `user://beehave_trial_runtime_log.jsonl` (sampled every 2s)

## Aggregated Comparison

- FSM avg FPS:
- BT avg FPS:
- FSM avg target_distance:
- BT avg target_distance:
- FSM state transitions:
- BT state transitions:

## Conclusion

- Preferred mode:
- Reason:
- Keep/Drop recommendation:
""",
        encoding="utf-8",
    )

    return integration_doc, checklist_doc, sandbox_readme, rollback_script, trial_config, trial_scene, compare_template, sample_report, day4_summary


def build_weekly_report(hours: int, out_file: Path, base_date: dt.date | None = None) -> None:
    monday, sunday = week_range(base_date or dt.date.today())
    report = f"""# Weekly Report Draft ({monday} ~ {sunday})

## Planned Capacity

- {hours}h total
- 70/20/10 split applied

## Shipped Outcomes

- [ ] Outcome 1 (measurable)
- [ ] Outcome 2 (measurable)
- [ ] Outcome 3 (measurable)

## Metrics Snapshot

- 10-minute survival rate:
- Time-to-first-death:
- Upgrade hesitation hotspots:

## External Integration Decision

- Candidate:
- Keep/drop:
- Why:

## Risks Next Week

- Risk 1:
- Risk 2:
- Risk 3:

## Next Week Top 5

1. [ ] 
2. [ ] 
3. [ ] 
4. [ ] 
5. [ ] 

## Reminder

- Fill metrics above, then update `docs/PROJECT_STATUS.md` section 4 and 6.
"""
    out_file.write_text(report, encoding="utf-8")


def sync_project_status(
    *,
    monday: dt.date,
    sunday: dt.date,
    weekly_file: Path,
    report_file: Path,
    focus: str,
    hours: int,
) -> None:
    """Refresh week links in PROJECT_STATUS.md (solo single source of truth)."""
    if not PROJECT_STATUS.exists():
        return
    text = PROJECT_STATUS.read_text(encoding="utf-8")
    stamp = dt.date.today().isoformat()
    weekly_rel = weekly_file.relative_to(ROOT).as_posix()
    report_rel = report_file.relative_to(ROOT).as_posix()

    replacements = [
        ("**最后更新：**", f"**最后更新：** {stamp}"),
        ("- **容量：**", f"- **容量：** {hours}h（70% 玩法 / 20% 流程 / 10% 实验）"),
        ("- **焦点句：**", f"- **焦点句：** {focus}"),
        (
            "- **周看板：**",
            f"- **周看板：** `{weekly_rel}`",
        ),
        (
            "- **周报告：**",
            f"- **周报告：** `{report_rel}`",
        ),
    ]

    lines = text.splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        matched = False
        for prefix, new_line in replacements:
            if line.startswith(prefix):
                out.append(new_line)
                matched = True
                break
        if not matched:
            out.append(line)
        i += 1

    PROJECT_STATUS.write_text("\n".join(out) + "\n", encoding="utf-8")


def write_default_config() -> None:
    if CONFIG.exists():
        return
    payload = {
        "weekly_hours": 25,
        "focus": "Core gameplay + stable delivery",
        "candidates": DEFAULT_CANDIDATES,
    }
    CONFIG.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def load_config() -> dict:
    write_default_config()
    return json.loads(CONFIG.read_text(encoding="utf-8"))


def choose_next_candidate(candidates: list[dict], today: dt.date) -> dict:
    if not candidates:
        raise ValueError("No candidates configured in pipeline_config.json")
    idx = today.toordinal() % len(candidates)
    return candidates[idx]


def run_pipeline(hours: int | None = None, focus: str | None = None, base_date: dt.date | None = None) -> dict[str, Path]:
    cfg = load_config()
    h = hours if hours is not None else int(cfg.get("weekly_hours", 25))
    f = focus if focus else str(cfg.get("focus", "Core gameplay + stable delivery"))
    today = base_date or dt.date.today()
    monday, _ = week_range(today)

    weekly_file = WEEKLY / f"WEEK_{monday}.md"
    report_file = REPORTS / f"REPORT_{monday}.md"
    build_weekly_board(hours=h, focus=f, out_file=weekly_file, base_date=today)
    build_weekly_report(hours=h, out_file=report_file, base_date=today)

    candidates = cfg.get("candidates", [])
    candidate = choose_next_candidate(candidates, today)
    safe_name = candidate["name"].strip().replace(" ", "_").replace("/", "_")
    eval_file = EVAL / f"{safe_name}_{today}.md"
    create_candidate_form(name=candidate["name"], repo_url=candidate["repo"], out_file=eval_file)

    log_file = LOGS / f"PIPELINE_{today}.log"
    log_lines = [
        f"generated_at={dt.datetime.now().isoformat(timespec='seconds')}",
        f"date={today}",
        f"hours={h}",
        f"focus={f}",
        f"weekly={weekly_file.relative_to(ROOT)}",
        f"evaluation={eval_file.relative_to(ROOT)}",
        f"report={report_file.relative_to(ROOT)}",
        f"candidate={candidate['name']}|{candidate['repo']}",
    ]
    log_file.write_text("\n".join(log_lines) + "\n", encoding="utf-8")

    _, sunday = week_range(today)
    sync_project_status(
        monday=monday,
        sunday=sunday,
        weekly_file=weekly_file,
        report_file=report_file,
        focus=f,
        hours=h,
    )

    return {
        "weekly": weekly_file,
        "evaluation": eval_file,
        "report": report_file,
        "log": log_file,
        "config": CONFIG,
    }


def _load_pipeline_log(log_file: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    if not log_file.exists():
        return data
    for raw in log_file.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or "=" not in line:
            continue
        k, v = line.split("=", 1)
        data[k.strip()] = v.strip()
    return data


def _resolve_rel_paths(values: Iterable[str]) -> list[Path]:
    resolved: list[Path] = []
    for value in values:
        if not value:
            continue
        resolved.append(ROOT / value)
    return resolved


def validate_auto_outputs(base_date: dt.date | None = None, max_age_days: int = 8) -> tuple[bool, list[str]]:
    today = base_date or dt.date.today()
    monday, _ = week_range(today)

    expected_weekly = WEEKLY / f"WEEK_{monday}.md"
    expected_report = REPORTS / f"REPORT_{monday}.md"
    expected_log = LOGS / f"PIPELINE_{today}.log"
    expected_eval_pattern = EVAL / f"*_{today}.md"

    issues: list[str] = []

    for required in (expected_weekly, expected_report, expected_log):
        if not required.exists():
            issues.append(f"missing required artifact: {required.relative_to(ROOT)}")

    todays_evals = sorted(EVAL.glob(expected_eval_pattern.name))
    if not todays_evals:
        issues.append(f"no evaluation generated for today: {expected_eval_pattern.name}")

    log_data = _load_pipeline_log(expected_log)
    logged_weekly = log_data.get("weekly")
    logged_report = log_data.get("report")
    logged_eval = log_data.get("evaluation")

    for path in _resolve_rel_paths([logged_weekly, logged_report, logged_eval]):
        if not path.exists():
            issues.append(f"log points to missing artifact: {path.relative_to(ROOT)}")

    if logged_weekly and (ROOT / logged_weekly) != expected_weekly:
        issues.append(
            f"log weekly mismatch: expected {expected_weekly.relative_to(ROOT)}, got {logged_weekly}"
        )
    if logged_report and (ROOT / logged_report) != expected_report:
        issues.append(
            f"log report mismatch: expected {expected_report.relative_to(ROOT)}, got {logged_report}"
        )

    freshness_cutoff = dt.datetime.now() - dt.timedelta(days=max_age_days)
    freshness_targets = [expected_weekly, expected_report, expected_log] + todays_evals
    for target in freshness_targets:
        if not target.exists():
            continue
        mtime = dt.datetime.fromtimestamp(target.stat().st_mtime)
        if mtime < freshness_cutoff:
            issues.append(
                f"stale artifact (> {max_age_days}d): {target.relative_to(ROOT)} (mtime={mtime.isoformat(timespec='seconds')})"
            )

    return len(issues) == 0, issues


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Automate project advancement artifacts")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_boot = sub.add_parser("bootstrap-week", help="Generate this week's execution board")
    p_boot.add_argument("--hours", type=int, default=25, help="Weekly available hours")
    p_boot.add_argument("--focus", default="Core gameplay + stable delivery", help="Weekly focus statement")
    p_boot.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")

    p_eval = sub.add_parser("evaluate-candidate", help="Create a candidate evaluation template")
    p_eval.add_argument("--name", required=True, help="Candidate name")
    p_eval.add_argument("--repo", required=True, help="Repository URL")

    p_report = sub.add_parser("weekly-report", help="Create weekly report draft")
    p_report.add_argument("--hours", type=int, default=25, help="Weekly available hours")
    p_report.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")

    p_auto = sub.add_parser("run-auto", help="Run full automation pipeline end-to-end")
    p_auto.add_argument("--hours", type=int, default=None, help="Override weekly available hours")
    p_auto.add_argument("--focus", default=None, help="Override weekly focus statement")
    p_auto.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")
    p_auto.add_argument("--archive-all-candidates", action="store_true", help="Generate evaluation forms for all configured candidates")
    p_auto.add_argument("--scaffold-beehave-trial", action="store_true", help="Generate isolated beehave trial scaffold")
    p_auto.add_argument("--summarize-beehave-day4", action="store_true", help="Run beehave runtime log summarizer")

    p_validate = sub.add_parser("validate-auto", help="Validate automation artifact consistency and freshness")
    p_validate.add_argument("--base-date", default=None, help="Base date in YYYY-MM-DD")
    p_validate.add_argument("--max-age-days", type=int, default=8, help="Maximum allowed age for generated artifacts")

    return parser.parse_args()


def main() -> int:
    ensure_dirs()
    args = parse_args()
    base_date = dt.date.fromisoformat(args.base_date) if getattr(args, "base_date", None) else None

    if args.cmd == "bootstrap-week":
        today = base_date or dt.date.today()
        monday, sunday = week_range(today)
        output = WEEKLY / f"WEEK_{monday}.md"
        report = REPORTS / f"REPORT_{monday}.md"
        build_weekly_board(hours=args.hours, focus=args.focus, out_file=output, base_date=base_date)
        sync_project_status(
            monday=monday,
            sunday=sunday,
            weekly_file=output,
            report_file=report,
            focus=args.focus,
            hours=args.hours,
        )
        print(f"[advance] weekly board generated: {output.relative_to(ROOT)}")
        print(f"[advance] project status synced: {PROJECT_STATUS.relative_to(ROOT)}")
        return 0

    if args.cmd == "evaluate-candidate":
        safe_name = args.name.strip().replace(" ", "_").replace("/", "_")
        output = EVAL / f"{safe_name}_{dt.date.today()}.md"
        create_candidate_form(name=args.name, repo_url=args.repo, out_file=output)
        print(f"[advance] candidate form generated: {output.relative_to(ROOT)}")
        return 0

    if args.cmd == "weekly-report":
        today = base_date or dt.date.today()
        monday, sunday = week_range(today)
        output = REPORTS / f"REPORT_{monday}.md"
        weekly = WEEKLY / f"WEEK_{monday}.md"
        build_weekly_report(hours=args.hours, out_file=output, base_date=base_date)
        sync_project_status(
            monday=monday,
            sunday=sunday,
            weekly_file=weekly,
            report_file=output,
            focus=load_config().get("focus", "Core gameplay + stable delivery"),
            hours=args.hours,
        )
        print(f"[advance] weekly report generated: {output.relative_to(ROOT)}")
        print(f"[advance] project status synced: {PROJECT_STATUS.relative_to(ROOT)}")
        return 0

    if args.cmd == "run-auto":
        outputs = run_pipeline(hours=args.hours, focus=args.focus, base_date=base_date)
        today = base_date or dt.date.today()
        if args.archive_all_candidates:
            cfg = load_config()
            generated, summary = archive_all_candidates(cfg.get("candidates", []), today)
            print(f"[advance] archived candidates: {len(generated)}")
            print(f"[advance] archive summary: {summary.relative_to(ROOT)}")
        if args.scaffold_beehave_trial:
            (
                plan_doc,
                checklist_doc,
                sandbox_readme,
                rollback_script,
                trial_config,
                trial_scene,
                compare_template,
                sample_report,
                day4_summary,
            ) = scaffold_beehave_trial(today)
            print(f"[advance] beehave plan: {plan_doc.relative_to(ROOT)}")
            print(f"[advance] beehave day1/day2 checklist: {checklist_doc.relative_to(ROOT)}")
            print(f"[advance] beehave sandbox: {sandbox_readme.relative_to(ROOT)}")
            print(f"[advance] beehave rollback script: {rollback_script.relative_to(ROOT)}")
            print(f"[advance] beehave trial config: {trial_config.relative_to(ROOT)}")
            print(f"[advance] beehave trial scene: {trial_scene.relative_to(ROOT)}")
            print(f"[advance] beehave compare template: {compare_template.relative_to(ROOT)}")
            print(f"[advance] beehave day3 sample: {sample_report.relative_to(ROOT)}")
            print(f"[advance] beehave day4 summary: {day4_summary.relative_to(ROOT)}")
        if args.summarize_beehave_day4:
            log_path = BEHAVE_TRIAL_REPORTS / f"runtime_log_{today}.jsonl"
            summary_path = INTEGRATIONS / f"BEEHAVE_DAY4_SUMMARY_{today}.md"
            print(
                "[advance] run summary command: "
                f"python tools/summarize_beehave_trial.py --log \"{log_path}\" "
                f"--summary \"{summary_path}\" --generate-sample-if-missing "
                "--update-weekly-report --update-evaluation --write-day7-decision"
            )
        print(f"[advance] config ready: {outputs['config'].relative_to(ROOT)}")
        print(f"[advance] weekly board: {outputs['weekly'].relative_to(ROOT)}")
        print(f"[advance] evaluation: {outputs['evaluation'].relative_to(ROOT)}")
        print(f"[advance] report: {outputs['report'].relative_to(ROOT)}")
        print(f"[advance] log: {outputs['log'].relative_to(ROOT)}")
        print(f"[advance] project status synced: {PROJECT_STATUS.relative_to(ROOT)}")
        return 0

    if args.cmd == "validate-auto":
        ok, issues = validate_auto_outputs(base_date=base_date, max_age_days=args.max_age_days)
        if ok:
            print("[advance] validate-auto OK")
            return 0
        print("[advance] validate-auto FAILED")
        for issue in issues:
            print(f"- {issue}")
        return 2

    print("[advance] unknown command")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

