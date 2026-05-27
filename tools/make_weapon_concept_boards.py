#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageEnhance, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tmp" / "weapon_concept_multiview"
OUT = ROOT / "tmp" / "weapon_concept_boards"

WEAPONS = [
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

CN = {
    "kunai": "苦无",
    "quantum_ball": "量子球",
    "lightning": "雷电发射器",
    "rocket": "火箭发射器",
    "molotov": "燃烧瓶",
    "guardian": "守卫者",
    "drone_ab": "AB无人机",
    "boomerang": "回旋镖",
    "frost_aura": "冰霜领域",
    "stun_mine": "眩晕地雷",
    "heal_aura": "治疗光环",
}


def load_img(path: Path, size=(420, 420)) -> Image.Image:
    return Image.open(path).convert("RGB").resize(size, Image.Resampling.LANCZOS)


def pass_line_art(img: Image.Image) -> Image.Image:
    gray = ImageOps.grayscale(img)
    edge = gray.filter(ImageFilter.FIND_EDGES)
    edge = ImageOps.autocontrast(edge, cutoff=8)
    edge = ImageEnhance.Contrast(edge).enhance(1.7)
    inv = ImageOps.invert(edge)
    return Image.merge("RGB", (inv, inv, inv))


def pass_energy_key(img: Image.Image) -> Image.Image:
    sat = ImageEnhance.Color(img).enhance(1.6)
    cont = ImageEnhance.Contrast(sat).enhance(1.35)
    glow = cont.filter(ImageFilter.GaussianBlur(2.2))
    mixed = Image.blend(cont, glow, 0.28)
    return mixed


def pass_material_mood(img: Image.Image) -> Image.Image:
    cool = ImageOps.colorize(ImageOps.grayscale(img), black="#111722", white="#8bb8ff")
    warm = ImageOps.colorize(ImageOps.grayscale(img), black="#1a120e", white="#ffb173")
    return Image.blend(cool, warm, 0.22)


def board_for_weapon(wid: str) -> Path:
    hero = load_img(SRC / f"{wid}_hero.png")
    side = load_img(SRC / f"{wid}_side.png")
    top = load_img(SRC / f"{wid}_top.png")
    line = pass_line_art(hero)
    energy = pass_energy_key(side)
    mood = pass_material_mood(top)

    w, h = 1360, 980
    canvas = Image.new("RGB", (w, h), (14, 16, 24))
    d = ImageDraw.Draw(canvas)
    f = ImageFont.load_default()

    d.rounded_rectangle((28, 24, w - 28, h - 24), radius=20, fill=(10, 12, 18), outline=(78, 92, 116), width=2)
    title = f"{CN.get(wid, wid)} / {wid}"
    d.text((48, 46), title, fill=(230, 238, 248), font=f)
    d.text((48, 72), "Concept Board: Silhouette / Energy / Material", fill=(150, 172, 198), font=f)

    panels = [
        ("Primary Hero", hero, (48, 130)),
        ("Line Art Pass", line, (480, 130)),
        ("Energy Readability", energy, (912, 130)),
        ("Material Mood", mood, (480, 560)),
    ]
    for label, im, (x, y) in panels:
        canvas.paste(im, (x, y))
        d.text((x + 6, y + 392), label, fill=(190, 208, 230), font=f)
        d.rounded_rectangle((x - 2, y - 2, x + 422, y + 422), radius=10, outline=(72, 86, 108), width=2)

    d.text((48, 560), "Design Notes", fill=(210, 224, 242), font=f)
    notes = [
        "- Keep silhouette distinct at icon scale",
        "- Energy color should match weapon identity",
        "- Secondary accents avoid full monochrome look",
        "- Preserve asymmetry for premium concept feel",
    ]
    yy = 588
    for n in notes:
        d.text((48, yy), n, fill=(156, 178, 204), font=f)
        yy += 28

    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"{wid}_concept_board.png"
    canvas.save(out)
    return out


def make_sheet(paths: list[Path]) -> None:
    thumbs = [(p.stem.replace("_concept_board", ""), Image.open(p).convert("RGB").resize((320, 230), Image.Resampling.LANCZOS)) for p in paths]
    cols = 3
    rows = (len(thumbs) + cols - 1) // cols
    pad = 16
    cw, ch = 320, 260
    sheet = Image.new("RGB", (pad + cols * (cw + pad), pad + rows * (ch + pad)), (12, 14, 20))
    d = ImageDraw.Draw(sheet)
    f = ImageFont.load_default()
    for i, (name, im) in enumerate(thumbs):
        r, c = divmod(i, cols)
        x = pad + c * (cw + pad)
        y = pad + r * (ch + pad)
        sheet.paste(im, (x, y))
        d.text((x + 6, y + 236), name, fill=(208, 220, 238), font=f)
    sheet.save(OUT / "weapon_concept_boards_sheet.png")


def main() -> None:
    outs: list[Path] = []
    for wid in WEAPONS:
        if not (SRC / f"{wid}_hero.png").exists():
            continue
        outs.append(board_for_weapon(wid))
    make_sheet(outs)
    print(f"Wrote {len(outs)} concept boards to {OUT}")


if __name__ == "__main__":
    main()
