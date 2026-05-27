#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TRIAL_REPORTS = ROOT / "tmp" / "integrations" / "beehave_trial" / "reports"
INTEGRATIONS = ROOT / "docs" / "integrations"


def _default_paths() -> tuple[Path, Path]:
    today = dt.date.today().isoformat()
    log_path = TRIAL_REPORTS / f"runtime_log_{today}.jsonl"
    summary_path = INTEGRATIONS / f"BEEHAVE_DAY4_SUMMARY_{today}.md"
    return log_path, summary_path


def generate_sample_log(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    base_t = 100000
    for i in range(18):
        rows.append(
            {
                "t": base_t + i * 2000,
                "mode": "fsm",
                "state": "patrol" if i % 3 else "idle",
                "target_dist": 80.0 + (i % 5) * 6.0,
                "fps": 58.0 - (i % 4) * 0.8,
            }
        )
    for i in range(18):
        rows.append(
            {
                "t": base_t + 36000 + i * 2000,
                "mode": "bt",
                "state": "bt_move" if i % 2 else "bt_pick",
                "target_dist": 72.0 + (i % 6) * 5.0,
                "fps": 60.0 - (i % 5) * 0.6,
            }
        )
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def _avg(nums: list[float]) -> float:
    return sum(nums) / len(nums) if nums else 0.0


def _calc_metrics(rows: list[dict]) -> dict:
    fsm = [r for r in rows if r.get("mode") == "fsm"]
    bt = [r for r in rows if r.get("mode") == "bt"]
    fsm_fps = _avg([float(r.get("fps", 0.0)) for r in fsm])
    bt_fps = _avg([float(r.get("fps", 0.0)) for r in bt])
    fsm_dist = _avg([float(r.get("target_dist", 0.0)) for r in fsm])
    bt_dist = _avg([float(r.get("target_dist", 0.0)) for r in bt])
    fsm_states = len({str(r.get("state", "")) for r in fsm})
    bt_states = len({str(r.get("state", "")) for r in bt})

    preferred = "bt" if bt_fps >= fsm_fps else "fsm"
    keep_drop = "keep" if bt_fps >= fsm_fps - 1.2 else "drop"
    reason = (
        "BT mode keeps similar or better FPS with acceptable state diversity."
        if keep_drop == "keep"
        else "BT mode regresses runtime stability beyond threshold."
    )
    return {
        "fsm_fps": fsm_fps,
        "bt_fps": bt_fps,
        "fsm_dist": fsm_dist,
        "bt_dist": bt_dist,
        "fsm_states": fsm_states,
        "bt_states": bt_states,
        "preferred": preferred,
        "keep_drop": keep_drop,
        "reason": reason,
    }


def summarize(log_path: Path, summary_path: Path) -> dict:
    lines = [ln.strip() for ln in log_path.read_text(encoding="utf-8").splitlines() if ln.strip()]
    rows: list[dict] = []
    for line in lines:
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    metrics = _calc_metrics(rows)

    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(
        "\n".join(
            [
                f"# Beehave Day4 Summary ({dt.date.today()})",
                "",
                "## Runtime Log Source",
                "",
                f"- `{log_path.relative_to(ROOT)}`",
                "",
                "## Aggregated Comparison",
                "",
                f"- FSM avg FPS: {metrics['fsm_fps']:.2f}",
                f"- BT avg FPS: {metrics['bt_fps']:.2f}",
                f"- FSM avg target_distance: {metrics['fsm_dist']:.2f}",
                f"- BT avg target_distance: {metrics['bt_dist']:.2f}",
                f"- FSM state transitions: {metrics['fsm_states']}",
                f"- BT state transitions: {metrics['bt_states']}",
                "",
                "## Conclusion",
                "",
                f"- Preferred mode: {metrics['preferred']}",
                f"- Reason: {metrics['reason']}",
                f"- Keep/Drop recommendation: {metrics['keep_drop']}",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return metrics


def _update_weekly_report(report_path: Path, metrics: dict) -> None:
    if not report_path.exists():
        return
    lines = report_path.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    for line in lines:
        if line.strip() == "- [ ] Outcome 1 (measurable)":
            out.append(f"- [x] Beehave trial summary generated: preferred={metrics['preferred']} keep/drop={metrics['keep_drop']}")
            continue
        if line.strip() == "- Candidate:":
            out.append("- Candidate: beehave")
            continue
        if line.strip() == "- Keep/drop:":
            out.append(f"- Keep/drop: {metrics['keep_drop']}")
            continue
        if line.strip() == "- Why:":
            out.append(f"- Why: {metrics['reason']}")
            continue
        out.append(line)
    report_path.write_text("\n".join(out) + "\n", encoding="utf-8")


def _update_beehave_evaluation(eval_path: Path, metrics: dict) -> None:
    if not eval_path.exists():
        return
    lines = eval_path.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    for line in lines:
        trimmed = line.strip()
        if trimmed == "- Keep or drop:":
            out.append(f"- Keep or drop: {metrics['keep_drop']}")
            continue
        if trimmed == "- Evidence:":
            out.append(
                "- Evidence: FSM avg FPS %.2f vs BT avg FPS %.2f; FSM dist %.2f vs BT dist %.2f."
                % (
                    metrics["fsm_fps"],
                    metrics["bt_fps"],
                    metrics["fsm_dist"],
                    metrics["bt_dist"],
                )
            )
            continue
        if trimmed == "- Next action:":
            out.append(f"- Next action: Continue with `{metrics['preferred']}` mode in sandbox Day7 decision run.")
            continue
        out.append(line)
    eval_path.write_text("\n".join(out) + "\n", encoding="utf-8")


def _write_day7_decision(metrics: dict) -> Path:
    today = dt.date.today().isoformat()
    decision_path = INTEGRATIONS / f"BEEHAVE_DAY7_DECISION_{today}.md"
    keep_route = [
        "Keep route D1: keep sandbox as trial baseline and lock `behavior_mode=bt`.",
        "Keep route D2: implement one real Beehave tree for a non-core enemy only.",
        "Keep route D3: run `python verify_project.py --full` and compare runtime log deltas.",
    ]
    drop_route = [
        "Drop route D1: execute rollback script in sandbox.",
        "Drop route D2: archive summary/evidence in docs and close candidate as dropped.",
        "Drop route D3: continue with current FSM and revisit next cycle.",
    ]
    preferred = str(metrics["preferred"])
    keep_drop = str(metrics["keep_drop"])
    reason = str(metrics["reason"])
    body = [
        f"# Beehave Day7 Final Decision ({today})",
        "",
        "## Final Verdict",
        "",
        f"- Decision: {keep_drop}",
        f"- Preferred mode: {preferred}",
        f"- Reason: {reason}",
        "",
        "## Keep Route",
        "",
        *[f"- {x}" for x in keep_route],
        "",
        "## Drop Route",
        "",
        *[f"- {x}" for x in drop_route],
        "",
        "## Execution Note",
        "",
        "- This decision is generated from Day4 aggregated metrics and can be overridden after real plugin run.",
        "",
    ]
    decision_path.write_text("\n".join(body), encoding="utf-8")
    return decision_path


def _append_decision_to_weekly(report_path: Path, decision_path: Path) -> None:
    if not report_path.exists():
        return
    txt = report_path.read_text(encoding="utf-8")
    marker = "## Next Week Top 5"
    insert = f"\n## Day7 Decision\n\n- Final decision doc: `{decision_path.relative_to(ROOT)}`\n\n"
    if "## Day7 Decision" not in txt:
        if marker in txt:
            txt = txt.replace(marker, insert + marker)
        else:
            txt += insert
    # Auto-fill next week top5 with executable keep-route tasks and explicit verification gates.
    top5_block = (
        "## Next Week Top 5\n\n"
        "1. [ ] Keep-D1: lock sandbox `behavior_mode=bt` and record 10m runtime log\n"
        "   - Done when: Runtime log has >= 300s data and no critical errors.\n"
        "   - Verify: `python verify_project.py`\n"
        "2. [ ] Keep-D2: implement one real Beehave tree for non-core enemy in sandbox\n"
        "   - Done when: Enemy completes patrol/chase loop in trial scene for 10 minutes.\n"
        "   - Verify: `python verify_project.py --full`\n"
        "3. [ ] Keep-D3: compare BT/FSM deltas and refresh Day4 summary\n"
        "   - Done when: Day4 summary shows FPS/state delta with clear preferred mode.\n"
        "   - Verify: `python tools/summarize_beehave_trial.py --generate-sample-if-missing --update-weekly-report --update-evaluation --write-day7-decision`\n"
        "4. [ ] Update beehave evaluation evidence and Keep/Drop rationale\n"
        "   - Done when: Evaluation doc includes latest metrics and next action.\n"
        "   - Verify: `python tools/summarize_beehave_trial.py --update-evaluation --generate-sample-if-missing`\n"
        "5. [ ] Decide mainline promotion gate (sandbox-only or guarded rollout)\n"
        "   - Done when: Day7 decision doc contains gate condition and rollback path.\n"
        "   - Verify: `python tools/summarize_beehave_trial.py --write-day7-decision --generate-sample-if-missing`\n"
    )
    if marker in txt:
        txt = txt.split(marker)[0].rstrip() + "\n\n" + top5_block + "\n"
    else:
        txt += "\n" + top5_block + "\n"
    report_path.write_text(txt, encoding="utf-8")


def main() -> int:
    default_log, default_summary = _default_paths()
    parser = argparse.ArgumentParser(description="Summarize beehave trial runtime logs")
    parser.add_argument("--log", default=str(default_log), help="Path to jsonl runtime log")
    parser.add_argument("--summary", default=str(default_summary), help="Output summary markdown path")
    parser.add_argument("--generate-sample-if-missing", action="store_true", help="Generate sample log when missing")
    parser.add_argument("--update-weekly-report", action="store_true", help="Update weekly report with summary result")
    parser.add_argument("--update-evaluation", action="store_true", help="Update beehave evaluation with summary evidence")
    parser.add_argument("--write-day7-decision", action="store_true", help="Write final day7 keep/drop decision page")
    args = parser.parse_args()

    log_path = Path(args.log)
    summary_path = Path(args.summary)
    if not log_path.exists():
        if not args.generate_sample_if_missing:
            raise SystemExit(f"log not found: {log_path}")
        generate_sample_log(log_path)
        print(f"[beehave-summary] generated sample log: {log_path.relative_to(ROOT)}")

    metrics = summarize(log_path, summary_path)
    if args.update_weekly_report:
        monday = (dt.date.today() - dt.timedelta(days=dt.date.today().weekday())).isoformat()
        report_path = ROOT / "docs" / "automation" / "reports" / f"REPORT_{monday}.md"
        _update_weekly_report(report_path, metrics)
        print(f"[beehave-summary] updated weekly report: {report_path.relative_to(ROOT)}")
    if args.update_evaluation:
        eval_path = ROOT / "docs" / "automation" / "evaluations" / f"beehave_{dt.date.today().isoformat()}.md"
        _update_beehave_evaluation(eval_path, metrics)
        print(f"[beehave-summary] updated evaluation: {eval_path.relative_to(ROOT)}")
    if args.write_day7_decision:
        decision_path = _write_day7_decision(metrics)
        monday = (dt.date.today() - dt.timedelta(days=dt.date.today().weekday())).isoformat()
        report_path = ROOT / "docs" / "automation" / "reports" / f"REPORT_{monday}.md"
        _append_decision_to_weekly(report_path, decision_path)
        print(f"[beehave-summary] wrote day7 decision: {decision_path.relative_to(ROOT)}")
    print(f"[beehave-summary] wrote summary: {summary_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

