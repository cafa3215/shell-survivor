extends SceneTree

## 验证 game_pack 核心 PNG 可被 FileAccess 字节流加载（与 Web 导出同路径）

const PATHS: PackedStringArray = [
	"res://assets/game_pack/textures/player_chibi.png",
	"res://assets/game_pack/textures/ground_tile.png",
	"res://assets/game_pack/textures/enemy_atlas.png",
]


func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	for p in PATHS:
		var img: Image = GameDB.load_png_if_exists(p)
		if img == null or img.is_empty():
			push_error("validate_web_assets: failed to load " + p)
			quit(1)
			return
		if img.get_width() < 64 or img.get_height() < 64:
			push_error("validate_web_assets: too small " + p)
			quit(1)
			return
	print("validate_web_assets: OK %d png(s)" % PATHS.size())
	quit(0)
