#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from typing import Dict, Tuple

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "tmp" / "weapon_stylekit"


Palette = Dict[str, Tuple[int, int, int]]


PALETTES: Dict[str, Palette] = {
    "electric_cyanblue": {
        "base": (32, 198, 255),
        "mid": (67, 130, 255),
        "deep": (16, 42, 116),
        "glow": (164, 240, 255),
        "spark": (220, 248, 255),
    },
    "explosive_orangered": {
        "base": (255, 108, 44),
        "mid": (255, 62, 47),
        "deep": (118, 24, 18),
        "glow": (255, 206, 120),
        "spark": (255, 239, 178),
    },
    "frost_coolblue": {
        "base": (92, 174, 255),
        "mid": (120, 222, 255),
        "deep": (24, 46, 102),
        "glow": (204, 241, 255),
        "spark": (234, 248, 255),
    },
    "heal_emerald": {
        "base": (62, 223, 165),
        "mid": (38, 173, 134),
        "deep": (16, 74, 66),
        "glow": (164, 255, 221),
        "spark": (226, 255, 240),
    },
}


def radial_core(size: int, p: Palette) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    c = size // 2
    for i in range(7, 0, -1):
        r = int(size * (0.12 + i * 0.10))
        t = i / 7.0
        col = (
            int(p["deep"][0] * (1 - t) + p["base"][0] * t),
            int(p["deep"][1] * (1 - t) + p["base"][1] * t),
            int(p["deep"][2] * (1 - t) + p["base"][2] * t),
            int(26 + t * 34),
        )
        d.ellipse((c - r, c - r, c + r, c + r), fill=col)
    d.ellipse((c - int(size * 0.16), c - int(size * 0.16), c + int(size * 0.16), c + int(size * 0.16)), fill=(*p["glow"], 170))
    d.ellipse((c - int(size * 0.08), c - int(size * 0.08), c + int(size * 0.08), c + int(size * 0.08)), fill=(*p["spark"], 230))
    return img.filter(ImageFilter.GaussianBlur(radius=size * 0.006))


def stripe_overlay(size: int, p: Palette) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    spacing = max(10, size // 18)
    for i in range(-size, size * 2, spacing):
        d.line((i, 0, i - size, size), fill=(*p["mid"], 56), width=max(2, size // 200))
    for i in range(0, size, spacing * 3):
        d.line((0, i, size, i), fill=(*p["glow"], 22), width=max(1, size // 280))
    return img.filter(ImageFilter.GaussianBlur(radius=size * 0.002))


def ring_icon(size: int, p: Palette) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    c = size // 2
    ro = int(size * 0.42)
    ri = int(size * 0.30)
    d.ellipse((c - ro, c - ro, c + ro, c + ro), outline=(*p["base"], 220), width=max(3, size // 45))
    d.ellipse((c - ri, c - ri, c + ri, c + ri), outline=(*p["glow"], 160), width=max(2, size // 80))
    for a in range(0, 360, 60):
        import math
        x = c + int(math.cos(math.radians(a)) * ro * 0.9)
        y = c + int(math.sin(math.radians(a)) * ro * 0.9)
        d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(*p["spark"], 220))
    return img.filter(ImageFilter.GaussianBlur(radius=size * 0.0015))


def write_palette_txt(path: Path, name: str, p: Palette) -> None:
    lines = [f"{name}"]
    for k, v in p.items():
        lines.append(f"{k}: rgb{v}  hex=#{v[0]:02X}{v[1]:02X}{v[2]:02X}")
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, p in PALETTES.items():
        sub = OUT_DIR / name
        sub.mkdir(parents=True, exist_ok=True)
        core = radial_core(512, p)
        stripes = stripe_overlay(512, p)
        ring = ring_icon(256, p)
        composed = Image.alpha_composite(core, stripes)
        composed.save(sub / "energy_surface.png")
        ring.save(sub / "carrier_ring_icon.png")
        write_palette_txt(sub / "palette.txt", name, p)
    print(f"Wrote stylekit to: {OUT_DIR}")


if __name__ == "__main__":
    main()
