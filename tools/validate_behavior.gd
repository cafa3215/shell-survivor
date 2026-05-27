extends SceneTree

## 行为级 headless 测试（不依赖字符串 token）：
## - RunLoadout 诅咒倍率
## - GameDirector 降压比例
## - RunStats 坏档清洗


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _test_run_loadout_curses():
		quit(1)
		return
	if not _test_game_director_relief():
		quit(1)
		return
	if not _test_runstats_sanitize():
		quit(1)
		return
	print("validate_behavior: OK")
	quit(0)


func _test_run_loadout_curses() -> bool:
	var loadout = load("res://scripts/core/RunLoadout.gd").new()
	if loadout.get_curse_move_speed_mul() != 1.0:
		push_error("validate_behavior: curse move mul should start at 1.0")
		return false
	loadout.apply_world_curse("slow", 2.0)
	if loadout.get_curse_move_speed_mul() != 0.8:
		push_error("validate_behavior: slow curse move mul expected 0.8")
		return false
	loadout.apply_world_curse("damage", 2.0)
	if loadout.get_curse_outgoing_damage_mul() != 0.85:
		push_error("validate_behavior: weak curse damage mul expected 0.85")
		return false
	loadout.apply_world_curse("nocollect", 2.0)
	if not loadout.is_curse_blocking_xp_pickup():
		push_error("validate_behavior: nocollect curse should block pickup")
		return false
	return true


func _test_game_director_relief() -> bool:
	var director = load("res://scripts/core/GameDirector.gd").new()
	if director.pressure_relief_ratio() != 0.0:
		push_error("validate_behavior: relief ratio should start at 0")
		return false
	director.pressure_relief = 130.0
	var r: float = director.pressure_relief_ratio()
	if r < 0.49 or r > 0.51:
		push_error("validate_behavior: relief ratio expected ~0.5, got %.3f" % r)
		return false
	return true


func _test_runstats_sanitize() -> bool:
	var rs := root.get_node_or_null("/root/RunStats")
	if rs == null:
		push_error("validate_behavior: RunStats autoload missing")
		return false
	if not rs.has_method("_sanitize_run_record"):
		push_error("validate_behavior: RunStats._sanitize_run_record missing")
		return false
	var bad := {
		"win": 1,
		"kills": "3",
		"damage": "n/a",
		"runtime": "120",
		"tags": ["survival_stable", 42],
	}
	var clean: Dictionary = rs.call("_sanitize_run_record", bad, 0)
	if typeof(clean.get("win", null)) != TYPE_BOOL:
		push_error("validate_behavior: sanitize win type")
		return false
	if int(clean.get("kills", -1)) != 3:
		push_error("validate_behavior: sanitize kills coercion")
		return false
	if int(clean.get("runtime", -1)) != 120:
		push_error("validate_behavior: sanitize runtime coercion")
		return false
	var tags: Variant = clean.get("tags", [])
	if not (tags is Array) or tags.size() != 2:
		push_error("validate_behavior: sanitize tags array")
		return false
	return true
