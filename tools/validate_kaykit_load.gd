extends SceneTree

## 校验 KayKit 资产是否已安装（hero / enemies / 配件 gltf）。

const REQUIRED: PackedStringArray = [
	"res://assets/game_pack/models/hero/rogue.glb",
	"res://assets/game_pack/models/enemies/skeleton_warrior.glb",
	"res://assets/game_pack/models/accessories/gltf/dagger.gltf",
	"res://assets/game_pack/models/accessories/gltf/staff.gltf",
	"res://assets/vendor/kaykit/adventurers/Characters/gltf/Rogue.glb",
]


func _init() -> void:
	var missing := 0
	for p in REQUIRED:
		if not FileAccess.file_exists(ProjectSettings.globalize_path(p)):
			push_error("validate_kaykit_load: missing " + p)
			missing += 1
		elif load(p) == null:
			push_error("validate_kaykit_load: cannot load " + p)
			missing += 1
	if missing == 0:
		print("validate_kaykit_load: OK")
	quit(0 if missing == 0 else 1)
