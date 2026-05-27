#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
扫描用户可见文案：若字符串在去掉 printf 占位后仍含连续英文字母，则报错。
白名单：tools/ui_string_allowlist.txt（每行一条正则，匹配整段字符串则放行）。
用法：python tools/audit_ui_cn_strings.py
退出码：0=无违规，1=有违规
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_SCAN_GD_CANDIDATES = [
    ROOT / "scripts" / "ui",
    ROOT / "scripts" / "core" / "Main.gd",
    ROOT / "scripts" / "core" / "Game.gd",
    ROOT / "scripts" / "core" / "EnemyManager.gd",
    ROOT / "scripts" / "core" / "WeaponSystem.gd",
    ROOT / "scripts" / "core" / "RandomEvents.gd",
    ROOT / "scripts" / "entities" / "Player.gd",
]
SCAN_TSCN_GLOBS = ["scenes/**/*.tscn"]

# 从常见 UI 赋值行提取引号内文案（双引号为主）
TEXT_PATTERN_GD = re.compile(
    r'(?:^|\s)(?:tooltip_)?text\s*=\s*"((?:\\.|[^"\\])*)"',
    re.MULTILINE,
)
EMIT_MSG_PATTERN = re.compile(
    r'(?:notification_shown|EventBus\.notification_shown)\.emit\s*\(\s*"((?:\\.|[^"\\])*)"',
    re.MULTILINE,
)
SHOW_PATTERN = re.compile(
    r'(?:^|\s)show\s*\(\s*"((?:\\.|[^"\\])*)"',
    re.MULTILINE,
)
TSCN_TEXT = re.compile(r'^\s*text\s*=\s*"((?:\\.|[^"\\])*)"', re.MULTILINE)

PRINTF_TOKEN = re.compile(
    r"%(?:\d+\$)?[+-]?(?:\d+|\*)?(?:\.\d+)?[sdifs%]"
)
# 去掉后若仍存在至少 2 个连续拉丁字母则视为英文残留
LATIN_RUN = re.compile(r"[A-Za-z]{2,}")


def load_allow(path: Path) -> list[re.Pattern]:
    out: list[re.Pattern] = []
    if not path.is_file():
        return out
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        try:
            out.append(re.compile(line))
        except re.error as e:
            print(f"白名单正则无效: {line!r} ({e})", file=sys.stderr)
    return out


def strip_for_check(s: str) -> str:
    s = PRINTF_TOKEN.sub("", s)
    return s


def is_allowed_full(s: str, allow: list[re.Pattern]) -> bool:
    s = s.strip()
    for p in allow:
        try:
            if p.fullmatch(s):
                return True
        except re.error:
            continue
    return False


def violates(s: str, allow: list[re.Pattern]) -> bool:
    s = s.replace("\\n", "\n")
    if not LATIN_RUN.search(s):
        return False
    if is_allowed_full(s.strip(), allow):
        return False
    stripped = strip_for_check(s)
    return bool(LATIN_RUN.search(stripped))


def iter_gd_files() -> list[Path]:
    files: list[Path] = []
    for item in _SCAN_GD_CANDIDATES:
        if not item.exists():
            continue
        if item.is_dir():
            files.extend(sorted(item.rglob("*.gd")))
        elif item.is_file() and item.suffix == ".gd":
            files.append(item)
    return files


def iter_tscn_files() -> list[Path]:
    out: list[Path] = []
    for pat in SCAN_TSCN_GLOBS:
        out.extend(ROOT.glob(pat))
    return sorted(set(out))


def extract_strings_gd(content: str) -> list[tuple[str, int]]:
    found: list[tuple[str, int]] = []
    for pat in (TEXT_PATTERN_GD, EMIT_MSG_PATTERN, SHOW_PATTERN):
        for m in pat.finditer(content):
            line_no = content[: m.start()].count("\n") + 1
            found.append((m.group(1), line_no))
    return found


def extract_strings_tscn(content: str) -> list[tuple[str, int]]:
    found: list[tuple[str, int]] = []
    for m in TSCN_TEXT.finditer(content):
        line_no = content[: m.start()].count("\n") + 1
        found.append((m.group(1), line_no))
    return found


def main() -> int:
    allow_path = ROOT / "tools" / "ui_string_allowlist.txt"
    allow = load_allow(allow_path)
    errors: list[str] = []

    for fp in iter_gd_files():
        if not fp.is_file():
            continue
        text = fp.read_text(encoding="utf-8", errors="replace")
        for s, line_no in extract_strings_gd(text):
            if violates(s, allow):
                rel = fp.relative_to(ROOT)
                errors.append(f"{rel}:{line_no}: {s[:120]!r}")

    for fp in iter_tscn_files():
        text = fp.read_text(encoding="utf-8", errors="replace")
        for s, line_no in extract_strings_tscn(text):
            if violates(s, allow):
                rel = fp.relative_to(ROOT)
                errors.append(f"{rel}:{line_no}: {s[:120]!r}")

    if errors:
        print("用户界面文案巡检：发现疑似英文（请汉化或加入白名单 tools/ui_string_allowlist.txt）：", file=sys.stderr)
        for e in errors:
            print(e, file=sys.stderr)
        return 1
    print("ui 文案巡检通过。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
