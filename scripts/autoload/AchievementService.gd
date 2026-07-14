extends Node

## 局内成就 + Steam 预留挂钩（无官方 SDK 时只记本地解锁）
const SAVE_PATH := "user://achievements.cfg"

var unlocked: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	unlocked.clear()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if not cfg.has_section("achievements"):
		return
	for k in cfg.get_section_keys("achievements"):
		if bool(cfg.get_value("achievements", k, false)):
			unlocked[String(k)] = true


func _save() -> void:
	var cfg := ConfigFile.new()
	for k in unlocked.keys():
		if bool(unlocked[k]):
			cfg.set_value("achievements", String(k), true)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("AchievementService: save failed (%d)" % err)


func is_unlocked(id: String) -> bool:
	return bool(unlocked.get(id, false))


func unlocked_count() -> int:
	return unlocked.size()


func definition_count() -> int:
	return GameDB.STEAM_ACHIEVEMENTS.size()


func summary_line() -> String:
	return "成就 %d/%d" % [unlocked_count(), definition_count()]


func try_unlock(id: String) -> bool:
	if id.is_empty() or not GameDB.STEAM_ACHIEVEMENTS.has(id):
		return false
	if is_unlocked(id):
		return false
	unlocked[id] = true
	_save()
	var def: Dictionary = GameDB.STEAM_ACHIEVEMENTS[id]
	var title := String(def.get("name", id))
	NotificationSystem.notify_message("成就解锁：%s" % title, 2.6, "achievement")
	_steam_set_achievement(id)
	return true


func _steam_set_achievement(id: String) -> void:
	# 预留：导出带 Steamworks 插件且 feature=steam 时转发
	if not OS.has_feature("steam"):
		return
	if not Engine.has_singleton("Steam"):
		return
	var steam: Object = Engine.get_singleton("Steam")
	if steam != null and steam.has_method("setAchievement"):
		steam.call("setAchievement", id)
	if steam != null and steam.has_method("storeStats"):
		steam.call("storeStats")


## 胜利结算时批处理；返回本局新解锁 id 列表
func evaluate_run_end(win: bool, ctx: Dictionary) -> Array[String]:
	var fresh: Array[String] = []
	if not win:
		return fresh
	_collect(fresh, "first_win")
	var mode := String(ctx.get("run_mode_id", ""))
	match mode:
		"trial":
			_collect(fresh, "mode_trial_win")
		"standard":
			_collect(fresh, "mode_standard_win")
		"endurance":
			_collect(fresh, "mode_endurance_win")
	var diff := String(ctx.get("difficulty_id", ""))
	if diff == "nightmare":
		_collect(fresh, "diff_nightmare_win")
	var chal := String(ctx.get("challenge_id", ""))
	match chal:
		"brittle":
			_collect(fresh, "chal_brittle_win")
		"swarm":
			_collect(fresh, "chal_swarm_win")
		"glass":
			_collect(fresh, "chal_glass_win")
		"iron":
			_collect(fresh, "chal_iron_win")
		"shadow":
			_collect(fresh, "chal_shadow_win")
	if chal != "none" and chal != "" and diff == "nightmare":
		_collect(fresh, "chal_any_nightmare")
		if chal == "glass":
			_collect(fresh, "chal_glass_nightmare")
	var build_w := String(ctx.get("primary_build_weapon", ""))
	if not build_w.is_empty():
		var ach_id := "build_%s" % build_w
		_collect(fresh, ach_id)
	if _all_build_wins_done():
		_collect(fresh, "build_all_eight")
	if int(ctx.get("map_stars", 0)) >= 3:
		_collect(fresh, "map_three_stars")
	if bool(ctx.get("endless_survived", false)):
		_collect(fresh, "endless_survive")
	# 收藏向成就（无数值膨胀）
	if MetaProgress != null:
		var fuse_n := MetaProgress.fusion_seen_count()
		var fuse_cap := maxi(1, MetaProgress.fusion_total_count())
		if fuse_n * 2 >= fuse_cap:
			_collect(fresh, "codex_fusions_half")
		if MetaProgress.school_mastery_seen_count() >= GameDB.SCHOOL_MASTERY_IDS.size():
			_collect(fresh, "codex_schools_all")
	return fresh


func _collect(fresh: Array[String], id: String) -> void:
	if try_unlock(id):
		fresh.append(id)


func _all_build_wins_done() -> bool:
	for wid in GameDB.BUILD_BALANCE_ROUTES.keys():
		if not is_unlocked("build_%s" % String(wid)):
			return false
	return true


func resolve_primary_build_weapon() -> String:
	var totals: Dictionary = {}
	for route_id in GameDB.BUILD_BALANCE_ROUTES.keys():
		totals[String(route_id)] = 0.0
	for src in RunStats.top_damage_sources(24):
		var wid := _source_to_weapon(String(src))
		if totals.has(wid):
			totals[wid] = float(totals[wid]) + RunStats.damage_of_source(String(src))
	var best := ""
	var best_dmg := 0.0
	for wid in totals.keys():
		var d := float(totals[wid])
		if d > best_dmg:
			best_dmg = d
			best = String(wid)
	return best


func _source_to_weapon(source: String) -> String:
	var s := source.to_lower()
	if s.begins_with("kunai"):
		return "kunai"
	if s.begins_with("guardian") or s.begins_with("heal"):
		return "guardian"
	if s.begins_with("lightning"):
		return "lightning"
	if s.begins_with("quantum"):
		return "quantum_ball"
	if s.begins_with("drone"):
		return "drone_ab"
	if s.begins_with("molotov"):
		return "molotov"
	# 火箭 / 击杀爆炸不是平衡表八路构筑，禁止误记到燃瓶
	if s.begins_with("rocket") or s.begins_with("explosion") or s.begins_with("mine"):
		return ""
	if s.begins_with("boomerang"):
		return "boomerang"
	if s.begins_with("frost"):
		return "frost_aura"
	if s.begins_with("stun"):
		return ""
	return ""
