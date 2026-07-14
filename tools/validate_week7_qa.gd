extends SceneTree

## 第 7 周 QA 守卫（headless）：
## 1) 8 路构筑通关率目标区间与离散度
## 2) 三模式时间轴一致性（boss / mini-boss / 时限）
## 3) Boss 专属技能合约方法存在
## 4) Boss 战存活软顶与性能常量健全

const REQUIRED_BOSS_SPECIAL_METHODS: PackedStringArray = [
	"boss_lightning_chain",
	"boss_magma_barrage",
	"boss_shadow_afterimage",
	"boss_shadow_siphon",
	"boss_shadow_collapse",
	"boss_thunder_field",
	"_boss_choose_attack",
	"_boss_choose_shadow",
	"_boss_choose_lightning",
	"_boss_choose_magma",
	"mark_mini_boss",
]


func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	if not _check_build_balance_routes():
		quit(1)
		return
	if not _check_run_modes():
		quit(1)
		return
	if not await _check_boss_behavior_contracts():
		quit(1)
		return
	if not _check_perf_caps():
		quit(1)
		return
	if not _check_fusion_passive_sync():
		quit(1)
		return
	print("validate_week7_qa: OK")
	quit(0)


func _check_build_balance_routes() -> bool:
	var gdb := root.get_node_or_null("/root/GameDB")
	if gdb == null:
		push_error("validate_week7_qa: GameDB missing")
		return false
	var routes: Dictionary = gdb.BUILD_BALANCE_ROUTES
	if routes.size() < 8:
		push_error("validate_week7_qa: expected >=8 BUILD_BALANCE_ROUTES")
		return false
	var lo := int(gdb.BUILD_CLEAR_PCT_MIN)
	var hi := int(gdb.BUILD_CLEAR_PCT_MAX)
	var spread_max := int(gdb.BUILD_CLEAR_PCT_SPREAD_MAX)
	var min_pct := 999
	var max_pct := -999
	for wid in routes.keys():
		var row: Dictionary = routes[wid]
		var pct := int(row.get("target_clear_pct", -1))
		var power := int(row.get("power_score", -1))
		var fusion := String(row.get("fusion", ""))
		if pct < lo or pct > hi:
			push_error("validate_week7_qa: route %s clear%% %d outside %d-%d" % [String(wid), pct, lo, hi])
			return false
		if power < lo or power > hi:
			push_error("validate_week7_qa: route %s power %d outside band" % [String(wid), power])
			return false
		if not gdb.FUSIONS.has(fusion):
			push_error("validate_week7_qa: route %s missing fusion %s" % [String(wid), fusion])
			return false
		if not gdb.WEAPONS.has(wid):
			push_error("validate_week7_qa: route weapon missing " + String(wid))
			return false
		min_pct = mini(min_pct, pct)
		max_pct = maxi(max_pct, pct)
	if max_pct - min_pct > spread_max:
		push_error("validate_week7_qa: clear%% spread %d > %d" % [max_pct - min_pct, spread_max])
		return false
	return true


func _check_run_modes() -> bool:
	var gdb := root.get_node_or_null("/root/GameDB")
	for mode_id in gdb.RUN_MODES.keys():
		var cfg: Dictionary = gdb.RUN_MODES[mode_id]
		var seconds := int(cfg.get("seconds", 0))
		var boss_at := int(cfg.get("boss_at", -1))
		if seconds <= 0 or boss_at <= 0 or boss_at >= seconds:
			push_error("validate_week7_qa: mode %s bad timeline seconds=%d boss_at=%d" % [String(mode_id), seconds, boss_at])
			return false
		var minis: Array = cfg.get("mini_bosses", [])
		var prev := -1
		for t in minis:
			var ti := int(t)
			if ti <= prev or ti >= boss_at:
				push_error("validate_week7_qa: mode %s mini_boss time invalid %d" % [String(mode_id), ti])
				return false
			prev = ti
		# 归一化进度：同相对时刻应可解释
		var u_boss := float(boss_at) / float(seconds)
		if u_boss < 0.55 or u_boss > 0.90:
			push_error("validate_week7_qa: mode %s boss progress %.2f out of [0.55,0.90]" % [String(mode_id), u_boss])
			return false
	# Director 归一化与三模式独立
	var p_trial := float(gdb.run_progress_normalized(150.0, 300.0))
	var p_std := float(gdb.run_progress_normalized(300.0, 600.0))
	if absf(p_trial - p_std) > 0.02:
		push_error("validate_week7_qa: progress normalize mismatch trial vs standard")
		return false
	return true


func _check_boss_behavior_contracts() -> bool:
	var packed: Resource = ResourceLoader.load("res://scenes/Game.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("validate_week7_qa: Game.tscn load failed")
		return false
	var game := (packed as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var em := game.get_node_or_null("EnemyManager")
	if em == null:
		push_error("validate_week7_qa: EnemyManager missing")
		return false
	for m in REQUIRED_BOSS_SPECIAL_METHODS:
		if not em.has_method(m):
			push_error("validate_week7_qa: EnemyManager missing " + m)
			return false
	var game_text := FileAccess.get_file_as_string("res://scripts/core/Game.gd")
	for token in ["_start_extraction_sequence", "on_mini_boss_killed", "BOSS_FIGHT_ALIVE_SOFT_CAP", "_tick_extraction"]:
		if game_text.find(token) == -1:
			push_error("validate_week7_qa: Game.gd missing token " + token)
			return false
	game.queue_free()
	return true


func _check_perf_caps() -> bool:
	var gdb := root.get_node_or_null("/root/GameDB")
	var boss_cap := int(gdb.BOSS_FIGHT_ALIVE_SOFT_CAP)
	var combat_cap := int(gdb.COMBAT_ALIVE_PERF_SOFT_CAP)
	var pool := int(gdb.ENEMY_MAX)
	if boss_cap < 300 or boss_cap > 500:
		push_error("validate_week7_qa: BOSS_FIGHT_ALIVE_SOFT_CAP expected ~400, got %d" % boss_cap)
		return false
	if combat_cap < boss_cap:
		push_error("validate_week7_qa: COMBAT_ALIVE_PERF_SOFT_CAP < boss cap")
		return false
	if pool < combat_cap * 2:
		push_error("validate_week7_qa: ENEMY_MAX too small vs soft caps")
		return false
	return true


func _check_fusion_passive_sync() -> bool:
	var gdb := root.get_node_or_null("/root/GameDB")
	var target_lv := int(gdb.FUSION_PASSIVE_LEVEL)
	for fid in gdb.FUSIONS.keys():
		var req: Dictionary = gdb.FUSIONS[fid].get("requires", {})
		for pid in req.keys():
			var shown := int(req[pid])
			var need := int(gdb.fusion_required_passive_level(shown))
			if need > target_lv + 1:
				push_error("validate_week7_qa: fusion %s req too high" % String(fid))
				return false
			if shown > target_lv + 1:
				push_error("validate_week7_qa: fusion %s display req %d stale (want ~%d)" % [String(fid), shown, target_lv])
				return false
	return true
