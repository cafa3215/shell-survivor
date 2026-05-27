extends Node2D
class_name Game

# ============================================
# 游戏主循环 - 导演系统/升级/BOSS/渲染
# HP由Player统一管理，Game只读取
# ============================================


const _RUN_LOADOUT := preload("res://scripts/core/RunLoadout.gd")
const _GAME_DIRECTOR := preload("res://scripts/core/GameDirector.gd")

var _loadout: Node
var _director: Node

var _director_mul: float:
	get:
		return _director.director_mul if _director else 1.0

var _xp_bonus_mul: float:
	get:
		return _director.xp_bonus_mul if _director else 1.0

var level := 1
var xp := 0
var xp_need := 12
var elapsed := 0.0
var map_index := 0
var _boss_spawned := false
var _ended := false
var _endless_mode := false  # BOSS击杀后进入无尽模式
var _post_process_rect: ColorRect
var _mini_boss_spawned: Array[int] = []  # 已触发的中BOSS时间索引
var _boss_draw_prev_alive := false  # BOSS 死亡后需再 redraw 一次以清掉 _draw 内容
var _last_pp_quality: Settings.Quality = Settings.Quality.MEDIUM
var _endless_supply_acc := 0.0  # 无尽阶段补给计时
var _dc_kill_streak := 0
var _dc_kill_streak_decay := 0.0
var _run_milestone_done: Dictionary = {}
var _kill_combo_callout_done: Dictionary = {}
var _hunter_archetype_fx_cd := 0.0
## 地图修饰（R10）：经验球拾取倍率 + 开局一句提示
var map_xp_pickup_mul := 1.0
var _map_hint := ""
## 约每 2～3 分钟一次的「节律补给」非刷怪决策点（R1）
var _next_decision_pulse_sec := 95.0
var _spawn_acc := 0.0
var _spawn_interval_sec := 0.12
## 首局前 3 分钟节奏脚本：用于加快“进入状态”的速度
var _early_flow_flags: Dictionary = {}
const _EARLY_FLOW_CFG_PATH := "res://assets/config/early_flow_card.json"
const _EARLY_FLOW_DEFAULT_CFG := {
	"spark_45_orb_count": 5,
	"spark_45_orb_value": 2,
	"spark_45_radius": 110.0,
	"spark_140_orb_count": 6,
	"spark_140_orb_value": 3,
	"spark_140_radius": 130.0
}
const _EARLY_FLOW_PRESET_KEYS := ["soft", "normal", "hardcore"]
var _early_flow_cfg: Dictionary = {}
var _adaptive_rescue_tick := 0.0

func _ready() -> void:
	get_tree().paused = false
	_load_early_flow_cfg()
	var last_map_i := GameDB.MAP_TEMPLATES.size() - 1
	var max_allowed := mini(last_map_i, MetaProgress.unlocked_map_upto)
	map_index = clampi(Settings.selected_map_index, 0, max_allowed)

	var map_cfg: Dictionary = GameDB.MAP_TEMPLATES[map_index]
	map_xp_pickup_mul = float(map_cfg.get("xp_pickup_mul", 1.0))
	_map_hint = String(map_cfg.get("hint", ""))
	$Player.add_to_group("player")
	EventBus.xp_collected.connect(_on_xp_collected)
	# 不再监听 player_damaged 来扣HP（由Player自行管理）
	# 仅用于HUD更新和音效
	EventBus.player_damaged.connect(_on_player_damaged_hud)
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_killed.connect(_on_enemy_killed_game)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.boss_spawned.connect(func():
		EventBus.play_sfx.emit(&"boss_warning", $Player.global_position)
	)
	
	# 视觉特效事件
	EventBus.screen_shake.connect(_on_screen_shake)
	EventBus.area_knockback.connect(_on_area_knockback)
	EventBus.screen_flash.connect(_on_screen_flash)
	EventBus.level_up.connect(_on_level_up)
	EventBus.game_over.connect(_on_game_over_internal)
	if not EventBus.fusion_applied.is_connected(_on_fusion_feedback):
		EventBus.fusion_applied.connect(_on_fusion_feedback)
	if not EventBus.graphics_quality_changed.is_connected(_on_graphics_quality_changed):
		EventBus.graphics_quality_changed.connect(_on_graphics_quality_changed)
	call_deferred("_ensure_runtime_visibility")
	
	# 播放BGM
	EventBus.play_music.emit(&"bgm_main")
	
	# 后处理初始化
	_post_process_rect = get_node_or_null("PostProcess/PostProcessRect")
	if _post_process_rect:
		_post_process_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_last_pp_quality = Settings.quality
	_apply_post_process_quality()
	
	# 初始化随机事件系统
	var random_events: Node = get_node_or_null("RandomEvents")
	if random_events == null:
		# 如果场景中没有RandomEvents节点，动态创建
		random_events = preload("res://scripts/core/RandomEvents.gd").new()
		random_events.name = "RandomEvents"
		add_child(random_events)
	_loadout = _RUN_LOADOUT.new()
	_loadout.name = "RunLoadout"
	add_child(_loadout)
	_loadout.bind(self)
	_director = _GAME_DIRECTOR.new()
	_director.name = "GameDirector"
	add_child(_director)
	_director.bind(self)

	call_deferred("_begin_run_loadout")


func _begin_run_loadout() -> void:
	_loadout.begin_archetype_pick_sequence()


func apply_world_curse(kind: String, duration_sec: float) -> void:
	_loadout.apply_world_curse(kind, duration_sec)


func get_curse_move_speed_mul() -> float:
	return _loadout.get_curse_move_speed_mul()


func get_curse_outgoing_damage_mul() -> float:
	return _loadout.get_curse_outgoing_damage_mul()


func is_curse_blocking_xp_pickup() -> bool:
	return _loadout.is_curse_blocking_xp_pickup()


func get_curse_hud_hint() -> String:
	return _loadout.get_curse_hud_hint()


func get_hud_relic_line_text() -> String:
	return _loadout.get_hud_relic_line_text()


func get_hud_archetype_line_text() -> String:
	return _loadout.get_hud_archetype_line_text()


func get_run_archetype_id() -> String:
	return _loadout.get_run_archetype_id()


func try_grant_run_relic_from_chest(chest_pos: Vector2, source: String = "treasure_box") -> bool:
	return _loadout.try_grant_run_relic_from_chest(chest_pos, source)


func _on_boss_defeated() -> void:
	RunStats.boss_defeat_sec = int(elapsed)
	_endless_mode = true
	_endless_supply_acc = 0.0
	EventBus.play_music.emit(&"bgm_main")
	NotificationSystem.notify_message("首领击破！无尽尸潮开始 — 坚持至计时结束即可撤离胜利", 4.0, "achievement")

func _trigger_endless_supply() -> void:
	var pl := $Player
	if pl == null:
		return
	if pl.has_method("heal"):
		pl.heal(float(pl.max_hp) * 0.035)
	var ex := get_node_or_null("ExperienceSystem")
	if ex and ex.has_method("spawn_orb"):
		var p: Vector2 = pl.global_position
		for _i in 3:
			ex.spawn_orb(p + Vector2(randf_range(-55.0, 55.0), randf_range(-55.0, 55.0)), 2)
	NotificationSystem.notify_message("无尽补给：恢复生命 + 经验球", 1.6, "success")
	# 无尽补给提示改为更克制的青绿，避免蓝圈抢屏。
	EventBus.screen_flash.emit(Color(0.46, 0.82, 0.62, 0.14), 0.1)

func _on_graphics_quality_changed(_q: int) -> void:
	_apply_post_process_quality()
	_last_pp_quality = Settings.quality


func pressure_relief_ratio() -> float:
	return _director.pressure_relief_ratio()


func _deferred_run_opening_tip() -> void:
	if _ended:
		return
	var body := "首局目标循环：吸球升级 → 选清场/保命 → 撑过下一波。坚持到右上角计时结束即可撤离。"
	if not _map_hint.is_empty():
		body += "\n" + _map_hint
	if map_xp_pickup_mul > 1.01:
		body += "\n本图经验球拾取 ×%.0f%%。" % (map_xp_pickup_mul * 100.0)
	if not _loadout.run_relic_id.is_empty():
		var rdef2: Dictionary = GameDB.RUN_RELICS.get(_loadout.run_relic_id, {}) as Dictionary
		if not rdef2.is_empty():
			body += "\n开局遗物：" + String(rdef2.get("name", _loadout.run_relic_id))
	NotificationSystem.notify_message(body, 4.4, "success")


func _load_early_flow_cfg() -> void:
	_early_flow_cfg = _EARLY_FLOW_DEFAULT_CFG.duplicate(true)
	if not FileAccess.file_exists(_EARLY_FLOW_CFG_PATH):
		return
	var f := FileAccess.open(_EARLY_FLOW_CFG_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	if txt.is_empty():
		return
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var ext: Dictionary = parsed
	var use_preset := "normal"
	if "early_flow_preset" in Settings:
		match int(Settings.early_flow_preset):
			Settings.EarlyFlowPreset.SOFT:
				use_preset = "soft"
			Settings.EarlyFlowPreset.HARDCORE:
				use_preset = "hardcore"
			_:
				use_preset = "normal"
	elif ext.has("preset"):
		use_preset = String(ext.get("preset", "normal")).to_lower()
	if ext.has("preset"):
		# 当未接入 Settings 时，仍支持 json preset 兜底
		if not ("early_flow_preset" in Settings):
			use_preset = String(ext.get("preset", "normal")).to_lower()
	if not _EARLY_FLOW_PRESET_KEYS.has(use_preset):
		use_preset = "normal"
	var profiles: Dictionary = {}
	if ext.has("profiles") and typeof(ext["profiles"]) == TYPE_DICTIONARY:
		profiles = ext["profiles"] as Dictionary
	if profiles.has(use_preset) and typeof(profiles[use_preset]) == TYPE_DICTIONARY:
		var p: Dictionary = profiles[use_preset] as Dictionary
		for k in p.keys():
			_early_flow_cfg[String(k)] = p[k]
	# 允许在根层继续覆盖，用于快速微调
	for k in _EARLY_FLOW_DEFAULT_CFG.keys():
		if ext.has(k):
			_early_flow_cfg[String(k)] = ext[k]


func _ef_i(key: String, fallback: int) -> int:
	return int(_early_flow_cfg.get(key, fallback))


func _ef_f(key: String, fallback: float) -> float:
	return float(_early_flow_cfg.get(key, fallback))


func _tick_early_flow_script() -> void:
	if _ended:
		return
	if elapsed > 180.0:
		return
	var ex := get_node_or_null("ExperienceSystem")
	var p := $Player
	# 0:20 再次强调可执行目标，避免“我该做什么”的迷茫
	if elapsed >= 20.0 and not _early_flow_flags.get("goal_loop_20s", false):
		_early_flow_flags["goal_loop_20s"] = true
		NotificationSystem.notify_message("现在优先：贴近吸球，尽快升到下一次三选一。", 2.0, "info")
	# 0:45 给予一次轻量爆发节点（经验球 + 轻反馈），降低前期平淡感
	if elapsed >= 45.0 and not _early_flow_flags.get("spark_45s", false):
		_early_flow_flags["spark_45s"] = true
		if ex and ex.has_method("spawn_orb") and p:
			var c45 := maxi(0, _ef_i("spark_45_orb_count", 5))
			var v45 := maxi(1, _ef_i("spark_45_orb_value", 2))
			var r45 := maxf(30.0, _ef_f("spark_45_radius", 110.0))
			for _i in c45:
				ex.spawn_orb(
					p.global_position + Vector2(randf_range(-r45, r45), randf_range(-r45, r45)),
					v45
				)
		NotificationSystem.notify_message("节奏加速：附近出现经验球，吸满准备构筑。", 2.0, "item")
		CombatFeedback.flash(Color(0.52, 0.88, 0.72, 0.14), 0.08, "subtle")
	# 1:20 给出明确优先级建议，让玩家知道“这次升级先拿什么”
	if elapsed >= 80.0 and not _early_flow_flags.get("tip_80s", false):
		_early_flow_flags["tip_80s"] = true
		NotificationSystem.notify_message("首局建议：前两次升级优先清场/移速，先把节奏跑起来。", 2.3, "success")
	# 2:20 再打一针短促爽点，给前3分钟一个可感知换挡
	if elapsed >= 140.0 and not _early_flow_flags.get("spark_140s", false):
		_early_flow_flags["spark_140s"] = true
		if ex and ex.has_method("spawn_orb") and p:
			var c140 := maxi(0, _ef_i("spark_140_orb_count", 6))
			var v140 := maxi(1, _ef_i("spark_140_orb_value", 3))
			var r140 := maxf(30.0, _ef_f("spark_140_radius", 130.0))
			for _i in c140:
				ex.spawn_orb(
					p.global_position + Vector2(randf_range(-r140, r140), randf_range(-r140, r140)),
					v140
				)
		NotificationSystem.notify_message("节奏换挡：吸球并预留走位，准备下一轮高压。", 2.2, "achievement")
		CombatFeedback.shake("ui", 2.4, 0.08)
	# 6:30 中盘前确认（给出明确打法建议）
	if elapsed >= 390.0 and not _early_flow_flags.get("tip_390s", false):
		_early_flow_flags["tip_390s"] = true
		NotificationSystem.notify_message("中盘建议：优先清远程/召唤，再回头收经验。", 2.2, "warning")
	# 9:00 高压前补给一次，降低中期断档
	if elapsed >= 540.0 and not _early_flow_flags.get("spark_540s", false):
		_early_flow_flags["spark_540s"] = true
		if ex and ex.has_method("spawn_orb") and p:
			for _i in 5:
				ex.spawn_orb(
					p.global_position + Vector2(randf_range(-120.0, 120.0), randf_range(-120.0, 120.0)),
					3
				)
		NotificationSystem.notify_message("高压前补给：抓紧吸球，准备接下一轮增压。", 2.1, "item")
		CombatFeedback.flash(Color(0.5, 0.86, 0.7, 0.12), 0.08, "subtle")


func _on_fusion_feedback(_fid: StringName) -> void:
	var p := $Player
	var pos: Vector2 = p.global_position if p else Vector2.ZERO
	NotificationSystem.notify_message("融合激活：火力质变 — 清屏节奏拉满。", 2.9, "achievement")
	CombatFeedback.flash(Color(0.92, 0.48, 1.0, 0.38), 0.22, "strong")
	CombatFeedback.shake("mega", 5.4, 0.16)
	EventBus.play_sfx.emit(&"upgrade_pick", pos)


func _ensure_runtime_visibility() -> void:
	var p := $Player
	if p:
		p.visible = true
		p.modulate = Color.WHITE
		if p.has_node("Camera2D"):
			var cam := p.get_node("Camera2D") as Camera2D
			if cam:
				cam.enabled = true
				cam.make_current()
	var hud := $HUD
	if hud:
		hud.visible = true

func _on_screen_shake(strength: float, duration: float) -> void:
	var camera := $Player.get_node_or_null("Camera2D") as CameraShake
	if camera:
		camera.shake(strength, duration)

func _on_area_knockback(center: Vector2, radius: float, force: float) -> void:
	$EnemyManager.apply_knockback(center, radius, force)

func _on_screen_flash(color: Color, duration: float) -> void:
	if not Settings.enable_screen_flash:
		return
	var hud := $HUD
	if hud and hud.has_node("Root/DamageFlash"):
		var flash := hud.get_node("Root/DamageFlash")
		if flash is CanvasItem:
			var canvas := flash as CanvasItem
			if flash is ColorRect:
				(flash as ColorRect).color = color
			canvas.modulate = Color(color.r, color.g, color.b, 0.2)
			canvas.visible = true
			var tween := create_tween()
			tween.tween_property(canvas, "modulate:a", 0.0, duration)
			tween.tween_callback(func() -> void:
				if is_instance_valid(canvas):
					canvas.visible = false
			)

func _on_enemy_killed_game(kind: StringName) -> void:
	RunStats.add_kill(kind)
	EventBus.play_sfx.emit(&"enemy_death", Vector2.ZERO)
	_maybe_threat_relief_on_kill(String(kind))
	_dc_kill_streak += 1
	_dc_kill_streak_decay = GameDB.DC_KILL_STREAK_WINDOW_SEC
	var bonus: float = clampf(
		float(_dc_kill_streak) * GameDB.DC_KILL_STREAK_SPEED_PER_KILL,
		0.0,
		GameDB.DC_KILL_STREAK_SPEED_CAP
	)
	var pl := $Player
	if pl and pl.has_method("set_kill_momentum_mul"):
		pl.set_kill_momentum_mul(1.0 + bonus)
	if pl and pl.has_method("get_archetype_kill_heal_flat") and pl.has_method("heal"):
		var heal_on_kill := float(pl.call("get_archetype_kill_heal_flat"))
		if heal_on_kill > 0.01:
			pl.call("heal", heal_on_kill)
			if _hunter_archetype_fx_cd <= 0.0:
				_hunter_archetype_fx_cd = 0.9
				EventBus.screen_flash.emit(Color(1.0, 0.45, 0.45, 0.14), 0.08)
				NotificationSystem.notify_message("猎杀专精：收割回复", 0.75, "item")
	if _dc_kill_streak > 0 and _dc_kill_streak % 14 == 0:
		CombatFeedback.shake("ui", 2.2, 0.08)
	_maybe_kill_combo_feedback()


func _maybe_threat_relief_on_kill(kind_s: String) -> void:
	_director.maybe_threat_relief_on_kill(kind_s, elapsed)


func pressure_relief_summary_line() -> String:
	return _director.pressure_relief_summary_line()


func _on_level_up(level: int) -> void:
	var particle_mgr := get_node_or_null("ParticleManager") as ParticleManager
	if particle_mgr:
		particle_mgr.level_up_effect($Player.global_position)
	EventBus.screen_flash.emit(Color(0.72, 0.82, 0.68, 1.0), 0.14)
	CombatFeedback.shake("heavy", 2.85, 0.1)
	EventBus.play_sfx.emit(&"level_up", $Player.global_position)
	if randf() < 0.48 and GameDB.DC_LEVEL_FLAVOR_LINES.size() > 0:
		var line: String = GameDB.DC_LEVEL_FLAVOR_LINES[randi() % GameDB.DC_LEVEL_FLAVOR_LINES.size()]
		NotificationSystem.notify_message(line, 1.45, "item")


func _maybe_kill_combo_feedback() -> void:
	var s := _dc_kill_streak
	var tiers := [8, 15, 25, 40, 60, 90, 120]
	for tier in tiers:
		if s != tier:
			continue
		var k := "combo_%d" % int(tier)
		if _kill_combo_callout_done.get(k, false):
			return
		_kill_combo_callout_done[k] = true
		NotificationSystem.notify_message("清场节奏 · %d 连杀！" % s, 1.45, "achievement")
		CombatFeedback.shake("ui", 2.35, 0.07)
		EventBus.play_sfx.emit(&"hit", $Player.global_position if $Player else Vector2.ZERO)
		return


func _tick_engagement_milestones() -> void:
	if _ended:
		return
	var t := elapsed
	var boss_t: float = float(GameDB.BOSS_SPAWN_TIME)
	var run_t: float = float(GameDB.RUN_TIME_SECONDS)
	var milestones: Array = [
		["m_55", 55.0, "提示：优先把经验球吸进身 — 升级三选一比硬刮怪更划算。", 2.6, "info"],
		["m_130", 130.0, "两分钟档：种类会开始变花，留走位别贪刀。", 2.4, "warning"],
		["m_300", 300.0, "五分钟节点：精英头目要来了，先拉开空间。", 2.8, "warning"],
		["m_600", 600.0, "十分钟：压力会上一个台阶，保命优先。", 2.5, "warning"],
		["m_900", 900.0, "十五分钟：构筑该成型了，留意地图光点事件。", 2.6, "item"],
		["m_boss2m", boss_t - 120.0, "约 2 分钟后 BOSS 登场 — 建议先清场、补等级。", 3.2, "warning"],
		["m_boss45", boss_t - 45.0, "BOSS 将近：检查血量与走位，准备拉长距离。", 2.8, "warning"],
		["m_ext3", run_t - 200.0, "最后约三分半：节奏收紧，优先保命与吸球。", 3.0, "achievement"],
		["m_ext1", run_t - 60.0, "最后 60 秒：坚持住即可胜利撤离！", 2.6, "achievement"],
	]
	for row in milestones:
		var key: String = String(row[0])
		if _run_milestone_done.get(key, false):
			continue
		if t < float(row[1]):
			continue
		_run_milestone_done[key] = true
		NotificationSystem.notify_message(String(row[2]), float(row[3]), String(row[4]))


func _tick_decision_pulse_rewards() -> void:
	if _ended:
		return
	if elapsed < _next_decision_pulse_sec:
		return
	_next_decision_pulse_sec = elapsed + randf_range(108.0, 168.0)
	_trigger_decision_pulse_reward()


func _trigger_decision_pulse_reward() -> void:
	var pl := $Player
	if pl == null:
		return
	NotificationSystem.notify_message(
		"节律补给：已在周围撒经验球 — 吸满准备下一波构筑选择。",
		2.75,
		"item"
	)
	var ex := get_node_or_null("ExperienceSystem")
	if ex and ex.has_method("spawn_orb"):
		for _i in 7:
			ex.spawn_orb(
				pl.global_position + Vector2(randf_range(-140.0, 140.0), randf_range(-140.0, 140.0)),
				3
			)
	EventBus.play_sfx.emit(&"level_up", pl.global_position)
	CombatFeedback.flash(Color(0.48, 0.86, 0.68, 0.14), 0.1, "subtle")
	CombatFeedback.shake("hit", 2.6, 0.08)


func _process(delta: float) -> void:
	_loadout.tick_curses(delta)
	if Settings.quality != _last_pp_quality:
		_last_pp_quality = Settings.quality
		_apply_post_process_quality()
	# 降压回馈衰减（不做数值爆炸，只让玩家“短时喘口气”）
	_update_relief_post_process()
	if _dc_kill_streak_decay > 0.0:
		_dc_kill_streak_decay -= delta
		if _dc_kill_streak_decay <= 0.0:
			_dc_kill_streak = 0
			_kill_combo_callout_done.clear()
			var pl2 := $Player
			if pl2 and pl2.has_method("set_kill_momentum_mul"):
				pl2.set_kill_momentum_mul(1.0)
	elapsed += delta
	_director.tick(delta, elapsed, level, _ended, _boss_spawned, _endless_mode)
	RunStats.runtime_sec = int(elapsed)
	_tick_early_flow_script()
	_tick_adaptive_rescue(delta)
	_tick_engagement_milestones()
	_tick_decision_pulse_rewards()

	# 游戏已结束，仅保留最小更新
	if _ended:
		$HUD.set_runtime(int(elapsed))
		$HUD.set_extraction_countdown(-1)
		return
	
	# 胜利条件：存活至撤离时间（与 BOSS 是否已死无关；BOSS 死后进入无尽直至此处）
	if elapsed >= GameDB.RUN_TIME_SECONDS:
		_ended = true
		_dc_kill_streak = 0
		_dc_kill_streak_decay = 0.0
		var plw := $Player
		if plw and plw.has_method("set_kill_momentum_mul"):
			plw.set_kill_momentum_mul(1.0)
		EventBus.game_over.emit(true)
		return
	
	# 无尽阶段：周期性补给（略降暴毙率、奖励走位）
	if _endless_mode:
		_endless_supply_acc += delta
		var hp_ratio_now := float($Player.hp) / maxf(1.0, float($Player.max_hp))
		var supply_interval := float(GameDB.ENDLESS_SUPPLY_INTERVAL_SEC)
		if hp_ratio_now < 0.35:
			supply_interval *= 0.72
		elif hp_ratio_now > 0.82:
			supply_interval *= 1.12
		if _director_mul > 1.45:
			supply_interval *= 0.9
		supply_interval = clampf(supply_interval, 18.0, 60.0)
		if _endless_supply_acc >= supply_interval:
			_endless_supply_acc = 0.0
			_trigger_endless_supply()
	
	# ========== BOSS战特殊机制 ==========
	if _boss_spawned and $EnemyManager.boss_alive():
		var boss_intensity: float = 1.0 + (1.0 - $EnemyManager.boss_hp_ratio()) * 0.5
		if randf() < 0.01 * boss_intensity:
			_spawn_enraged_wave()
	
	if (not _boss_spawned) and elapsed >= GameDB.BOSS_SPAWN_TIME:
		_boss_spawned = true
		RunStats.boss_spawn_sec = int(elapsed)
		$EnemyManager.spawn_boss($Player.global_position + Vector2(0, -420))
		EventBus.play_music.emit(&"bgm_boss")
	
	# 中BOSS机制：5/10/15分钟出现精英BOSS
	for i in GameDB.MINI_BOSS_TIMES.size():
		if not _mini_boss_spawned.has(i) and elapsed >= GameDB.MINI_BOSS_TIMES[i]:
			_mini_boss_spawned.append(i)
			_spawn_mini_boss(i)
	
	var target := _target_enemy_count()
	# 无尽模式：敌人压力持续增长
	if _endless_mode:
		target += int(elapsed / 60.0) * 50
	var enemy_alive: int = $EnemyManager.alive_count()
	if enemy_alive < target:
		var pressure_mul := 1.0 + clampf((_director_mul - 1.0) * 0.7, 0.0, 0.8)
		_spawn_acc += delta * pressure_mul
		var runtime_spawn_interval := _spawn_interval_sec / maxf(_director.spawn_perf_multiplier(), 0.1)
		if _spawn_acc >= runtime_spawn_interval:
			_spawn_acc = fmod(_spawn_acc, runtime_spawn_interval)
			var deficit := target - enemy_alive
			var batch := int(round(float(_spawn_batch_size(deficit, enemy_alive)) * _director.spawn_perf_multiplier()))
			batch = maxi(1, batch) if deficit > 0 else 0
			if batch > 0:
				_spawn_wave(batch)
	
	# 从Player读取HP（单一数据源）
	var player_hp := float($Player.hp)
	var player_max_hp := float($Player.max_hp)
	$HUD.set_runtime(int(elapsed))
	$HUD.set_hp(player_hp, player_max_hp)
	$HUD.set_level(level)
	$HUD.set_xp(xp, xp_need)
	$HUD.set_enemy_count(enemy_alive)
	$HUD.set_director_info(_director_mul, _xp_bonus_mul, elapsed, $EnemyManager.boss_alive(), pressure_relief_ratio())
	$HUD.set_boss_info($EnemyManager.boss_alive(), $EnemyManager.boss_hp_ratio(), $EnemyManager.boss_phase())
	$HUD.set_endless(_endless_mode)
	var time_to_extract: float = GameDB.RUN_TIME_SECONDS - elapsed
	if time_to_extract <= float(GameDB.EXTRACTION_ALERT_BEFORE_SEC) and time_to_extract > 0.0:
		$HUD.set_extraction_countdown(int(ceil(time_to_extract)))
	else:
		$HUD.set_extraction_countdown(-1)
	if Input.is_action_just_pressed("pause"):
		EventBus.toggle_pause_requested.emit()
	# BOSS 立绘由 _draw 绘制：仅在有 BOSS 或 BOSS 刚死时重绘，避免每帧 CanvasItem 全量绘制
	var boss_vis: bool = $EnemyManager.boss_alive()
	if boss_vis:
		queue_redraw()
		_boss_draw_prev_alive = true
	elif _boss_draw_prev_alive:
		queue_redraw()
		_boss_draw_prev_alive = false


func _tick_adaptive_rescue(delta: float) -> void:
	# 前10分钟若明显落后，给轻量应急补偿，避免连续崩盘。
	if _ended or elapsed > 600.0:
		return
	_adaptive_rescue_tick -= delta
	if _adaptive_rescue_tick > 0.0:
		return
	_adaptive_rescue_tick = 7.5
	var hp_ratio := float($Player.hp) / maxf(1.0, float($Player.max_hp))
	var level_target := int(round(GameDB.director_expected_level(elapsed)))
	var behind := level_target - level
	if hp_ratio > 0.38 and behind < 2:
		return
	var ex := get_node_or_null("ExperienceSystem")
	if ex and ex.has_method("spawn_orb"):
		for _i in 3:
			ex.spawn_orb(
				$Player.global_position + Vector2(randf_range(-90.0, 90.0), randf_range(-90.0, 90.0)),
				2
			)
	if hp_ratio < 0.28 and $Player.has_method("heal"):
		$Player.heal(float($Player.max_hp) * 0.015)
	if not _early_flow_flags.get("adaptive_rescue_tip", false):
		_early_flow_flags["adaptive_rescue_tip"] = true
		NotificationSystem.notify_message("稳住节奏：先吸球升级，再处理高威胁单位。", 1.8, "success")

# 仅用于HUD音效和统计，不再扣HP
func _on_player_damaged_hud(amount: float) -> void:
	RunStats.add_damage_taken(amount)
	EventBus.play_sfx.emit(&"player_damage", $Player.global_position)

func _on_player_died() -> void:
	if not _ended:
		_ended = true
		EventBus.game_over.emit(false)

func _spawn_wave(spawn_override: int = -1) -> void:
	var p: Vector2 = $Player.global_position
	var map_cfg: Dictionary = GameDB.MAP_TEMPLATES[map_index]
	var lvl_pressure := int(level / 4)
	var n := 4 + GameDB.director_wave_time_bonus(elapsed) + lvl_pressure + (2 if elapsed > 600.0 else 0)
	n = int(round(float(n) * _director_mul))
	# 8~16 分钟中盘平滑：先稳住尖峰，再逐步回压，避免连续高压窗口叠加。
	if elapsed >= 480.0 and elapsed <= 960.0:
		var mid_u := clampf((elapsed - 480.0) / 480.0, 0.0, 1.0)
		var mid_mul := lerpf(0.82, 0.95, mid_u)
		n = int(round(float(n) * mid_mul))
		# 当导演倍率偏高且血量偏低时，再给轻量缓冲，提升“可回稳”概率。
		var hp_ratio := float($Player.hp) / maxf(1.0, float($Player.max_hp))
		if _director_mul > 1.22 and hp_ratio < 0.55:
			n = maxi(3, n - 2)
	# 无尽模式额外敌人波次
	if _endless_mode:
		var endless_u := _endless_runtime_minutes()
		var endless_bonus := int(elapsed / 120.0) * 2
		# 无尽后段（约 8 分钟）把增量从“硬拉高”改成“可呼吸爬升”。
		if endless_u >= 8.0:
			endless_bonus = int(round(float(endless_bonus) * 0.72))
		elif endless_u >= 5.0:
			endless_bonus = int(round(float(endless_bonus) * 0.84))
		n += endless_bonus
	match Settings.quality:
		Settings.Quality.LOW:
			n = maxi(3, n - 2)
		Settings.Quality.HIGH:
			n += 2
		_:
			pass
	if spawn_override > 0:
		n = mini(n, spawn_override)
	for _i in n:
		var angle := randf() * TAU
		var dist := randf_range(float(map_cfg["spawn_radius_min"]), float(map_cfg["spawn_radius_max"]))
		var pos: Vector2 = p + Vector2(cos(angle), sin(angle)) * dist
		$EnemyManager.spawn_enemy(pos, _roll_enemy_kind(elapsed, float(map_cfg["ranged_weight"])))

# BOSS战期间的特殊波次 - 更强大的敌人
func _spawn_enraged_wave() -> void:
	var p: Vector2 = $Player.global_position
	var map_cfg: Dictionary = GameDB.MAP_TEMPLATES[map_index]
	
	# 生成一波精英/特殊敌人
	var enraged_count := 3 + randi() % 3
	for _i in enraged_count:
		var angle := randf() * TAU
		var dist := randf_range(500.0, 800.0)
		var pos: Vector2 = p + Vector2(cos(angle), sin(angle)) * dist
		# BOSS战期间更多精英和召唤师
		var enemy_type: int
		var roll := randf()
		if roll < 0.3:
			enemy_type = 9  # 精英
		elif roll < 0.5:
			enemy_type = 6  # 召唤师
		elif roll < 0.7:
			enemy_type = 7  # 冲刺者
		else:
			enemy_type = 8  # 暗影
		
		$EnemyManager.spawn_enemy(pos, enemy_type)
	
	# 显示通知
	NotificationSystem.notify_message("敌人增援！", 1.5, "warning")
	CombatFeedback.shake("heavy", 2.8, 0.09)
	EventBus.boss_warning.emit(0.3, 0.4)

func _target_enemy_count() -> int:
	return _director.target_enemy_count(elapsed, level, _endless_mode)


func _endless_runtime_minutes() -> float:
	if not _endless_mode:
		return 0.0
	return maxf(0.0, elapsed - float(GameDB.BOSS_SPAWN_TIME)) / 60.0


func _spawn_batch_size(deficit: int, enemy_alive: int) -> int:
	var cap := 10
	match Settings.quality:
		Settings.Quality.LOW:
			cap = 6
		Settings.Quality.MEDIUM:
			cap = 10
		Settings.Quality.HIGH:
			cap = 14
	if Settings.reduce_particles:
		cap = maxi(4, cap - 2)
	# 场上敌人很高时削峰，避免瞬时抖动
	if enemy_alive > 950:
		cap = int(round(float(cap) * 0.72))
	elif enemy_alive > 760:
		cap = int(round(float(cap) * 0.84))
	return mini(maxi(1, cap), maxi(0, deficit))


func _roll_enemy_kind(t: float, ranged_weight: float) -> int:
	var x := randf()
	var elite_bonus := clampf((_director_mul - 1.0) * 0.16, 0.0, 0.18)
	var pressure_u := clampf((_director_mul - 0.92) / 0.7, 0.0, 1.0)
	var ranged_bias := ranged_weight * (0.85 + pressure_u * 0.45)
	var boss_t := float(GameDB.BOSS_SPAWN_TIME)
	var pre_boss_soft := t >= boss_t - 180.0 and t < boss_t
	var post_boss_soft := _boss_spawned and (not _endless_mode) and t <= boss_t + 180.0
	# 无尽模式增加精英出现率
	if _endless_mode:
		elite_bonus += 0.08
	
	# ========== 分阶段导演：让 8~15 分钟出现明确“换挡感” ==========
	# 0-60秒：快速敌人出现，增加压力
	if t < 60.0:
		if x < 0.60:
			return 1 if randf() < 0.4 else 0  # 40%快速敌人
		return 0
	# 60-180秒：开始出现远程和坦克
	if t < 180.0:
		if x < 0.55:
			return 0
		if x < 0.75:
			return 1  # 快速敌人
		if x < 0.88:
			return 3 if randf() < ranged_bias else 4  # 远程或自爆
		return 2  # 坦克
	# 180-360秒：中期铺垫，开始强调远程与坦克混编
	if t < 360.0:
		if x < 0.26:
			return 0
		if x < 0.45:
			return 1
		if x < 0.63:
			return 2
		if x < 0.80:
			return 3 if randf() < ranged_bias else 4
		return 6  # 召唤师开始出现
	# 360-540秒：第一次明确换挡，召唤师/冲锋者进入主舞台
	if t < 540.0:
		if x < 0.17:
			return 0
		if x < 0.30:
			return 1
		if x < 0.45:
			return 2
		if x < 0.60:
			return 3 if randf() < ranged_bias else 4
		if x < 0.79:
			return 6
		return 7
	# 540-900秒：高压混合，暗影开始作为“阅读干扰项”
	if t < 900.0:
		# 9~11 分钟：减轻“多高威胁并发”尖峰，先给可回稳窗口。
		if t < 660.0:
			if x < 0.14:
				return 0
			if x < 0.30:
				return 1
			if x < 0.47:
				return 2
			if x < 0.63:
				return 3 if randf() < ranged_bias else 4
			if x < 0.75:
				return 6
			if x < 0.82:
				return 7
			return 6 if pre_boss_soft else 8
		# 11~13 分钟：逐步回压，保留读场空间。
		if t < 780.0:
			if x < 0.10:
				return 0
			if x < 0.22:
				return 1
			if x < 0.35:
				return 2
			if x < 0.52:
				return 3 if randf() < ranged_bias else 6
			if x < 0.63:
				return 4
			if x < 0.77:
				return 6
			if x < (0.88 if pre_boss_soft else 0.84):
				return 7
			return 6 if pre_boss_soft else 8
		# 13~15 分钟：回到高压混合，但仍保留预BOSS软化。
		if x < 0.08:
			return 0
		if x < 0.19:
			return 1
		if x < 0.32:
			return 2
		if x < 0.48:
			return 3 if randf() < ranged_bias else 6
		if x < 0.59:
			return 4
		if x < 0.73:
			return 6
		if x < (0.89 if pre_boss_soft else 0.85):
			return 7  # 冲刺者
		return 6 if pre_boss_soft else 8  # 预BOSS减少阅读干扰（暗影）
	# 900秒+：精英为主；无尽模式再抬高精英占比（与 elite_bonus 叠加）
	var endless_elite_shift := 0.09 if _endless_mode else 0.0
	var elite_threshold: float = 0.86 - elite_bonus - endless_elite_shift
	if pre_boss_soft:
		elite_threshold += 0.03
	elif post_boss_soft:
		elite_threshold += 0.02
	if x > elite_threshold:
		return 9
	# 非精英时：无尽略提高高威胁种类占比
	if _endless_mode:
		var r2 := randf()
		if r2 < 0.24:
			return 6
		if r2 < 0.49:
			return 7
		if r2 < 0.76:
			return 8
		return 5 + randi() % 2
	return 5 + randi() % 4


func _on_xp_collected(amount: int) -> void:
	var skill_stats: Dictionary = $SkillSystem.stats
	var xp_bonus := 1.0 + float(skill_stats.get("xp_bonus", 0.0))
	var amt := int(round(float(amount) * map_xp_pickup_mul))
	xp += int(round(float(amt) * _xp_bonus_mul * xp_bonus))
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		var level_factor: float = GameDB.xp_need_multiplier_for_level(level)
		xp_need = int(xp_need * level_factor + 2)
		EventBus.level_up.emit(level)
		EventBus.request_upgrade.emit()

func _on_game_over_internal(win: bool) -> void:
	if win:
		EventBus.play_sfx.emit(&"victory", Vector2.ZERO)
	else:
		EventBus.play_sfx.emit(&"defeat", Vector2.ZERO)
	EventBus.stop_music.emit()

# BOSS视觉渲染 - 高清增强版
func _draw() -> void:
	if not $EnemyManager.boss_alive():
		return
	var boss_pos: Vector2 = $EnemyManager.boss_pos()
	var time := Time.get_ticks_msec() * 0.001
	var hp_ratio: float = $EnemyManager.boss_hp_ratio()
	var phase: int = $EnemyManager.boss_phase()
	
	# 外部能量场（更柔和）
	var pulse := 1.0 + 0.05 * sin(time * 2.5)
	var aura_r := 58.0 * pulse
	draw_circle(boss_pos, aura_r, Color(0.2, 0.04, 0.04, 0.06 + 0.03 * sin(time * 1.5)))
	# 第二层能量场
	draw_circle(boss_pos, aura_r * 0.75, Color(0.3, 0.05, 0.04, 0.04 + 0.02 * sin(time * 3.0)))
	
	# 外环装饰弧线（旋转，更密集）
	var outer_rot := time * 1.5
	for i in 5:
		var a_start := outer_rot + TAU * 0.2 * float(i)
		var arc_len := PI * (0.3 + 0.2 * sin(time * 2.0 + float(i)))
		draw_arc(boss_pos, 52.0 * pulse, a_start, a_start + arc_len, 16, Color(0.9, 0.2, 0.12, 0.2), 2.5)
	
	# BOSS主体阴影
	draw_circle(boss_pos + Vector2(3, 3), 36.0, Color(0.15, 0.02, 0.02, 0.5))
	
	# BOSS主体（更大更立体）
	draw_circle(boss_pos, 36.0, Color(0.85, 0.12, 0.12, 0.95))
	# 内部渐变高光
	draw_circle(boss_pos + Vector2(-5, -5), 22.0, Color(0.95, 0.3, 0.2, 0.3))
	draw_circle(boss_pos + Vector2(-3, -3), 14.0, Color(1.0, 0.4, 0.3, 0.15))
	# 底部暗影
	draw_circle(boss_pos + Vector2(2, 4), 28.0, Color(0.4, 0.05, 0.05, 0.25))
	
	# 装甲环（多层）
	draw_arc(boss_pos, 40.0, 0.0, TAU, 40, Color(1.0, 0.35, 0.2, 0.65), 3.5)
	draw_arc(boss_pos, 34.0, 0.0, TAU, 32, Color(0.9, 0.22, 0.15, 0.35), 2.0)
	# 旋转装甲板
	for i in 4:
		var a := time * 0.8 + TAU * 0.25 * float(i)
		draw_arc(boss_pos, 37.0, a, a + PI * 0.35, 8, Color(1.0, 0.5, 0.3, 0.4), 4.0)
	
	# 裂纹装饰（BOSS身体上的裂纹线条）
	for i in 3:
		var crack_a := TAU * 0.33 * float(i) + 0.5
		var crack_start := boss_pos + Vector2(cos(crack_a), sin(crack_a)) * 12.0
		var crack_end := boss_pos + Vector2(cos(crack_a + 0.2), sin(crack_a + 0.2)) * 30.0
		draw_line(crack_start, crack_end, Color(1.0, 0.6, 0.3, 0.3), 1.5)
	
	# 面部：发光眼睛（更大更亮）
	var eye_glow := 0.7 + 0.3 * sin(time * 5.0)
	draw_circle(boss_pos + Vector2(-10, -6), 5.5, Color(1.0, 0.85, 0.25, eye_glow * 0.7))
	draw_circle(boss_pos + Vector2(10, -6), 5.5, Color(1.0, 0.85, 0.25, eye_glow * 0.7))
	# 瞳孔
	draw_circle(boss_pos + Vector2(-10, -6), 3.0, Color(1.0, 0.2, 0.0, 1.0))
	draw_circle(boss_pos + Vector2(10, -6), 3.0, Color(1.0, 0.2, 0.0, 1.0))
	# 眼睛内光点
	draw_circle(boss_pos + Vector2(-10, -7), 1.5, Color(1.0, 1.0, 0.8, eye_glow))
	draw_circle(boss_pos + Vector2(10, -7), 1.5, Color(1.0, 1.0, 0.8, eye_glow))
	
	# 嘴部裂痕（更大更深）
	draw_line(boss_pos + Vector2(-8, 8), boss_pos + Vector2(-2, 14), Color(1.0, 0.35, 0.1, 0.8), 2.5)
	draw_line(boss_pos + Vector2(-2, 14), boss_pos + Vector2(2, 12), Color(1.0, 0.35, 0.1, 0.8), 2.5)
	draw_line(boss_pos + Vector2(2, 12), boss_pos + Vector2(8, 8), Color(1.0, 0.35, 0.1, 0.8), 2.5)
	
	# 核心旋转光点（柔和版）
	var core_angle := time * 2.0
	var core_pos := boss_pos + Vector2(cos(core_angle), sin(core_angle)) * 8.0
	draw_circle(core_pos, 6.0, Color(0.9, 0.6, 0.2, 0.5))
	draw_circle(boss_pos, 8.0, Color(0.8, 0.4, 0.15, 0.35))
	# 核心闪烁
	draw_circle(boss_pos, 4.0, Color(0.9, 0.7, 0.35, 0.15 + 0.1 * sin(time * 6.0)))
	
	# 血量环（更粗更明显）
	var arc_end := TAU * hp_ratio
	var hp_color := Color(0.2, 1.0, 0.2, 0.85) if hp_ratio > 0.5 else (Color(1.0, 0.8, 0.2, 0.85) if hp_ratio > 0.25 else Color(1.0, 0.2, 0.2, 0.85))
	# 血量环背景
	draw_arc(boss_pos, 54.0, -PI/2, -PI/2 + TAU, 40, Color(0.15, 0.05, 0.05, 0.4), 3.0)
	# 血量环前景
	draw_arc(boss_pos, 54.0, -PI/2, -PI/2 + arc_end, 40, hp_color, 5.0)
	# 血量环发光
	draw_arc(boss_pos, 54.0, -PI/2, -PI/2 + arc_end, 40, Color(hp_color.r, hp_color.g, hp_color.b, 0.2), 9.0)
	
	# 阶段标记（更大更亮）
	for i in range(phase):
		var mark_angle := -PI/2 + TAU * 0.25 * float(i)
		var mark_pos := boss_pos + Vector2(cos(mark_angle), sin(mark_angle)) * 60.0
		draw_circle(mark_pos, 5.0, Color(1.0, 0.4, 0.2, 0.85))
		draw_circle(mark_pos, 3.0, Color(1.0, 0.85, 0.35, 0.95))
		# 标记脉冲
		var mark_pulse := 0.3 + 0.3 * sin(time * 4.0 + float(i))
		draw_circle(mark_pos, 8.0, Color(1.0, 0.5, 0.2, mark_pulse * 0.2))
	
	# 阶段3特效：暗能量粒子（更多更大）
	if phase >= 3:
		for i in 8:
			var p_angle := time * 1.2 + TAU * 0.125 * float(i)
			var p_r := 44.0 + 6.0 * sin(time * 3.0 + float(i))
			var p_pos := boss_pos + Vector2(cos(p_angle), sin(p_angle)) * p_r
			draw_circle(p_pos, 4.0, Color(0.6, 0.1, 0.1, 0.45 + 0.3 * sin(time * 4.0 + float(i))))
			# 粒子尾迹
			var trail_pos := boss_pos + Vector2(cos(p_angle - 0.15), sin(p_angle - 0.15)) * (p_r - 3.0)
			draw_circle(trail_pos, 2.5, Color(0.5, 0.05, 0.05, 0.2))
	
	# 阶段2+：脉动波
	if phase >= 2:
		var wave_r := 46.0 + 10.0 * sin(time * 2.5)
		var wave_alpha := 0.08 + 0.06 * sin(time * 3.0)
		draw_arc(boss_pos, wave_r, 0.0, TAU, 40, Color(0.8, 0.15, 0.1, wave_alpha), 2.0)

# 后处理画质控制
func _apply_post_process_quality() -> void:
	if _post_process_rect == null:
		return
	var mat := _post_process_rect.material as ShaderMaterial
	if mat == null:
		return
	match Settings.quality:
		Settings.Quality.LOW:
			_post_process_rect.visible = false
			mat.set_shader_parameter("dc_style_mix", 0.0)
		Settings.Quality.MEDIUM:
			_post_process_rect.visible = true
			mat.set_shader_parameter("bloom_intensity", 0.06)
			mat.set_shader_parameter("bloom_threshold", 0.88)
			mat.set_shader_parameter("chromatic_aberration", 0.032)
			mat.set_shader_parameter("scanline_strength", 0.0012)
			mat.set_shader_parameter("vignette_strength", 0.085)
			mat.set_shader_parameter("vignette_softness", 0.64)
			mat.set_shader_parameter("saturation", 0.97)
			mat.set_shader_parameter("contrast", 1.045)
			mat.set_shader_parameter("grain_strength", 0.011)
			mat.set_shader_parameter("dc_style_mix", 0.1)
		Settings.Quality.HIGH:
			_post_process_rect.visible = true
			mat.set_shader_parameter("bloom_intensity", 0.078)
			mat.set_shader_parameter("bloom_threshold", 0.86)
			mat.set_shader_parameter("chromatic_aberration", 0.042)
			mat.set_shader_parameter("scanline_strength", 0.0016)
			mat.set_shader_parameter("vignette_strength", 0.095)
			mat.set_shader_parameter("vignette_softness", 0.65)
			mat.set_shader_parameter("saturation", 0.975)
			mat.set_shader_parameter("contrast", 1.055)
			mat.set_shader_parameter("grain_strength", 0.013)
			mat.set_shader_parameter("dc_style_mix", 0.12)


func _update_relief_post_process() -> void:
	if _post_process_rect == null or not _post_process_rect.visible:
		return
	var mat := _post_process_rect.material as ShaderMaterial
	if mat == null:
		return
	# “战局回稳”时略微降躁：减轻像差/颗粒/晕影，给玩家心理“呼吸感”
	var r := pressure_relief_ratio()
	if r <= 0.001:
		return
	var ca_base := 0.045 if Settings.quality == Settings.Quality.MEDIUM else 0.055
	var grain_base := 0.011 if Settings.quality == Settings.Quality.MEDIUM else 0.013
	var vig_base := 0.085 if Settings.quality == Settings.Quality.MEDIUM else 0.095
	mat.set_shader_parameter("chromatic_aberration", lerpf(ca_base, ca_base * 0.72, r))
	mat.set_shader_parameter("grain_strength", lerpf(grain_base, grain_base * 0.68, r))
	mat.set_shader_parameter("vignette_strength", lerpf(vig_base, vig_base * 0.82, r))

# 中BOSS生成
func _spawn_mini_boss(index: int) -> void:
	var p: Vector2 = $Player.global_position
	var angle := randf() * TAU
	var pos := p + Vector2(cos(angle), sin(angle)) * 380.0
	# 随机选择精英类型（无尽：更高权重出大红精英）
	var elite_type: int
	if _endless_mode:
		elite_type = 9 if randf() < 0.82 else 7
	else:
		elite_type = 9 if randf() > 0.4 else 7  # 70%精英，30%召唤师
	var idx: int = $EnemyManager.spawn_enemy(pos, elite_type)
	if idx >= 0:
		# 强化精英为中BOSS
		$EnemyManager.hp[idx] *= GameDB.MINI_BOSS_HP_SCALE
		$EnemyManager.damage[idx] *= GameDB.MINI_BOSS_DMG_SCALE
		$EnemyManager.speed[idx] *= 0.8  # 略慢但更危险
		
		# 根据类型显示不同名称
		var boss_name := "精英BOSS" if elite_type == 9 else "召唤师BOSS"
		NotificationSystem.notify_message(boss_name + "出现！", 2.0, "warning")
		EventBus.boss_warning.emit(0.5, 0.8)
		EventBus.play_sfx.emit(&"boss_warning", p)
		
		# 掉落额外经验
		var exp_sys = get_node_or_null("ExperienceSystem")
		if exp_sys and exp_sys.has_method("spawn_orb"):
			for _i in 5:
				exp_sys.spawn_orb(pos + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 3)
