#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "weapon_model_previews"
OUT = SRC / "weapon_models_sheet_v1.png"

ORDER = [
    "kunai",
    "quantum_ball",
    "lightning",
    "rocket",
    "molotov",
    "guardian",
    "drone_ab",
    "boomerang",
    "frost_aura",
    "stun_mine",
    "heal_aura",
]


def main() -> None:
    cards = []
    for k in ORDER:
        p = SRC / f"{k}.png"
        if p.exists():
            cards.append((k, Image.open(p).convert("RGB").resize((360, 360))))
    cols = 4
    rows = (len(cards) + cols - 1) // cols
    pad = 24
    cell_w, cell_h = 360, 400
    canvas = Image.new("RGB", (pad + cols * (cell_w + pad), pad + rows * (cell_h + pad)), (14, 16, 22))
    d = ImageDraw.Draw(canvas)
    f = ImageFont.load_default()
    for i, (name, im) in enumerate(cards):
        r, c = divmod(i, cols)
        x = pad + c * (cell_w + pad)
        y = pad + r * (cell_h + pad)
        canvas.paste(im, (x, y))
        d.text((x + 8, y + 366), name, fill=(210, 220, 235), font=f)
    canvas.save(OUT)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
