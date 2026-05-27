#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from typing import Tuple

import cv2
import numpy as np
from PIL import Image
from rembg import remove


ROOT = Path(__file__).resolve().parents[1]
IN_IMG = ROOT / "assets" / "game_pack" / "textures" / "player_chibi.png"
OUT_DIR = ROOT / "tmp" / "mech_proxy_model"


def cutout_from_black_bg(bgr: np.ndarray) -> np.ndarray:
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    _, mask = cv2.threshold(gray, 12, 255, cv2.THRESH_BINARY)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8), iterations=1)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8), iterations=2)
    return mask


def cutout_with_rembg(rgb: np.ndarray) -> np.ndarray:
    # 专业抠图：U2Net 前景分离，返回 alpha mask
    png_bytes = cv2.imencode(".png", cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR))[1].tobytes()
    out_bytes = remove(png_bytes)
    arr = np.frombuffer(out_bytes, dtype=np.uint8)
    out = cv2.imdecode(arr, cv2.IMREAD_UNCHANGED)
    if out is None or out.shape[2] < 4:
        raise RuntimeError("rembg output invalid")
    alpha = out[:, :, 3]
    return alpha


def keep_main_component(mask: np.ndarray) -> np.ndarray:
    # 保留最大连通前景，去掉零散干扰部位。
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats((mask > 0).astype(np.uint8), connectivity=8)
    if num_labels <= 1:
        return mask
    areas = stats[1:, cv2.CC_STAT_AREA]
    best = 1 + int(np.argmax(areas))
    kept = np.zeros_like(mask, dtype=np.uint8)
    kept[labels == best] = 255
    kept = cv2.morphologyEx(kept, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8), iterations=1)
    kept = cv2.morphologyEx(kept, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8), iterations=1)
    return kept


def bbox_from_mask(mask: np.ndarray) -> Tuple[int, int, int, int]:
    ys, xs = np.where(mask > 0)
    if xs.size == 0:
        return 0, 0, mask.shape[1], mask.shape[0]
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def split_layers(rgba: np.ndarray) -> dict[str, np.ndarray]:
    h, w = rgba.shape[:2]
    alpha = rgba[:, :, 3].astype(np.float32) / 255.0
    layers: dict[str, np.ndarray] = {}
    yy = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
    xx = np.linspace(-1.0, 1.0, w, dtype=np.float32)[None, :]
    ones_h = np.ones((h, 1), dtype=np.float32)
    ones_w = np.ones((1, w), dtype=np.float32)

    def gauss(y0: float, sigma: float) -> np.ndarray:
        return np.exp(-((yy - y0) ** 2) / (2.0 * sigma * sigma))

    # 纵向主分层权重
    w_head = gauss(0.18, 0.10) * ones_w
    w_shoulder = gauss(0.33, 0.09) * ones_w
    w_chest = gauss(0.48, 0.10) * ones_w
    w_pelvis = gauss(0.63, 0.08) * ones_w
    w_legs = gauss(0.83, 0.14) * ones_w

    # 手臂权重：靠左右边缘更高，并限制在上半身范围。
    side = (np.clip((np.abs(xx) - 0.22) / 0.78, 0.0, 1.0) ** 1.8) * ones_h
    arm_band = np.exp(-((yy - 0.50) ** 2) / (2.0 * 0.16 * 0.16))
    w_arms = side * arm_band * 1.45

    stack = np.stack([w_head, w_shoulder, w_chest, w_pelvis, w_arms, w_legs], axis=0)
    # 关键：改为“逐像素唯一归属”防止半透明叠层造成雾化/重影。
    dominant = np.argmax(stack, axis=0)

    names = ["head", "shoulder", "chest", "pelvis", "arms", "legs"]
    for i, name in enumerate(names):
        m = (dominant == i).astype(np.uint8) * 255
        # 边界轻微平滑，避免硬锯齿，但不做大面积半透明。
        m = cv2.GaussianBlur(m, (0, 0), 0.45)
        m = np.clip(m, 0, 255).astype(np.uint8)
        a = np.clip(alpha * (m.astype(np.float32) / 255.0), 0.0, 1.0)
        out = rgba.copy()
        out[:, :, 3] = np.clip(a * 255.0, 0, 255).astype(np.uint8)
        layers[name] = out
    return layers


def save_expected_preview(rgba: np.ndarray, out_path: Path) -> None:
    # 先生成“预期效果图”：清晰轮廓、无断层、无重影，仅展示目标方向。
    h, w = rgba.shape[:2]
    bgr = cv2.cvtColor(rgba[:, :, :3], cv2.COLOR_RGB2BGR)
    alpha = rgba[:, :, 3].astype(np.float32) / 255.0

    def view(yaw: float) -> np.ndarray:
        xshift = int(abs(yaw) * w * 0.09)
        if yaw < 0:
            src = np.float32([[xshift, 0], [w, 0], [0, h], [w - xshift, h]])
        else:
            src = np.float32([[0, 0], [w - xshift, 0], [xshift, h], [w, h]])
        dst = np.float32([[0, 0], [w, 0], [0, h], [w, h]])
        M = cv2.getPerspectiveTransform(src, dst)
        vbgr = cv2.warpPerspective(bgr, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT)
        va = cv2.warpPerspective((alpha * 255.0).astype(np.uint8), M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT)
        canvas = np.zeros((h, w, 4), dtype=np.uint8)
        canvas[:, :, :3] = vbgr
        canvas[:, :, 3] = va
        return canvas

    left = view(-1.0)
    center = view(0.0)
    right = view(1.0)
    pad = 20
    trip = np.zeros((h + pad * 2, w * 3 + pad * 4, 4), dtype=np.uint8)
    trip[:, :, :3] = (20, 20, 24)
    trip[:, :, 3] = 255
    for idx, img in enumerate([left, center, right]):
        x = pad + idx * (w + pad)
        y = pad
        roi = trip[y:y + h, x:x + w].astype(np.float32)
        fg = img.astype(np.float32)
        a = fg[:, :, 3:4] / 255.0
        roi[:, :, :3] = fg[:, :, :3] * a + roi[:, :, :3] * (1.0 - a)
        roi[:, :, 3] = 255
        trip[y:y + h, x:x + w] = roi.astype(np.uint8)
    Image.fromarray(cv2.cvtColor(trip, cv2.COLOR_BGRA2RGBA)).save(out_path)


def warp_layer(img: np.ndarray, yaw: float) -> np.ndarray:
    h, w = img.shape[:2]
    xshift = int(abs(yaw) * w * 0.12)
    if yaw < 0:
        src = np.float32([[xshift, 0], [w, 0], [0, h], [w - xshift, h]])
    else:
        src = np.float32([[0, 0], [w - xshift, 0], [xshift, h], [w, h]])
    dst = np.float32([[0, 0], [w, 0], [0, h], [w, h]])
    M = cv2.getPerspectiveTransform(src, dst)
    out = cv2.warpPerspective(img, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT)
    return out


def alpha_comp(base: np.ndarray, fg: np.ndarray, dx: int = 0, dy: int = 0) -> np.ndarray:
    out = base.copy()
    h, w = fg.shape[:2]
    bh, bw = out.shape[:2]
    x0 = max(0, dx)
    y0 = max(0, dy)
    x1 = min(bw, dx + w)
    y1 = min(bh, dy + h)
    if x0 >= x1 or y0 >= y1:
        return out
    fx0 = x0 - dx
    fy0 = y0 - dy
    fx1 = fx0 + (x1 - x0)
    fy1 = fy0 + (y1 - y0)
    fg_roi = fg[fy0:fy1, fx0:fx1].astype(np.float32)
    bg_roi = out[y0:y1, x0:x1].astype(np.float32)
    a = fg_roi[:, :, 3:4] / 255.0
    out[y0:y1, x0:x1] = (fg_roi[:, :, :3] * a + bg_roi[:, :, :3] * (1.0 - a)).astype(np.uint8)
    return out


def build_view(layers: dict[str, np.ndarray], yaw: float) -> np.ndarray:
    h, w = next(iter(layers.values())).shape[:2]
    canvas = np.zeros((h, w, 3), dtype=np.uint8)

    warped_legs = warp_layer(layers["legs"], yaw)
    warped_pelvis = warp_layer(layers["pelvis"], yaw * 0.92)
    warped_chest = warp_layer(layers["chest"], yaw * 0.85)
    warped_shoulder = warp_layer(layers["shoulder"], yaw * 0.78)
    warped_arms = warp_layer(layers["arms"], yaw * 1.08)
    warped_head = warp_layer(layers["head"], yaw * 0.62)

    leg_dx = int(yaw * 10)
    pelvis_dx = int(yaw * 6)
    chest_dx = int(yaw * 4)
    shoulder_dx = int(yaw * 3)
    arm_dx = int(yaw * 11)
    head_dx = int(yaw * -2)

    canvas = alpha_comp(canvas, warped_legs, dx=leg_dx, dy=0)
    canvas = alpha_comp(canvas, warped_pelvis, dx=pelvis_dx, dy=int(h * 0.004))
    canvas = alpha_comp(canvas, warped_chest, dx=chest_dx, dy=int(h * 0.012))
    canvas = alpha_comp(canvas, warped_shoulder, dx=shoulder_dx, dy=int(h * 0.016))
    canvas = alpha_comp(canvas, warped_arms, dx=arm_dx, dy=int(h * 0.012))
    canvas = alpha_comp(canvas, warped_head, dx=head_dx, dy=int(-h * 0.005))

    return canvas


def save_triptych(center_rgb: np.ndarray, left_rgb: np.ndarray, right_rgb: np.ndarray, out_path: Path) -> None:
    h, w = center_rgb.shape[:2]
    pad = 24
    trip = np.zeros((h + pad * 2, w * 3 + pad * 4, 3), dtype=np.uint8)
    trip[:] = (16, 18, 24)
    trip[pad:pad + h, pad:pad + w] = left_rgb
    trip[pad:pad + h, pad * 2 + w:pad * 2 + w * 2] = center_rgb
    trip[pad:pad + h, pad * 3 + w * 2:pad * 3 + w * 3] = right_rgb
    Image.fromarray(cv2.cvtColor(trip, cv2.COLOR_BGR2RGB)).save(out_path)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if not IN_IMG.exists():
        raise SystemExit(f"Input image not found: {IN_IMG}")
    pil = Image.open(IN_IMG).convert("RGB")
    rgb = np.array(pil)
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)

    # 优先使用专业 AI 抠图；失败时回退到黑底阈值法。
    try:
        mask = cutout_with_rembg(rgb)
    except Exception:
        mask = cutout_from_black_bg(bgr)
    mask = keep_main_component(mask)

    x0, y0, x1, y1 = bbox_from_mask(mask)
    crop_bgr = bgr[y0:y1, x0:x1]
    crop_mask = mask[y0:y1, x0:x1]
    rgba = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = crop_mask
    save_expected_preview(cv2.cvtColor(rgba, cv2.COLOR_BGRA2RGBA), OUT_DIR / "expected_preview.png")

    layers = split_layers(rgba)
    # 整身层：用于保形渲染（避免关节拼装失真）。
    full_rgba = cv2.cvtColor(rgba, cv2.COLOR_BGRA2RGBA)
    Image.fromarray(full_rgba).save(OUT_DIR / "layer_full.png")
    for name, layer in layers.items():
        Image.fromarray(cv2.cvtColor(layer, cv2.COLOR_BGRA2RGBA)).save(OUT_DIR / f"layer_{name}.png")

    center = build_view(layers, 0.0)
    left = build_view(layers, -1.0)
    right = build_view(layers, 1.0)
    save_triptych(center, left, right, OUT_DIR / "proxy_triptych_preview.png")

    print("Wrote:", OUT_DIR / "proxy_triptych_preview.png")
    print("Wrote:", OUT_DIR / "expected_preview.png")
    print("Wrote layers:", "layer_full.png, " + ", ".join(str((OUT_DIR / f'layer_{k}.png').name) for k in layers.keys()))


if __name__ == "__main__":
    main()
