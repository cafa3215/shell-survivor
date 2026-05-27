#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from typing import Dict, Tuple

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "tmp" / "weapon_carrier_concepts"

Palette = Dict[str, Tuple[int, int, int]]

PALETTES: Dict[str, Palette] = {
    "electric": {"deep": (10, 30, 92), "base": (34, 196, 255), "mid": (89, 132, 255), "glow": (173, 242, 255), "spark": (232, 250, 255)},
    "explosive": {"deep": (92, 22, 16), "base": (255, 108, 50), "mid": (255, 62, 47), "glow": (255, 208, 126), "spark": (255, 242, 184)},
    "frost": {"deep": (16, 44, 98), "base": (96, 174, 255), "mid": (124, 224, 255), "glow": (206, 243, 255), "spark": (238, 250, 255)},
    "heal": {"deep": (12, 68, 60), "base": (62, 222, 166), "mid": (38, 170, 132), "glow": (170, 255, 224), "spark": (232, 255, 244)},
}

LABELS = {
    "electric": ("Arc Fork Emitter", "Chain / Shock"),
    "explosive": ("Pressure Rocket Chamber", "Blast / Shockwave"),
    "frost": ("Cryo Field Resonator", "Slow / Freeze"),
    "heal": ("Bio-Regen Halo", "Pulse / Restore"),
}


def bg_card(size: int = 768) -> Image.Image:
    img = Image.new("RGBA", (size, size), (12, 14, 18, 255))
    d = ImageDraw.Draw(img, "RGBA")
    for y in range(size):
        t = y / max(1, size - 1)
        col = (int(12 + t * 10), int(14 + t * 14), int(18 + t * 20), 255)
        d.line((0, y, size, y), fill=col)
    return img


def draw_core(img: Image.Image, p: Palette, key: str) -> None:
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = img.size[0] // 2, img.size[1] // 2 - 40
    # core shell
    d.ellipse((cx - 130, cy - 130, cx + 130, cy + 130), fill=(*p["deep"], 210), outline=(*p["mid"], 180), width=4)
    d.ellipse((cx - 96, cy - 96, cx + 96, cy + 96), fill=(*p["base"], 120))
    d.ellipse((cx - 48, cy - 48, cx + 48, cy + 48), fill=(*p["glow"], 150))
    d.ellipse((cx - 22, cy - 22, cx + 22, cy + 22), fill=(*p["spark"], 240))

    if key == "electric":
        for i in range(6):
            off = -90 + i * 36
            d.line((cx - 120, cy + off, cx + 120, cy + off - 18), fill=(*p["mid"], 95), width=3)
    elif key == "explosive":
        for r in (64, 92, 120):
            d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(*p["glow"], 85), width=5)
    elif key == "frost":
        for i in range(8):
            ang = i * 45
            import math
            x2 = cx + int(math.cos(math.radians(ang)) * 124)
            y2 = cy + int(math.sin(math.radians(ang)) * 124)
            d.line((cx, cy, x2, y2), fill=(*p["mid"], 90), width=3)
    elif key == "heal":
        for r in (58, 86, 114):
            d.arc((cx - r, cy - r, cx + r, cy + r), 20, 340, fill=(*p["glow"], 120), width=6)


def draw_info(img: Image.Image, key: str) -> None:
    d = ImageDraw.Draw(img, "RGBA")
    title, sub = LABELS[key]
    f = ImageFont.load_default()
    d.rounded_rectangle((54, 560, 714, 710), radius=20, fill=(8, 10, 14, 188), outline=(80, 92, 110, 120), width=2)
    d.text((78, 592), title, fill=(228, 234, 242, 255), font=f)
    d.text((78, 626), sub, fill=(168, 186, 206, 255), font=f)
    d.text((78, 662), f"Theme: {key}", fill=(128, 146, 164, 255), font=f)


def render_one(key: str, p: Palette) -> None:
    img = bg_card(768)
    draw_core(img, p, key)
    draw_info(img, key)
    img = img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=135, threshold=2))
    (OUT_DIR / f"carrier_concept_{key}.png").parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT_DIR / f"carrier_concept_{key}.png")


def render_sheet() -> None:
    keys = ["electric", "explosive", "frost", "heal"]
    cards = [Image.open(OUT_DIR / f"carrier_concept_{k}.png").convert("RGBA") for k in keys]
    w, h = cards[0].size
    pad = 26
    sheet = Image.new("RGBA", (w * 2 + pad * 3, h * 2 + pad * 3), (10, 12, 16, 255))
    for i, c in enumerate(cards):
        r, cidx = divmod(i, 2)
        x = pad + cidx * (w + pad)
        y = pad + r * (h + pad)
        sheet.paste(c, (x, y), c)
    sheet.save(OUT_DIR / "carrier_concept_sheet_v1.png")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for k, p in PALETTES.items():
        render_one(k, p)
    render_sheet()
    print(f"Wrote concepts to: {OUT_DIR}")


if __name__ == "__main__":
    main()
