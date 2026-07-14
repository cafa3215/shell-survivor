#!/usr/bin/env python3
"""
Release preflight checks for Shell Survivor.

Default: fast checks (load + release contracts)
Optional: include gameplay smoke with --full
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def run_step(name: str, cmd: list[str]) -> int:
    print(f"[verify] {name} ...")
    proc = subprocess.run(
        cmd,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0:
        print(f"[verify] {name} FAILED (code={proc.returncode})")
        if proc.stdout.strip():
            print(proc.stdout.strip())
        return proc.returncode
    print(f"[verify] {name} OK")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Project verification checks")
    parser.add_argument(
        "--full",
        action="store_true",
        help="Include longer gameplay smoke check (validate_play.gd)",
    )
    parser.add_argument(
        "--godot-bin",
        default="godot",
        help="Godot executable name/path (default: godot)",
    )
    args = parser.parse_args()

    godot = args.godot_bin
    steps: list[tuple[str, list[str]]] = [
        (
            "validate_load",
            [godot, "--headless", "--script", "res://tools/validate_load.gd"],
        ),
        (
            "validate_modules",
            [godot, "--headless", "--script", "res://tools/validate_modules.gd"],
        ),
        (
            "validate_dimensions",
            [godot, "--headless", "--script", "res://tools/validate_dimensions.gd"],
        ),
        (
            "validate_release",
            [godot, "--headless", "--script", "res://tools/validate_release.gd"],
        ),
        (
            "validate_boss_chain",
            [godot, "--headless", "--script", "res://tools/validate_boss_chain.gd"],
        ),
        (
            "validate_active_skill_chain",
            [godot, "--headless", "--script", "res://tools/validate_active_skill_chain.gd"],
        ),
        (
            "validate_reward_result_chain",
            [godot, "--headless", "--script", "res://tools/validate_reward_result_chain.gd"],
        ),
        (
            "validate_behavior",
            [godot, "--headless", "--script", "res://tools/validate_behavior.gd"],
        ),
        (
            "validate_week7_qa",
            [godot, "--headless", "--script", "res://tools/validate_week7_qa.gd"],
        ),
        (
            "validate_week8_ship",
            [godot, "--headless", "--script", "res://tools/validate_week8_ship.gd"],
        ),
    ]
    if args.full:
        steps.append(
            (
                "validate_play",
                [godot, "--headless", "--script", "res://tools/validate_play.gd"],
            )
        )

    for name, cmd in steps:
        code = run_step(name, cmd)
        if code != 0:
            return code

    print("[verify] ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
