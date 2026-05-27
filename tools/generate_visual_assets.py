#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成高分辨率 PNG：融合弹壳 Q 版 + 《重生细胞》式暗色城堡/青绿感染氛围。
依赖: pip install pillow
运行: python tools/generate_visual_assets.py
输出: assets/textures/generated/*.png
"""
from __future__ import annotations

import math
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
except ImportError as e:
    raise SystemExit("请先安装 Pillow: pip install pillow") from e

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "textures" / "generated"


def add_outline_rgba(
    im: Image.Image,
    rgb: tuple[int, int, int] = (22, 24, 34),
    thickness: int = 4,
) -> Image.Image:
    """外扩 alpha 做描边，再叠回原图（偏手游/美漫可读轮廓）。"""
    a = im.split()[-1]
    dil = a
    for _ in range(thickness):
        dil = dil.filter(ImageFilter.MaxFilter(3))
    out_a = ImageChops.subtract(dil, a)
    ol = Image.merge(
        "RGBA",
        (
            Image.new("L", im.size, rgb[0]),
            Image.new("L", im.size, rgb[1]),
            Image.new("L", im.size, rgb[2]),
            out_a,
        ),
    )
    return Image.alpha_composite(ol, im)


def _hash2(ix: int, iy: int) -> float:
    """0..1 确定性噪声"""
    s = (ix * 374761393 + iy * 668265263) & 0xFFFFFFFF
    s = (s ^ (s >> 13)) * 1274126177 & 0xFFFFFFFF
    return (s ^ (s >> 16)) / 4294967296.0


def seamless_noise(x: int, y: int, w: int, h: int, scale: float) -> float:
    """环面采样平滑值噪声"""
    fx = (x / scale) % w
    fy = (y / scale) % h
    x0, y0 = int(fx), int(fy)
    x1, y0n = (x0 + 1) % w, (y0 + 1) % h
    tx, ty = fx - x0, fy - y0
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    n00 = _hash2(x0, y0)
    n10 = _hash2(x1, y0)
    n01 = _hash2(x0, y0n)
    n11 = _hash2(x1, y0n)
    a = n00 * (1 - tx) + n10 * tx
    b = n01 * (1 - tx) + n11 * tx
    return a * (1 - ty) + b * ty


def draw_ground_tile(size: int = 512) -> Image.Image:
    """可平铺城堡石砖地：冷灰蓝 + 苔藓绿缝 + 血迹褐斑（重生细胞氛围）"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            n = seamless_noise(x, y, size, size, 52.0)
            n2 = seamless_noise(x + 23, y + 11, size, size, 19.0)
            base_r = 0.1 + n * 0.07 + n2 * 0.035
            base_g = 0.11 + n * 0.08 + n2 * 0.04
            base_b = 0.14 + n * 0.1 + n2 * 0.05
            spot = 0.025 * math.sin(x * 0.09) * math.sin(y * 0.08)
            r = int(min(255, max(0, (base_r + spot) * 255)))
            g = int(min(255, max(0, (base_g + spot) * 255)))
            b = int(min(255, max(0, (base_b + spot) * 255)))
            px[x, y] = (r, g, b, 255)
    dr = ImageDraw.Draw(img)
    # 砖缝线（暗）
    step = 64
    for x in range(0, size, step):
        dr.line((x, 0, x, size - 1), fill=(18, 22, 28, 140), width=2)
    for y in range(0, size, step):
        dr.line((0, y, size - 1, y), fill=(22, 26, 32, 120), width=2)
    # 苔藓渗线
    for i in range(160):
        sx = int(seamless_noise(i * 3, i * 7, size, size, 1.0) * (size - 1))
        sy = int(seamless_noise(i * 5, i * 2, size, size, 1.0) * (size - 1))
        ang = seamless_noise(i, i, 128, 128, 20.0) * math.pi * 2
        ex = int(sx + math.cos(ang) * (4 + i % 6))
        ey = int(sy + math.sin(ang) * (4 + i % 6))
        dr.line((sx, sy, ex, ey), fill=(28, 88, 62, 95), width=1)
    # 褐色旧血迹斑点
    for i in range(22):
        cx = int(seamless_noise(i * 47, i, size, size, 1.0) * (size - 24)) + 12
        cy = int(seamless_noise(i, i * 47, size, size, 1.0) * (size - 24)) + 12
        rr = 3 + (i % 5)
        dr.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(72, 36, 38, 70))
    # 金屑高光（弓箭手/弹壳式闪点）
    dr2 = ImageDraw.Draw(img)
    for i in range(90):
        fx = int(seamless_noise(i * 13, i * 17, size, size, 1.0) * (size - 4)) + 2
        fy = int(seamless_noise(i * 19, i * 11, size, size, 1.0) * (size - 4)) + 2
        dr2.ellipse((fx, fy, fx + 2, fy + 2), fill=(255, 220, 120, 55))
    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    return img


def _draw_one_enemy_cell(dr, cx: float, cy: float, variant: int, mag: float = 1.0) -> None:
    """单格灰阶剪影（坐标按 mag 放大，便于先高清绘制再缩小）。"""
    m = lambda v: v * mag
    outline = (12, 14, 22, 255)
    hi = (252, 250, 255, 255)
    mid = (205, 202, 218, 255)
    lo = (155, 148, 168, 255)
    sh = (120, 112, 135, 255)
    if variant == 0:  # 瘦长跑尸 + 露骨 + 涎水
        dr.ellipse((cx - m(10), cy - m(22), cx + m(10), cy - m(6)), fill=mid, outline=outline, width=max(2, int(m(2))))
        dr.rounded_rectangle((cx - m(6), cy - m(4), cx + m(6), cy + m(18)), radius=int(m(3)), fill=lo, outline=outline, width=max(2, int(m(2))))
        dr.line((cx - m(3), cy - m(2), cx + m(3), cy + m(8)), fill=sh, width=max(1, int(m(2))))
        dr.ellipse((cx - m(8), cy - m(20), cx - m(2), cy - m(14)), fill=hi)
        dr.ellipse((cx + m(2), cy - m(20), cx + m(8), cy - m(14)), fill=hi)
        dr.ellipse((cx - m(5), cy - m(17), cx - m(3), cy - m(15)), fill=(32, 36, 44, 255))
        dr.ellipse((cx + m(3), cy - m(17), cx + m(5), cy - m(15)), fill=(32, 36, 44, 255))
        dr.ellipse((cx - m(2), cy - m(8), cx + m(2), cy - m(4)), fill=(160, 48, 52, 220))
        dr.line((cx, cy - m(4), cx, cy + m(2)), fill=(200, 220, 200, 180), width=max(1, int(m(1.2))))
    elif variant == 1:  # 宽坦克尸 + 裂纹
        dr.ellipse((cx - m(18), cy - m(16), cx + m(18), cy + m(14)), fill=mid, outline=outline, width=max(2, int(m(3))))
        dr.ellipse((cx - m(12), cy - m(22), cx + m(12), cy - m(8)), fill=hi, outline=outline, width=max(2, int(m(2))))
        dr.line((cx - m(8), cy - m(18), cx + m(4), cy - m(10)), fill=(60, 58, 70, 255), width=max(1, int(m(1.5))))
        dr.ellipse((cx - m(6), cy - m(18), cx - m(1), cy - m(12)), fill=(28, 28, 36, 255))
        dr.ellipse((cx + m(1), cy - m(18), cx + m(6), cy - m(12)), fill=(28, 28, 36, 255))
        dr.ellipse((cx - m(4), cy - m(15), cx - m(2), cy - m(13)), fill=(240, 240, 248, 255))
        dr.ellipse((cx + m(2), cy - m(15), cx + m(4), cy - m(13)), fill=(240, 240, 248, 255))
    elif variant == 2:  # 喷吐者：鼓胀 + 毒囊高光
        dr.ellipse((cx - m(14), cy - m(18), cx + m(14), cy + m(10)), fill=mid, outline=outline, width=max(2, int(m(2))))
        dr.ellipse((cx - m(4), cy - m(14), cx + m(4), cy - m(6)), fill=(72, 220, 140, 235))
        dr.ellipse((cx - m(3), cy - m(12), cx + m(3), cy - m(8)), fill=(120, 255, 190, 120))
        dr.ellipse((cx - m(10), cy + m(2), cx + m(10), cy + m(12)), fill=lo, outline=outline, width=max(2, int(m(2))))
        dr.arc((cx - m(8), cy - m(6), cx + m(8), cy + m(4)), start=200, end=340, fill=(40, 44, 52, 255), width=max(2, int(m(2))))
    else:  # 尖角精英 + 肩甲
        dr.ellipse((cx - m(12), cy - m(20), cx + m(12), cy - m(4)), fill=mid, outline=outline, width=max(2, int(m(2))))
        dr.polygon([(cx, cy - m(28)), (cx - m(6), cy - m(18)), (cx + m(6), cy - m(18))], fill=lo, outline=outline)
        dr.rounded_rectangle((cx - m(10), cy - m(2), cx + m(10), cy + m(16)), radius=int(m(4)), fill=hi, outline=outline, width=max(2, int(m(2))))
        dr.polygon([(cx - m(22), cy - m(8)), (cx - m(14), cy - m(4)), (cx - m(16), cy + m(4))], fill=sh, outline=outline)
        dr.polygon([(cx + m(22), cy - m(8)), (cx + m(14), cy - m(4)), (cx + m(16), cy + m(4))], fill=sh, outline=outline)
        dr.ellipse((cx - m(7), cy - m(16), cx - m(2), cy - m(10)), fill=(22, 24, 32, 255))
        dr.ellipse((cx + m(2), cy - m(16), cx + m(7), cy - m(10)), fill=(22, 24, 32, 255))


def draw_enemy_atlas() -> Image.Image:
    """内部 512×128 高清绘制 → 缩至 256×64（引擎 UV 仍为 4×0.25 列）。"""
    w, h = 512, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    for col in range(4):
        cx = float(col * 128 + 64)
        cy = 64.0
        _draw_one_enemy_cell(dr, cx, cy, col, mag=2.0)
    img = img.resize((256, 64), Image.Resampling.LANCZOS)
    return add_outline_rgba(img, (16, 18, 26), thickness=3)


def draw_enemy_base(size: int = 128) -> Image.Image:
    """
    灰度 Q 版丧尸基底：先 128 绘制 → 2× 最近邻放大 → 描边 → 压回 64（更清晰轮廓）。
    """
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    cx, cy = size / 2, size / 2 + 4
    outline = (16, 18, 24, 255)
    body_hi = (242, 240, 248, 255)
    body_mid = (200, 196, 212, 255)
    body_lo = (148, 142, 158, 255)
    bbox = (cx - 22, cy - 18, cx + 22, cy + 20)
    dr.ellipse(bbox, fill=body_mid, outline=outline, width=3)
    dr.ellipse((cx - 18, cy - 14, cx + 18, cy + 12), fill=body_hi)
    dr.ellipse((cx - 18, cy - 36, cx + 18, cy - 6), fill=body_mid, outline=outline, width=3)
    dr.ellipse((cx - 14, cy - 32, cx + 14, cy - 10), fill=body_hi)
    dr.ellipse((cx - 16, cy - 40, cx - 8, cy - 32), fill=body_lo, outline=outline, width=2)
    dr.ellipse((cx + 8, cy - 40, cx + 16, cy - 32), fill=body_lo, outline=outline, width=2)
    dr.ellipse((cx - 12, cy - 26, cx - 2, cy - 16), fill=(255, 255, 255, 255), outline=outline, width=2)
    dr.ellipse((cx + 2, cy - 26, cx + 12, cy - 16), fill=(255, 255, 255, 255), outline=outline, width=2)
    dr.ellipse((cx - 9, cy - 23, cx - 5, cy - 19), fill=(26, 28, 36, 255))
    dr.ellipse((cx + 5, cy - 23, cx + 9, cy - 19), fill=(26, 28, 36, 255))
    dr.arc((cx - 8, cy - 14, cx + 8, cy - 4), start=0, end=180, fill=outline, width=2)
    dr.ellipse((cx - 14, cy + 18, cx + 14, cy + 28), fill=(36, 38, 48, 210))
    dr.line((cx - 10, cy + 2, cx + 12, cy - 4), fill=(88, 92, 108, 255), width=2)
    img = img.resize((256, 256), Image.Resampling.NEAREST)
    img = add_outline_rgba(img, (18, 20, 28), thickness=5)
    img = img.resize((64, 64), Image.Resampling.LANCZOS)
    return img


def _run_leg_offset(phase: int, side: int) -> tuple[float, float]:
    """跑步相位 0..2：左右腿 (dx, dy) 逻辑单位，与 sc() 相乘；待机 phase=-1 不偏移。"""
    if phase < 0:
        return (0.0, 0.0)
    # 左(-1) / 右(1)：迈步、腾空、换脚
    tbl = (
        ((-2.2, -3.8), (2.4, 5.2)),
        ((0.4, 1.2), (0.4, 1.0)),
        ((2.4, 5.2), (-2.2, -3.8)),
    )
    return tbl[phase % 3][0 if side < 0 else 1]


def draw_player_chibi(size: int = 384, run_phase: int = -1, pose: str | None = None) -> Image.Image:
    """Q 版主角：run_phase=-1 待机/步态；0..2 跑步；pose='attack'|'hit' 为战斗单帧（与跑步互斥）。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s = size / 128.0
    cx = size / 2
    cy_base = size / 2 + int(6 * s)

    def sc(v: float) -> int:
        return int(round(v * s))

    bob = 0
    if pose == "hit":
        bob = sc(-5.5)
        run_phase = -1
    elif pose == "attack":
        bob = sc(-2.0)
        run_phase = -1
    elif run_phase >= 0:
        bob = sc([1.4, -3.2, 1.4][run_phase % 3])
    cy = cy_base + bob

    # 地面投影（最底层）
    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shdr = ImageDraw.Draw(sh)
    shdr.ellipse((cx - sc(42), cy_base + sc(24), cx + sc(42), cy_base + sc(56)), fill=(0, 0, 0, 100))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=max(3.0, size / 96.0)))
    img = Image.alpha_composite(img, sh)

    outline = (12, 14, 22, 255)
    skin = (232, 210, 198, 255)
    skin_hi = (248, 228, 215, 255)
    cap = (48, 52, 68, 255)
    cap_hi = (78, 84, 102, 255)
    hood = (38, 92, 108, 255)
    hood_sh = (22, 58, 72, 255)
    pants = (36, 44, 62, 255)
    pants_hi = (62, 78, 98, 255)
    shoe = (28, 30, 38, 255)
    belt = (92, 28, 32, 255)
    bow = (55, 48, 42, 255)
    eye_glow = (70, 200, 150, 220)

    # 脚下光晕（细胞式绿雾）。注意：alpha_composite 会返回新图，必须在之后重建 Draw，
    # 否则后续笔画仍写在合成前的旧缓冲区上，导出的 PNG 只有光晕、角色会“消失”。
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdr = ImageDraw.Draw(glow)
    gdr.ellipse((cx - sc(28), cy_base + sc(14), cx + sc(28), cy_base + sc(40)), fill=(28, 110, 88, 28))
    img = Image.alpha_composite(img, glow)
    dr = ImageDraw.Draw(img)

    # 腿（跑步时交替前后迈步）
    for side in (-1, 1):
        ox, oy = _run_leg_offset(run_phase, side)
        lx = cx + side * sc(7.5) + sc(ox)
        y0 = cy + sc(14) + sc(oy)
        y1 = cy + sc(38) + sc(oy)
        dr.rounded_rectangle((lx - sc(5.5), y0, lx + sc(5.5), y1), radius=sc(3), outline=outline, width=sc(2), fill=pants)
        dr.rounded_rectangle((lx - sc(3), y0 + sc(2), lx + sc(1), y0 + sc(16)), radius=sc(1), fill=pants_hi)
        dr.rounded_rectangle((lx - sc(5), y0 + sc(20), lx + sc(5), y0 + sc(25)), radius=sc(2), outline=outline, width=sc(2), fill=shoe)

    # 弹壳式亮黄描边（外衣外轮廓）
    dr.rounded_rectangle((cx - sc(21), cy - sc(6), cx + sc(21), cy + sc(22)), radius=sc(8), outline=(255, 210, 48, 255), width=sc(2))
    # 身体
    dr.rounded_rectangle((cx - sc(19), cy - sc(4), cx + sc(19), cy + sc(20)), radius=sc(7), outline=outline, width=sc(3), fill=hood)
    dr.rounded_rectangle((cx - sc(16), cy + sc(2), cx + sc(16), cy + sc(14)), radius=sc(4), fill=hood_sh)
    dr.rounded_rectangle((cx - sc(16), cy + sc(12), cx + sc(16), cy + sc(17)), radius=sc(2), fill=belt)

    # 手臂（攻击帧：右臂前伸、左臂后摆）
    for side in (-1, 1):
        ax = cx + side * sc(21)
        if pose == "attack" and side > 0:
            dr.rounded_rectangle((ax - sc(4), cy - sc(2), ax + sc(16), cy + sc(14)), radius=sc(3), outline=outline, width=sc(2), fill=hood)
            dr.ellipse((ax + sc(10), cy + sc(10), ax + sc(18), cy + sc(16)), outline=outline, width=sc(2), fill=skin)
        elif pose == "attack" and side < 0:
            dr.rounded_rectangle((ax - sc(12), cy + sc(2), ax + sc(4), cy + sc(15)), radius=sc(3), outline=outline, width=sc(2), fill=hood)
            dr.ellipse((ax - sc(10), cy + sc(12), ax - sc(2), cy + sc(17)), outline=outline, width=sc(2), fill=skin)
        else:
            dr.rounded_rectangle((ax - sc(5), cy, ax + sc(5), cy + sc(16)), radius=sc(3), outline=outline, width=sc(2), fill=hood)
            dr.ellipse((ax - sc(4), cy + sc(12), ax + sc(4), cy + sc(18)), outline=outline, width=sc(2), fill=skin)

    # 弓
    dr.ellipse((cx - sc(10), cy - sc(8), cx - sc(4), cy - sc(2)), fill=bow, outline=outline, width=sc(1))
    dr.rounded_rectangle((cx - sc(3), cy - sc(10), cx + sc(3), cy + sc(4)), radius=sc(2), fill=bow, outline=outline, width=sc(1))
    if pose == "attack":
        dr.ellipse((cx + sc(12), cy - sc(6), cx + sc(22), cy + sc(6)), fill=(255, 230, 140, 200), outline=outline, width=sc(1))
        dr.line(
            (cx + sc(24), cy, cx + sc(38), cy - sc(2)),
            fill=(255, 250, 200),
            width=max(2, sc(2)),
        )

    # 头
    dr.ellipse((cx - sc(16), cy - sc(38), cx + sc(16), cy - sc(8)), outline=outline, width=sc(3), fill=skin)
    dr.ellipse((cx - sc(13), cy - sc(35), cx + sc(7), cy - sc(18)), fill=skin_hi)
    # 弓箭手式脸颊高光
    dr.ellipse((cx - sc(11), cy - sc(24), cx - sc(8), cy - sc(20)), fill=(255, 245, 240, 200))
    dr.ellipse((cx + sc(8), cy - sc(24), cx + sc(11), cy - sc(20)), fill=(255, 245, 240, 200))
    # 帽檐 + 帽顶
    dr.ellipse((cx - sc(20), cy - sc(48), cx + sc(20), cy - sc(28)), outline=outline, width=sc(2), fill=cap)
    dr.ellipse((cx - sc(14), cy - sc(46), cx - sc(2), cy - sc(36)), fill=cap_hi)
    dr.ellipse((cx - sc(14), cy - sc(34), cx + sc(14), cy - sc(18)), fill=cap)

    # 五官
    if pose == "hit":
        dr.line((cx - sc(6), cy - sc(27), cx - sc(2), cy - sc(23)), fill=outline, width=sc(2))
        dr.line((cx - sc(6), cy - sc(23), cx - sc(2), cy - sc(27)), fill=outline, width=sc(2))
        dr.line((cx + sc(2), cy - sc(27), cx + sc(6), cy - sc(23)), fill=outline, width=sc(2))
        dr.line((cx + sc(2), cy - sc(23), cx + sc(6), cy - sc(27)), fill=outline, width=sc(2))
        dr.arc((cx - sc(5), cy - sc(17), cx + sc(5), cy - sc(10)), start=0, end=180, fill=(92, 42, 48, 255), width=sc(2))
    else:
        dr.ellipse((cx - sc(6), cy - sc(28), cx - sc(1), cy - sc(22)), fill=(20, 36, 28, 255), outline=outline, width=sc(1))
        dr.ellipse((cx + sc(1), cy - sc(28), cx + sc(6), cy - sc(22)), fill=(20, 36, 28, 255), outline=outline, width=sc(1))
        dr.ellipse((cx - sc(4.5), cy - sc(26), cx - sc(2.5), cy - sc(23)), fill=(eye_glow[0], eye_glow[1], eye_glow[2], 255))
        dr.ellipse((cx + sc(2.5), cy - sc(26), cx + sc(4.5), cy - sc(23)), fill=(eye_glow[0], eye_glow[1], eye_glow[2], 255))
        dr.ellipse((cx - sc(4), cy - sc(25.5), cx - sc(3), cy - sc(23.5)), fill=(12, 22, 18, 255))
        dr.ellipse((cx + sc(3), cy - sc(25.5), cx + sc(4), cy - sc(23.5)), fill=(12, 22, 18, 255))
        dr.arc((cx - sc(5), cy - sc(18), cx + sc(5), cy - sc(12)), start=0, end=180, fill=outline, width=sc(2))
    # 小提灯（暖色点光）
    dr.ellipse((cx + sc(24), cy + sc(4), cx + sc(32), cy + sc(12)), fill=(255, 175, 72, 130), outline=outline, width=sc(1))
    dr.ellipse((cx + sc(26), cy + sc(6), cx + sc(30), cy + sc(10)), fill=(255, 240, 200, 255))

    img = img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=125, threshold=2))
    img = add_outline_rgba(img, (18, 20, 30), thickness=max(3, int(size / 96)))
    return img


def draw_player_run_strip(size: int = 384) -> Image.Image:
    """横向三帧跑步条带，供 Godot Sprite2D.region_rect 切帧。"""
    frames = [draw_player_chibi(size, run_phase=i, pose=None) for i in range(3)]
    w, h = size * 3, size
    strip = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.paste(fr, (i * size, 0))
    return strip


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    paths = {
        "ground_tile.png": draw_ground_tile(512),
        "enemy_base.png": draw_enemy_base(128),
        "enemy_atlas.png": draw_enemy_atlas(),
        "player_chibi.png": draw_player_chibi(384),
        "player_run_strip.png": draw_player_run_strip(384),
        "player_attack.png": draw_player_chibi(384, run_phase=-1, pose="attack"),
        "player_hit.png": draw_player_chibi(384, run_phase=-1, pose="hit"),
    }
    for name, im in paths.items():
        fp = OUT / name
        im.save(fp, "PNG", optimize=True)
        print("Wrote", fp.relative_to(ROOT), im.size)
    print("完成。在 Godot 中打开项目以生成 .import；或直接用运行时 load_from_file。")


if __name__ == "__main__":
    main()
