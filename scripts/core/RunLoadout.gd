extends Node
class_name RunLoadout

## 局内战备：专精 / 遗物 / 诅咒（从 Game.gd 拆出）

const RUN_ARCHETYPES := {
	"assault": {
		"name": "突击",
		"desc": "机动突进：移速提升 12%，冲刺冷却缩短 20%。",
		"stat_add": {"fire_rate": 0.08},
		"player_cfg": {"move_speed_mul": 1.12, "dash_cd_mul": 0.8, "kill_heal_flat": 0.0}
	},
	"guardian": {
		"name": "守护",
		"desc": "稳健抗压：减伤 +10%，额外生命成长 +30。",
		"stat_add": {"dr": 0.10, "hp_growth": 30.0},
		"player_cfg": {"move_speed_mul": 1.0, "dash_cd_mul": 1.0, "kill_heal_flat": 0.0}
	},
	"hunter": {
		"name": "猎杀",
		"desc": "爆发收割：暴击 +12%，吸血 +3%，击杀回复 2 点生命。",
		"stat_add": {"crit_chance": 0.12, "lifesteal": 0.03},
		"player_cfg": {"move_speed_mul": 1.04, "dash_cd_mul": 1.0, "kill_heal_flat": 2.0}
	}
}

var run_relic_id: String = ""
var run_archetype_id: String = ""
var run_relic_second_id: String = ""
var _post_relic_run_sealed := false
var _curse_slow_rem := 0.0
var _curse_weak_rem := 0.0
var _curse_no_pickup_rem := 0.0

var _game: Node = null


func bind(game: Node) -> void:
	_game = game


func cmdline_headless() -> bool:
	for a in OS.get_cmdline_args():
		if str(a) == "--headless":
			return true
	return false


func begin_archetype_pick_sequence() -> void:
	var options := _build_archetype_options()
	if options.is_empty():
		begin_relic_pick_sequence()
		return
	if cmdline_headless():
		apply_chosen_archetype(String(options[0].get("id", "")))
		begin_relic_pick_sequence()
		return
	_open_archetype_pick_ui(options)


func _build_archetype_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array = RUN_ARCHETYPES.keys()
	ids.sort()
	for aid_any in ids:
		var aid := String(aid_any)
		var def: Dictionary = RUN_ARCHETYPES[aid]
		out.append({
			"id": aid,
			"name": String(def.get("name", aid)),
			"desc": String(def.get("desc", "")),
			"tag": "专精"
		})
	return out


func _build_unlocked_relic_pool() -> Array[String]:
	var pool: Array[String] = []
	for rid in GameDB.RUN_RELICS.keys():
		var rs := String(rid)
		if MetaProgress.is_run_relic_unlocked_for_pool(rs):
			pool.append(rs)
	if pool.is_empty():
		for rid in GameDB.RUN_RELICS.keys():
			var def0: Dictionary = GameDB.RUN_RELICS[rid]
			if int(def0.get("unlock_min_wins", 99)) == 0 and int(def0.get("scrap_unlock", 1)) == 0:
				pool.append(String(rid))
	return pool


func _open_archetype_pick_ui(options: Array[Dictionary]) -> void:
	EventBus.upgrade_ui_state_changed.emit(true)
	EventBus.game_paused.emit()
	_game.get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = 96
	layer.name = "RunArchetypePickLayer"
	var p: RunRelicPickPanel = preload("res://scenes/ui/RunRelicPickPanel.tscn").instantiate()
	p.configure_generic(
		"角色专精 · 三选一",
		"本局角色风格会明显变化；选择后立刻生效。",
		"点击选择，或按数字键 1 / 2 / 3",
		options
	)
	p.option_chosen.connect(func(chosen_id: String) -> void: _on_archetype_panel_chosen(layer, chosen_id))
	_game.add_child(layer)
	layer.add_child(p)


func _on_archetype_panel_chosen(layer: Node, archetype_id: String) -> void:
	if layer and is_instance_valid(layer):
		layer.queue_free()
	_game.get_tree().paused = false
	EventBus.game_resumed.emit()
	EventBus.upgrade_ui_state_changed.emit(false)
	apply_chosen_archetype(archetype_id)
	begin_relic_pick_sequence()


func apply_chosen_archetype(archetype_id: String) -> void:
	if archetype_id.is_empty() or not RUN_ARCHETYPES.has(archetype_id):
		return
	run_archetype_id = archetype_id
	var def: Dictionary = RUN_ARCHETYPES[archetype_id]
	var ss: Node = _game.get_node_or_null("SkillSystem")
	if ss and ss.has_method("set_run_archetype"):
		ss.call("set_run_archetype", archetype_id, def.get("stat_add", {}))
	var pl := _game.get_node_or_null("Player")
	if pl and pl.has_method("set_run_archetype"):
		pl.call("set_run_archetype", archetype_id, def.get("player_cfg", {}))
	if not cmdline_headless():
		var n := String(def.get("name", archetype_id))
		NotificationSystem.notify_message("已选择角色专精：" + n, 2.0, "success")


func begin_relic_pick_sequence() -> void:
	var pool := _build_unlocked_relic_pool()
	if pool.is_empty():
		finish_run_start_after_relic()
		return
	pool.shuffle()
	var choices: Array[String] = []
	var n_pick := mini(3, pool.size())
	for i in n_pick:
		choices.append(pool[i])
	if choices.size() <= 1:
		apply_chosen_relic(choices[0] if choices.size() == 1 else "")
		finish_run_start_after_relic()
		return
	if cmdline_headless():
		choices.sort()
		apply_chosen_relic(choices[0])
		finish_run_start_after_relic()
		return
	_open_relic_pick_ui(choices)


func _open_relic_pick_ui(choices: Array[String]) -> void:
	EventBus.upgrade_ui_state_changed.emit(true)
	EventBus.game_paused.emit()
	_game.get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = 95
	layer.name = "RunRelicPickLayer"
	var p: Control = preload("res://scenes/ui/RunRelicPickPanel.tscn").instantiate()
	var ids := PackedStringArray()
	for c in choices:
		ids.append(c)
	p.configure(ids)
	p.relic_chosen.connect(func(chosen_rid: String) -> void: _on_relic_panel_chosen(layer, chosen_rid))
	_game.add_child(layer)
	layer.add_child(p)


func _on_relic_panel_chosen(layer: Node, rid: String) -> void:
	if layer and is_instance_valid(layer):
		layer.queue_free()
	_game.get_tree().paused = false
	EventBus.game_resumed.emit()
	EventBus.upgrade_ui_state_changed.emit(false)
	apply_chosen_relic(rid)
	finish_run_start_after_relic()


func apply_chosen_relic(rid: String) -> void:
	if rid.is_empty():
		return
	run_relic_id = rid
	RunStats.set_current_run_relic(run_relic_id)
	var def: Dictionary = GameDB.RUN_RELICS[run_relic_id]
	var stat_add: Dictionary = def.get("stat_add", {}) as Dictionary
	var ss: Node = _game.get_node_or_null("SkillSystem")
	if ss and ss.has_method("set_run_relic_stat_add"):
		ss.call("set_run_relic_stat_add", stat_add)
	var rn := String(def.get("name", run_relic_id))
	if not cmdline_headless():
		NotificationSystem.notify_message("已选择战备遗物：" + rn, 2.2, "success")
	var pl := _game.get_node_or_null("Player")
	if pl:
		EventBus.play_sfx.emit(&"upgrade_pick", pl.global_position)


func finish_run_start_after_relic() -> void:
	if _post_relic_run_sealed:
		return
	_post_relic_run_sealed = true
	EventBus.game_started.emit()
	_game.call_deferred("_deferred_run_opening_tip")


func tick_curses(delta: float) -> void:
	if _curse_slow_rem > 0.0:
		_curse_slow_rem = maxf(0.0, _curse_slow_rem - delta)
	if _curse_weak_rem > 0.0:
		_curse_weak_rem = maxf(0.0, _curse_weak_rem - delta)
	if _curse_no_pickup_rem > 0.0:
		_curse_no_pickup_rem = maxf(0.0, _curse_no_pickup_rem - delta)


func apply_world_curse(kind: String, duration_sec: float) -> void:
	var d := maxf(duration_sec, 0.05)
	match kind:
		"slow":
			_curse_slow_rem = maxf(_curse_slow_rem, d)
		"damage":
			_curse_weak_rem = maxf(_curse_weak_rem, d)
		"nocollect":
			_curse_no_pickup_rem = maxf(_curse_no_pickup_rem, d)


func get_curse_move_speed_mul() -> float:
	return 0.8 if _curse_slow_rem > 0.0 else 1.0


func get_curse_outgoing_damage_mul() -> float:
	return 0.85 if _curse_weak_rem > 0.0 else 1.0


func is_curse_blocking_xp_pickup() -> bool:
	return _curse_no_pickup_rem > 0.0


func get_curse_hud_hint() -> String:
	var parts: Array[String] = []
	if _curse_slow_rem > 0.0:
		parts.append("移速↓")
	if _curse_weak_rem > 0.0:
		parts.append("输出↓")
	if _curse_no_pickup_rem > 0.0:
		parts.append("禁拾取")
	if parts.is_empty():
		return ""
	return "诅咒：" + " ".join(parts)


func get_hud_relic_line_text() -> String:
	var parts: Array[String] = []
	if not run_relic_id.is_empty():
		var n1 := GameDB.run_relic_display_name(run_relic_id)
		if not n1.is_empty():
			parts.append("开局 " + n1)
	if not run_relic_second_id.is_empty():
		var n2 := GameDB.run_relic_display_name(run_relic_second_id)
		if not n2.is_empty():
			parts.append("追加 " + n2)
	if parts.is_empty():
		return ""
	return "遗物：" + " · ".join(parts)


func get_hud_archetype_line_text() -> String:
	if run_archetype_id.is_empty() or not RUN_ARCHETYPES.has(run_archetype_id):
		return ""
	match run_archetype_id:
		"assault":
			return "专精：突击 | 移速↑ 冲刺CD↓"
		"guardian":
			return "专精：守护 | 减伤↑ 生命成长↑"
		"hunter":
			return "专精：猎杀 | 暴击↑ 吸血↑ 击杀回复"
		_:
			var def: Dictionary = RUN_ARCHETYPES[run_archetype_id]
			return "专精：" + String(def.get("name", run_archetype_id))


func get_run_archetype_id() -> String:
	return run_archetype_id


func _pool_relic_ids_for_bonus_drop() -> Array[String]:
	var out: Array[String] = []
	for rid in GameDB.RUN_RELICS.keys():
		var rs := String(rid)
		if not MetaProgress.is_run_relic_unlocked_for_pool(rs):
			continue
		if rs == run_relic_id or rs == run_relic_second_id:
			continue
		out.append(rs)
	return out


func try_grant_run_relic_from_chest(_chest_pos: Vector2, source: String = "treasure_box") -> bool:
	if not run_relic_second_id.is_empty():
		return false
	if run_relic_id.is_empty():
		return false
	var pool := _pool_relic_ids_for_bonus_drop()
	if pool.is_empty():
		return false
	pool.shuffle()
	var pick := pool[0]
	run_relic_second_id = pick
	RunStats.set_current_run_relic_second(pick)
	var def: Dictionary = GameDB.RUN_RELICS[pick]
	var stat_add: Dictionary = def.get("stat_add", {}) as Dictionary
	var ss: Node = _game.get_node_or_null("SkillSystem")
	if ss and ss.has_method("merge_run_relic_stat_add"):
		ss.call("merge_run_relic_stat_add", stat_add)
	var nm := String(def.get("name", pick))
	var ds := String(def.get("desc", ""))
	if not cmdline_headless():
		var headline := "宝箱遗物"
		match source:
			"curse_altar":
				headline = "诅咒祭坛析出遗物"
			"healing_shrine":
				headline = "治愈祭坛析出遗物"
			_:
				headline = "宝箱遗物"
		NotificationSystem.notify_message("%s：%s\n%s" % [headline, nm, ds], 2.8, "achievement")
	var pl := _game.get_node_or_null("Player")
	if pl:
		EventBus.play_sfx.emit(&"upgrade_pick", pl.global_position)
	return true
