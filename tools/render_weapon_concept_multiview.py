#!/usr/bin/env python3
from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
REG_PATH = ROOT / "assets" / "config" / "weapon_model_registry.json"
OUT_DIR = ROOT / "tmp" / "weapon_concept_multiview"

VIEWS = {
    "hero": {"cam_loc": (0.0, -2.2, 1.55), "cam_rot": (72, 0, 0), "lens": 68},
    "side": {"cam_loc": (1.8, -1.6, 1.25), "cam_rot": (70, 0, 42), "lens": 72},
    "top": {"cam_loc": (0.0, -0.05, 2.9), "cam_rot": (89, 0, 0), "lens": 62},
}


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def setup_scene() -> None:
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE"
    s.render.resolution_x = 1280
    s.render.resolution_y = 1280
    s.render.image_settings.file_format = "PNG"
    s.render.film_transparent = False
    if hasattr(s, "eevee") and hasattr(s.eevee, "use_bloom"):
        s.eevee.use_bloom = True
        if hasattr(s.eevee, "bloom_intensity"):
            s.eevee.bloom_intensity = 0.09

    world = bpy.data.worlds.new("ConceptWorld")
    s.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.025, 0.03, 0.045, 1.0)
    bg.inputs[1].default_value = 1.0

    bpy.ops.object.light_add(type="AREA", location=(0.0, -2.5, 2.5))
    key = bpy.context.active_object
    key.data.energy = 1550
    key.data.color = (1.0, 0.95, 0.9)
    key.scale = (3.4, 3.4, 3.4)

    bpy.ops.object.light_add(type="POINT", location=(1.6, 1.3, 1.4))
    rim = bpy.context.active_object
    rim.data.energy = 260
    rim.data.color = (0.5, 0.74, 1.0)

    bpy.ops.object.light_add(type="POINT", location=(-1.4, -0.6, 0.8))
    fill = bpy.context.active_object
    fill.data.energy = 120
    fill.data.color = (0.75, 0.82, 1.0)

    bpy.ops.mesh.primitive_plane_add(size=6.0, location=(0.0, 0.0, -0.2))
    floor = bpy.context.active_object
    mat = bpy.data.materials.new(name="Floor")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.07, 0.09, 0.13, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.82
    floor.data.materials.append(mat)


def import_weapon(glb_path: str) -> bpy.types.Object | None:
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=glb_path)
    added = [o for o in bpy.data.objects if o.name not in before]
    roots = [o for o in added if o.parent is None]
    if roots:
        return roots[0]
    return added[0] if added else None


def _iter_mesh_children(root: bpy.types.Object) -> list[bpy.types.Object]:
    out: list[bpy.types.Object] = []
    for o in [root] + list(root.children_recursive):
        if o.type == "MESH":
            out.append(o)
    return out


def _world_bounds(root: bpy.types.Object) -> tuple[float, float, float, float, float, float]:
    meshes = _iter_mesh_children(root)
    if not meshes:
        return (-0.5, 0.5, -0.5, 0.5, -0.2, 0.8)
    xs: list[float] = []
    ys: list[float] = []
    zs: list[float] = []
    for m in meshes:
        for c in m.bound_box:
            w = m.matrix_world @ Vector((c[0], c[1], c[2]))
            xs.append(float(w.x))
            ys.append(float(w.y))
            zs.append(float(w.z))
    return (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))


def _fit_camera(cam: bpy.types.Object, root: bpy.types.Object, view_key: str) -> None:
    min_x, max_x, min_y, max_y, min_z, max_z = _world_bounds(root)
    cx = (min_x + max_x) * 0.5
    cy = (min_y + max_y) * 0.5
    cz = (min_z + max_z) * 0.5
    sx = max_x - min_x
    sy = max_y - min_y
    sz = max_z - min_z
    size = max(sx, sy, sz, 0.4)
    pad = 1.9
    # Use orthographic camera to avoid perspective clipping.
    cam.data.type = "ORTHO"
    if view_key == "top":
        cam.location = (cx, cy, max_z + size * 4.0)
        cam.rotation_euler = tuple(math.radians(a) for a in (89, 0, 0))
        cam.data.ortho_scale = max(sx, sy) * pad
    elif view_key == "side":
        cam.location = (cx + size * 3.0, cy - size * 2.2, cz + size * 2.0)
        cam.rotation_euler = tuple(math.radians(a) for a in (70, 0, 42))
        cam.data.ortho_scale = max(sx, sz) * pad
    else:
        cam.location = (cx, cy - size * 3.1, cz + size * 2.25)
        cam.rotation_euler = tuple(math.radians(a) for a in (72, 0, 0))
        cam.data.ortho_scale = max(sx, sz) * pad


def ensure_camera() -> bpy.types.Object:
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def render_view(cam: bpy.types.Object, out_path: Path, view_key: str) -> None:
    # Camera transform is now auto-fitted per weapon bounds.
    bpy.context.scene.render.filepath = str(out_path)
    bpy.ops.render.render(write_still=True)


def render_one_weapon(weapon_id: str, glb_res: str) -> None:
    clear_scene()
    setup_scene()
    cam = ensure_camera()
    glb_abs = str((ROOT / glb_res.replace("res://", "")).resolve())
    root = import_weapon(glb_abs)
    if root is None:
        print(f"[WARN] failed import: {weapon_id}")
        return
    root.location = (0.0, 0.0, 0.0)
    # High-tech clean look: slightly cool overall tint and restrained bloom.
    for o in _iter_mesh_children(root):
        for slot in o.material_slots:
            m = slot.material
            if m and m.use_nodes:
                bsdf = m.node_tree.nodes.get("Principled BSDF")
                if bsdf:
                    c = bsdf.inputs["Base Color"].default_value
                    bsdf.inputs["Base Color"].default_value = (min(1.0, c[0] * 0.96), min(1.0, c[1] * 1.01), min(1.0, c[2] * 1.05), c[3])
    for vk in VIEWS.keys():
        out = OUT_DIR / f"{weapon_id}_{vk}.png"
        _fit_camera(cam, root, vk)
        render_view(cam, out, vk)
        print(f"Wrote {out}")


def make_sheet() -> None:
    from PIL import Image, ImageDraw, ImageFont

    files = sorted([p for p in OUT_DIR.glob("*_hero.png")])
    if not files:
        return
    cards = []
    for p in files:
        cards.append((p.stem.replace("_hero", ""), Image.open(p).convert("RGB").resize((300, 300))))
    cols = 4
    rows = (len(cards) + cols - 1) // cols
    pad = 20
    cell_h = 336
    canvas = Image.new("RGB", (pad + cols * (300 + pad), pad + rows * (cell_h + pad)), (14, 16, 24))
    d = ImageDraw.Draw(canvas)
    f = ImageFont.load_default()
    for i, (name, im) in enumerate(cards):
        r, c = divmod(i, cols)
        x = pad + c * (300 + pad)
        y = pad + r * (cell_h + pad)
        canvas.paste(im, (x, y))
        d.text((x + 6, y + 306), name, fill=(220, 230, 245), font=f)
    sheet = OUT_DIR / "weapon_concept_multiview_sheet.png"
    canvas.save(sheet)
    print(f"Wrote {sheet}")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if not REG_PATH.exists():
        raise SystemExit(f"Missing registry: {REG_PATH}")
    data = json.loads(REG_PATH.read_text(encoding="utf-8"))
    weapons = data.get("weapons", {})
    for wid, info in weapons.items():
        glb = info.get("model_glb", "")
        if not glb:
            continue
        render_one_weapon(wid, glb)
    make_sheet()


if __name__ == "__main__":
    main()
