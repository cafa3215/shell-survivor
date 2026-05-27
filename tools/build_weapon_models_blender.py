#!/usr/bin/env python3
from __future__ import annotations

import json
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
OUT_MODEL_DIR = ROOT / "assets" / "game_pack" / "models" / "weapons"
OUT_PREVIEW_DIR = ROOT / "tmp" / "weapon_model_previews"
OUT_REGISTRY = ROOT / "assets" / "config" / "weapon_model_registry.json"


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def make_mat(name: str, color: tuple[float, float, float, float], metallic: float, roughness: float, emission: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission > 0.0:
            bsdf.inputs["Emission Color"].default_value = color
            bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def make_theme(theme: str) -> dict[str, bpy.types.Material]:
    p = {
        "neutral": (0.74, 0.79, 0.87, 1.0),
        "electric": (0.28, 0.84, 1.0, 1.0),
        "explosive": (1.0, 0.42, 0.22, 1.0),
        "frost": (0.52, 0.86, 1.0, 1.0),
        "heal": (0.34, 0.9, 0.66, 1.0),
    }[theme]
    return {
        "armor": make_mat(f"M_{theme}_armor", (0.14, 0.16, 0.2, 1.0), 0.55, 0.34),
        "frame": make_mat(f"M_{theme}_frame", (0.42, 0.46, 0.56, 1.0), 0.72, 0.28),
        "energy": make_mat(f"M_{theme}_energy", p, 0.12, 0.22, emission=3.2),
        "accent": make_mat(f"M_{theme}_accent", (min(1.0, p[0] + 0.18), min(1.0, p[1] + 0.1), min(1.0, p[2] + 0.1), 1.0), 0.2, 0.24),
    }


def tint_material(mat: bpy.types.Material, color: tuple[float, float, float, float], emission: float | None = None) -> None:
    if mat is None or not mat.use_nodes:
        return
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is None:
        return
    bsdf.inputs["Base Color"].default_value = color
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission


def apply_weapon_palette(weapon_id: str, mats: dict[str, bpy.types.Material]) -> None:
    # 贴合项目色系，但保证武器间识别度。
    weapon_tint = {
        "kunai": (0.72, 0.9, 1.0, 1.0),
        "quantum_ball": (0.56, 0.96, 0.72, 1.0),
        "lightning": (0.38, 0.88, 1.0, 1.0),
        "rocket": (1.0, 0.48, 0.2, 1.0),
        "molotov": (1.0, 0.62, 0.24, 1.0),
        "guardian": (0.66, 0.8, 1.0, 1.0),
        "drone_ab": (0.34, 0.78, 1.0, 1.0),
        "boomerang": (0.62, 0.84, 1.0, 1.0),
        "frost_aura": (0.7, 0.94, 1.0, 1.0),
        "stun_mine": (1.0, 0.55, 0.3, 1.0),
        "heal_aura": (0.4, 0.92, 0.68, 1.0),
    }
    armor_tint = {
        "kunai": (0.12, 0.16, 0.22, 1.0),
        "quantum_ball": (0.1, 0.17, 0.2, 1.0),
        "lightning": (0.1, 0.16, 0.2, 1.0),
        "rocket": (0.2, 0.14, 0.12, 1.0),
        "molotov": (0.18, 0.12, 0.1, 1.0),
        "guardian": (0.12, 0.14, 0.2, 1.0),
        "drone_ab": (0.1, 0.14, 0.2, 1.0),
        "boomerang": (0.12, 0.16, 0.22, 1.0),
        "frost_aura": (0.11, 0.16, 0.21, 1.0),
        "stun_mine": (0.2, 0.13, 0.11, 1.0),
        "heal_aura": (0.1, 0.18, 0.15, 1.0),
    }
    ec = weapon_tint.get(weapon_id, (0.7, 0.85, 1.0, 1.0))
    ac = armor_tint.get(weapon_id, (0.14, 0.16, 0.2, 1.0))
    tint_material(mats["energy"], ec, emission=3.6)
    tint_material(mats["accent"], (min(1.0, ec[0] + 0.14), min(1.0, ec[1] + 0.08), min(1.0, ec[2] + 0.08), 1.0), emission=1.2)
    tint_material(mats["armor"], ac)


def bevel(obj: bpy.types.Object, width: float = 0.018) -> None:
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = 2


def add_cube(name: str, loc, scale, mat) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.data.materials.append(mat)
    bevel(o, 0.01)
    return o


def add_cyl(name: str, loc, radius: float, depth: float, mat, rot=(0.0, 0.0, 0.0), v=24) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    bevel(o, 0.008)
    return o


def add_ico(name: str, loc, radius: float, mat, sub=2) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(radius=radius, location=loc, subdivisions=sub)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    return o


def add_cone(name: str, loc, radius: float, depth: float, mat, rot=(0.0, 0.0, 0.0), v=18) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=v, radius1=radius, radius2=radius * 0.18, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    bevel(o, 0.006)
    return o


def add_torus(name: str, loc, major: float, minor: float, mat, rot=(0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(location=loc, major_radius=major, minor_radius=minor, rotation=rot, major_segments=24, minor_segments=12)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    return o


def add_decal_strip(name: str, loc, scale, mat, rot=(0.0, 0.0, 0.0)) -> bpy.types.Object:
    # Ultra-thin plate used as symbolic decal layer.
    return add_cube(name, loc, scale, mat)


def root_empty(name: str) -> bpy.types.Object:
    r = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(r)
    return r


def parent(root: bpy.types.Object, objs: list[bpy.types.Object]) -> None:
    for o in objs:
        o.parent = root


def build_weapon_model(weapon_id: str, theme: str) -> bpy.types.Object:
    m = make_theme(theme)
    apply_weapon_palette(weapon_id, m)
    root = root_empty(f"WPN_{weapon_id}")
    parts: list[bpy.types.Object] = []

    if weapon_id == "kunai":
        parts += [
            add_cube("blade", (0, 0, 0.42), (0.055, 0.27, 0.33), m["frame"]),
            add_cube("core", (0, 0, 0.38), (0.015, 0.23, 0.24), m["energy"]),
            add_cyl("grip", (0, 0, 0.03), 0.045, 0.2, m["armor"]),
            add_cube("guard", (0, 0, 0.18), (0.1, 0.016, 0.02), m["accent"]),
            add_cone("tip_mark", (0, 0, 0.66), 0.04, 0.1, m["energy"], (math.radians(180), 0, 0)),
            add_decal_strip("decal_k1", (0.018, 0.0, 0.33), (0.008, 0.16, 0.004), m["accent"]),
            add_decal_strip("decal_k2", (-0.02, 0.0, 0.48), (0.007, 0.11, 0.004), m["accent"]),
        ]
    elif weapon_id == "quantum_ball":
        parts += [
            add_ico("core", (0, 0, 0.16), 0.19, m["energy"]),
            add_torus("ring_a", (0, 0, 0.16), 0.28, 0.018, m["frame"], (math.radians(90), 0, 0)),
            add_torus("ring_b", (0, 0, 0.16), 0.22, 0.014, m["accent"], (0, math.radians(90), 0)),
            add_ico("pulse", (0, 0, 0.16), 0.07, m["accent"], sub=1),
            add_cube("node_q_asym", (0.19, 0.0, 0.25), (0.025, 0.025, 0.04), m["accent"]),
        ]
    elif weapon_id == "lightning":
        parts += [
            add_cube("fork_l", (-0.08, 0, 0.32), (0.028, 0.23, 0.25), m["frame"]),
            add_cube("fork_r", (0.08, 0, 0.32), (0.028, 0.23, 0.25), m["frame"]),
            add_cube("spine", (0, 0, 0.28), (0.02, 0.26, 0.23), m["energy"]),
            add_cyl("handle", (0, 0, 0.02), 0.05, 0.25, m["armor"]),
            add_cone("arc_mark_a", (-0.13, 0, 0.52), 0.03, 0.08, m["accent"], (math.radians(90), 0, math.radians(22))),
            add_cone("arc_mark_b", (0.13, 0, 0.52), 0.03, 0.08, m["accent"], (math.radians(90), 0, math.radians(-22))),
            add_decal_strip("decal_l1", (0.0, 0.0, 0.3), (0.006, 0.18, 0.004), m["energy"]),
            add_cube("asym_lug", (-0.11, 0.0, 0.14), (0.018, 0.04, 0.018), m["accent"]),
        ]
    elif weapon_id == "rocket":
        parts += [
            add_cyl("body", (0, 0, 0.2), 0.11, 0.5, m["frame"]),
            add_cyl("core", (0, 0, 0.18), 0.055, 0.45, m["energy"]),
            add_cube("fin_a", (0, 0.09, -0.02), (0.12, 0.016, 0.06), m["accent"]),
            add_cube("fin_b", (0, -0.09, -0.02), (0.12, 0.016, 0.06), m["accent"]),
            add_torus("warning_ring", (0, 0, 0.44), 0.12, 0.012, m["accent"], (math.radians(90), 0, 0)),
            add_decal_strip("decal_r1", (0.0, 0.0, 0.26), (0.09, 0.006, 0.004), m["energy"]),
            add_cube("asym_thruster", (0.06, 0.0, -0.07), (0.03, 0.03, 0.05), m["accent"]),
        ]
    elif weapon_id == "molotov":
        parts += [
            add_cyl("flask", (0, 0, 0.14), 0.12, 0.34, m["frame"]),
            add_cyl("fuel", (0, 0, 0.12), 0.085, 0.2, m["energy"]),
            add_cube("neck", (0, 0, 0.35), (0.045, 0.045, 0.08), m["accent"]),
            add_cone("flame_mark", (0, 0, 0.46), 0.04, 0.1, m["energy"], (math.radians(180), 0, 0)),
            add_decal_strip("decal_m1", (0.07, 0.0, 0.17), (0.02, 0.07, 0.004), m["accent"]),
        ]
    elif weapon_id == "guardian":
        parts += [
            add_torus("ring", (0, 0, 0.14), 0.29, 0.022, m["frame"], (math.radians(90), 0, 0)),
            add_ico("hub", (0, 0, 0.14), 0.09, m["energy"]),
            add_cube("blade_n", (0, 0.31, 0.14), (0.04, 0.03, 0.06), m["accent"]),
            add_cube("blade_s", (0, -0.31, 0.14), (0.04, 0.03, 0.06), m["accent"]),
            add_torus("shield_mark", (0, 0, 0.14), 0.18, 0.01, m["energy"], (0, math.radians(90), 0)),
            add_decal_strip("decal_g1", (0.0, 0.29, 0.14), (0.02, 0.012, 0.02), m["energy"]),
            add_cube("asym_gnode", (-0.22, 0.0, 0.14), (0.024, 0.024, 0.024), m["accent"]),
        ]
    elif weapon_id == "drone_ab":
        parts += [add_cube("pod_l", (-0.16, 0, 0.15), (0.1, 0.15, 0.06), m["frame"]), add_cube("pod_r", (0.16, 0, 0.15), (0.1, 0.15, 0.06), m["frame"]), add_cube("beam", (0, 0, 0.14), (0.13, 0.03, 0.03), m["energy"]), add_cube("top_l", (-0.16, 0, 0.23), (0.05, 0.06, 0.02), m["accent"]), add_cube("top_r", (0.16, 0, 0.23), (0.05, 0.06, 0.02), m["accent"])]
        parts += [add_decal_strip("decal_d1", (-0.16, 0.0, 0.18), (0.03, 0.003, 0.012), m["energy"]), add_decal_strip("decal_d2", (0.16, 0.0, 0.18), (0.03, 0.003, 0.012), m["energy"]), add_cube("asym_ant", (0.24, 0.0, 0.25), (0.01, 0.01, 0.05), m["accent"])]
    elif weapon_id == "boomerang":
        parts += [
            add_cube("arm_l", (-0.13, 0, 0.14), (0.16, 0.03, 0.06), m["frame"]),
            add_cube("arm_r", (0.13, 0, 0.14), (0.16, 0.03, 0.06), m["frame"]),
            add_cube("edge_l", (-0.13, 0, 0.19), (0.14, 0.01, 0.02), m["energy"]),
            add_cube("edge_r", (0.13, 0, 0.19), (0.14, 0.01, 0.02), m["energy"]),
            add_decal_strip("decal_b1", (0.0, 0.0, 0.17), (0.025, 0.003, 0.02), m["accent"]),
        ]
    elif weapon_id == "frost_aura":
        parts += [
            add_torus("ring_outer", (0, 0, 0.14), 0.29, 0.02, m["frame"], (math.radians(90), 0, 0)),
            add_torus("ring_inner", (0, 0, 0.14), 0.22, 0.014, m["energy"], (math.radians(90), 0, 0)),
            add_cone("crystal", (0, 0, 0.4), 0.03, 0.12, m["accent"], (math.radians(180), 0, 0)),
            add_cube("snow_mark_h", (0, 0, 0.14), (0.16, 0.01, 0.01), m["energy"]),
            add_cube("snow_mark_v", (0, 0, 0.14), (0.01, 0.16, 0.01), m["energy"]),
            add_cube("snow_mark_d1", (0, 0, 0.14), (0.12, 0.01, 0.01), m["accent"]),
        ]
    elif weapon_id == "stun_mine":
        parts += [
            add_cyl("disc", (0, 0, 0.1), 0.18, 0.12, m["frame"]),
            add_cyl("pulse", (0, 0, 0.12), 0.08, 0.06, m["energy"]),
            add_cube("spike_a", (0.2, 0, 0.1), (0.03, 0.01, 0.02), m["accent"]),
            add_cube("spike_b", (-0.2, 0, 0.1), (0.03, 0.01, 0.02), m["accent"]),
            add_torus("mine_warn", (0, 0, 0.1), 0.14, 0.008, m["energy"], (math.radians(90), 0, 0)),
        ]
    elif weapon_id == "heal_aura":
        parts += [
            add_torus("halo", (0, 0, 0.14), 0.28, 0.02, m["frame"], (math.radians(90), 0, 0)),
            add_ico("seed", (0, 0, 0.14), 0.08, m["energy"]),
            add_torus("leaf_ring", (0, 0, 0.14), 0.21, 0.012, m["accent"], (math.radians(90), 0, 0)),
            add_cone("leaf_a", (0.08, 0, 0.22), 0.03, 0.11, m["accent"], (math.radians(35), 0, math.radians(38))),
            add_cone("leaf_b", (-0.08, 0, 0.22), 0.03, 0.11, m["accent"], (math.radians(35), 0, math.radians(-38))),
            add_decal_strip("decal_h1", (0, 0, 0.2), (0.018, 0.003, 0.02), m["energy"]),
        ]
    parent(root, parts)
    return root


def setup_render() -> None:
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE"
    s.render.resolution_x = 1024
    s.render.resolution_y = 1024
    s.render.image_settings.file_format = "PNG"
    s.render.film_transparent = False
    if hasattr(s, "eevee"):
        if hasattr(s.eevee, "use_bloom"):
            s.eevee.use_bloom = True
            if hasattr(s.eevee, "bloom_intensity"):
                s.eevee.bloom_intensity = 0.08
    world = bpy.data.worlds.new("WeaponWorld")
    s.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.03, 0.04, 0.06, 1.0)
    bg.inputs[1].default_value = 1.0
    bpy.ops.object.light_add(type="AREA", location=(0.0, -2.2, 2.3))
    key = bpy.context.active_object
    key.data.energy = 1200
    key.data.color = (1.0, 0.95, 0.92)
    key.scale = (2.8, 2.8, 2.8)
    bpy.ops.object.light_add(type="POINT", location=(1.4, 1.1, 1.3))
    rim = bpy.context.active_object
    rim.data.energy = 220
    rim.data.color = (0.48, 0.72, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=5.0, location=(0.0, 0.0, -0.18))
    floor = bpy.context.active_object
    floor_mat = make_mat("Floor", (0.08, 0.1, 0.14, 1.0), 0.1, 0.76)
    floor.data.materials.append(floor_mat)
    cam_data = bpy.data.cameras.new("Camera")
    cam = bpy.data.objects.new("Camera", cam_data)
    s.collection.objects.link(cam)
    cam.location = (0.0, -2.08, 1.48)
    cam.rotation_euler = (math.radians(71), 0.0, 0.0)
    cam_data.lens = 65
    s.camera = cam


def export_one(weapon_id: str, theme: str) -> dict:
    reset_scene()
    setup_render()
    root = build_weapon_model(weapon_id, theme)
    OUT_MODEL_DIR.mkdir(parents=True, exist_ok=True)
    OUT_PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    glb_path = OUT_MODEL_DIR / f"{weapon_id}.glb"
    png_path = OUT_PREVIEW_DIR / f"{weapon_id}.png"
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for ch in root.children_recursive:
        ch.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format="GLB", use_selection=True)
    bpy.context.scene.render.filepath = str(png_path)
    bpy.ops.render.render(write_still=True)
    return {"model_glb": f"res://assets/game_pack/models/weapons/{weapon_id}.glb", "preview_png": str(png_path), "theme": theme}


def main() -> None:
    weapons = [
        ("kunai", "neutral"), ("quantum_ball", "electric"), ("lightning", "electric"), ("rocket", "explosive"),
        ("molotov", "explosive"), ("guardian", "neutral"), ("drone_ab", "electric"), ("boomerang", "frost"),
        ("frost_aura", "frost"), ("stun_mine", "explosive"), ("heal_aura", "heal"),
    ]
    reg = {"weapons": {}}
    for wid, theme in weapons:
        reg["weapons"][wid] = export_one(wid, theme)
        print(f"Built model: {wid}")
    OUT_REGISTRY.parent.mkdir(parents=True, exist_ok=True)
    OUT_REGISTRY.write_text(json.dumps(reg, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote registry: {OUT_REGISTRY}")


if __name__ == "__main__":
    main()
