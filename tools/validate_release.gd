extends SceneTree

## 发布前自检（轻量）：
## - 关键 autoload 是否可用
## - Main 场景关键 UI 节点是否存在
## - 核心脚本方法是否存在（避免重构后调用断裂）

const REQUIRED_AUTOLOADS: PackedStringArray = [
	"EventBus",
	"GameDB",
	"Settings",
	"RunStats",
	"CombatFeedback",
	"MetaProgress",
	"AudioManager",
	"InputManager",
	"NotificationSystem",
]

const REQUIRED_MAIN_NODES: PackedStringArray = [
	"MenuLayer/Root/Panel/StartButton",
	"MenuLayer/Root/Panel/QuitButton",
	"PauseLayer/PausePanel",
	"ResultLayer/ResultPanel",
]

func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	# 1) autoload presence
	for nm in REQUIRED_AUTOLOADS:
		if root.get_node_or_null("/root/" + nm) == null:
			push_error("validate_release: missing autoload " + nm)
			quit(1)
			return

	# 2) Main_new instantiate
	var packed: Resource = ResourceLoader.load("res://scenes/Main_new.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("validate_release: Main_new load failed")
		quit(1)
		return
	var main := (packed as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# 3) key node checks
	for path in REQUIRED_MAIN_NODES:
		if main.get_node_or_null(path) == null:
			push_error("validate_release: missing node " + path)
			quit(1)
			return

	# 4) key method checks (cross-module contracts)
	var run_stats := root.get_node_or_null("/root/RunStats")
	if run_stats == null or not run_stats.has_method("menu_next_run_hint"):
		push_error("validate_release: RunStats.menu_next_run_hint missing")
		quit(1)
		return
	if not run_stats.has_method("finalize_latest_run"):
		push_error("validate_release: RunStats.finalize_latest_run missing")
		quit(1)
		return

	var settings := root.get_node_or_null("/root/Settings")
	if settings == null or not settings.has_method("set_quality"):
		push_error("validate_release: Settings.set_quality missing")
		quit(1)
		return

	print("validate_release: OK")
	quit(0)
