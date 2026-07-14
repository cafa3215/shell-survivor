extends Node
class_name WeaponSystem

# ============================================
# 武器系统 - 全自动射击 + 8种武器独特行为
# ============================================

var player: Node2D
var enemy_manager: Node2D
var level_map := {}
var cd_map := {}
var timer_map := {}
var _skill_system: Node

# 特效管理
var _rocket_pending: Array[Dictionary] = []
var _burn_zones: Array[Dictionary] = []
var _weapon_telegraph: WeaponTelegraph
var _projectile_layer: WeaponProjectileLayer

# ========== 新功能性武器状态 ==========
var _frost_aura_active: bool = false
var _frost_aura_timer: float = 0.0
var _frost_freeze_pulse_cd: float = 0.0
var _heal_aura_timer: float = 0.0
var _mine_positions: Array[Vector2] = []

# 武器特效计时器
var _guardian_angle := 0.0
var _drone_positions: Array[Vector2] = []
var _drone_angle := 0.0
var _drone_tick := 0.0
var _guardian_knockback_tick := 0.0
var _particle_mgr: Node2D
var _damage_numbers_this_frame := 0
var _max_damage_numbers_per_frame := 18
var _fx_source_cooldowns: Dictionary = {}
var _hit_feedback_recent: Array[Dictionary] = []
const _HIT_FEEDBACK_SPATIAL_R2 := 576.0 # 24px
const _HIT_FEEDBACK_SPATIAL_WINDOW := 0.07
var _fusion_lv4_hint_sent: Dictionary = {}
var _fusion_spike_cd := 0.0
var _threat_hit_cd: float = 0.0
var _extreme_perf_mode := false
var _extreme_perf_tick := 0.0
var _dev_reload_hotkey_cd := 0.0
var _run_combat_active := false
var _combat_warmup_rem := 0.0
const _COMBAT_WARMUP_SEC := 1.35
## 当前武器开火是否真暴击（供跳字/命中皮读取；延迟伤害用 pending 字段覆盖）
var _shot_is_crit := false

## 核心武器“逻辑卡片”：集中维护轨迹/命中/特效关键参数，便于快速扩展新武器。
const _WEAPON_LOGIC_CARD := {
	"kunai": {
		"travel_min": 110.0, "travel_max_base": 320.0, "travel_max_per_lv": 15.0,
		"trail_arc_jitter": 26.0, "trail_arc_mul_base": 0.52, "trail_arc_mul_per_lv": 0.05,
		"line_width_base": 18.0, "line_width_per_lv": 2.1, "line_hit_cap_base": 3, "line_hit_cap_lv_div": 2,
		"line_hit_cap_evolved_bonus": 3, "line_damage_mul_normal": 0.62, "line_damage_mul_evolved": 0.56,
		"finisher_radius_mul": 1.18, "finisher_damage_mul_evolved": 1.25
	},
	"quantum_ball": {
		"search_radius_base": 180.0, "search_radius_per_lv": 20.0,
		"burst_radius_base": 70.0, "burst_radius_per_lv": 4.0,
		"hex_count": 6, "hex_ring_mul": 0.76, "hex_radius_mul": 0.2, "hex_damage_mul": 0.2,
		"chain_base": 1, "chain_lv_div": 2, "chain_evolved_bonus": 2, "chain_search_radius": 150.0
	},
	"lightning": {
		"strike_radius_base": 88.0, "strike_radius_per_lv": 3.0,
		"hex_points": 6, "hex_ring_mul": 0.62, "hex_radius_mul": 0.24, "hex_damage_mul": 0.24,
		"jump_base": 2, "jump_lv_div": 2, "jump_evolved_bonus": 3, "jump_range_base": 200.0, "jump_range_per_lv": 15.0,
		"main_stun_normal": 0.14, "main_stun_evolved": 0.32
	},
	"rocket": {
		"search_radius": 210.0, "speed": 400.0, "life": 0.45,
		"blast_radius_base": 95.0, "blast_radius_per_lv": 6.0,
		"delay_normal": 0.25, "delay_evolved": 0.15
	}
}

## 伤害来源字符串 → 命中特效预设（Batch4：单表路由，避免 match 分叉失控）
const _DAMAGE_SOURCE_HIT_PRESET := {
	"kunai_hit": "slash",
	"kunai_pierce": "slash",
	"kunai_finish": "slash",
	"quantum_burst": "arcane_heavy",
	"quantum_bounce": "arcane_soft",
	"quantum_holy": "arcane_burst",
	"quantum_hex": "arcane_soft",
	"lightning_strike": "volt",
	"lightning_jump": "volt_soft",
	"lightning_hex": "volt",
	"molotov_impact": "fire_impact",
	"molotov_burn": "fire_tick",
	"rocket_explode": "rocket_main",
	"rocket_secondary": "rocket_secondary",
	"rocket_cone": "rocket_secondary",
	"guardian_spin": "kinetic_ring",
	"guardian_tick": "kinetic_tick",
	"guardian_slice": "kinetic_ring",
	"drone_attack": "drone_beam",
	"drone_pulse": "drone_tick",
	"drone_sweep": "drone_beam",
	"boomerang_out": "boomer",
	"boomerang_return": "boomer",
	"boomerang_orbit": "boomer_soft",
	"boomerang_crescent": "boomer_soft",
	"mine_explosion": "mine_big",
	"mine_wave": "mine_big",
	"molotov_cone": "fire_impact",
	"frost_wave": "kinetic_tick",
	"heal_wave": "kinetic_tick",
}

## 命中图形 + 音效策略卡片（source 维度）：逐步替代散落 match。
const _SOURCE_FEEDBACK_CARD := {
	# --- kunai ---
	"kunai_hit": {"weapon": "kunai", "preset": "slash", "palette": "kunai", "sfx_event": "kunai_hit", "intensity_mul": 0.94},
	"kunai_pierce": {"weapon": "kunai", "preset": "slash", "palette": "kunai", "sfx_event": "kunai_pierce", "intensity_mul": 0.88},
	"kunai_finish": {"weapon": "kunai", "preset": "slash", "palette": "kunai", "sfx_event": "kunai_finish", "intensity_mul": 1.08},
	# --- quantum ---
	"quantum_burst": {"weapon": "quantum_ball", "preset": "arcane_heavy", "palette": "quantum_ball", "sfx_event": "quantum_burst", "intensity_mul": 1.1},
	"quantum_bounce": {"weapon": "quantum_ball", "preset": "arcane_soft", "palette": "quantum_ball", "sfx_event": "quantum_bounce", "intensity_mul": 0.9},
	"quantum_holy": {"weapon": "quantum_ball", "preset": "arcane_burst", "palette": "quantum_ball", "sfx_event": "quantum_holy", "intensity_mul": 1.16},
	"quantum_hex": {"weapon": "quantum_ball", "preset": "arcane_soft", "palette": "quantum_ball", "sfx_event": "quantum_hex", "intensity_mul": 0.92},
	# --- lightning ---
	"lightning_strike": {"weapon": "lightning", "preset": "volt", "palette": "lightning", "sfx_event": "lightning_strike", "intensity_mul": 1.08},
	"lightning_jump": {"weapon": "lightning", "preset": "volt_soft", "palette": "lightning", "sfx_event": "lightning_jump", "intensity_mul": 0.9},
	"lightning_hex": {"weapon": "lightning", "preset": "volt", "palette": "lightning", "sfx_event": "lightning_hex", "intensity_mul": 0.92},
	# --- rocket ---
	"rocket_explode": {"weapon": "rocket", "preset": "rocket_main", "palette": "rocket", "sfx_event": "rocket_explode", "intensity_mul": 1.2},
	"rocket_secondary": {"weapon": "rocket", "preset": "rocket_secondary", "palette": "rocket", "sfx_event": "rocket_secondary", "force_hit_type": "kill", "intensity_mul": 1.02},
	"rocket_cone": {"weapon": "rocket", "preset": "rocket_secondary", "palette": "rocket", "sfx_event": "rocket_cone", "intensity_mul": 0.9},
	# --- others (fallback migration) ---
	"molotov_impact": {"weapon": "molotov", "preset": "fire_impact", "palette": "molotov", "sfx_event": "molotov_impact"},
	"molotov_burn": {"weapon": "molotov", "preset": "fire_tick", "palette": "molotov", "sfx_event": "molotov_burn", "intensity_mul": 0.78},
	"molotov_cone": {"weapon": "molotov", "preset": "fire_impact", "palette": "molotov", "sfx_event": "molotov_cone", "intensity_mul": 0.9},
	"guardian_spin": {"weapon": "guardian", "preset": "kinetic_ring", "palette": "guardian", "sfx_event": "guardian_spin"},
	"guardian_tick": {"weapon": "guardian", "preset": "kinetic_tick", "palette": "guardian", "sfx_event": "guardian_tick", "intensity_mul": 0.76},
	"guardian_slice": {"weapon": "guardian", "preset": "kinetic_ring", "palette": "guardian", "sfx_event": "guardian_slice", "intensity_mul": 0.9},
	"drone_attack": {"weapon": "drone_ab", "preset": "drone_beam", "palette": "drone_ab", "sfx_event": "drone_attack"},
	"drone_pulse": {"weapon": "drone_ab", "preset": "drone_tick", "palette": "drone_ab", "sfx_event": "drone_pulse", "intensity_mul": 0.82},
	"drone_sweep": {"weapon": "drone_ab", "preset": "drone_beam", "palette": "drone_ab", "sfx_event": "drone_sweep", "intensity_mul": 0.92},
	"boomerang_out": {"weapon": "boomerang", "preset": "boomer", "palette": "boomerang", "sfx_event": "boomerang_out"},
	"boomerang_return": {"weapon": "boomerang", "preset": "boomer", "palette": "boomerang", "sfx_event": "boomerang_return", "intensity_mul": 0.94},
	"boomerang_orbit": {"weapon": "boomerang", "preset": "boomer_soft", "palette": "boomerang", "sfx_event": "boomerang_orbit", "intensity_mul": 0.86},
	"boomerang_crescent": {"weapon": "boomerang", "preset": "boomer_soft", "palette": "boomerang", "sfx_event": "boomerang_crescent", "intensity_mul": 0.84},
	"mine_explosion": {"weapon": "stun_mine", "preset": "mine_big", "palette": "stun_mine", "sfx_event": "mine_explosion", "intensity_mul": 1.05},
	"mine_wave": {"weapon": "stun_mine", "preset": "mine_big", "palette": "stun_mine", "sfx_event": "mine_wave", "intensity_mul": 0.9},
	"frost_wave": {"weapon": "stun_mine", "preset": "kinetic_tick", "palette": "stun_mine", "sfx_event": "frost_wave", "intensity_mul": 0.84},
	"heal_wave": {"weapon": "guardian", "preset": "kinetic_tick", "palette": "guardian", "sfx_event": "heal_wave", "intensity_mul": 0.82},
}
const _SOURCE_FEEDBACK_CARD_CONFIG_PATH := "res://assets/config/weapon_feedback_card.json"
var _source_feedback_card_runtime: Dictionary = {}

func _ready() -> void:
	player = get_parent().get_node_or_null("Player")
	enemy_manager = get_parent().get_node_or_null("EnemyManager")
	_particle_mgr = get_parent().get_node_or_null("ParticleManager")
	_skill_system = get_parent().get_node_or_null("SkillSystem")
	
	# 初始化武器等级
	for wid in GameDB.WEAPONS.keys():
		level_map[wid] = 0
		cd_map[wid] = GameDB.WEAPONS[wid]["base_cd"]
		timer_map[wid] = 999.0
	
	# 开局仅苦无：第二武器靠升级获得，避免特效叠满屏
	level_map["kunai"] = 1
	timer_map["kunai"] = 0.85
	
	# 设置自动射击模式
	InputManager.set_aim_mode(InputManager.AimMode.AUTO)
	InputManager.auto_fire = true
	
	EventBus.fusion_applied.connect(_on_fusion_applied)
	EventBus.weapon_cards_reload_requested.connect(_on_weapon_cards_reload_requested)
	if not EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.connect(_on_game_started)
	_weapon_telegraph = get_parent().get_node_or_null("WeaponTelegraph")
	_ensure_projectile_layer()
	
	# 初始化无人机位置
	_drone_positions.clear()
	_drone_positions.append(Vector2.ZERO)
	_drone_positions.append(Vector2.ZERO)
	_load_source_feedback_card_runtime()


func _on_game_started() -> void:
	_run_combat_active = false
	_combat_warmup_rem = _COMBAT_WARMUP_SEC
	for wid in timer_map.keys():
		if int(level_map.get(wid, 0)) > 0:
			timer_map[wid] = maxf(float(timer_map[wid]), 0.75)
	if _projectile_layer != null and _projectile_layer.has_method("clear_weapon_mounts"):
		_projectile_layer.clear_weapon_mounts()

func _process(delta: float) -> void:
	_update_dev_hot_reload_input(delta)
	_damage_numbers_this_frame = 0
	_update_fx_cooldowns(delta)
	_ensure_runtime_refs()
	if _combat_warmup_rem > 0.0:
		_combat_warmup_rem = maxf(0.0, _combat_warmup_rem - delta)
		if _combat_warmup_rem <= 0.0:
			_run_combat_active = true

	# Runtime self-heal: keep auto aim/fire stable during long sessions.
	if InputManager.aim_mode != InputManager.AimMode.AUTO:
		InputManager.set_aim_mode(InputManager.AimMode.AUTO)
	InputManager.auto_fire = true

	if player == null or enemy_manager == null:
		return
	_update_extreme_perf_mode(delta)
	_sync_vfx_overload_mul()
	if _run_combat_active:
		_sync_weapon_presence_visuals()

	# 更新特效
	_update_rocket_pending(delta)
	_update_burn_zones(delta)
	_update_drones(delta)
	_update_guardian(delta)
	# ========== 更新功能性武器 ==========
	_update_frost_aura(delta)
	_update_heal_aura(delta)
	_update_mines(delta)

	if not InputManager.should_fire():
		return
	if not _run_combat_active:
		return

	# 自动射击所有激活的武器
	for wid in timer_map.keys():
		if level_map[wid] <= 0:
			continue
	
		timer_map[wid] -= delta
		if timer_map[wid] <= 0.0:
			timer_map[wid] = _scaled_cd(wid)
			_fire_weapon(wid)
			if player != null and player.has_method("notify_weapon_fired"):
				player.notify_weapon_fired(wid)

func _sync_weapon_presence_visuals() -> void:
	if _projectile_layer == null or player == null:
		return
	if player.has_method("uses_kaykit_visual") and bool(player.call("uses_kaykit_visual")):
		_projectile_layer.clear_weapon_mounts()
		return
	var active: Array[String] = []
	for wid in level_map.keys():
		var lv := int(level_map.get(wid, 0))
		if lv <= 0:
			continue
		active.append(String(wid))
	active.sort()
	var aim_dir := Vector2.RIGHT
	var target: Variant = _nearest_enemy_pos(player.global_position, 420.0)
	if target != null:
		var d := Vector2(target) - player.global_position
		if d.length() > 0.01:
			aim_dir = d.normalized()
	_projectile_layer.sync_weapon_mounts(player.global_position, active, aim_dir)

func _update_extreme_perf_mode(delta: float) -> void:
	if not Settings.extreme_perf_guard:
		if _extreme_perf_mode:
			_extreme_perf_mode = false
			_max_damage_numbers_per_frame = 18
			if _weapon_telegraph != null and _weapon_telegraph.has_method("set_runtime_overload_mul"):
				_weapon_telegraph.set_runtime_overload_mul(1.0)
			if _projectile_layer != null and _projectile_layer.has_method("set_runtime_overload_mul"):
				_projectile_layer.set_runtime_overload_mul(1.0)
			if _particle_mgr != null and _particle_mgr.has_method("set_runtime_overload_mul"):
				_particle_mgr.set_runtime_overload_mul(1.0)
			NotificationSystem.notify_message("高压性能保护已关闭", 1.0, "warning")
		return
	_extreme_perf_tick -= delta
	if _extreme_perf_tick > 0.0:
		return
	_extreme_perf_tick = 0.22
	if enemy_manager == null or not enemy_manager.has_method("alive_count"):
		return
	var alive := int(enemy_manager.alive_count())
	var enter_count := 1200
	var exit_count := 860
	var vfx_profile := 1
	if Settings and Settings.has_method("get"):
		vfx_profile = int(Settings.get("vfx_profile"))
		match vfx_profile:
			0:
				enter_count = 980
				exit_count = 720
			2:
				enter_count = 1450
				exit_count = 1080
			_:
				enter_count = 1200
				exit_count = 860
	var want_extreme := _extreme_perf_mode
	if not _extreme_perf_mode and alive >= enter_count:
		want_extreme = true
	elif _extreme_perf_mode and alive <= exit_count:
		want_extreme = false
	if want_extreme == _extreme_perf_mode:
		return
	_extreme_perf_mode = want_extreme
	_max_damage_numbers_per_frame = 10 if _extreme_perf_mode else 18
	if _weapon_telegraph != null and _weapon_telegraph.has_method("set_runtime_overload_mul"):
		_weapon_telegraph.set_runtime_overload_mul(0.74 if _extreme_perf_mode else 1.0)
	if _projectile_layer != null and _projectile_layer.has_method("set_runtime_overload_mul"):
		_projectile_layer.set_runtime_overload_mul(0.78 if _extreme_perf_mode else 1.0)
	if _particle_mgr != null and _particle_mgr.has_method("set_runtime_overload_mul"):
		_particle_mgr.set_runtime_overload_mul(0.74 if _extreme_perf_mode else 1.0)
	NotificationSystem.notify_message("高压性能保护" if _extreme_perf_mode else "高压性能保护已解除", 1.0, "warning")

func _sync_vfx_overload_mul() -> void:
	if _extreme_perf_mode:
		return
	var pressure := _runtime_pressure_mul()
	var mul := 1.0
	if pressure > 1.2:
		mul = lerpf(1.0, 0.84, clampf((pressure - 1.2) / 0.65, 0.0, 1.0))
	if _weapon_telegraph != null and _weapon_telegraph.has_method("set_runtime_overload_mul"):
		_weapon_telegraph.set_runtime_overload_mul(mul)
	if _projectile_layer != null and _projectile_layer.has_method("set_runtime_overload_mul"):
		_projectile_layer.set_runtime_overload_mul(lerpf(mul, 1.0, 0.35))
	if _particle_mgr != null and _particle_mgr.has_method("set_runtime_overload_mul"):
		_particle_mgr.set_runtime_overload_mul(mul)

func level_up_weapon(id: String) -> void:
	var prev_lv := int(level_map.get(id, 0))
	var was_new := prev_lv <= 0
	# 新武器检查栏位上限
	if int(level_map.get(id, 0)) == 0:
		var active_count := 0
		for wid in level_map.keys():
			# 治疗光环视为支援栏：不挤占输出武器位
			if String(wid) == "heal_aura":
				continue
			if int(level_map[wid]) > 0:
				active_count += 1
		var slot_cap := GameDB.WEAPON_SLOTS
		if id == "heal_aura":
			slot_cap += 1
		if active_count >= slot_cap and id != "heal_aura":
			# 栏位已满，替换等级最低的非治疗武器
			var lowest_wid := ""
			var lowest_lv := 99
			for wid in level_map.keys():
				if String(wid) == "heal_aura":
					continue
				var lv := int(level_map[wid])
				if lv > 0 and lv < lowest_lv:
					lowest_lv = lv
					lowest_wid = wid
			if lowest_wid != "":
				level_map[lowest_wid] = 0
				NotificationSystem.notify_message("武器栏位已满！%s被替换" % String(GameDB.WEAPONS[lowest_wid]["name"]), 2.0, "warning")
	level_map[id] = min(int(level_map.get(id, 0)) + 1, 5)
	var new_lv := int(level_map[id])
	_emit_weapon_presentation(id, was_new, prev_lv, new_lv)
	if was_new and new_lv == 1:
		var wn_new := String(GameDB.WEAPONS[id].get("name", id))
		NotificationSystem.notify_message("获得武器：" + wn_new, 1.25, "item")
		if _projectile_layer != null and _projectile_layer.has_method("play_weapon_unlock_fx"):
			_projectile_layer.play_weapon_unlock_fx(id, player.global_position)
	if new_lv == 4 and not _fusion_lv4_hint_sent.get(id, false):
		_fusion_lv4_hint_sent[id] = true
		var wn := String(GameDB.WEAPONS[id].get("name", id))
		NotificationSystem.notify_message("【节点】" + wn + " 等级4：再升一级满星，可走向融合。", 3.0, "achievement")


func _emit_weapon_presentation(id: String, was_new: bool, prev_lv: int, new_lv: int) -> void:
	if player == null or not is_instance_valid(player):
		return
	var weapon_entry: Variant = GameDB.WEAPONS.get(id, {})
	var wn := id
	if weapon_entry is Dictionary:
		wn = String(weapon_entry.get("name", id))
	var payload := {
		"weapon_name": wn,
		"prev_lv": prev_lv,
		"new_lv": new_lv,
		"world_pos": player.global_position,
	}
	if was_new and new_lv == 1:
		EventBus.weapon_presentation_requested.emit(StringName(id), &"first_acquire", payload)
	elif prev_lv >= 1 and new_lv > prev_lv:
		EventBus.weapon_presentation_requested.emit(StringName(id), &"level_up", payload)


func apply_fusion(fid: String) -> void:
	match fid:
		"kunai_ex": level_map["kunai"] = 6
		"quantum_ball_ex": level_map["quantum_ball"] = 6
		"lightning_ex": level_map["lightning"] = 6
		"rocket_ex": level_map["rocket"] = 6
		"molotov_ex": level_map["molotov"] = 6
		"guardian_ex": level_map["guardian"] = 6
		"drone_ex": level_map["drone_ab"] = 6
		"boomerang_ex": level_map["boomerang"] = 6
		# ========== 新功能性武器融合 ==========
		"frost_aura_ex": level_map["frost_aura"] = 6
		"stun_mine_ex": level_map["stun_mine"] = 6
		"heal_aura_ex": level_map["heal_aura"] = 6
	EventBus.fusion_applied.emit(StringName(fid))

func _scaled_cd(wid: String) -> float:
	var fr := 0.0
	if _skill_system and _skill_system.stats.has("fire_rate"):
		fr = float(_skill_system.stats["fire_rate"])
	# fire_rate 与升级卡一致：+0.10 → APS +10%（CD = base / (1+fr)）
	var base: float = float(cd_map[wid]) / maxf(0.3, 1.0 + fr)
	# 《弓箭手传说》：站定略减武器间隔（边走边打略慢）
	if player and player.velocity.length() < GameDB.ARCHERO_STATIONARY_VEL_THRESH:
		base *= GameDB.ARCHERO_STATIONARY_WEAPON_CD_MUL
	return base


func _ensure_runtime_refs() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if player == null or not is_instance_valid(player):
		player = parent.get_node_or_null("Player")
	if enemy_manager == null or not is_instance_valid(enemy_manager):
		enemy_manager = parent.get_node_or_null("EnemyManager")
	if _skill_system == null or not is_instance_valid(_skill_system):
		_skill_system = parent.get_node_or_null("SkillSystem")
	if _particle_mgr == null or not is_instance_valid(_particle_mgr):
		_particle_mgr = parent.get_node_or_null("ParticleManager")
	_ensure_projectile_layer()


func _ensure_projectile_layer() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if _projectile_layer != null and is_instance_valid(_projectile_layer):
		return
	_projectile_layer = parent.get_node_or_null("WeaponProjectileLayer") as WeaponProjectileLayer
	if _projectile_layer != null:
		return
	_projectile_layer = WeaponProjectileLayer.new()
	_projectile_layer.name = "WeaponProjectileLayer"
	_projectile_layer.z_index = 12
	parent.call_deferred("add_child", _projectile_layer)


func _world_curse_out_damage_mul() -> float:
	var g := get_parent()
	if g != null and g.has_method("get_curse_outgoing_damage_mul"):
		return float(g.call("get_curse_outgoing_damage_mul"))
	return 1.0


func _stat(key: String, default: float = 0.0) -> float:
	if _skill_system and _skill_system.stats.has(key):
		return float(_skill_system.stats[key])
	return default


# ============================================
# 8种武器独特行为实现
# ============================================

func _fire_weapon(wid: String) -> void:
	var p: Vector2 = player.global_position
	var lv := int(level_map[wid])
	# 攻击力被动加成
	var atk_bonus := 1.0
	if _skill_system and _skill_system.stats.has("atk_bonus"):
		atk_bonus = 1.0 + float(_skill_system.stats["atk_bonus"])
	# 暴击判定
	var is_crit := false
	var crit_chance := GameDB.BASE_CRIT_CHANCE
	if _skill_system and _skill_system.stats.has("crit_chance"):
		crit_chance = float(_skill_system.stats["crit_chance"])
	if randf() < crit_chance:
		is_crit = true
		atk_bonus *= GameDB.CRIT_MULTIPLIER
	var ex_mul := (1.5 if lv >= 6 else 1.0) * atk_bonus * _world_curse_out_damage_mul() * _early_game_damage_mul(wid, lv)
	var is_evolved := lv >= 6
	_shot_is_crit = is_crit
	match wid:
		"kunai":
			_fire_kunai(p, lv, ex_mul, is_evolved)
		"quantum_ball":
			_fire_quantum_ball(p, lv, ex_mul, is_evolved)
		"lightning":
			_fire_lightning(p, lv, ex_mul, is_evolved)
		"rocket":
			_fire_rocket(p, lv, ex_mul, is_evolved)
		"molotov":
			_fire_molotov(p, lv, ex_mul, is_evolved)
		"guardian":
			_fire_guardian(p, lv, ex_mul, is_evolved)
		"drone_ab":
			_fire_drone(p, lv, ex_mul, is_evolved)
		"boomerang":
			_fire_boomerang(p, lv, ex_mul, is_evolved)
		# ========== 新功能性武器 ==========
		"frost_aura":
			_fire_frost_aura(p, lv, ex_mul, is_evolved)
		"stun_mine":
			_fire_stun_mine(p, lv, ex_mul, is_evolved)
		"heal_aura":
			_fire_heal_aura(p, lv, ex_mul, is_evolved)
	_shot_is_crit = false


func _orbit_damage_mul(is_evolved: bool) -> float:
	var atk := 1.0
	if _skill_system and _skill_system.stats.has("atk_bonus"):
		atk = 1.0 + float(_skill_system.stats["atk_bonus"])
	return (1.5 if is_evolved else 1.0) * atk * _world_curse_out_damage_mul()


func _early_game_damage_mul(_wid: String, _lv: int) -> float:
	return 1.0

# 1. 苦无 - 投掷武器，进化后无限追踪穿透
func _fire_kunai(p: Vector2, lv: int, ex_mul: float, is_evolved: bool) -> void:
	var card: Dictionary = _WEAPON_LOGIC_CARD["kunai"]
	var origin := _weapon_fire_origin()
	var target: Variant = _nearest_enemy_pos(p)
	if target == null:
		target = p + Vector2.RIGHT * 200.0
	
	var dmg := (20.0 + lv * 5.5) * ex_mul
	var rad := 12.0 + lv * 1.5
	var target_pos := Vector2(target)
	var aim_dir := (target_pos - p).normalized() if target != null else Vector2.RIGHT
	var travel := clampf(
		origin.distance_to(target_pos),
		float(card["travel_min"]),
		float(card["travel_max_base"]) + lv * float(card["travel_max_per_lv"])
	)
	target_pos = origin + aim_dir * travel
	var arc_side := 1.0 if randf() > 0.5 else -1.0
	var arc_strength := float(card["trail_arc_mul_base"]) + lv * float(card["trail_arc_mul_per_lv"])
	var arc_jitter := randf_range(-float(card["trail_arc_jitter"]), float(card["trail_arc_jitter"]))
	var arc_mid := origin.lerp(target_pos, 0.44) + aim_dir.orthogonal() * arc_jitter * arc_strength * arc_side
	if lv >= 3:
		# 高等级：S 形双控制点，弹道更可辨
		var arc_mid2 := origin.lerp(target_pos, 0.72) + aim_dir.orthogonal() * arc_jitter * arc_strength * -arc_side * 0.55
		_projectile_visual_bezier_cubic(origin, arc_mid, arc_mid2, target_pos, "kunai", 0.42, lv, is_evolved)
	else:
		_projectile_visual_bezier(origin, arc_mid, target_pos, "kunai", 0.38, lv, is_evolved)
	var fan_bonus := _stat("kunai_fan_angle")
	if lv >= 2 or is_evolved:
		var kunai_echo_spread := 0.07 + float(lv) * 0.006 + fan_bonus
		var echo_arc_l := origin.lerp(target_pos, 0.5) + aim_dir.orthogonal() * (-18.0 - float(lv) * 2.0)
		var echo_arc_r := origin.lerp(target_pos, 0.5) + aim_dir.orthogonal() * (18.0 + float(lv) * 2.0)
		_projectile_visual_bezier(origin + aim_dir.orthogonal() * -5.0, echo_arc_l, target_pos, "kunai", 0.2, lv, is_evolved, aim_dir.rotated(-kunai_echo_spread))
		_projectile_visual_bezier(origin + aim_dir.orthogonal() * 5.0, echo_arc_r, target_pos, "kunai", 0.2, lv, is_evolved, aim_dir.rotated(kunai_echo_spread))
	if _weapon_telegraph != null and _runtime_pressure_mul() < 1.2:
		_weapon_telegraph.add_kunai_impact_cross(target_pos, aim_dir, 0.14, 0.82 + lv * 0.04)
	var line_hits := _get_enemies_in_line(origin, target_pos, float(card["line_width_base"]) + lv * float(card["line_width_per_lv"]))
	var line_hit_cap := int(card["line_hit_cap_base"]) + int(lv / int(card["line_lv_div"] if card.has("line_lv_div") else card["line_hit_cap_lv_div"])) + (int(card["line_hit_cap_evolved_bonus"]) if is_evolved else 0) + int(_stat("kunai_pierce"))
	var line_damage := dmg * (float(card["line_damage_mul_evolved"]) if is_evolved else float(card["line_damage_mul_normal"]))
	var hit_count := 0
	for hit_pos in line_hits:
		if hit_count >= line_hit_cap:
			break
		enemy_manager.apply_damage_circle(hit_pos, rad * 0.45, line_damage, &"kunai")
		_report_damage("kunai_hit", line_damage, false, is_evolved, hit_pos)
		hit_count += 1
	var finisher_dmg := dmg * (1.25 if is_evolved else 1.0)
	enemy_manager.apply_damage_circle(target_pos, rad * float(card["finisher_radius_mul"]), finisher_dmg, &"kunai")
	var to_boss: bool = enemy_manager.apply_damage_to_boss(target_pos, rad * float(card["finisher_radius_mul"]), finisher_dmg)
	_report_damage("kunai_finish", finisher_dmg, to_boss, is_evolved, target_pos)
	if is_evolved:
		for side in [-1.0, 1.0]:
			var side_dir := aim_dir.rotated(side * (0.24 + fan_bonus))
			var side_end := origin + side_dir * (travel * 0.82)
			_projectile_line_salvo(origin, side_end, "kunai", 0.12, 5, lv, true)
			var side_hits := _get_enemies_in_line(origin, side_end, 14.0 + lv * 1.4)
			var side_dmg := dmg * 0.42
			var side_cap := 2 + int(lv / 3)
			var side_count := 0
			for side_hit in side_hits:
				if side_count >= side_cap:
					break
				enemy_manager.apply_damage_circle(side_hit, rad * 0.36, side_dmg, &"kunai")
				_report_damage("kunai_pierce", side_dmg, false, true, side_hit)
				side_count += 1

# 2. 足球 - 反弹+AOE，进化后神圣一击
func _fire_quantum_ball(p: Vector2, lv: int, ex_mul: float, is_evolved: bool) -> void:
	var card: Dictionary = _WEAPON_LOGIC_CARD["quantum_ball"]
	# 寻找最佳目标（敌人密集区域）
	var target: Variant = _find_best_aoe_target(p, float(card["search_radius_base"]) + lv * float(card["search_radius_per_lv"]))
	if target == null:
		target = p + _rand_vec(180.0)
	
	var aim_dir := (Vector2(target) - p).normalized()
	var tg: Vector2 = Vector2(target)
	var mid := p.lerp(tg, 0.48) + aim_dir.orthogonal() * (22.0 + lv * 2.5)
	_projectile_visual_bezier(p, mid, tg, "quantum_ball", 0.44, lv, is_evolved)
	
	var dmg := (25.0 + lv * 7.2) * ex_mul
	var rad := float(card["burst_radius_base"]) + lv * float(card["burst_radius_per_lv"])
	
	if _weapon_telegraph != null:
		var pressure := _runtime_pressure_mul()
		_weapon_telegraph.add_quantum_burst_preview(tg, rad, 0.18)
		if pressure < 1.05:
			_weapon_telegraph.add_quantum_hex_pulse(tg, rad * 0.84, 0.14)
	_projectile_line_salvo(p, tg, "quantum_ball", 0.14, 6, lv, is_evolved)
	
	# 主爆炸
	enemy_manager.apply_damage_circle(target, rad, dmg, &"quantum_ball")
	var to_boss: bool = enemy_manager.apply_damage_to_boss(target, rad, dmg)
	_report_damage("quantum_burst", dmg, to_boss, is_evolved, target)
	var q_hex_dmg := dmg * float(card["hex_damage_mul"])
	for i in range(int(card["hex_count"])):
		var ang := TAU * float(i) / float(int(card["hex_count"]))
		var q_pos := tg + Vector2(cos(ang), sin(ang)) * (rad * float(card["hex_ring_mul"]))
		enemy_manager.apply_damage_circle(q_pos, rad * float(card["hex_radius_mul"]), q_hex_dmg, &"quantum_ball")
		var q_boss: bool = enemy_manager.apply_damage_to_boss(q_pos, rad * float(card["hex_radius_mul"]), q_hex_dmg)
		_report_damage("quantum_hex", q_hex_dmg, q_boss, is_evolved, q_pos)
	
	# 反弹链式效果
	var chain_count := int(card["chain_base"]) + int(lv / int(card["chain_lv_div"])) + (int(card["chain_evolved_bonus"]) if is_evolved else 0)
	var last_pos: Vector2 = target if target != null else p
	var visited: Array[Vector2] = []
	visited.append(target if target != null else p)
	
	for i in chain_count:
		var next_target: Variant = _find_bounce_target(last_pos, visited, float(card["chain_search_radius"]))
		if next_target == null:
			break
		var next_pos := Vector2(next_target)
		
		visited.append(next_pos)
		
		if _projectile_layer != null:
			_projectile_line_salvo(last_pos, next_pos, "quantum_ball", 0.12, 5, lv, is_evolved)
		
		var chain_dmg := dmg * (0.5 if i == 0 else 0.35)
		var chain_rad := rad * (0.7 if i == 0 else 0.5)
		
		enemy_manager.apply_damage_circle(next_pos, chain_rad, chain_dmg, &"quantum_ball")
		var chain_boss: bool = enemy_manager.apply_damage_to_boss(next_pos, chain_rad, chain_dmg)
		_report_damage("quantum_bounce", chain_dmg, chain_boss, is_evolved, next_pos)
		
		last_pos = next_pos
	
	# 进化：神圣一击（对BOSS额外伤害）
	if is_evolved and to_boss:
		var holy_dmg := dmg * 0.5
		enemy_manager.apply_damage_circle(target, rad * 0.5, holy_dmg, &"quantum_ball")
		_report_damage("quantum_holy", holy_dmg, true, true, target)

# 3. 雷电 - 高爆发+眩晕，链式跳跃
func _fire_lightning(p: Vector2, lv: int, ex_mul: float, is_evolved: bool) -> void:
	var card: Dictionary = _WEAPON_LOGIC_CARD["lightning"]
	var target: Variant = _nearest_enemy_pos(p)
	if target == null:
		target = p + _rand_vec(260.0)
	
	var dmg := (41.0 + lv * 9.0) * ex_mul
	var rad := float(card["strike_radius_base"]) + lv * float(card["strike_radius_per_lv"])
	
	# 显示雷电预警 + 弹体齐射（玩家→目标）
	if _weapon_telegraph != null:
		var pressure := _runtime_pressure_mul()
		_weapon_telegraph.add_lightning_mark(target, rad, 0.06)
		if pressure < 1.2:
			_weapon_telegraph.add_lightning_hex_pulse(Vector2(target), rad * 0.62, 0.14)
	_projectile_line_salvo(p, Vector2(target), "lightning", 0.11, 7, lv, is_evolved)
	
	# 主雷电伤害
	enemy_manager.apply_damage_circle(target, rad, dmg, &"lightning")
	var to_boss: bool = enemy_manager.apply_damage_to_boss(target, rad, dmg)
	_report_damage("lightning_strike", dmg, to_boss, is_evolved, target)
	var hex_points := int(card["hex_points"])
	var hex_ring := rad * float(card["hex_ring_mul"])
	var hex_dmg := dmg * float(card["hex_damage_mul"])
	for i in range(hex_points):
		var ang := TAU * float(i) / float(hex_points)
		var node_pos := Vector2(target) + Vector2(cos(ang), sin(ang)) * hex_ring
		enemy_manager.apply_damage_circle(node_pos, rad * float(card["hex_radius_mul"]), hex_dmg, &"lightning")
		var hex_boss: bool = enemy_manager.apply_damage_to_boss(node_pos, rad * float(card["hex_radius_mul"]), hex_dmg)
		_report_damage("lightning_hex", hex_dmg, hex_boss, is_evolved, node_pos)
	EventBus.lightning_strike.emit(p, Vector2(target))
	EventBus.enemy_stunned.emit(Vector2(target), float(card["main_stun_evolved"]) if is_evolved else float(card["main_stun_normal"]))
	
	# 链式跳跃（避免反复命中同一目标）；雷链专精加次数/距离
	var jump_count := int(card["jump_base"]) + int(lv / int(card["jump_lv_div"])) + (int(card["jump_evolved_bonus"]) if is_evolved else 0) + int(_stat("lightning_jumps"))
	var jump_range := float(card["jump_range_base"]) + lv * float(card["jump_range_per_lv"]) + _stat("lightning_jump_range")
	var last_pos2: Vector2 = target if target != null else p
	var jump_dmg := dmg * 0.6
	var visited: Array[Vector2] = []
	visited.append(last_pos2)

	for _i in jump_count:
		var jump_target: Variant = _find_bounce_target(last_pos2, visited, jump_range)
		var lp2: Vector2 = last_pos2
		if jump_target == null or jump_target.distance_to(lp2) > jump_range:
			break
		var jump_pos: Vector2 = jump_target
		visited.append(jump_pos)

		_projectile_line_salvo(lp2, jump_pos, "lightning", 0.1, 5, lv, is_evolved)

		enemy_manager.apply_damage_circle(jump_pos, rad * 0.7, jump_dmg, &"lightning")
		var jump_boss: bool = enemy_manager.apply_damage_to_boss(jump_pos, rad * 0.7, jump_dmg)
		_report_damage("lightning_jump", jump_dmg, jump_boss, is_evolved, jump_pos)
		EventBus.lightning_strike.emit(lp2, jump_pos)
		EventBus.enemy_stunned.emit(jump_pos, 0.1 if not is_evolved else 0.28)
		if is_evolved and randf() < 0.58:
			var branch_t: Variant = _find_bounce_target(jump_pos, visited, jump_range * 0.58)
			if branch_t != null:
				var branch_pos := Vector2(branch_t)
				_projectile_line_salvo(jump_pos, branch_pos, "lightning", 0.09, 4, lv, true)
				var branch_dmg := jump_dmg * 0.46
				enemy_manager.apply_damage_circle(branch_pos, rad * 0.52, branch_dmg, &"lightning")
				var branch_boss: bool = enemy_manager.apply_damage_to_boss(branch_pos, rad * 0.52, branch_dmg)
				_report_damage("lightning_jump", branch_dmg, branch_boss, true, branch_pos)
				EventBus.enemy_stunned.emit(branch_pos, 0.08 if not is_evolved else 0.2)

		last_pos2 = jump_pos
		jump_dmg *= 0.8  # 伤害递减

# 4. 火箭 - 爆炸范围伤害，延迟引爆
func _fire_rocket(p: Vector2, lv: int, ex_mul: float, is_evolved: bool) -> void:
	var card: Dictionary = _WEAPON_LOGIC_CARD["rocket"]
	var target: Variant = _find_best_aoe_target(p, float(card["search_radius"]))
	if target == null:
		target = p + _rand_vec(210.0)
	
	var aim_dir := (Vector2(target) - p).normalized()
	var tg: Vector2 = Vector2(target)
	var arc_ctrl := p.lerp(tg, 0.55) + aim_dir.orthogonal() * (28.0 + lv * 2.0)
	_projectile_visual_bezier(p, arc_ctrl, tg, "rocket", float(card["life"]) * 0.92, lv, is_evolved)
	# 火箭发射瞬间增加尾焰，强调“重型发射器”反馈。
	if _particle_mgr != null:
		_particle_mgr.rocket_embers(p - aim_dir * 10.0, Color(1.0, 0.7, 0.36, 0.95))
	
	var dmg := (58.0 + lv * 10.5) * ex_mul
	var rad := float(card["blast_radius_base"]) + lv * float(card["blast_radius_per_lv"])
	var delay := float(card["delay_evolved"]) if is_evolved else float(card["delay_normal"])
	
	# 显示火箭预警
	if _weapon_telegraph != null:
		_weapon_telegraph.add_rocket_mark(target, rad, delay)
		_weapon_telegraph.add_rocket_fan(Vector2(target), aim_dir, rad * 1.12, 0.2)
	if _particle_mgr != null:
		_particle_mgr.shockwave_ring(Vector2(target), Color(1.0, 0.62, 0.24, 0.58))
	
	# 延迟爆炸
	_rocket_pending.append({
		"pos": target,
		"radius": rad,
		"damage": dmg,
		"time": delay,
		"is_evolved": is_evolved,
		"dir": aim_dir,
		"is_crit": _shot_is_crit,
	})

# 5. 燃烧瓶 - 地面持续灼烧AOE
func _fire_molotov(p: Vector2, lv: int, ex_mul: float, is_evolved: bool) -> void:
	var target: Variant = _find_best_aoe_target(p, 170.0)
	if target == null:
		target = p + _rand_vec(170.0)
	
	var aim_dir := (Vector2(target) - p).normalized()
	var tg: Vector2 = Vector2(target)
	var apex := p.lerp(tg, 0.42) + Vector2(0.0, -48.0 - lv * 4.0)
	_projectile_visual_bezier(p, apex, tg, "molotov", 0.48, lv, is_evolved)
	
	var burn_mul := 1.0 + _stat("burn_dps_mul")
	var dmg := (19.0 + lv * 4.5) * ex_mul * burn_mul
	var rad := 115.0 + lv * 5.0
	var burn_time := 3.2 + lv * 0.25
	
	if is_evolved:
		burn_time *= 1.5
		rad *= 1.3
	
	if _weapon_telegraph != null:
		_weapon_telegraph.add_molotov_impact_flash(Vector2(target), rad * 0.5, 0.16)
		_weapon_telegraph.add_burn_mark(target, rad, burn_time)
		_weapon_telegraph.add_molotov_cone(Vector2(target), aim_dir, rad * 0.94, 0.16)
	
	# 落地瞬间小范围爆发，提升手感
	var impact_dmg := dmg * (0.9 if is_evolved else 0.6)
	enemy_manager.apply_damage_circle(target, rad * 0.45, impact_dmg, &"molotov")
	var impact_boss: bool = enemy_manager.apply_damage_to_boss(target, rad * 0.45, impact_dmg)
	_report_damage("molotov_impact", impact_dmg, impact_boss, is_evolved, target)
	_apply_sector_damage(Vector2(target), aim_dir, rad * 0.8, 40.0 if is_evolved else 32.0, impact_dmg * 0.46, "molotov_cone", true, is_evolved)

	# 添加燃烧区域（DOT 跳字本身关闭；命中皮不标暴击，避免持续假暴击）
	_burn_zones.append({
		"pos": target,
		"radius": rad,
		"dps": dmg,
		"tick": 0.0,
		"tick_interval": 0.4,
		"time": burn_time,
		"is_evolved": is_evolved,
		"is_crit": false,
		"spread_chance": _stat("burn_spread_chance"),
		"can_spread": true,
	})

# 6. 守卫者 - 旋转挡弹+击退
func _fire_guardian(p: Vector2, lv: int, ex_mul: float, is_evolved: bool) -> void:
	var dmg := (10.5 + lv * 2.2) * ex_mul
	var rad := 92.0 + lv * 8.0 + _stat("orbit_radius")
	var guardian_count := 2 + int(lv / 2) + int(_stat("orbit_count"))
	if is_evolved:
		guardian_count += 2
	
	if _weapon_telegraph != null:
		_weapon_telegraph.add_guardian_mark(p, rad, 0.34, guardian_count, 1.22 if is_evolved else 1.0)
	
	# 立即造成一次伤害
	enemy_manager.apply_damage_circle(p, rad * 0.6, dmg, &"guardian")
	var to_boss: bool = enemy_manager.apply_damage_to_boss(p, rad * 0.6, dmg)
	_report_damage("guardian_spin", dmg, to_boss, is_evolved, p)
	
	# 击退效果（进化更强）
	EventBus.area_knockback.emit(p, rad, 95.0 if not is_evolved else 170.0)

# 7. AB无人机 - 自动跟随攻击
func _fire_drone(p: Vector2, lv: int, ex_mul: float, is_evolved: bool) -> void:
	var drone_count := 2 + int(lv / 3) + int(_stat("orbit_count"))
	if is_evolved:
		drone_count += 2
	
	# 更新无人机位置
	while _drone_positions.size() < drone_count:
		_drone_positions.append(p)
	while _drone_positions.size() > drone_count:
		_drone_positions.pop_back()
	
	for i in range(drone_count):
		var angle := _drone_angle + (TAU / drone_count) * i
		var orbit_radius := 80.0 + lv * 5.0 + _stat("orbit_radius")
		var drone_pos := p + Vector2(cos(angle), sin(angle)) * orbit_radius
		_drone_positions[i] = drone_pos
		
		var dmg := (11.5 + lv * 2.2) * ex_mul
		var rad := 52.0 + lv * 2.0
		
		# 显示无人机
		if _weapon_telegraph != null:
			_weapon_telegraph.add_drone_mark(p, drone_pos, 0.22, 5.0)
		
		# 无人机扫射（替代原地圆形伤害）：提高武器辨识度
		var target: Variant = _nearest_enemy_pos(drone_pos, 180.0 + lv * 12.0)
		var hit_pos: Vector2 = drone_pos + Vector2.RIGHT * 26.0
		if target != null:
			hit_pos = Vector2(target)
		var sweep_hits := _get_enemies_in_line(drone_pos, hit_pos, 22.0 + lv * 1.8)
		var sweep_cap := 3 + int(lv / 2) + (2 if is_evolved else 0)
		var sweep_dmg := dmg * 0.62
		var hit_count := 0
		for s in sweep_hits:
			if hit_count >= sweep_cap:
				break
			enemy_manager.apply_damage_circle(s, rad * 0.3, sweep_dmg, &"drone_ab")
			_report_damage("drone_sweep", sweep_dmg, false, is_evolved, s)
			hit_count += 1
		var burst_dmg := dmg * (0.95 if is_evolved else 0.8)
		enemy_manager.apply_damage_circle(hit_pos, rad * 0.42, burst_dmg, &"drone_ab")
		var to_boss: bool = enemy_manager.apply_damage_to_boss(hit_pos, rad * 0.42, burst_dmg)
		_report_damage("drone_attack", burst_dmg, to_boss, is_evolved, hit_pos)
		_projectile_line_salvo(drone_pos, hit_pos, "drone_ab", 0.12, 5, lv, is_evolved)

# 8. 回旋镖 - 回旋轨迹
func _fire_boomerang(p: Vector2, lv: int, ex_mul: float, is_evolved: bool) -> void:
	var target: Variant = _nearest_enemy_pos(p)
	if target == null:
		target = p + _rand_vec(170.0)
	
	var aim_dir := (Vector2(target) - p).normalized()
	var tg: Vector2 = Vector2(target)
	var out_arc := p.lerp(tg, 0.62) + aim_dir.orthogonal() * 24.0
	_projectile_visual_bezier(p, out_arc, tg, "boomerang", 0.28, lv, is_evolved)
	
	var dmg := (26.0 + lv * 5.5) * ex_mul
	var rad := 82.0 + lv * 3.0
	
	if _weapon_telegraph != null:
		_weapon_telegraph.add_boomerang_crescent(tg, (tg - p).normalized(), 0.2, 1.0 + lv * 0.04)
	
	enemy_manager.apply_damage_circle(target, rad, dmg, &"boomerang")
	var to_boss: bool = enemy_manager.apply_damage_to_boss(target, rad, dmg)
	_report_damage("boomerang_out", dmg, to_boss, is_evolved, target)
	_apply_sector_damage(tg, (tg - p).normalized(), rad * 0.72, 28.0, dmg * 0.35, "boomerang_crescent", true, is_evolved)
	
	var return_pos: Vector2 = p + (p - target).normalized() * minf(90.0 + lv * 6.0, target.distance_to(p))
	var ret_arc := tg.lerp(return_pos, 0.58) + (return_pos - tg).orthogonal() * 18.0
	_projectile_visual_bezier(tg, ret_arc, return_pos, "boomerang", 0.32, lv, is_evolved)
	
	if _weapon_telegraph != null:
		_weapon_telegraph.add_boomerang_crescent(return_pos, (p - tg).normalized(), 0.22, 0.9 + lv * 0.03)
	
	var ret_dmg := dmg * (0.7 if lv < 6 else 0.9)
	enemy_manager.apply_damage_circle(return_pos, rad * 0.8, ret_dmg, &"boomerang")
	var ret_boss: bool = enemy_manager.apply_damage_to_boss(return_pos, rad * 0.8, ret_dmg)
	_report_damage("boomerang_return", ret_dmg, ret_boss, is_evolved, return_pos)
	
	if is_evolved:
		var orbit_pos: Vector2 = p + (tg - p).rotated(PI / 2).normalized() * 100.0
		enemy_manager.apply_damage_circle(orbit_pos, rad * 0.6, dmg * 0.5, &"boomerang")
		_report_damage("boomerang_orbit", dmg * 0.5, false, true, orbit_pos)
		_projectile_visual_bezier(return_pos, (return_pos + orbit_pos) * 0.5 + (orbit_pos - return_pos).orthogonal() * 14.0, orbit_pos, "boomerang", 0.22, lv, true)
		_projectile_visual_bezier(orbit_pos, (orbit_pos + p) * 0.5 + (p - orbit_pos).orthogonal() * 12.0, p, "boomerang", 0.18, lv, true)

# ========== 9. 冰霜领域 - 持续减速周围敌人 ==========
func _fire_frost_aura(p: Vector2, lv: int, ex_mul: float, is_evolved: bool) -> void:
	_frost_aura_active = true
	_frost_aura_timer = 0.5  # 每次触发持续0.5秒
	
	# 显示冰霜领域特效
	if _weapon_telegraph != null:
		var aura_radius := 140.0 + lv * 15.0 + _stat("frost_spread_radius") * 0.5
		if is_evolved:
			aura_radius *= 1.5
		_weapon_telegraph.add_frost_aura_mark(p, aura_radius, 0.4)
	var frost_dmg := (6.0 + lv * 1.35) * ex_mul
	enemy_manager.apply_damage_circle(p, 68.0 + lv * 5.0, frost_dmg, &"frost_aura")
	var frost_boss: bool = enemy_manager.apply_damage_to_boss(p, 68.0 + lv * 5.0, frost_dmg)
	_report_damage("frost_wave", frost_dmg, frost_boss, is_evolved, p)

# ========== 10. 眩晕地雷 - 踩到触发范围眩晕 ==========
func _fire_stun_mine(p: Vector2, lv: int, ex_mul: float, is_evolved: bool) -> void:
	# 在玩家朝向（自动锁敌 / 鼠标 / 触摸瞄准）前方放置地雷
	var nearest: Variant = _nearest_enemy_pos(p)
	var nearest_pos := Vector2.ZERO if nearest == null else Vector2(nearest)
	var aim_dir: Vector2 = InputManager.get_aim_direction(p, nearest_pos)
	var mine_pos: Vector2 = p + aim_dir * (80.0 + lv * 10.0)
	
	# 限制地雷数量
	var max_mines := 3 + lv
	if is_evolved:
		max_mines += 2
	while _mine_positions.size() >= max_mines:
		_mine_positions.pop_front()
	
	_mine_positions.append(mine_pos)
	
	# 显示地雷
	if _weapon_telegraph != null:
		_weapon_telegraph.add_mine_mark(mine_pos, 45.0 + lv * 3.0, 0.3)

# ========== 11. 治疗光环 - 持续恢复生命（不打伤害，不占输出栏位判定见 level_up_weapon）==========
func _fire_heal_aura(p: Vector2, lv: int, ex_mul: float, is_evolved: bool) -> void:
	_heal_aura_timer = 0.4
	if _weapon_telegraph != null:
		var heal_radius := 120.0 + lv * 12.0
		if is_evolved:
			heal_radius *= 1.4
		_weapon_telegraph.add_heal_aura_mark(p, heal_radius, 0.3)
	# 进化时轻量驱散周围，替代原伤害占用定位
	if is_evolved:
		EventBus.area_knockback.emit(p, 70.0 + lv * 4.0, 48.0)

# ============================================
# 辅助函数
# ============================================

## 与自动武器（如苦无）寻敌一致的瞄准方向：最近敌人体方向；无敌人时向右。
func get_auto_weapon_aim_dir(from_pos: Vector2) -> Vector2:
	var tgt: Variant = _nearest_enemy_pos(from_pos)
	if tgt == null:
		return Vector2.RIGHT
	return (Vector2(tgt) - from_pos).normalized()


func _weapon_fire_origin() -> Vector2:
	if player != null and is_instance_valid(player) and player.has_method("get_weapon_fire_origin"):
		return player.call("get_weapon_fire_origin") as Vector2
	if player != null and is_instance_valid(player):
		return player.global_position
	return Vector2.ZERO


func _nearest_enemy_pos(center: Vector2, max_range := 99999.0) -> Variant:
	return enemy_manager.get_closest_enemy_pos(center, max_range)

func _rand_vec(radius: float) -> Vector2:
	var a: float = randf() * TAU
	var r: float = randf() * radius
	return Vector2(cos(a), sin(a)) * r

# 寻找最佳AOE目标（敌人最密集的区域）
func _find_best_aoe_target(center: Vector2, radius: float) -> Vector2:
	var nearest: Variant = _nearest_enemy_pos(center, radius)
	if nearest == null:
		return center + _rand_vec(radius * 0.5)
	return Vector2(nearest)

# 寻找反弹目标（避免重复）
func _find_bounce_target(from: Vector2, visited: Array[Vector2], search_radius: float) -> Variant:
	var candidates: Array[Vector2] = enemy_manager.get_enemies_in_radius(from, search_radius)
	for enemy_pos in candidates:
		var is_visited := false
		for v in visited:
			if enemy_pos.distance_to(v) < 20.0:
				is_visited = true
				break
		if not is_visited:
			return enemy_pos
	return null

# 获取直线上的敌人
func _get_enemies_in_line(start: Vector2, end: Vector2, width: float) -> Array[Vector2]:
	return enemy_manager.get_enemies_in_line(start, end, width)

func _kill_weapon_for_sector_source(source: String) -> StringName:
	match source:
		"molotov_cone", "molotov_impact", "molotov_burn":
			return &"molotov"
		"rocket_cone", "rocket_explode", "rocket_secondary":
			return &"rocket"
		"boomerang_crescent", "boomerang_out", "boomerang_return", "boomerang_orbit":
			return &"boomerang"
		"mine_wave", "mine_explosion":
			return &"stun_mine"
		"guardian_slice", "guardian_spin", "guardian_tick":
			return &"guardian"
	return &""


func _apply_sector_damage(center: Vector2, dir: Vector2, radius: float, half_angle_deg: float, dmg: float, source: String, to_boss_check := true, from_fusion := false, is_crit: Variant = null) -> void:
	if radius <= 1.0 or dmg <= 0.01:
		return
	var n := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var cos_th := cos(deg_to_rad(clampf(half_angle_deg, 5.0, 90.0)))
	var kill_w := _kill_weapon_for_sector_source(source)
	var candidates: Array[Vector2] = enemy_manager.get_enemies_in_radius(center, radius)
	for epos in candidates:
		var v := epos - center
		var d := v.length()
		if d < 0.01 or d > radius:
			continue
		if n.dot(v / d) < cos_th:
			continue
		enemy_manager.apply_damage_circle(epos, 12.0, dmg, kill_w)
		_report_damage(source, dmg, false, from_fusion, epos, is_crit)
	if to_boss_check:
		var boss_pos: Vector2 = enemy_manager.boss_pos()
		var boss_vec := boss_pos - center
		var boss_dist := boss_vec.length()
		if enemy_manager.boss_alive() and boss_dist > 0.01 and boss_dist <= radius and n.dot(boss_vec / boss_dist) >= cos_th:
			var to_boss: bool = enemy_manager.apply_damage_to_boss(boss_pos, 22.0, dmg)
			if to_boss:
				_report_damage(source, dmg, true, from_fusion, boss_pos, is_crit)

func _on_fusion_applied(fid: StringName) -> void:
	RunStats.fusions += 1
	if MetaProgress != null and MetaProgress.has_method("mark_fusion_seen"):
		MetaProgress.mark_fusion_seen(String(fid))

# ============================================
# 特效更新
# ============================================

func _update_rocket_pending(delta: float) -> void:
	for i in range(_rocket_pending.size() - 1, -1, -1):
		var item: Dictionary = _rocket_pending[i]
		item["time"] = float(item["time"]) - delta
		
		if float(item["time"]) <= 0.0:
			var pos: Vector2 = item["pos"]
			var radius := float(item["radius"])
			var damage := float(item["damage"]) * _world_curse_out_damage_mul()
			var is_evolved: bool = item.get("is_evolved", false)
			var impact_dir: Vector2 = item.get("dir", Vector2.RIGHT)
			var rocket_crit: bool = bool(item.get("is_crit", false))
			
			# 爆炸伤害
			enemy_manager.apply_damage_circle(pos, radius, damage, &"rocket")
			var to_boss: bool = enemy_manager.apply_damage_to_boss(pos, radius, damage)
			_report_damage("rocket_explode", damage, to_boss, is_evolved, pos, rocket_crit)
			# 前向扇区冲击波（命中形状差异化）
			_apply_sector_damage(pos, impact_dir, radius * (1.2 if is_evolved else 1.02), 34.0 if is_evolved else 28.0, damage * 0.34, "rocket_cone", true, is_evolved, rocket_crit)
			
			# 进化：二次爆炸
			if is_evolved:
				var secondary_dmg := damage * 0.4
				enemy_manager.apply_damage_circle(pos, radius * 1.5, secondary_dmg, &"rocket")
				_report_damage("rocket_secondary", secondary_dmg, to_boss, true, pos, rocket_crit)
			
			_rocket_pending.remove_at(i)

func _update_burn_zones(delta: float) -> void:
	for i in range(_burn_zones.size() - 1, -1, -1):
		var z: Dictionary = _burn_zones[i]
		z["time"] = float(z["time"]) - delta
		z["tick"] = float(z["tick"]) - delta
		
		if float(z["tick"]) <= 0.0:
			z["tick"] = float(z["tick_interval"])
			var pos: Vector2 = z["pos"]
			var radius := float(z["radius"])
			var dps := float(z["dps"])
			var is_evolved: bool = z.get("is_evolved", false)
			var tick_damage := dps * float(z["tick_interval"]) * _world_curse_out_damage_mul()
			
			enemy_manager.apply_damage_circle(pos, radius, tick_damage, &"molotov")
			var to_boss: bool = enemy_manager.apply_damage_to_boss(pos, radius, tick_damage)
			_report_damage("molotov_burn", tick_damage, to_boss, is_evolved, pos, false)
			# 燃爆专精：有几率向邻格蔓延次级火池（不可再蔓延，防雪崩）
			if bool(z.get("can_spread", false)) and _burn_zones.size() < 14:
				var spread_p := float(z.get("spread_chance", 0.0))
				if spread_p > 0.0 and randf() < spread_p:
					var ang := randf() * TAU
					var spread_pos := pos + Vector2(cos(ang), sin(ang)) * (radius * 0.9)
					_burn_zones.append({
						"pos": spread_pos,
						"radius": radius * 0.62,
						"dps": dps * 0.55,
						"tick": 0.2,
						"tick_interval": float(z["tick_interval"]),
						"time": minf(float(z["time"]), 1.6),
						"is_evolved": is_evolved,
						"is_crit": false,
						"spread_chance": 0.0,
						"can_spread": false,
					})
					if _weapon_telegraph != null:
						_weapon_telegraph.add_burn_mark(spread_pos, radius * 0.62, 1.2)
		
		if float(z["time"]) <= 0.0:
			_burn_zones.remove_at(i)
		else:
			# 写回更新后的 tick/time，避免持续灼烧在高负载下节拍失真。
			_burn_zones[i] = z

func _update_drones(delta: float) -> void:
	var orbit_speed := 2.0 * delta
	_drone_angle += orbit_speed
	if _drone_angle > TAU:
		_drone_angle -= TAU

	if level_map.get("drone_ab", 0) <= 0:
		return
	if player == null:
		return

	var lv := int(level_map["drone_ab"])
	var is_evolved := lv >= 6
	var drone_count := 2 + int(lv / 3) + int(_stat("orbit_count"))
	if is_evolved:
		drone_count += 2
	while _drone_positions.size() < drone_count:
		_drone_positions.append(player.global_position)
	while _drone_positions.size() > drone_count:
		_drone_positions.pop_back()
	var orbit_radius := 80.0 + lv * 5.0 + _stat("orbit_radius")
	var p := player.global_position
	for i in range(drone_count):
		var angle := _drone_angle + (TAU / float(maxi(1, drone_count))) * float(i)
		_drone_positions[i] = p + Vector2(cos(angle), sin(angle)) * orbit_radius

	_drone_tick -= delta
	if _drone_tick > 0.0:
		return
	_drone_tick = 0.18

	var ex_mul := _orbit_damage_mul(is_evolved)
	var pulse_dmg := (8.5 + lv * 1.85) * ex_mul
	var pulse_rad := 36.0 + lv * 2.2

	for dpos in _drone_positions:
		var target: Variant = _nearest_enemy_pos(dpos, 120.0 + lv * 10.0)
		if target == null:
			continue
		var hit_pos: Vector2 = target
		enemy_manager.apply_damage_circle(hit_pos, pulse_rad, pulse_dmg, &"drone_ab")
		var to_boss: bool = enemy_manager.apply_damage_to_boss(hit_pos, pulse_rad, pulse_dmg)
		_report_damage("drone_pulse", pulse_dmg, to_boss, is_evolved, hit_pos, false)
		_projectile_line_salvo(dpos, hit_pos, "drone_ab", 0.1, 4, lv, is_evolved)

func _update_guardian(delta: float) -> void:
	_guardian_angle += 3.0 * delta
	if _guardian_angle > TAU:
		_guardian_angle -= TAU

	# 守卫者持续旋转伤害
	if level_map.get("guardian", 0) <= 0:
		if _projectile_layer != null:
			_projectile_layer.sync_guardian_blades(Vector2.ZERO, 0.0, 0, false)
		return

	_guardian_knockback_tick -= delta
	var lv := int(level_map["guardian"])
	var is_evolved := lv >= 6
	var ex_mul := _orbit_damage_mul(is_evolved)
	var dmg := (7.0 + lv * 1.35) * ex_mul * delta  # 每秒伤害（周7下调）
	var rad := 90.0 + lv * 7.5 + _stat("orbit_radius")

	# 旋转位置计算
	var guardian_count := 2 + int(lv / 2) + int(_stat("orbit_count"))
	if is_evolved:
		guardian_count += 2
	if _projectile_layer != null:
		_projectile_layer.sync_guardian_blades(player.global_position, rad * 0.72, guardian_count, is_evolved)

	for i in range(guardian_count):
		var angle := _guardian_angle + (TAU / guardian_count) * i
		var guard_pos := player.global_position + Vector2(cos(angle), sin(angle)) * rad * 0.7
		var sweep_dir := Vector2(cos(angle), sin(angle))

		enemy_manager.apply_damage_circle(guard_pos, 25.0, dmg, &"guardian")
		var to_boss: bool = enemy_manager.apply_damage_to_boss(guard_pos, 25.0, dmg)
		if to_boss:
			_report_damage("guardian_tick", dmg, true, is_evolved, guard_pos, false)
		_apply_sector_damage(guard_pos, sweep_dir, 44.0 + lv * 2.5, 24.0, dmg * (0.92 if is_evolved else 0.76), "guardian_slice", true, is_evolved)
		if _weapon_telegraph != null and (i % 2 == 0 or is_evolved):
			_weapon_telegraph.add_guardian_slice(guard_pos, sweep_dir, 34.0 + lv * 2.8, 0.12)

	# 节流击退，避免每帧触发大范围冲量造成性能抖动。
	if _guardian_knockback_tick <= 0.0:
		_guardian_knockback_tick = 0.14 if is_evolved else 0.22
		EventBus.area_knockback.emit(player.global_position, rad * 0.82, 90.0 if not is_evolved else 155.0)

# ========== 冰霜领域更新 ==========
func _update_frost_aura(delta: float) -> void:
	var lv := int(level_map.get("frost_aura", 0))
	if lv <= 0:
		if _projectile_layer != null:
			_projectile_layer.sync_aura("frost_aura", Vector2.ZERO, 0.0, false, false)
		return
	
	var is_evolved := lv >= 6
	var p: Vector2 = player.global_position
	var aura_radius := 140.0 + lv * 15.0 + _stat("frost_spread_radius") * 0.5
	if is_evolved:
		aura_radius *= 1.5
	if _projectile_layer != null:
		_projectile_layer.sync_aura("frost_aura", p, aura_radius, _frost_aura_timer > 0.0, is_evolved)
	
	_frost_aura_timer -= delta
	_frost_freeze_pulse_cd = maxf(0.0, _frost_freeze_pulse_cd - delta)
	if _frost_aura_timer > 0.0:
		# 持续范围伤害 + 减速；进化才脉冲短冻（不用 slow 比例误当冻结秒数）
		var dmg := (13.0 + lv * 3.0) * delta * _world_curse_out_damage_mul()
		var slow_amount := clampf(0.32 + lv * 0.05, 0.32, 0.68)
		if is_evolved:
			slow_amount = minf(0.75, slow_amount + 0.12)
		enemy_manager.apply_damage_circle(p, aura_radius, dmg, &"frost_aura")
		if enemy_manager.has_method("apply_slow_in_circle"):
			enemy_manager.apply_slow_in_circle(p, aura_radius, slow_amount, 0.35)
		# 进化或叠冰域专精时脉冲冻结（专精加时长+扩散）
		var freeze_pulse := is_evolved or _stat("frost_duration_add") > 0.0
		if freeze_pulse and _frost_freeze_pulse_cd <= 0.0 and enemy_manager.has_method("freeze_enemy"):
			_frost_freeze_pulse_cd = 0.45
			var freeze_dur := 0.28 + lv * 0.03 + _stat("frost_duration_add")
			var freeze_r := 80.0 + _stat("frost_spread_radius")
			enemy_manager.freeze_enemy(p, freeze_dur, freeze_r)

# ========== 治疗光环更新 ==========
func _update_heal_aura(delta: float) -> void:
	var lv := int(level_map.get("heal_aura", 0))
	if lv <= 0:
		if _projectile_layer != null:
			_projectile_layer.sync_aura("heal_aura", Vector2.ZERO, 0.0, false, false)
		return
	
	_heal_aura_timer -= delta
	var is_evolved := lv >= 6
	var p: Vector2 = player.global_position
	
	# 计算治疗量
	var heal_radius := 120.0 + lv * 12.0
	if is_evolved:
		heal_radius *= 1.4
	if _projectile_layer != null:
		_projectile_layer.sync_aura("heal_aura", p, heal_radius, true, is_evolved)
	if _heal_aura_timer > 0.0:
		return
	
	_heal_aura_timer = 0.4  # 重置计时器
	
	var heal_per_tick := (3.0 + lv * 1.2) * 0.4  # 每0.4秒的治疗量
	if is_evolved:
		heal_per_tick *= 1.5  # 进化提升50%治疗
	
	# 进化效果：吸收周围敌人生命
	var bonus_heal := 0.0
	if is_evolved:
		var enemies_in_range: Array[Vector2] = enemy_manager.get_enemies_in_radius(p, heal_radius)
		bonus_heal = enemies_in_range.size() * 0.5  # 每个敌人额外治疗0.5
	
	# 应用治疗
	var total_heal := heal_per_tick + bonus_heal
	if player.has_method("heal"):
		(player as Node).heal(total_heal)
		EventBus.player_healed.emit(total_heal)

# ========== 地雷更新 ==========
func _update_mines(delta: float) -> void:
	var lv := int(level_map.get("stun_mine", 0))
	if lv <= 0 or _mine_positions.is_empty():
		if _projectile_layer != null:
			_projectile_layer.sync_mines([], false)
		return
	
	var is_evolved := lv >= 6
	var p: Vector2 = player.global_position
	var explosion_radius := 45.0 + lv * 3.0
	if is_evolved:
		explosion_radius *= 1.3
	
	var explosion_damage := (18.0 + lv * 4.0)
	if is_evolved:
		explosion_damage *= 1.4
	explosion_damage *= _world_curse_out_damage_mul()
	if _projectile_layer != null:
		_projectile_layer.sync_mines(_mine_positions, is_evolved)
	
	# 检查敌人是否踩到地雷
	for i in range(_mine_positions.size() - 1, -1, -1):
		var mine_pos: Vector2 = _mine_positions[i]
		
		# 地雷随玩家移动
		var new_mine_pos := mine_pos + (p - mine_pos) * delta * 0.5
		_mine_positions[i] = new_mine_pos
		
		# 检查范围内是否有敌人
		var enemies: Array[Vector2] = enemy_manager.get_enemies_in_radius(new_mine_pos, explosion_radius)
		if not enemies.is_empty():
			# 触发地雷爆炸
			enemy_manager.apply_damage_circle(new_mine_pos, explosion_radius, explosion_damage, &"stun_mine")
			EventBus.enemy_stunned.emit(new_mine_pos, 0.5 + lv * 0.1)
			_report_damage("mine_explosion", explosion_damage, false, is_evolved, new_mine_pos)
			var mine_dir := (p - new_mine_pos).normalized()
			if mine_dir.length() < 0.001:
				mine_dir = Vector2.RIGHT
			for off in [0.0, 120.0, -120.0]:
				var wave_dir := mine_dir.rotated(deg_to_rad(off))
				_apply_sector_damage(new_mine_pos, wave_dir, explosion_radius * 1.05, 22.0 if is_evolved else 18.0, explosion_damage * 0.28, "mine_wave", false, is_evolved)
				if _weapon_telegraph != null:
					_weapon_telegraph.add_mine_shock_cone(new_mine_pos, wave_dir, explosion_radius * 0.86, 0.14)
			
			# 进化效果：连锁爆炸
			if is_evolved:
				for enemy_pos in enemies:
					enemy_manager.apply_damage_circle(enemy_pos, explosion_radius * 0.6, explosion_damage * 0.5, &"stun_mine")
					EventBus.enemy_stunned.emit(enemy_pos, 0.3)
			
			# 视觉效果
			if _particle_mgr and _particle_mgr.has_method("explosion"):
				_particle_mgr.explosion(new_mine_pos)
			CombatFeedback.shake("heavy", 4.0, 0.15)
			
			# 移除地雷
			_mine_positions.remove_at(i)

func _update_fx_cooldowns(delta: float) -> void:
	_fusion_spike_cd = maxf(_fusion_spike_cd - delta, 0.0)
	_threat_hit_cd = maxf(_threat_hit_cd - delta, 0.0)
	if _fx_source_cooldowns.is_empty():
		return
	# Iterate over a snapshot to avoid mutating dictionary during traversal.
	var keys := _fx_source_cooldowns.keys()
	for key in keys:
		var left := float(_fx_source_cooldowns[key]) - delta
		if left <= 0.0:
			_fx_source_cooldowns.erase(key)
		else:
			_fx_source_cooldowns[key] = left

func _can_emit_fx_for_source(source: String) -> bool:
	# 高频 DOT / 环绕武器在高敌人数时会刷屏，做来源节流。
	var pressure := _runtime_pressure_mul()
	var cd := 0.0
	match source:
		"kunai_hit", "kunai_pierce", "kunai_finish":
			cd = 0.028 * pressure
		"lightning_hex", "lightning_jump", "lightning_strike":
			cd = 0.032 * pressure
		"quantum_burst", "quantum_hex", "quantum_bounce":
			cd = 0.038 * pressure
		"rocket_cone":
			cd = 0.04 * pressure
		"boomerang_out", "boomerang_return", "boomerang_orbit":
			cd = 0.03 * pressure
		"guardian_tick":
			cd = 0.08 * pressure
		"molotov_burn":
			cd = 0.12 * pressure
		"drone_pulse":
			cd = 0.06 * pressure
		_:
			cd = 0.0
	if cd <= 0.0:
		return true
	if _fx_source_cooldowns.has(source):
		return false
	_fx_source_cooldowns[source] = cd
	return true

func _report_damage(source: String, amount: float, to_boss: bool, from_fusion: bool, pos: Vector2 = Vector2.ZERO, is_crit: Variant = null) -> void:
	RunStats.add_damage_source(source, amount, to_boss, from_fusion)
	var can_emit_source_fx := _can_emit_fx_for_source(source)
	var show_as_crit := bool(is_crit) if is_crit != null else _shot_is_crit
	
	# ========== 冰冻被动效果（含冰域专精扩散）==========
	if not to_boss and _skill_system and _skill_system.stats.get("freeze_chance", 0.0) > 0:
		if randf() < float(_skill_system.stats["freeze_chance"]):
			var freeze_dur := float(_skill_system.stats.get("freeze_duration", 0.0))
			if freeze_dur > 0:
				var freeze_r := 80.0 + float(_skill_system.stats.get("frost_spread_radius", 0.0))
				enemy_manager.freeze_enemy(pos, freeze_dur, freeze_r)
	
	# 触发粒子特效（基于武器类型）
	if _particle_mgr and amount > 8.0 and pos != Vector2.ZERO and can_emit_source_fx:
		_trigger_weapon_particles(source, pos)
		_emit_weapon_sfx(source, pos)
	if _weapon_telegraph != null and pos != Vector2.ZERO and _should_emit_hit_feedback(source, amount, can_emit_source_fx):
		if _should_emit_hit_feedback_at_pos(pos):
			var hit_type := _resolve_hit_type(source, amount, to_boss, from_fusion, show_as_crit)
			var intensity := _resolve_hit_intensity(source, amount, to_boss, from_fusion, show_as_crit)
			_weapon_telegraph.add_hit_feedback(pos, _hit_palette_key(source), hit_type, intensity, _splatter_dir_at(pos))
			_register_hit_feedback_pos(pos)
	_maybe_fusion_spike_feedback(pos, amount, to_boss, from_fusion)
	_maybe_threat_hit_feedback(pos, amount, to_boss, source)
	
	# 伤害跳字（持续DOT/守卫者tick不逐帧刷字，避免UI开销过高）
	var allow_damage_number := source != "molotov_burn" and source != "guardian_tick"
	var number_threshold := 5.0
	if _runtime_pressure_mul() > 1.35 and not to_boss:
		number_threshold = 9.0
	if Settings.show_damage_numbers and allow_damage_number and amount > number_threshold and _damage_numbers_this_frame < _max_damage_numbers_per_frame:
		_damage_numbers_this_frame += 1
		# 跳字数值 = 真实结算伤害（禁止展示倍率）
		EventBus.damage_number_spawned.emit(pos, amount, show_as_crit)


func _runtime_pressure_mul() -> float:
	# 高压（敌人数/BOSS）时提升反馈节流，防止视觉噪声淹没可读信息。
	if enemy_manager == null:
		return 1.0
	var alive := 0
	if enemy_manager.has_method("alive_count"):
		alive = int(enemy_manager.alive_count())
	var mul := 1.0
	if alive >= 1300:
		mul = 1.85
	elif alive >= 900:
		mul = 1.55
	elif alive >= 650:
		mul = 1.25
	if enemy_manager.has_method("boss_alive") and bool(enemy_manager.boss_alive()):
		mul += 0.25
	return mul


func _emit_weapon_sfx(source: String, pos: Vector2) -> void:
	var cfg := _feedback_card(source)
	var sfx_event := String(cfg.get("sfx_event", ""))
	if sfx_event == "":
		return
	# 卡片化音效入口：source 可映射到独立事件，方便后续 AB 音色切换。
	EventBus.play_sfx.emit(StringName(sfx_event), pos)

func _hit_palette_key(source: String) -> String:
	return String(_feedback_card(source).get("palette", "quantum_ball"))


func _hit_tint(source: String) -> Color:
	var key := _hit_palette_key(source)
	var cols: Dictionary = WeaponTelegraph.WEAPON_COLORS.get(key, WeaponTelegraph.WEAPON_COLORS["kunai"])
	var p: Color = cols["primary"]
	return Color(minf(p.r * 1.06, 1.0), minf(p.g * 1.06, 1.0), minf(p.b * 1.06, 1.0), 1.0)

func _resolve_hit_type(source: String, amount: float, to_boss: bool, from_fusion: bool, is_crit: bool = false) -> StringName:
	# 暴击皮只跟真实暴击走；禁止用伤害阈值冒充暴击
	if is_crit:
		return WeaponTelegraph.HIT_CRIT
	var forced := String(_feedback_card(source).get("force_hit_type", ""))
	if forced != "":
		match forced:
			"kill":
				return WeaponTelegraph.HIT_KILL
			"crit":
				# 配置里的 force crit 不得绕过真实判定
				return WeaponTelegraph.HIT_NORMAL
			"threat":
				return WeaponTelegraph.HIT_THREAT
			_:
				return WeaponTelegraph.HIT_NORMAL
	if to_boss:
		return WeaponTelegraph.HIT_THREAT
	if from_fusion or amount >= 115.0:
		return WeaponTelegraph.HIT_KILL
	return WeaponTelegraph.HIT_NORMAL

func _resolve_hit_intensity(source: String, amount: float, to_boss: bool, from_fusion: bool, is_crit: bool = false) -> float:
	var scale := clampf(amount / 70.0, 0.85, 1.65)
	if is_crit:
		scale += 0.18
	if to_boss:
		scale += 0.2
	if from_fusion:
		scale += 0.12
	scale *= float(_feedback_card(source).get("intensity_mul", 1.0))
	return clampf(scale, 0.8, 1.75)

func _should_emit_hit_feedback(source: String, amount: float, source_fx_allowed: bool) -> bool:
	var min_amount := float(_feedback_card(source).get("min_hit_amount", 12.0))
	if amount < min_amount:
		return false
	if source == "molotov_burn" or source == "guardian_tick":
		return false
	if source == "drone_pulse" and amount < 16.0:
		return false
	if source == "kunai_hit" and amount < 14.0 and _runtime_pressure_mul() > 1.15:
		return false
	return source_fx_allowed or amount >= 42.0


func _should_emit_hit_feedback_at_pos(pos: Vector2) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	for i in range(_hit_feedback_recent.size() - 1, -1, -1):
		var rec: Dictionary = _hit_feedback_recent[i]
		if now - float(rec.get("t", 0.0)) > _HIT_FEEDBACK_SPATIAL_WINDOW:
			_hit_feedback_recent.remove_at(i)
			continue
		if pos.distance_squared_to(rec.get("pos", Vector2.ZERO)) <= _HIT_FEEDBACK_SPATIAL_R2:
			return false
	return true


func _register_hit_feedback_pos(pos: Vector2) -> void:
	_hit_feedback_recent.append({"pos": pos, "t": Time.get_ticks_msec() * 0.001})
	if _hit_feedback_recent.size() > 48:
		_hit_feedback_recent.remove_at(0)


func _splatter_dir_at(pos: Vector2) -> Vector2:
	if player == null or pos == Vector2.ZERO:
		return Vector2.ZERO
	var d := pos - player.global_position
	if d.length_squared() < 4.0:
		return Vector2.from_angle(randf() * TAU)
	return d.normalized()


func _play_hit_fx_preset(preset_id: String, pos: Vector2, source: String, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if not _particle_mgr:
		return
	var tint := _hit_tint(source)
	var tint_soft := Color(tint.r, tint.g, tint.b, 0.82)
	match preset_id:
		"slash":
			var brief := _runtime_pressure_mul() >= 1.15
			if brief:
				_particle_mgr.splatter_hit(pos, tint_soft, hit_dir)
				if randf() < 0.38:
					_particle_mgr.kunai_glint(pos, tint)
			else:
				_particle_mgr.impact_splash(pos, tint_soft, hit_dir, 1.05, false)
				_particle_mgr.kunai_glint(pos, tint)
			CombatFeedback.shake("minion", 1.45 if brief else 1.65, 0.048 if brief else 0.055)
		"arcane_heavy":
			_particle_mgr.shockwave_ring(pos, tint)
			_particle_mgr.magic_burst(pos, tint)
			if randf() < 0.5:
				_particle_mgr.lightning_spark(pos, tint)
			CombatFeedback.shake("hit", 3.2, 0.1)
			CombatFeedback.flash(Color(0.62, 0.72, 0.42, 1.0), 0.06, "subtle")
		"arcane_soft":
			_particle_mgr.magic_burst(pos, tint_soft)
			if randf() < 0.35:
				_particle_mgr.shockwave_ring(pos, Color(tint.r, tint.g, tint.b, 0.55))
			CombatFeedback.shake("minion", 2.35, 0.065)
		"arcane_burst":
			_particle_mgr.shockwave_ring(pos, tint)
			_particle_mgr.magic_burst(pos, tint)
			if randf() < 0.5:
				_particle_mgr.lightning_spark(pos, Color(1.0, 0.95, 0.65, 1.0))
			CombatFeedback.shake("hit", 3.55, 0.11)
			CombatFeedback.flash(Color(0.78, 0.88, 0.48, 1.0), 0.07, "normal")
		"volt":
			_particle_mgr.impact_splash(pos, tint, hit_dir, 0.95)
			_particle_mgr.lightning_spark(pos, tint)
			CombatFeedback.shake("hit", 2.75, 0.085)
			CombatFeedback.flash(Color(0.32, 0.52, 0.92, 1.0), 0.05, "subtle")
		"volt_soft":
			_particle_mgr.lightning_spark(pos, tint_soft)
			CombatFeedback.shake("minion", 2.15, 0.06)
		"fire_impact":
			_particle_mgr.shockwave_ring(pos, Color(1.0, 0.55, 0.15, 1.0))
			_particle_mgr.explosion(pos, tint)
			CombatFeedback.shake("heavy", 3.2, 0.1)
			CombatFeedback.flash(Color(0.85, 0.38, 0.12, 1.0), 0.07, "normal")
		"fire_tick":
			_particle_mgr.fire_burn(pos, 1.0)
		"rocket_main":
			_particle_mgr.shockwave_ring(pos, Color(1.0, 0.62, 0.22, 1.0))
			_particle_mgr.explosion(pos, tint)
			_particle_mgr.smoke(pos)
			_particle_mgr.rocket_embers(pos, tint)
			CombatFeedback.shake("heavy", 5.0, 0.18)
			CombatFeedback.flash(Color(1.0, 0.52, 0.22, 1.0), 0.08, "strong")
		"rocket_secondary":
			_particle_mgr.shockwave_ring(pos, Color(1.0, 0.5, 0.18, 0.85))
			_particle_mgr.explosion(pos, tint_soft)
			_particle_mgr.smoke(pos)
			_particle_mgr.rocket_embers(pos, tint_soft)
			CombatFeedback.shake("heavy", 4.35, 0.14)
			CombatFeedback.flash(Color(1.0, 0.58, 0.3, 1.0), 0.06, "normal")
		"kinetic_ring":
			_particle_mgr.impact_splash(pos, tint_soft, hit_dir, 1.12)
			if randf() < 0.48:
				_particle_mgr.magic_burst(pos, tint_soft)
			CombatFeedback.shake("hit", 2.35, 0.065)
		"kinetic_tick":
			_particle_mgr.splatter_hit(pos, tint_soft, hit_dir)
		"drone_beam":
			_particle_mgr.lightning_spark(pos, tint)
			_particle_mgr.magic_burst(pos, tint_soft)
			_particle_mgr.shockwave_ring(pos, Color(tint.r * 0.9, tint.g * 0.75, 1.0, 0.75))
			CombatFeedback.shake("minion", 2.15, 0.052)
		"drone_tick":
			_particle_mgr.lightning_spark(pos, tint_soft)
			if randf() < 0.5:
				_particle_mgr.magic_burst(pos, tint_soft)
		"boomer":
			_particle_mgr.magic_burst(pos, tint)
			_particle_mgr.shockwave_ring(pos, Color(1.0, 0.82, 0.45, 0.9))
			CombatFeedback.shake("hit", 2.15, 0.075)
		"boomer_soft":
			_particle_mgr.magic_burst(pos, tint_soft)
			CombatFeedback.shake("minion", 1.55, 0.05)
		"mine_big":
			_particle_mgr.shockwave_ring(pos, Color(1.0, 0.92, 0.35, 1.0))
			_particle_mgr.explosion(pos, tint)
			_particle_mgr.magic_burst(pos, Color(0.85, 0.65, 1.0, 1.0))
			_particle_mgr.lightning_spark(pos, tint)
			CombatFeedback.flash(Color(0.78, 0.58, 1.0, 0.85), 0.06, "subtle")
			CombatFeedback.shake("heavy", 4.65, 0.14)
		"generic_light":
			if randf() < 0.58:
				_particle_mgr.hit_effect(pos, tint_soft)
			CombatFeedback.shake("minion", 1.25, 0.04)
		_:
			pass


func _trigger_weapon_particles(source: String, pos: Vector2) -> void:
	var preset: String = String(_feedback_card(source).get("preset", _DAMAGE_SOURCE_HIT_PRESET.get(source, "generic_light")))
	_play_hit_fx_preset(preset, pos, source, _splatter_dir_at(pos))


func _feedback_card(source: String) -> Dictionary:
	return _source_feedback_card_runtime.get(source, _SOURCE_FEEDBACK_CARD.get(source, {}))


func _load_source_feedback_card_runtime() -> void:
	# 代码内常量做兜底，外部 json 仅做覆盖，避免配置缺项导致运行异常。
	_source_feedback_card_runtime = _SOURCE_FEEDBACK_CARD.duplicate(true)
	if not FileAccess.file_exists(_SOURCE_FEEDBACK_CARD_CONFIG_PATH):
		return
	var f := FileAccess.open(_SOURCE_FEEDBACK_CARD_CONFIG_PATH, FileAccess.READ)
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
	for key in ext.keys():
		var k := String(key)
		var v: Variant = ext[key]
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var merged: Dictionary = _SOURCE_FEEDBACK_CARD.get(k, {}).duplicate(true)
		for sub_k in (v as Dictionary).keys():
			merged[sub_k] = (v as Dictionary)[sub_k]
		_source_feedback_card_runtime[k] = merged


func _on_weapon_cards_reload_requested() -> void:
	_load_source_feedback_card_runtime()
	NotificationSystem.notify_message("武器反馈配置已热重载", 0.9, "success")


func _update_dev_hot_reload_input(delta: float) -> void:
	_dev_reload_hotkey_cd = maxf(_dev_reload_hotkey_cd - delta, 0.0)
	if not Settings.debug_hud:
		return
	if _dev_reload_hotkey_cd > 0.0:
		return
	if Input.is_key_pressed(KEY_F8):
		_dev_reload_hotkey_cd = 0.45
		EventBus.weapon_cards_reload_requested.emit()


func _maybe_fusion_spike_feedback(pos: Vector2, amount: float, to_boss: bool, from_fusion: bool) -> void:
	if not from_fusion or pos == Vector2.ZERO:
		return
	if _fusion_spike_cd > 0.0:
		return
	if not to_boss and amount < 70.0:
		return
	_fusion_spike_cd = 0.58
	CombatFeedback.shake("hit", 3.1, 0.07)
	CombatFeedback.flash(Color(0.92, 0.68, 1.0, 0.22), 0.08, "subtle")
	if randf() < 0.34:
		NotificationSystem.notify_message("融合火力命中高峰！", 1.1, "achievement")


func _maybe_threat_hit_feedback(pos: Vector2, amount: float, to_boss: bool, source: String) -> void:
	if pos == Vector2.ZERO:
		return
	# Boss 命中：用更稳定的节流与颜色语言
	if to_boss:
		if _threat_hit_cd > 0.0:
			return
		if amount < 35.0:
			return
		_threat_hit_cd = 0.22
		CombatFeedback.shake("boss", 3.4, 0.075)
		CombatFeedback.flash(Color(1.0, 0.35, 0.28, 0.12), 0.06, "subtle")
		if _particle_mgr and _particle_mgr.has_method("shockwave_ring"):
			_particle_mgr.shockwave_ring(pos, Color(1.0, 0.38, 0.28, 1.0))
		return

	# 普通敌人：仅在高威胁目标附近命中时触发（spitter/summoner/charger/elite）
	if _threat_hit_cd > 0.0 or amount < 18.0:
		return
	var k := -1
	if enemy_manager and enemy_manager.has_method("threat_kind_near"):
		k = int(enemy_manager.threat_kind_near(pos, 28.0))
	if k == -1:
		return
	if not (k == 3 or k == 6 or k == 7 or k == 9):
		return
	_threat_hit_cd = 0.28
	match k:
		9:
			CombatFeedback.shake("heavy", 3.0, 0.07)
			CombatFeedback.flash(Color(1.0, 0.3, 0.22, 0.1), 0.055, "subtle")
			if _particle_mgr and _particle_mgr.has_method("shockwave_ring"):
				_particle_mgr.shockwave_ring(pos, Color(1.0, 0.35, 0.25, 1.0))
		7:
			CombatFeedback.shake("hit", 2.6, 0.06)
			CombatFeedback.flash(Color(1.0, 0.6, 0.32, 0.09), 0.05, "subtle")
			if _particle_mgr and _particle_mgr.has_method("shockwave_ring"):
				_particle_mgr.shockwave_ring(pos, Color(1.0, 0.58, 0.3, 1.0))
		6:
			CombatFeedback.shake("hit", 2.4, 0.06)
			CombatFeedback.flash(Color(0.92, 0.45, 1.0, 0.09), 0.05, "subtle")
			if _particle_mgr and _particle_mgr.has_method("shockwave_ring"):
				_particle_mgr.shockwave_ring(pos, Color(0.92, 0.45, 1.0, 1.0))
		3:
			CombatFeedback.shake("minion", 2.0, 0.05)
			CombatFeedback.flash(Color(0.35, 1.0, 0.62, 0.075), 0.045, "subtle")
			if _particle_mgr and _particle_mgr.has_method("shockwave_ring"):
				_particle_mgr.shockwave_ring(pos, Color(0.35, 1.0, 0.62, 1.0))
		_:
			pass

# ============================================
# 投射物可视化辅助
# ============================================

func _projectile_visual(from: Vector2, dir: Vector2, kind: String, speed: float = 600.0, lifetime: float = 0.3, weapon_lv: int = 1, evolved: bool = false) -> void:
	if _projectile_layer != null:
		_projectile_layer.spawn_projectile(kind, from, dir, speed, lifetime, weapon_lv, evolved)
	elif _weapon_telegraph != null:
		_weapon_telegraph.add_projectile(from, dir, kind, speed, lifetime, weapon_lv, evolved)


func _volley_count_for_kind(kind: String) -> int:
	match kind:
		"kunai":
			return 4
		"quantum_ball":
			return 5
		"rocket":
			return 3
		"molotov":
			return 3
		"boomerang":
			return 4
		"lightning":
			return 6
		"drone_ab":
			return 4
		_:
			return 3


func _projectile_line_salvo(from_pos: Vector2, to_pos: Vector2, kind: String, lifetime: float, segments: int, weapon_lv: int = 1, evolved: bool = false) -> void:
	if _projectile_layer == null:
		return
	if _projectile_layer.has_method("spawn_line_salvo"):
		_projectile_layer.spawn_line_salvo(kind, from_pos, to_pos, lifetime, segments, weapon_lv, evolved)


func _projectile_visual_bezier(p0: Vector2, p1: Vector2, p2: Vector2, kind: String, lifetime: float, weapon_lv: int = 1, evolved: bool = false, _final_dir: Vector2 = Vector2.ZERO) -> void:
	if _projectile_layer != null:
		if _projectile_layer.has_method("spawn_bezier_volley"):
			_projectile_layer.spawn_bezier_volley(kind, p0, p1, p2, lifetime, _volley_count_for_kind(kind), weapon_lv, evolved)
		else:
			_projectile_layer.spawn_projectile_bezier(kind, p0, p1, p2, lifetime, weapon_lv, evolved)
	elif _weapon_telegraph != null:
		_weapon_telegraph.add_kunai_arc_trail(p0, p1, p2, lifetime * 0.55)


func _projectile_visual_bezier_cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, kind: String, lifetime: float, weapon_lv: int = 1, evolved: bool = false) -> void:
	if _projectile_layer != null:
		if _projectile_layer.has_method("spawn_bezier_cubic_volley"):
			_projectile_layer.spawn_bezier_cubic_volley(kind, p0, p1, p2, p3, lifetime, _volley_count_for_kind(kind), weapon_lv, evolved)
		else:
			_projectile_layer.spawn_projectile_bezier_cubic(kind, p0, p1, p2, p3, lifetime, weapon_lv, evolved)
	elif _weapon_telegraph != null:
		_weapon_telegraph.add_kunai_arc_trail(p0, p1, p2, lifetime * 0.42)
