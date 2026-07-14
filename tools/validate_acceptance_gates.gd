extends SceneTree

## 验收门：
## 1) P0 信任债关键开关
## 2) 四地图均有 map_rule
## 3) 五流派专精挂在 PASSIVES + SCHOOL_MASTERY_IDS
## 4) 至少一种地图规则会改玩家移动（Player.set_map_move_field + poison/moving_safe）


func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var ok := true
	ok = _check_p0_trust() and ok
	ok = _check_map_rules() and ok
	ok = _check_five_schools() and ok
	ok = _check_move_field_api() and ok
	if ok:
		print("validate_acceptance_gates: OK")
		quit(0)
	else:
		quit(1)


func _check_p0_trust() -> bool:
	var gdb := root.get_node_or_null("/root/GameDB")
	if gdb == null:
		push_error("gates: GameDB missing")
		return false
	if absf(float(gdb.ENDLESS_DAMAGE_NUMBER_MUL) - 1.0) > 0.001:
		push_error("gates: ENDLESS_DAMAGE_NUMBER_MUL must be 1.0")
		return false
	for wid in gdb.WEAPONS.keys():
		var w: Dictionary = gdb.WEAPONS[wid]
		if w.has("base_dmg"):
			push_error("gates: dead base_dmg still present on " + String(wid))
			return false
	if not gdb.BOSS_SKILLS.has("enrage"):
		push_error("gates: enrage missing")
		return false
	var enr: Dictionary = gdb.BOSS_SKILLS["enrage"]
	if not enr.has("hp_threshold") or not enr.has("dmg_mul"):
		push_error("gates: enrage config not wired fields")
		return false
	return true


func _check_map_rules() -> bool:
	var gdb := root.get_node_or_null("/root/GameDB")
	if gdb.MAP_TEMPLATES.size() < 4:
		push_error("gates: need 4 maps")
		return false
	var needed := {
		"poison_ring": false,
		"moving_safe_zone": false,
		"elite_hunt": false,
		"event_bias": false,
	}
	for tpl in gdb.MAP_TEMPLATES:
		var rule: Dictionary = tpl.get("map_rule", {}) as Dictionary
		var rid := String(rule.get("id", ""))
		if rid.is_empty():
			push_error("gates: map missing map_rule " + String(tpl.get("id", "?")))
			return false
		if needed.has(rid):
			needed[rid] = true
	for k in needed.keys():
		if not bool(needed[k]):
			push_error("gates: missing map_rule id " + String(k))
			return false
	return true


func _check_five_schools() -> bool:
	var gdb := root.get_node_or_null("/root/GameDB")
	if gdb.SCHOOL_MASTERY_IDS.size() < 5:
		push_error("gates: SCHOOL_MASTERY_IDS < 5")
		return false
	for pid in gdb.SCHOOL_MASTERY_IDS:
		if not gdb.PASSIVES.has(String(pid)):
			push_error("gates: missing PASSIVES " + String(pid))
			return false
	return true


func _check_move_field_api() -> bool:
	# 静态检查脚本源，确认移动场已接入
	var player_src := FileAccess.get_file_as_string("res://scripts/entities/Player.gd")
	var game_src := FileAccess.get_file_as_string("res://scripts/core/Game.gd")
	if player_src.find("set_map_move_field") < 0 or player_src.find("_map_move_mul") < 0:
		push_error("gates: Player missing map move field")
		return false
	if game_src.find("_set_player_map_move_field") < 0:
		push_error("gates: Game missing _set_player_map_move_field")
		return false
	if game_src.find("pull") < 0 or game_src.find("0.72") < 0:
		push_error("gates: poison/moving map move modifiers missing")
		return false
	return true
