extends SceneTree

## 第 8 周发售准备守卫：
## - 成就表完整（8 构筑 + 挑战 + 模式）
## - Demo / 无尽常量
## - AchievementService 契约
## - 商店文案与 HOWTO 非空


func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	if not _check_store_copy():
		quit(1)
		return
	if not _check_achievements():
		quit(1)
		return
	if not _check_endless_demo_flags():
		quit(1)
		return
	if not _check_achievement_service():
		quit(1)
		return
	print("validate_week8_ship: OK")
	quit(0)


func _check_store_copy() -> bool:
	var gdb := root.get_node_or_null("/root/GameDB")
	if gdb == null:
		push_error("validate_week8_ship: GameDB missing")
		return false
	if String(gdb.STORE_PAGE_BLURB).length() < 40:
		push_error("validate_week8_ship: STORE_PAGE_BLURB too short")
		return false
	if gdb.HOWTO_STEPS.size() < 5:
		push_error("validate_week8_ship: HOWTO_STEPS incomplete")
		return false
	var howto_blob := " ".join(gdb.HOWTO_STEPS)
	if howto_blob.find("试炼") < 0 or howto_blob.find("标准") < 0:
		push_error("validate_week8_ship: HOWTO missing trial/standard copy")
		return false
	return true


func _check_achievements() -> bool:
	var gdb := root.get_node_or_null("/root/GameDB")
	var required: PackedStringArray = [
		"first_win", "mode_trial_win", "mode_standard_win", "mode_endurance_win",
		"diff_nightmare_win", "chal_brittle_win", "chal_swarm_win", "chal_glass_win",
		"chal_iron_win", "chal_shadow_win", "chal_glass_nightmare", "chal_any_nightmare",
		"codex_fusions_half", "codex_schools_all",
		"build_all_eight", "endless_survive",
	]
	for rid in required:
		if not gdb.STEAM_ACHIEVEMENTS.has(rid):
			push_error("validate_week8_ship: missing achievement " + rid)
			return false
	for wid in gdb.BUILD_BALANCE_ROUTES.keys():
		var aid := "build_%s" % String(wid)
		if not gdb.STEAM_ACHIEVEMENTS.has(aid):
			push_error("validate_week8_ship: missing build achievement " + aid)
			return false
	return true


func _check_endless_demo_flags() -> bool:
	var gdb := root.get_node_or_null("/root/GameDB")
	if not bool(gdb.ENDLESS_AFTER_EXTRACTION):
		push_error("validate_week8_ship: ENDLESS_AFTER_EXTRACTION should be true for ship")
		return false
	if float(gdb.ENDLESS_SOFT_INTRO_SEC) < 240.0:
		push_error("validate_week8_ship: ENDLESS_SOFT_INTRO_SEC too short")
		return false
	if absf(float(gdb.ENDLESS_DAMAGE_NUMBER_MUL) - 1.0) > 0.001:
		push_error("validate_week8_ship: ENDLESS_DAMAGE_NUMBER_MUL must be 1.0 (no fake numbers)")
		return false
	# Demo 检测函数必须存在
	if not gdb.has_method("is_demo_build"):
		push_error("validate_week8_ship: is_demo_build missing")
		return false
	return true


func _check_achievement_service() -> bool:
	var ach := root.get_node_or_null("/root/AchievementService")
	if ach == null:
		push_error("validate_week8_ship: AchievementService autoload missing")
		return false
	for m in ["try_unlock", "evaluate_run_end", "resolve_primary_build_weapon", "summary_line"]:
		if not ach.has_method(m):
			push_error("validate_week8_ship: AchievementService missing " + m)
			return false
	var game_text := FileAccess.get_file_as_string("res://scripts/core/Game.gd")
	for token in ["_begin_post_extraction_endless", "get_damage_number_display_mul", "_mission_cleared"]:
		if game_text.find(token) == -1:
			push_error("validate_week8_ship: Game.gd missing " + token)
			return false
	return true
