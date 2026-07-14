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
var run_mode_id := GameDB.DEFAULT_RUN_MODE
var run_time_seconds := 600
var boss_spawn_time := 480.0
var mini_boss_times: Array[int] = [120, 300, 420]
var difficulty_id := GameDB.DEFAULT_DIFFICULTY
var challenge_id := GameDB.DEFAULT_CHALLENGE
var _diff_enemy_hp_mul := 1.0
var _diff_enemy_dmg_mul := 1.0
var _challenge_enemy_hp_mul := 1.0
var _challenge_enemy_dmg_mul := 1.0
var _boss_spawned := false
var _ended := false
var _endless_mode := false  # 撤离成功后无尽突围
var _endless_started_elapsed := 0.0
var _mission_cleared := false  # 已完成主线撤离；无尽死亡仍算胜利
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
## 站桩检测：连续停留会提高刷怪压力
var _stationary_sec := 0.0
var _stationary_prev_pos := Vector2.ZERO
## 地图区域任务
var _zone_objective_kind := -1
var _zone_objective_target := 0
var _zone_objective_progress := 0
var _zone_objective_done := false
const _CENTER_SOFT_RADIUS := 400.0
const _FAR_SPAWN_BIAS := 0.72
## 地图可感知规则（MAP_TEMPLATES.map_rule）
var _map_rule: Dictionary = {}
var _map_rule_started := false
var _map_rule_announced := false
var _map_ring_center := Vector2.ZERO
var _map_ring_radius := 0.0
var _map_safe_target := Vector2.ZERO
var _map_safe_retarget_cd := 0.0
var _map_rule_telegraph_cd := 0.0
## 击破首领后撤离窗（标准/持久模式）
var _extraction_active := false
var _extraction_pos := Vector2.ZERO
var _extraction_remain := 0.0
var _extraction_hold := 0.0
var _extraction_telegraph_cd := 0.0
var _boss_pickup_siphon_rem := 0.0
const _EXTRACTION_WINDOW_SEC := 30.0
const _EXTRACTION_HOLD_SEC := 1.25
const _EXTRACTION_RADIUS := 95.0
## 第 6 周：宝箱第二遗物软关闭（避免同局双遗物膨胀）
const ENABLE_SECOND_CHEST_RELIC := false

func _ready() -> void:
	get_tree().paused = false
	# 先于 Player 刷新地图移动场，避免慢一帧用旧拉力
	process_priority = -20
	_load_early_flow_cfg()
	var last_map_i := GameDB.MAP_TEMPLATES.size() - 1
	var max_allowed := mini(last_map_i, MetaProgress.unlocked_map_upto)
	map_index = clampi(Settings.selected_map_index, 0, max_allowed)
	_apply_run_mode_settings()

	var map_cfg: Dictionary = GameDB.MAP_TEMPLATES[map_index]
	map_xp_pickup_mul = float(map_cfg.get("xp_pickup_mul", 1.0))
	_map_hint = String(map_cfg.get("hint", ""))
	_init_zone_objective(map_cfg)
	_init_map_rule(map_cfg)
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
	if not EventBus.game_started.is_connected(_on_run_started_kickstart):
		EventBus.game_started.connect(_on_run_started_kickstart)
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
	call_deferred("_apply_map_event_bias")
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
	if not ENABLE_SECOND_CHEST_RELIC:
		return false
	return _loadout.try_grant_run_relic_from_chest(chest_pos, source)


func on_mini_boss_killed(pos: Vector2, wave_index: int) -> void:
	EventBus.mini_boss_defeated.emit(wave_index, pos)
	var hunt := String(_map_rule.get("id", "")) == "elite_hunt"
	var orb_mul := float(_map_rule.get("orb_mul", 1.0)) if hunt else 1.0
	var heal_mul := float(_map_rule.get("heal_mul", 1.0)) if hunt else 1.0
	var extra_orbs := int(_map_rule.get("extra_orbs", 0)) if hunt else 0
	var ex := get_node_or_null("ExperienceSystem")
	if ex and ex.has_method("spawn_orb"):
		var orb_n := int(round(float(8 + wave_index * 2) * orb_mul)) + extra_orbs
		var orb_v := 3 + mini(2, wave_index) + (1 if hunt else 0)
		for _i in orb_n:
			ex.spawn_orb(pos + Vector2(randf_range(-70.0, 70.0), randf_range(-70.0, 70.0)), orb_v)
	var pl := $Player
	if pl and pl.has_method("heal"):
		pl.heal(float(pl.max_hp) * (0.08 + 0.02 * float(wave_index)) * heal_mul)
	if hunt:
		NotificationSystem.notify_message("荒漠精英猎杀：强化补给已投放。", 2.2, "achievement")
	else:
		NotificationSystem.notify_message("精英猎杀完成：补给已投放。", 2.0, "achievement")
	CombatFeedback.flash(Color(1.0, 0.72, 0.28, 0.22), 0.12, "strong")
	CombatFeedback.shake("heavy", 3.2, 0.1)


func _on_boss_defeated() -> void:
	if _ended or _extraction_active:
		return
	RunStats.boss_defeat_sec = int(elapsed)
	_dc_kill_streak = 0
	_dc_kill_streak_decay = 0.0
	var plw := $Player
	if plw and plw.has_method("set_kill_momentum_mul"):
		plw.set_kill_momentum_mul(1.0)
	# 试炼模式：击破即胜；标准/持久：必须到达撤离点
	if run_mode_id == "trial":
		_ended = true
		NotificationSystem.notify_message("首领击破！试炼完成。", 3.5, "achievement")
		EventBus.game_over.emit(true)
		return
	_start_extraction_sequence()


func _start_extraction_sequence() -> void:
	_extraction_active = true
	_extraction_remain = _EXTRACTION_WINDOW_SEC
	_extraction_hold = 0.0
	_extraction_telegraph_cd = 0.0
	var em := $EnemyManager
	if em and em.has_method("boss_pos"):
		_extraction_pos = em.boss_pos()
	else:
		_extraction_pos = $Player.global_position
	NotificationSystem.notify_message(
		"首领击破！%.0f 秒内进入撤离光圈并停留。" % _EXTRACTION_WINDOW_SEC,
		3.2,
		"achievement"
	)
	EventBus.boss_telegraph.emit(0, _extraction_pos, Vector2.ZERO, _EXTRACTION_RADIUS, 0.85)
	EventBus.play_music.emit(&"bgm_main")


func _tick_extraction(delta: float) -> void:
	if not _extraction_active or _ended:
		return
	_extraction_remain -= delta
	_extraction_telegraph_cd -= delta
	if _extraction_telegraph_cd <= 0.0:
		_extraction_telegraph_cd = 1.1
		EventBus.boss_telegraph.emit(0, _extraction_pos, Vector2.ZERO, _EXTRACTION_RADIUS, 1.05)
	$HUD.set_extraction_countdown(int(ceil(maxf(_extraction_remain, 0.0))), "extract")
	var pl := $Player
	if pl == null:
		return
	if pl.global_position.distance_to(_extraction_pos) <= _EXTRACTION_RADIUS:
		_extraction_hold += delta
		if _extraction_hold >= _EXTRACTION_HOLD_SEC:
			_finish_extraction(true)
			return
	else:
		_extraction_hold = maxf(0.0, _extraction_hold - delta * 1.5)
	if _extraction_remain <= 0.0:
		_finish_extraction(false)


func _finish_extraction(success: bool) -> void:
	if _ended:
		return
	_extraction_active = false
	$HUD.set_extraction_countdown(-1)
	if success:
		if (
			run_mode_id == "endurance"
			and GameDB.ENDLESS_AFTER_EXTRACTION
			and not GameDB.is_demo_build()
		):
			_begin_post_extraction_endless()
			return
		_ended = true
		NotificationSystem.notify_message("撤离成功！任务完成。", 3.2, "achievement")
		EventBus.game_over.emit(true)
	else:
		_ended = true
		NotificationSystem.notify_message("撤离超时：未能到达撤离点。", 2.8, "error")
		EventBus.game_over.emit(false)


func _begin_post_extraction_endless() -> void:
	_mission_cleared = true
	_endless_mode = true
	_endless_started_elapsed = elapsed
	_ended = false
	NotificationSystem.notify_message(
		"撤离完成 → 无尽突围！前 %.0f 分钟压力较软，尽情清场。" % (GameDB.ENDLESS_SOFT_INTRO_SEC / 60.0),
		3.4,
		"achievement"
	)
	$HUD.set_endless(true)
	EventBus.play_music.emit(&"bgm_main")
	CombatFeedback.flash(Color(1.0, 0.55, 0.2, 0.2), 0.16, "strong")


func get_damage_number_display_mul() -> float:
	# 信任债：跳字必须等于真实伤害，禁止无尽放大伪装
	return 1.0


func apply_boss_pickup_siphon(duration_sec: float) -> void:
	_boss_pickup_siphon_rem = maxf(_boss_pickup_siphon_rem, duration_sec)


func get_boss_pickup_siphon_mul() -> float:
	return 0.35 if _boss_pickup_siphon_rem > 0.0 else 1.0

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


func _init_map_rule(map_cfg: Dictionary) -> void:
	_map_rule = {}
	_map_rule_started = false
	_map_rule_announced = false
	_map_ring_center = Vector2.ZERO
	_map_ring_radius = 0.0
	_map_safe_target = Vector2.ZERO
	_map_safe_retarget_cd = 0.0
	_map_rule_telegraph_cd = 0.0
	var rule_v: Variant = map_cfg.get("map_rule")
	if typeof(rule_v) == TYPE_DICTIONARY:
		_map_rule = (rule_v as Dictionary).duplicate(true)


func _apply_map_event_bias() -> void:
	if String(_map_rule.get("id", "")) != "event_bias":
		return
	var re := get_node_or_null("RandomEvents")
	if re == null or not re.has_method("set_event_interval_scales"):
		return
	var muls: Dictionary = _map_rule.get("interval_mul", {}) as Dictionary
	re.call("set_event_interval_scales", muls)
	if not _map_rule_announced:
		_map_rule_announced = true
		var msg := String(_map_rule.get("announce", ""))
		if not msg.is_empty():
			NotificationSystem.notify_message(msg, 2.8, "item")


func _set_player_map_move_field(move_mul: float, pull_vel: Vector2 = Vector2.ZERO) -> void:
	var pl := $Player
	if pl != null and pl.has_method("set_map_move_field"):
		pl.call("set_map_move_field", move_mul, pull_vel)


func _tick_map_rule(delta: float) -> void:
	# 撤离窗 / 无尽突围：停用地图拉力场，避免残留错误推进
	if _ended or _map_rule.is_empty() or _extraction_active or _endless_mode:
		_set_player_map_move_field(1.0, Vector2.ZERO)
		return
	var rid := String(_map_rule.get("id", ""))
	match rid:
		"poison_ring":
			_tick_map_poison_ring(delta)
		"moving_safe_zone":
			_tick_map_moving_safe_zone(delta)
		"elite_hunt":
			_set_player_map_move_field(1.0, Vector2.ZERO)
			if not _map_rule_announced and elapsed >= 8.0:
				_map_rule_announced = true
				var msg := String(_map_rule.get("announce", ""))
				if not msg.is_empty():
					NotificationSystem.notify_message(msg, 2.6, "item")
		_:
			_set_player_map_move_field(1.0, Vector2.ZERO)


func _tick_map_poison_ring(delta: float) -> void:
	var start_sec := float(_map_rule.get("start_sec", 120.0))
	if elapsed < start_sec:
		_set_player_map_move_field(1.0, Vector2.ZERO)
		return
	var pl := $Player as Player
	if pl == null:
		return
	if not _map_rule_started:
		_map_rule_started = true
		_map_ring_center = pl.global_position
		_map_ring_radius = float(_map_rule.get("radius_start", 560.0))
		if not _map_rule_announced:
			_map_rule_announced = true
			NotificationSystem.notify_message(String(_map_rule.get("announce", "毒圈启动。")), 2.8, "warning")
	var dur := maxf(1.0, float(_map_rule.get("duration_sec", 360.0)))
	var t := clampf((elapsed - start_sec) / dur, 0.0, 1.0)
	var r0 := float(_map_rule.get("radius_start", 560.0))
	var r1 := float(_map_rule.get("radius_end", 240.0))
	_map_ring_radius = lerpf(r0, r1, t)
	_pulse_map_ring_telegraph(delta)
	var dist: float = pl.global_position.distance_to(_map_ring_center)
	if dist > _map_ring_radius:
		# 圈外：减速 + 向内吸（改变走位）+ 持续掉血
		var inward: Vector2 = (_map_ring_center - pl.global_position).normalized()
		var pull: Vector2 = inward * lerpf(36.0, 78.0, clampf((dist - _map_ring_radius) / 180.0, 0.0, 1.0))
		_set_player_map_move_field(0.72, pull)
		pl.take_damage(float(_map_rule.get("dps_out", 7.0)) * delta)
	else:
		_set_player_map_move_field(1.0, Vector2.ZERO)


func _tick_map_moving_safe_zone(delta: float) -> void:
	var start_sec := float(_map_rule.get("start_sec", 90.0))
	if elapsed < start_sec:
		_set_player_map_move_field(1.0, Vector2.ZERO)
		return
	var pl := $Player as Player
	if pl == null:
		return
	if not _map_rule_started:
		_map_rule_started = true
		_map_ring_center = pl.global_position
		_map_safe_target = pl.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 180.0
		_map_ring_radius = float(_map_rule.get("radius", 210.0))
		_map_safe_retarget_cd = float(_map_rule.get("retarget_sec", 16.0))
		if not _map_rule_announced:
			_map_rule_announced = true
			NotificationSystem.notify_message(String(_map_rule.get("announce", "安全区启动。")), 2.8, "warning")
	_map_safe_retarget_cd -= delta
	if _map_safe_retarget_cd <= 0.0:
		_map_safe_retarget_cd = float(_map_rule.get("retarget_sec", 16.0))
		_map_safe_target = pl.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(160.0, 280.0)
	var move_speed := float(_map_rule.get("move_speed", 58.0))
	_map_ring_center = _map_ring_center.move_toward(_map_safe_target, move_speed * delta)
	_pulse_map_ring_telegraph(delta)
	var dist: float = pl.global_position.distance_to(_map_ring_center)
	if dist > _map_ring_radius:
		# 圈外：强减速 + 吸回安全区（必须跟圈移动）
		var inward: Vector2 = (_map_ring_center - pl.global_position).normalized()
		var pull: Vector2 = inward * lerpf(48.0, 110.0, clampf((dist - _map_ring_radius) / 140.0, 0.0, 1.0))
		_set_player_map_move_field(0.62, pull)
		pl.take_damage(float(_map_rule.get("dps_out", 6.0)) * delta)
	else:
		# 圈内：略加速，奖励跟区走位
		_set_player_map_move_field(1.1, Vector2.ZERO)


func _pulse_map_ring_telegraph(delta: float) -> void:
	_map_rule_telegraph_cd -= delta
	if _map_rule_telegraph_cd > 0.0:
		return
	_map_rule_telegraph_cd = 0.9
	EventBus.boss_telegraph.emit(0, _map_ring_center, Vector2.ZERO, _map_ring_radius, 0.95)


func _init_zone_objective(map_cfg: Dictionary) -> void:
	_zone_objective_done = false
	_zone_objective_progress = 0
	_zone_objective_kind = -1
	_zone_objective_target = 0
	var zo: Variant = map_cfg.get("zone_objective")
	if typeof(zo) != TYPE_DICTIONARY:
		return
	var zod: Dictionary = zo
	_zone_objective_kind = int(zod.get("kind", -1))
	_zone_objective_target = maxi(1, int(zod.get("count", 1)))


func get_zone_objective_hud_line() -> String:
	if _zone_objective_kind < 0 or _zone_objective_target <= 0:
		return ""
	var map_cfg: Dictionary = GameDB.MAP_TEMPLATES[map_index]
	var zo: Dictionary = map_cfg.get("zone_objective", {}) as Dictionary
	var label := String(zo.get("label", "区域任务"))
	if _zone_objective_done:
		return "区域任务：%s 已完成" % label
	return "区域任务：%s %d/%d" % [label, _zone_objective_progress, _zone_objective_target]


func _tick_stationary_pressure(delta: float) -> void:
	var pl := $Player
	if pl == null:
		return
	var pos: Vector2 = pl.global_position
	if _stationary_prev_pos == Vector2.ZERO:
		_stationary_prev_pos = pos
		return
	var moved := pos.distance_to(_stationary_prev_pos)
	if moved < 42.0 * maxf(delta, 0.001):
		_stationary_sec += delta
	else:
		_stationary_sec = 0.0
	_stationary_prev_pos = pos


func _spawn_pressure_stationary_mul() -> float:
	if _stationary_sec >= 8.0:
		return 1.38
	if _stationary_sec >= 4.0:
		return 1.15
	return 1.0


func _player_forward_dir() -> Vector2:
	var pl := $Player
	if pl == null:
		return Vector2.RIGHT
	if "velocity" in pl:
		var vel: Vector2 = pl.velocity
		if vel.length() > 20.0:
			return vel.normalized()
	if pl.has_method("get_last_horiz_facing"):
		var facing := float(pl.call("get_last_horiz_facing"))
		if absf(facing) > 0.01:
			return Vector2(signf(facing), 0.0)
	return Vector2.RIGHT


func _spawn_orbs_ahead(count: int, value: int, forward_min: float, forward_max: float, spread: float) -> void:
	var ex := get_node_or_null("ExperienceSystem")
	var pl := $Player
	if ex == null or pl == null or not ex.has_method("spawn_orb"):
		return
	var origin: Vector2 = pl.global_position
	var fwd := _player_forward_dir()
	var side := fwd.orthogonal()
	for _i in count:
		var dist := randf_range(forward_min, forward_max)
		var lateral := randf_range(-spread, spread)
		ex.spawn_orb(origin + fwd * dist + side * lateral, value)


func _apply_zone_objective_kill(kind: StringName) -> void:
	if _zone_objective_done or _zone_objective_kind < 0:
		return
	var kind_id := _enemy_kind_to_id(String(kind))
	if kind_id != _zone_objective_kind:
		return
	_zone_objective_progress = mini(_zone_objective_target, _zone_objective_progress + 1)
	if _zone_objective_progress < _zone_objective_target:
		return
	_zone_objective_done = true
	var map_cfg: Dictionary = GameDB.MAP_TEMPLATES[map_index]
	var zo: Dictionary = map_cfg.get("zone_objective", {}) as Dictionary
	var label := String(zo.get("label", "区域任务"))
	NotificationSystem.notify_message("区域任务完成：%s — 前方补给已投放。" % label, 2.8, "achievement")
	_spawn_orbs_ahead(5, 3, 260.0, 420.0, 90.0)
	var pl := $Player
	if pl and pl.has_method("heal"):
		pl.heal(float(pl.max_hp) * 0.06)
	CombatFeedback.flash(Color(0.55, 0.9, 0.72, 0.16), 0.12, "subtle")


func _enemy_kind_to_id(kind_s: String) -> int:
	match kind_s:
		"grunter": return 0
		"runner": return 1
		"tank": return 2
		"spitter": return 3
		"boomer": return 4
		"guard": return 5
		"summoner": return 6
		"charger": return 7
		"shade": return 8
		"elite": return 9
		_:
			return -1


func _apply_run_mode_settings() -> void:
	if GameDB.is_demo_build():
		Settings.set_selected_run_mode("trial")
	run_mode_id = GameDB.normalize_run_mode_id(Settings.selected_run_mode)
	var mode_cfg: Dictionary = GameDB.get_run_mode(run_mode_id)
	run_time_seconds = int(mode_cfg.get("seconds", GameDB.run_time_for_mode()))
	boss_spawn_time = float(mode_cfg.get("boss_at", GameDB.boss_spawn_time_for_mode()))
	mini_boss_times = GameDB.mini_boss_times_for_mode(run_mode_id)
	difficulty_id = GameDB.normalize_difficulty_id(Settings.selected_difficulty)
	challenge_id = GameDB.normalize_challenge_id(Settings.selected_challenge)
	var diff: Dictionary = GameDB.get_difficulty_tier(difficulty_id)
	var challenge: Dictionary = GameDB.get_challenge_contract(challenge_id)
	_diff_enemy_hp_mul = float(diff.get("enemy_hp_mul", 1.0))
	_diff_enemy_dmg_mul = float(diff.get("enemy_dmg_mul", 1.0))
	_challenge_enemy_hp_mul = float(challenge.get("enemy_hp_mul", 1.0))
	_challenge_enemy_dmg_mul = float(challenge.get("enemy_dmg_mul", 1.0))
	call_deferred("_apply_meta_run_modifiers")


func _apply_meta_run_modifiers() -> void:
	var ss := get_node_or_null("SkillSystem")
	if ss and ss.has_method("apply_challenge_contract"):
		ss.call("apply_challenge_contract", GameDB.get_challenge_contract(challenge_id))
	if ss and ss.has_method("apply_map_mastery_bonus"):
		ss.call("apply_map_mastery_bonus", MetaProgress.get_map_mastery_stat_bonus(map_index))
	var em := get_node_or_null("EnemyManager")
	if em and em.has_method("set_run_scaling"):
		em.call(
			"set_run_scaling",
			_diff_enemy_hp_mul * _challenge_enemy_hp_mul,
			_diff_enemy_dmg_mul * _challenge_enemy_dmg_mul
		)
	var challenge: Dictionary = GameDB.get_challenge_contract(challenge_id)
	var badge := String(challenge.get("badge", ""))
	if not badge.is_empty() and not cmdline_headless_hint():
		NotificationSystem.notify_message("挑战契约生效：%s" % String(challenge.get("label", badge)), 2.2, "warning")


func cmdline_headless_hint() -> bool:
	for a in OS.get_cmdline_args():
		if str(a) == "--headless":
			return true
	return false


func build_run_end_context() -> Dictionary:
	var build_w := ""
	if AchievementService != null and AchievementService.has_method("resolve_primary_build_weapon"):
		build_w = String(AchievementService.resolve_primary_build_weapon())
	return {
		"difficulty_id": difficulty_id,
		"challenge_id": challenge_id,
		"run_mode_id": run_mode_id,
		"zone_objective_done": _zone_objective_done,
		"no_curse": not bool(_loadout.cursed_this_run) if _loadout else true,
		"boss_defeat_sec": RunStats.boss_defeat_sec,
		"primary_build_weapon": build_w,
		"endless_survived": _endless_mode and _mission_cleared,
		"map_stars": MetaProgress.get_map_stars(map_index),
	}


func _deferred_run_opening_tip() -> void:
	if _ended:
		return
	var mode_cfg: Dictionary = GameDB.get_run_mode(run_mode_id)
	var mode_hint := String(mode_cfg.get("hint", ""))
	# 胜利条件按模式写清，禁止标准/持久暗示“击破即胜”
	var goal := "目标：击破终局首领即胜利。"
	if run_mode_id == "standard" or run_mode_id == "endurance":
		goal = "目标：击破终局首领后，进入撤离光圈并停留完成任务。"
	var body := goal + " 吸球升级 → 选清场/保命 → 主动接战。"
	if not mode_hint.is_empty():
		body = mode_hint + "\n" + body
	if not _map_hint.is_empty():
		body += "\n" + _map_hint
	if map_xp_pickup_mul > 1.01:
		body += "\n本图经验球拾取 ×%.0f%%。" % (map_xp_pickup_mul * 100.0)
	# 主播友好：开局亮出本局选择面（专精/契约/遗物）
	var arche_line := get_hud_archetype_line_text()
	if not arche_line.is_empty():
		body += "\n" + arche_line
	var chal_cfg: Dictionary = GameDB.get_challenge_contract(challenge_id)
	var chal_label := String(chal_cfg.get("label", ""))
	if not chal_label.is_empty() and challenge_id != "none":
		body += "\n本局契约：" + chal_label
	if _loadout and not _loadout.run_relic_id.is_empty():
		var rdef2: Dictionary = GameDB.RUN_RELICS.get(_loadout.run_relic_id, {}) as Dictionary
		if not rdef2.is_empty():
			body += "\n开局遗物：" + String(rdef2.get("name", _loadout.run_relic_id))
	var zo_line := get_zone_objective_hud_line()
	if not zo_line.is_empty():
		body += "\n" + zo_line
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


func upgrade_panel_allowed() -> bool:
	return elapsed >= _ef_f("explore_upgrade_min_sec", 0.0)


func _early_spawn_pressure_mul() -> float:
	var ramp_sec := _ef_f("early_spawn_mul_sec", 150.0)
	if ramp_sec <= 0.0 or elapsed >= ramp_sec:
		return 1.0
	var min_mul := clampf(_ef_f("early_spawn_mul_min", 0.55), 0.15, 1.0)
	return lerpf(min_mul, 1.0, elapsed / ramp_sec)


func _early_spawn_interval_mul() -> float:
	var ramp_sec := _ef_f("early_spawn_mul_sec", 150.0)
	if ramp_sec <= 0.0 or elapsed >= ramp_sec:
		return 1.0
	return maxf(_ef_f("early_spawn_interval_mul", 1.0), 1.0)


func _early_xp_pickup_mul() -> float:
	var ramp_sec := _ef_f("early_xp_ramp_sec", 120.0)
	var bonus := _ef_f("early_xp_bonus_mul", 1.0)
	if ramp_sec <= 0.0 or elapsed >= ramp_sec:
		return 1.0
	return lerpf(bonus, 1.0, elapsed / ramp_sec)


func _on_run_started_kickstart() -> void:
	if _ended:
		return
	var ex := get_node_or_null("ExperienceSystem")
	var p := $Player
	if ex == null or p == null or not ex.has_method("spawn_orb"):
		return
	var count := maxi(0, _ef_i("kickstart_orb_count", 0))
	if count <= 0:
		return
	var value := maxi(1, _ef_i("kickstart_orb_value", 1))
	var radius := maxf(40.0, _ef_f("spark_45_radius", 90.0) * 0.85)
	for _i in count:
		ex.spawn_orb(
			p.global_position + Vector2(randf_range(-radius, radius), randf_range(-radius, radius)),
			value
		)
	var frac := clampf(_ef_f("kickstart_xp_frac", 0.0), 0.0, 0.25)
	if frac > 0.0:
		var bonus := maxi(1, int(round(float(xp_need) * frac)))
		xp += bonus


func _tick_early_flow_script() -> void:
	if _ended:
		return
	# 前期脚本仅覆盖前 3 分钟：球仍然投放，文案最多 2 条
	if elapsed > 180.0:
		return
	var quiet_until := _ef_f("quiet_tips_until_sec", 0.0)
	var tips_muted := quiet_until > 0.0 and elapsed < quiet_until
	var tip_budget := int(_early_flow_flags.get("tip_budget", 0))
	var spark20_at := _ef_f("spark_20_at_sec", -1.0)
	if spark20_at >= 0.0 and elapsed >= spark20_at and not _early_flow_flags.get("spark_20s", false):
		_early_flow_flags["spark_20s"] = true
		_spawn_orbs_ahead(maxi(0, _ef_i("spark_20_orb_count", 3)), maxi(1, _ef_i("spark_20_orb_value", 1)), 120.0, 220.0, 70.0)
		if not tips_muted and tip_budget < 2:
			NotificationSystem.notify_message("开局优先：跟上去吸球，尽快拿到第一次三选一。", 2.0, "item")
			_early_flow_flags["tip_budget"] = tip_budget + 1
			tip_budget = int(_early_flow_flags["tip_budget"])
	var spark45_at := _ef_f("spark_45_at_sec", 45.0)
	if elapsed >= spark45_at and not _early_flow_flags.get("spark_45s", false):
		_early_flow_flags["spark_45s"] = true
		_spawn_orbs_ahead(maxi(0, _ef_i("spark_45_orb_count", 5)), maxi(1, _ef_i("spark_45_orb_value", 2)), 160.0, 300.0, 90.0)
		CombatFeedback.flash(Color(0.52, 0.88, 0.72, 0.14), 0.08, "subtle")
	if elapsed >= 140.0 and not _early_flow_flags.get("spark_140s", false):
		_early_flow_flags["spark_140s"] = true
		_spawn_orbs_ahead(maxi(0, _ef_i("spark_140_orb_count", 6)), maxi(1, _ef_i("spark_140_orb_value", 3)), 200.0, 340.0, 100.0)
		CombatFeedback.shake("ui", 2.4, 0.08)
		if tip_budget < 2:
			NotificationSystem.notify_message("节奏换挡：吸球并预留走位，压力会抬升。", 2.1, "achievement")
			_early_flow_flags["tip_budget"] = tip_budget + 1


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
				cam.limit_enabled = false
				cam.position_smoothing_enabled = false
				cam.make_current()
				if p.has_method("_configure_camera_follow"):
					p.call("_configure_camera_follow")
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
	_apply_zone_objective_kill(kind)
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
	var boss_t: float = boss_spawn_time
	var run_t: float = float(run_time_seconds)
	var milestones: Array = [
		["m_55", 55.0, "提示：优先把经验球吸进身 — 升级三选一比硬刮怪更划算。", 2.6, "info"],
		["m_130", 130.0, "两分钟档：种类会开始变花，留走位别贪刀。", 2.4, "warning"],
		["m_300", 300.0, "五分钟节点：精英头目要来了，先拉开空间。", 2.8, "warning"],
		["m_600", 600.0, "十分钟：压力会上一个台阶，保命优先。", 2.5, "warning"],
		["m_900", 900.0, "十五分钟：构筑该成型了，留意地图光点事件。", 2.6, "item"],
		["m_boss2m", boss_t - 120.0, "约 2 分钟后 BOSS 登场 — 建议先清场、补等级。", 3.2, "warning"],
		["m_boss45", boss_t - 45.0, "BOSS 将近：检查血量与走位，准备拉长距离。", 2.8, "warning"],
		["m_ext3", run_t - 200.0, "最后约三分半：节奏收紧，优先保命与吸球。", 3.0, "achievement"],
		["m_ext1", run_t - 60.0, "", 2.6, "warning"],
	]
	for row in milestones:
		var key: String = String(row[0])
		if _run_milestone_done.get(key, false):
			continue
		if t < float(row[1]):
			continue
		var msg := String(row[2])
		if key == "m_ext1":
			msg = _milestone_final_minute_message()
			if msg.is_empty():
				_run_milestone_done[key] = true
				continue
		_run_milestone_done[key] = true
		NotificationSystem.notify_message(msg, float(row[3]), String(row[4]))


func _milestone_final_minute_message() -> String:
	# 末段提示必须跟当前规则态一致，禁止撤离窗内仍催「击破首领」
	if _endless_mode or _mission_cleared:
		return ""
	if _extraction_active:
		return "最后阶段：尽快进入撤离光圈并停留；超时即任务失败。"
	var em := $EnemyManager
	if em and em.has_method("boss_alive") and em.boss_alive():
		return "最后 60 秒：尽快击破首领；超时未击破将任务失败。"
	if _boss_spawned:
		# 首领已倒且未进撤离态（异常空窗）：不再发误导句
		return ""
	return "最后 60 秒：终局首领仍未击破；超时将任务失败。"


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
		"节律补给：经验球投放在移动方向前方 — 跟上去吸满。",
		2.75,
		"item"
	)
	_spawn_orbs_ahead(7, 3, 220.0, 380.0, 110.0)
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
	_tick_stationary_pressure(delta)
	if _boss_pickup_siphon_rem > 0.0:
		_boss_pickup_siphon_rem = maxf(0.0, _boss_pickup_siphon_rem - delta)
	_tick_extraction(delta)
	_tick_engagement_milestones()
	_tick_decision_pulse_rewards()
	_tick_map_rule(delta)

	# 游戏已结束，仅保留最小更新
	if _ended:
		$HUD.set_runtime(int(elapsed))
		$HUD.set_extraction_countdown(-1)
		return
	
	# 任务超时：未在时限内击破首领则失败；撤离/无尽期间不停表失败
	if (not _extraction_active) and (not _endless_mode) and elapsed >= float(run_time_seconds):
		_ended = true
		_dc_kill_streak = 0
		_dc_kill_streak_decay = 0.0
		var plw := $Player
		if plw and plw.has_method("set_kill_momentum_mul"):
			plw.set_kill_momentum_mul(1.0)
		if not $EnemyManager.boss_alive() and RunStats.boss_defeat_sec >= 0:
			EventBus.game_over.emit(true)
		else:
			NotificationSystem.notify_message("任务超时：未能及时击破首领。", 2.8, "error")
			EventBus.game_over.emit(false)
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
	
	if (not _boss_spawned) and elapsed >= boss_spawn_time:
		_boss_spawned = true
		RunStats.boss_spawn_sec = int(elapsed)
		$EnemyManager.spawn_boss($Player.global_position + Vector2(0, -420))
		EventBus.play_music.emit(&"bgm_boss")
	
	# 中BOSS机制：5/10/15分钟出现精英BOSS
	for i in mini_boss_times.size():
		if not _mini_boss_spawned.has(i) and elapsed >= float(mini_boss_times[i]):
			_mini_boss_spawned.append(i)
			_spawn_mini_boss(i)
	
	var target := _target_enemy_count()
	# 无尽模式：敌人压力持续增长
	if _endless_mode:
		target += int(elapsed / 60.0) * 50
	# 周7：Boss 战 / 撤离窗口压存活目标，给 Boss telegraph + 武器算力留帧时
	if (_boss_spawned and $EnemyManager.boss_alive()) or _extraction_active:
		target = mini(target, GameDB.BOSS_FIGHT_ALIVE_SOFT_CAP)
	elif _endless_mode and (elapsed - _endless_started_elapsed) < GameDB.ENDLESS_SOFT_INTRO_SEC:
		# 周8：无尽前 5 分钟更软
		target = mini(target, int(round(float(GameDB.BOSS_FIGHT_ALIVE_SOFT_CAP) * 0.85)))
	else:
		target = mini(target, GameDB.COMBAT_ALIVE_PERF_SOFT_CAP)
	var enemy_alive: int = $EnemyManager.alive_count()
	if enemy_alive < target:
		var pressure_mul := 1.0 + clampf((_director_mul - 1.0) * 0.7, 0.0, 0.8)
		_spawn_acc += delta * pressure_mul
		var runtime_spawn_interval := (_spawn_interval_sec * _early_spawn_interval_mul()) / maxf(_director.spawn_perf_multiplier(), 0.1)
		if enemy_alive >= GameDB.BOSS_FIGHT_ALIVE_SOFT_CAP:
			runtime_spawn_interval *= 1.35
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
	var time_to_deadline: float = float(run_time_seconds) - elapsed
	if _extraction_active:
		$HUD.set_extraction_countdown(int(ceil(maxf(_extraction_remain, 0.0))), "extract")
	elif time_to_deadline <= float(GameDB.EXTRACTION_ALERT_BEFORE_SEC) and time_to_deadline > 0.0:
		$HUD.set_extraction_countdown(int(ceil(time_to_deadline)), "deadline")
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
	if _ended:
		return
	_ended = true
	# 已撤离进无尽：倒下仍记胜利
	if _endless_mode and _mission_cleared:
		NotificationSystem.notify_message("无尽突围结束 — 撤离成绩已保全。", 2.8, "achievement")
		EventBus.game_over.emit(true)
		return
	EventBus.game_over.emit(false)

func _spawn_wave(spawn_override: int = -1) -> void:
	var p: Vector2 = $Player.global_position
	var map_cfg: Dictionary = GameDB.MAP_TEMPLATES[map_index]
	var lvl_pressure := int(level / 4)
	var n := 4 + GameDB.director_wave_time_bonus(elapsed, float(run_time_seconds)) + lvl_pressure + (2 if elapsed > float(run_time_seconds) * 0.556 else 0)
	n = int(round(float(n) * _director_mul * _early_spawn_pressure_mul() * _spawn_pressure_stationary_mul()))
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
		var min_r := float(map_cfg["spawn_radius_min"])
		var max_r := float(map_cfg["spawn_radius_max"])
		# 移动安全区：优先在远处刷怪，减少中心站桩收益
		if randf() < _FAR_SPAWN_BIAS:
			min_r = maxf(min_r, _CENTER_SOFT_RADIUS * 0.82)
		if _stationary_sec >= 4.0:
			min_r = maxf(min_r, _CENTER_SOFT_RADIUS * 0.9)
		var dist := randf_range(min_r, max_r)
		var pos: Vector2 = p + Vector2(cos(angle), sin(angle)) * dist
		var kind_roll := _roll_enemy_kind(elapsed, float(map_cfg["ranged_weight"]))
		if _stationary_sec >= 8.0 and randf() < 0.28:
			kind_roll = 3 if randf() < float(map_cfg["ranged_weight"]) + 0.22 else 6
		$EnemyManager.spawn_enemy(pos, kind_roll)

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
	return maxf(0.0, elapsed - boss_spawn_time) / 60.0


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
	# 场上敌人很高时削峰，避免瞬时抖动（周7软顶优先）
	if enemy_alive > GameDB.COMBAT_ALIVE_PERF_SOFT_CAP:
		cap = int(round(float(cap) * 0.62))
	elif enemy_alive > GameDB.BOSS_FIGHT_ALIVE_SOFT_CAP:
		cap = int(round(float(cap) * 0.78))
	return mini(maxi(1, cap), maxi(0, deficit))


func _roll_enemy_kind(t: float, ranged_weight: float) -> int:
	var x := randf()
	var elite_bonus := clampf((_director_mul - 1.0) * 0.16, 0.0, 0.18)
	var pressure_u := clampf((_director_mul - 0.92) / 0.7, 0.0, 1.0)
	var ranged_bias := ranged_weight * (0.85 + pressure_u * 0.45)
	var boss_t := boss_spawn_time
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
	var amt := int(round(float(amount) * map_xp_pickup_mul * _early_xp_pickup_mul()))
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
			mat.set_shader_parameter("bloom_intensity", 0.068)
			mat.set_shader_parameter("bloom_threshold", 0.875)
			mat.set_shader_parameter("chromatic_aberration", 0.032)
			mat.set_shader_parameter("scanline_strength", 0.0012)
			mat.set_shader_parameter("vignette_strength", 0.082)
			mat.set_shader_parameter("vignette_softness", 0.64)
			mat.set_shader_parameter("saturation", 0.99)
			mat.set_shader_parameter("contrast", 1.052)
			mat.set_shader_parameter("grain_strength", 0.011)
			mat.set_shader_parameter("dc_style_mix", 0.11)
		Settings.Quality.HIGH:
			_post_process_rect.visible = true
			mat.set_shader_parameter("bloom_intensity", 0.085)
			mat.set_shader_parameter("bloom_threshold", 0.855)
			mat.set_shader_parameter("chromatic_aberration", 0.042)
			mat.set_shader_parameter("scanline_strength", 0.0016)
			mat.set_shader_parameter("vignette_strength", 0.092)
			mat.set_shader_parameter("vignette_softness", 0.65)
			mat.set_shader_parameter("saturation", 0.985)
			mat.set_shader_parameter("contrast", 1.062)
			mat.set_shader_parameter("grain_strength", 0.013)
			mat.set_shader_parameter("dc_style_mix", 0.13)


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
	# 随机选择精英类型：9=大红精英，7=冲锋者（带冲锋 AI）
	var elite_type: int
	if _endless_mode:
		elite_type = 9 if randf() < 0.82 else 7
	else:
		elite_type = 9 if randf() > 0.4 else 7
	var idx: int = $EnemyManager.spawn_enemy(pos, elite_type)
	if idx >= 0:
		var hp_scale := GameDB.MINI_BOSS_HP_SCALE
		var dmg_scale := GameDB.MINI_BOSS_DMG_SCALE
		if index == 0:
			hp_scale = GameDB.MINI_BOSS_FIRST_HP_SCALE
			dmg_scale = GameDB.MINI_BOSS_FIRST_DMG_SCALE
		$EnemyManager.hp[idx] *= hp_scale
		$EnemyManager.damage[idx] *= dmg_scale
		$EnemyManager.speed[idx] *= 0.8
		if $EnemyManager.has_method("mark_mini_boss"):
			$EnemyManager.mark_mini_boss(idx, index)
		var boss_name := "精英猎杀目标" if elite_type == 9 else "冲锋猎杀目标"
		# 每波 1 个轻量专属：增援 / 疾跑 / 真冲锋（文案与行为必须一致）
		match index % 3:
			0:
				for _j in 2:
					var ang2 := randf() * TAU
					$EnemyManager.spawn_enemy(pos + Vector2(cos(ang2), sin(ang2)) * randf_range(70.0, 120.0), 0)
				NotificationSystem.notify_message("%s出现！会召唤增援，优先击破。" % boss_name, 2.0, "warning")
			1:
				$EnemyManager.speed[idx] *= 1.35
				NotificationSystem.notify_message("%s出现！疾跑精英，优先击破。" % boss_name, 2.0, "warning")
			_:
				# 非冲锋种则切到 kind 7，否则提示「冲锋」是假的
				if elite_type != 7 and $EnemyManager.has_method("set_kind_keep_combat_stats"):
					$EnemyManager.set_kind_keep_combat_stats(idx, 7)
					if $EnemyManager.has_method("mark_mini_boss"):
						$EnemyManager.mark_mini_boss(idx, index)
					boss_name = "冲锋猎杀目标"
				NotificationSystem.notify_message("%s出现！会冲锋突进，优先击破。" % boss_name, 2.0, "warning")
		EventBus.boss_warning.emit(0.5, 0.8)
		EventBus.play_sfx.emit(&"boss_warning", p)
		var exp_sys = get_node_or_null("ExperienceSystem")
		if exp_sys and exp_sys.has_method("spawn_orb"):
			for _i in 5:
				exp_sys.spawn_orb(pos + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 3)
