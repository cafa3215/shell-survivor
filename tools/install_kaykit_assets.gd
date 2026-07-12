extends SceneTree

## 从 .vendor 或已解压 vendor 同步 KayKit 到 game_pack（可重复运行）。

const VENDOR_ADV := "res://assets/vendor/kaykit/adventurers/"
const VENDOR_SKEL := "res://assets/vendor/kaykit/skeletons/"


func _init() -> void:
	var ok := 0
	var pairs: Array = [
		[VENDOR_ADV + "Characters/gltf/Rogue.glb", "res://assets/game_pack/models/hero/rogue.glb"],
		[VENDOR_SKEL + "Characters/gltf/Skeleton_Warrior.glb", "res://assets/game_pack/models/enemies/skeleton_warrior.glb"],
		[VENDOR_SKEL + "Characters/gltf/Skeleton_Mage.glb", "res://assets/game_pack/models/enemies/skeleton_mage.glb"],
		[VENDOR_SKEL + "Characters/gltf/Skeleton_Rogue.glb", "res://assets/game_pack/models/enemies/skeleton_rogue.glb"],
		[VENDOR_SKEL + "Characters/gltf/Skeleton_Minion.glb", "res://assets/game_pack/models/enemies/skeleton_minion.glb"],
	]
	for pair in pairs:
		ok += 1 if _copy(String(pair[0]), String(pair[1])) else 0
	var acc_src := VENDOR_ADV + "Assets/gltf/"
	var acc_dst := "res://assets/game_pack/models/accessories/gltf/"
	ok += _copy_dir(acc_src, acc_dst)
	print("install_kaykit_assets: synced files, ok_steps=%d" % ok)
	quit(0)


func _copy(src_rel: String, dst_rel: String) -> bool:
	var src := ProjectSettings.globalize_path(src_rel)
	var dst := ProjectSettings.globalize_path(dst_rel)
	if not FileAccess.file_exists(src):
		push_error("install_kaykit_assets: missing " + src_rel)
		return false
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	return DirAccess.copy_absolute(src, dst) == OK


func _copy_dir(src_rel: String, dst_rel: String) -> int:
	var n := 0
	var src_global := ProjectSettings.globalize_path(src_rel)
	var dst_global := ProjectSettings.globalize_path(dst_rel)
	DirAccess.make_dir_recursive_absolute(dst_global)
	var dir := DirAccess.open(src_global)
	if dir == null:
		push_error("install_kaykit_assets: cannot open " + src_rel)
		return 0
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and (file.ends_with(".gltf") or file.ends_with(".bin") or file.ends_with(".png")):
			if DirAccess.copy_absolute(src_global.path_join(file), dst_global.path_join(file)) == OK:
				n += 1
		file = dir.get_next()
	return n
