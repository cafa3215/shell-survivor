#!/usr/bin/env python3
from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "game_pack" / "textures" / "weapon_cards"
CFG_PATH = ROOT / "assets" / "config" / "weapon_carrier_cards.json"

PALETTES: Dict[str, Dict[str, Tuple[int, int, int]]] = {
    "neutral": {"deep": (38, 45, 56), "base": (129, 145, 170), "mid": (178, 192, 214), "glow": (214, 222, 235), "spark": (242, 246, 251)},
    "electric": {"deep": (9, 28, 92), "base": (30, 188, 255), "mid": (84, 124, 255), "glow": (161, 237, 255), "spark": (230, 250, 255)},
    "explosive": {"deep": (88, 23, 18), "base": (255, 108, 54), "mid": (255, 66, 52), "glow": (255, 205, 132), "spark": (255, 241, 186)},
    "frost": {"deep": (18, 44, 100), "base": (95, 176, 255), "mid": (121, 220, 255), "glow": (200, 242, 255), "spark": (236, 249, 255)},
    "heal": {"deep": (12, 68, 58), "base": (61, 219, 160), "mid": (40, 166, 126), "glow": (170, 255, 220), "spark": (230, 255, 243)},
}

WEAPONS: List[Dict[str, str]] = [
    {"id": "kunai", "name": "苦无", "theme": "neutral", "carrier": "磁轨裂刃仓", "fire_mode": "直线连射 / 穿透", "hit_fx": "细刃穿刺闪", "desc": "高频直射，重在稳定压血。", "rhythm": "高频短间隔", "projectile_style": "窄体高速针形弹道", "signature": "needle"},
    {"id": "quantum_ball", "name": "量子球", "theme": "electric", "carrier": "相位球笼", "fire_mode": "弹跳散射 / 反弹", "hit_fx": "量子回弹晕光", "desc": "弹跳覆盖广，适合清杂与控场。", "rhythm": "中频持续", "projectile_style": "球体反弹轨迹", "signature": "orb"},
    {"id": "lightning", "name": "雷电发射器", "theme": "electric", "carrier": "弧叉发射器", "fire_mode": "链式跳电", "hit_fx": "分叉电弧爆", "desc": "连锁打击多目标，爆发清线。", "rhythm": "脉冲连锁", "projectile_style": "瞬发锁链电弧", "signature": "fork"},
    {"id": "rocket", "name": "火箭发射器", "theme": "explosive", "carrier": "压能火箭膛", "fire_mode": "蓄压爆射", "hit_fx": "同心冲击环", "desc": "单发重火力，区域清场核心。", "rhythm": "低频重击", "projectile_style": "粗体拖尾爆弹", "signature": "rocket"},
    {"id": "molotov", "name": "燃烧瓶", "theme": "explosive", "carrier": "热焰燃剂囊", "fire_mode": "抛物投掷", "hit_fx": "落地灼烧印", "desc": "持续灼烧，压制路径与追兵。", "rhythm": "中低频抛投", "projectile_style": "抛物线燃烧瓶", "signature": "flask"},
    {"id": "guardian", "name": "守卫者", "theme": "neutral", "carrier": "轨卫枢纽", "fire_mode": "环绕切割", "hit_fx": "击退脉冲圈", "desc": "近身防线，削弱贴脸风险。", "rhythm": "持续环绕", "projectile_style": "环体周向切割", "signature": "ring"},
    {"id": "drone_ab", "name": "AB无人机", "theme": "electric", "carrier": "双联中继核", "fire_mode": "双机交替射束", "hit_fx": "双点同步火花", "desc": "持续压制，补足机动输出。", "rhythm": "交替点射", "projectile_style": "双源并行射线", "signature": "twin"},
    {"id": "boomerang", "name": "回旋镖", "theme": "frost", "carrier": "返弧导轨架", "fire_mode": "往返曲线切割", "hit_fx": "回返斩波纹", "desc": "双程命中，走位收益高。", "rhythm": "双程往返", "projectile_style": "弧形回返弹道", "signature": "arc"},
    {"id": "frost_aura", "name": "冰霜领域", "theme": "frost", "carrier": "寒域共振器", "fire_mode": "范围持续场", "hit_fx": "冻结裂纹 + 寒雾", "desc": "减速控场，稳住高压波次。", "rhythm": "持续场频率", "projectile_style": "环形扩散场", "signature": "snow"},
    {"id": "stun_mine", "name": "眩晕地雷", "theme": "explosive", "carrier": "脉冲陷阱核", "fire_mode": "布设触发", "hit_fx": "径向眩晕波", "desc": "卡点反打，制造安全窗口。", "rhythm": "触发爆发", "projectile_style": "定点触发脉冲", "signature": "mine"},
    {"id": "heal_aura", "name": "治疗光环", "theme": "heal", "carrier": "生机回路环", "fire_mode": "周期脉冲治疗", "hit_fx": "净化升腾波", "desc": "续航核心，容错率提升。", "rhythm": "周期回响", "projectile_style": "柔和环波扩散", "signature": "leaf"},
]


def _bg(size: int = 512) -> Image.Image:
    img = Image.new("RGBA", (size, size), (12, 14, 18, 255))
    d = ImageDraw.Draw(img, "RGBA")
    for y in range(size):
        t = y / float(size - 1)
        c = (int(11 + t * 16), int(14 + t * 19), int(18 + t * 28), 255)
        d.line((0, y, size, y), fill=c)
    return img


def _ring(draw: ImageDraw.ImageDraw, cx: int, cy: int, radius: int, col: Tuple[int, int, int], alpha: int, width: int) -> None:
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=(*col, alpha), width=width)


def _draw_carrier(img: Image.Image, theme: str, idx: int, signature: str) -> None:
    p = PALETTES[theme]
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = 256, 196
    d.rounded_rectangle((66, 44, 446, 348), radius=24, fill=(8, 10, 14, 130), outline=(84, 96, 118, 110), width=2)
    d.ellipse((cx - 106, cy - 106, cx + 106, cy + 106), fill=(*p["deep"], 212), outline=(*p["mid"], 180), width=4)
    d.ellipse((cx - 74, cy - 74, cx + 74, cy + 74), fill=(*p["base"], 135))
    d.ellipse((cx - 36, cy - 36, cx + 36, cy + 36), fill=(*p["glow"], 166))
    d.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), fill=(*p["spark"], 235))
    _ring(d, cx, cy, 122, p["mid"], 96, 3)
    _ring(d, cx, cy, 142, p["glow"], 74, 2)

    phase = (idx % 4) * 0.45
    for i in range(7):
        a = phase + i * (2 * math.pi / 7.0)
        x = cx + int(math.cos(a) * 130)
        y = cy + int(math.sin(a) * 130)
        r = 4 + (i % 3)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(*p["spark"], 155))
    # Per-weapon signature marks (inspired by genre readability language).
    if signature == "needle":
        d.polygon([(256, 112), (266, 196), (256, 280), (246, 196)], fill=(*p["spark"], 120))
    elif signature == "orb":
        d.ellipse((232, 172, 280, 220), outline=(*p["spark"], 180), width=3)
    elif signature == "fork":
        d.line((228, 150, 256, 196), fill=(*p["spark"], 170), width=3)
        d.line((256, 196, 284, 150), fill=(*p["spark"], 170), width=3)
    elif signature == "rocket":
        d.rectangle((244, 156, 268, 246), fill=(*p["spark"], 108))
    elif signature == "flask":
        d.rounded_rectangle((238, 154, 274, 244), radius=10, fill=(*p["spark"], 108))
    elif signature == "ring":
        _ring(d, 256, 196, 60, p["spark"], 200, 4)
    elif signature == "twin":
        d.ellipse((226, 178, 248, 200), fill=(*p["spark"], 160))
        d.ellipse((264, 192, 286, 214), fill=(*p["spark"], 160))
    elif signature == "arc":
        d.arc((188, 132, 324, 268), 40, 320, fill=(*p["spark"], 190), width=4)
    elif signature == "snow":
        d.line((256, 132, 256, 260), fill=(*p["spark"], 180), width=3)
        d.line((208, 196, 304, 196), fill=(*p["spark"], 180), width=3)
    elif signature == "mine":
        d.regular_polygon((256, 196, 26), 6, fill=(*p["spark"], 130))
    elif signature == "leaf":
        d.polygon([(256, 150), (286, 196), (256, 242), (226, 196)], fill=(*p["spark"], 130))


def _draw_label(img: Image.Image, weapon: Dict[str, str]) -> None:
    d = ImageDraw.Draw(img, "RGBA")
    f = ImageFont.load_default()
    d.rounded_rectangle((40, 356, 472, 488), radius=16, fill=(8, 10, 14, 188), outline=(86, 98, 122, 128), width=2)
    d.text((58, 374), weapon["name"] + " · " + weapon["carrier"], fill=(230, 236, 244, 255), font=f)
    d.text((58, 404), "发射: " + weapon["fire_mode"], fill=(176, 194, 214, 255), font=f)
    d.text((58, 430), "命中: " + weapon["hit_fx"], fill=(160, 182, 206, 255), font=f)
    d.text((58, 456), f"{weapon['rhythm']} · {weapon['projectile_style']}", fill=(132, 152, 174, 255), font=f)


def _render_card(weapon: Dict[str, str], idx: int) -> str:
    img = _bg(512)
    _draw_carrier(img, weapon["theme"], idx, weapon["signature"])
    _draw_label(img, weapon)
    img = img.filter(ImageFilter.UnsharpMask(radius=1.4, percent=130, threshold=2))
    rel = f"res://assets/game_pack/textures/weapon_cards/{weapon['id']}_card.png"
    out = OUT_DIR / f"{weapon['id']}_card.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    return rel


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    payload = {"weapons": {}}
    for i, w in enumerate(WEAPONS):
        tex = _render_card(w, i)
        payload["weapons"][w["id"]] = {
            "name": w["name"],
            "carrier_name": w["carrier"],
            "theme": w["theme"],
            "fire_mode": w["fire_mode"],
            "hit_fx": w["hit_fx"],
            "desc": w["desc"],
            "rhythm": w["rhythm"],
            "projectile_style": w["projectile_style"],
            "texture": tex,
        }
    CFG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CFG_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote cards to {OUT_DIR}")
    print(f"Wrote config to {CFG_PATH}")


if __name__ == "__main__":
    main()
