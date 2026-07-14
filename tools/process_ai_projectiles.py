"""Post-process AI-generated projectile PNGs: remove black bg, resize, copy to game paths."""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow required: pip install Pillow")
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "assets" / "previews" / "weapon_projectiles" / "ai_set_a" / "raw"
OUT = ROOT / "assets" / "previews" / "weapon_projectiles" / "ai_set_a" / "processed"
GAME = ROOT / "assets" / "game_pack" / "vfx" / "projectiles"
CURSOR_ASSETS = Path(r"C:\Users\17221\.cursor\projects\e-Desktop-Ai\assets")
SIZE = 512
BG_THRESHOLD = 28  # pixels with r,g,b all below -> transparent


WEAPONS = [
    "kunai", "quantum_ball", "lightning", "rocket", "boomerang", "drone_ab",
    "molotov", "guardian", "frost_aura", "heal_aura", "stun_mine",
]

# Special: kunai f0 uses the approved sample A
KUNAI_F0_SRC = CURSOR_ASSETS / "kunai_ai_sample_a.png"


def remove_black_bg(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r <= BG_THRESHOLD and g <= BG_THRESHOLD and b <= BG_THRESHOLD:
                px[x, y] = (0, 0, 0, 0)
    return img


def fit_square(img: Image.Image, size: int) -> Image.Image:
    img = img.convert("RGBA")
    bbox = img.getbbox()
    if not bbox:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cropped = img.crop(bbox)
    cw, ch = cropped.size
    scale = min((size * 0.82) / cw, (size * 0.82) / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ox = (size - nw) // 2 + int(size * 0.06)  # bias right for trail space
    oy = (size - nh) // 2
    canvas.paste(resized, (ox, oy), resized)
    return canvas


def process_one(src: Path, dst: Path) -> None:
    img = Image.open(src)
    img = remove_black_bg(img)
    img = fit_square(img, SIZE)
    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, "PNG")
    print(f"  {dst.relative_to(ROOT)}")


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    # Copy kunai f0 from approved sample
    if KUNAI_F0_SRC.exists():
        shutil.copy2(KUNAI_F0_SRC, RAW / "kunai_f0.png")
        print(f"copied kunai f0 from {KUNAI_F0_SRC.name}")

    missing = []
    for kind in WEAPONS:
        for f in range(4):
            name = f"{kind}_f{f}.png"
            src = RAW / name
            if not src.exists():
                # also check cursor assets folder
                alt = CURSOR_ASSETS / name
                if alt.exists():
                    shutil.copy2(alt, src)
                else:
                    missing.append(name)
                    continue
            dst = OUT / kind / f"frame_{f}.png"
            process_one(src, dst)
            game_dst = GAME / kind / f"frame_{f}.png"
            game_dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dst, game_dst)

    if missing:
        print(f"\nMissing {len(missing)} files in raw/:")
        for m in missing:
            print(f"  - {m}")
    else:
        print(f"\nAll {len(WEAPONS)*4} frames processed -> {OUT} and {GAME}")


if __name__ == "__main__":
    main()
