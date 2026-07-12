extends SceneTree

## 为缺失源文件的武器模型生成最小占位 GLB（单三角面），供 Godot 导入管线使用。
## 正式资产请用 tools/build_weapon_models_blender.py 覆盖。

const WEAPON_IDS: PackedStringArray = [
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

const OUT_DIR := "res://assets/game_pack/models/weapons"


func _init() -> void:
	var bytes := _minimal_glb_bytes()
	var ok := 0
	for weapon_id in WEAPON_IDS:
		var rel := "%s/%s.glb" % [OUT_DIR, weapon_id]
		if _write_bytes(rel, bytes):
			ok += 1
		else:
			push_error("emit_placeholder_weapon_glbs: failed " + rel)
	print("emit_placeholder_weapon_glbs: wrote %d/%d" % [ok, WEAPON_IDS.size()])
	quit(0 if ok == WEAPON_IDS.size() else 1)


func _write_bytes(rel_path: String, data: PackedByteArray) -> bool:
	var path := ProjectSettings.globalize_path(rel_path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(data)
	f.close()
	return true


func _minimal_glb_bytes() -> PackedByteArray:
	var json_text := (
		'{"asset":{"version":"2.0","generator":"ShellSurvivor"},'
		+ '"scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"mesh":0}],'
		+ '"meshes":[{"primitives":[{"attributes":{"POSITION":0},"indices":1}]}],'
		+ '"accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3",'
		+ '"max":[0.08,0.12,0.0],"min":[-0.08,0.0,0.0]},'
		+ '{"bufferView":1,"componentType":5123,"count":3,"type":"SCALAR"}],'
		+ '"bufferViews":[{"buffer":0,"byteOffset":0,"byteLength":36},'
		+ '{"buffer":0,"byteOffset":36,"byteLength":6}],'
		+ '"buffers":[{"byteLength":42}]}'
	)
	var json_bytes := json_text.to_utf8_buffer()
	while json_bytes.size() % 4 != 0:
		json_bytes.append(0x20)

	var bin_bytes := PackedByteArray()
	bin_bytes.append_array(PackedFloat32Array([-0.08, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.12, 0.0]).to_byte_array())
	bin_bytes.append_array(PackedByteArray([0, 0, 1, 0, 2, 0]))
	while bin_bytes.size() % 4 != 0:
		bin_bytes.append(0)

	var total := 12 + 8 + json_bytes.size() + 8 + bin_bytes.size()
	var out := PackedByteArray()
	out.append_array("glTF".to_utf8_buffer())
	out.append_array(PackedByteArray([0x02, 0x00, 0x00, 0x00]))
	out.append_array(_u32_le(total))
	out.append_array(_u32_le(json_bytes.size()))
	out.append_array(_u32_le(0x4E4F534A)) # JSON
	out.append_array(json_bytes)
	out.append_array(_u32_le(bin_bytes.size()))
	out.append_array(_u32_le(0x004E4942)) # BIN
	out.append_array(bin_bytes)
	return out


func _u32_le(v: int) -> PackedByteArray:
	return PackedByteArray([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF])
