#!/usr/bin/env python3
from __future__ import annotations

import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
LAYER_DIR = ROOT / "tmp" / "mech_proxy_model"
OUT_FILE = ROOT / "tmp" / "mech_blender_front_preview.png"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block, do_unlink=True)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block, do_unlink=True)


def make_layer_material(name: str, image_path: Path) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    mat.blend_method = "BLEND"
    if hasattr(mat, "shadow_method"):
        mat.shadow_method = "NONE"
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(image_path))
    tex.interpolation = "Smart"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def add_image_plane(name: str, image_path: Path, z: float, y: float, scale: float) -> bpy.types.Object:
    img = bpy.data.images.load(str(image_path))
    w, h = img.size[0], img.size[1]
    ratio = w / max(1, h)
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.0, y, z), rotation=(math.radians(90.0), 0.0, 0.0))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale.x = scale * ratio
    obj.scale.y = scale
    mat = make_layer_material(f"MAT_{name}", image_path)
    obj.data.materials.append(mat)
    return obj


def build_mech_variant(name: str, x: float, yaw_deg: float) -> bpy.types.Object:
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = "PLAIN_AXES"
    root.location = (x, 0.0, 0.0)
    root.rotation_euler = (0.0, math.radians(yaw_deg), 0.0)
    bpy.context.scene.collection.objects.link(root)

    # 单层保形：完全避免叠层重影，改用材质法线假光增强体积。
    main = add_image_plane(f"{name}_full_main", LAYER_DIR / "layer_full.png", z=0.11, y=0.07, scale=1.0)
    nt = main.active_material.node_tree
    tex = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeTexImage"), None)
    bsdf = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"), None)
    if tex is None or bsdf is None:
        main.parent = root
        return root
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    to_bw = nt.nodes.new("ShaderNodeRGBToBW")
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.22
    bump.inputs["Distance"].default_value = 0.08
    ramp.color_ramp.elements[0].position = 0.28
    ramp.color_ramp.elements[1].position = 0.78
    nt.links.new(tex.outputs["Color"], to_bw.inputs["Color"])
    nt.links.new(to_bw.outputs["Val"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.58
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
    main.parent = root
    return root


def setup_scene() -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = False
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT_FILE)

    world = bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.05, 0.06, 0.08, 1.0)
    bg.inputs[1].default_value = 1.0

    bpy.ops.object.light_add(type="AREA", location=(0.0, -1.8, 1.95))
    key = bpy.context.active_object
    key.data.energy = 920
    key.data.color = (1.0, 0.92, 0.9)
    key.scale = (2.8, 2.8, 2.8)

    bpy.ops.object.light_add(type="POINT", location=(0.0, 0.9, 1.0))
    rim = bpy.context.active_object
    rim.data.energy = 65
    rim.data.color = (0.95, 0.25, 0.22)

    bpy.ops.mesh.primitive_plane_add(size=6.0, location=(0.0, 0.0, -0.2))
    ground = bpy.context.active_object
    gmat = bpy.data.materials.new("Ground")
    gmat.use_nodes = True
    gb = gmat.node_tree.nodes["Principled BSDF"]
    gb.inputs["Base Color"].default_value = (0.12, 0.14, 0.18, 1.0)
    gb.inputs["Roughness"].default_value = 0.72
    ground.data.materials.append(gmat)

    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0.0, -2.15, 1.22)
    cam.rotation_euler = (math.radians(74), 0.0, 0.0)
    cam_data.lens = 58
    scene.camera = cam


def main() -> None:
    clear_scene()
    setup_scene()
    build_mech_variant("Center", 0.0, 0.0)
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"Wrote {OUT_FILE}")


if __name__ == "__main__":
    main()
