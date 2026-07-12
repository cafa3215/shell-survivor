extends Node2D
class_name EnemyManager

# ============================================
# 敌人管理器 - MultiMesh + 空间分区 + 对象池
# ============================================

var pool := PoolManager.new()
var grid := SpatialGrid.new()
var positions: PackedVector2Array
var hp: PackedFloat32Array
var speed: PackedFloat32Array
var kind: PackedInt32Array
var damage: PackedFloat32Array
var active_indices := PackedInt32Array()
var _player: Node2D
var _buckets: Array[PackedInt32Array] = [
	PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array(),
	PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()
]
var _frame := 0
var _mm := MultiMesh.new()
var _mm_node := MultiMeshInstance2D.new()
var _boss_alive := false
var _boss_hp := 3000.0
var _boss_hp_max := 3000.0
var _boss_pos := Vector2.ZERO
var _boss_speed := 46.0
var _boss_attack_cd := 0.0
var _boss_pending_t := 0.0
var _boss_pending_radius := 0.0
var _boss_pending_damage := 0.0
var _boss_pending_kind := 0 # 0=circle,1=dash,2=pulse,3=cone
var _boss_pending_dir := Vector2.ZERO
var _special_cd: PackedFloat32Array
var _stun_time: PackedFloat32Array
var _ai_phase: PackedFloat32Array
var _charger_windup: PackedFloat32Array
var _spitter_windup: PackedFloat32Array
var _weapon_telegraph: Node = null
var _last_bucket_count := 4
var _player_retries := 0
var _enemy_uses_atlas := false
var _threat_cache_tick := 0
var _threat_cache: Array[Dictionary] = []
var _elapsed_minutes_cache := 0.0

# 属性缩放（随时间增强敌人）
var _enemy_hp_scale := 1.0
var _enemy_dmg_scale := 1.0
var _enemy_speed_scale := 1.0

# ========== 被动效果相关 ==========
var _freeze_time: PackedFloat32Array  # 冰冻时间
var _visual_scale_mul: PackedFloat32Array

# 高威胁击杀确认（低噪声）：节流 + 简短提示
var _threat_kill_cd := 0.0
var _threat_kill_chain := 0
var _threat_kill_chain_decay := 0.0
var _combo_kill_count := 0
var _combo_kill_decay := 0.0
var _combo_notify_cd := 0.0

# 池内存活索引（仅遍历存活实例，避免每帧扫满 ENEMY_MAX）
var _pool_alive_list: PackedInt32Array = []
var _pool_alive_pos: PackedInt32Array = []

# 击杀爆炸被动：入队后在 apply_damage_circle / flush 里循环结算，避免同步递归撑爆栈
var _pending_kill_explosions: Array[Dictionary] = []
var _kill_fx_weapon_stack: Array[StringName] = []

# 常量提取
const CONTACT_RADIUS := 18.0
const BOOMER_EXPLODE_RADIUS := 26.0
const SPITTER_KEEP_DIST := 120.0
const SPITTER_FIRE_DIST := 260.0
const CHARGER_DASH_RANGE := 220.0
const SPITTER_WINDUP_SEC := 0.30
const CHARGER_WINDUP_MAX := 0.16
const STUN_RANGE := 96.0
const BOSS_CONTACT_RADIUS := 34.0
const BOSS_CONTACT_DMG := 16.0
const _READABILITY_NEAR_RADIUS := 136.0
const _READABILITY_FADE_RADIUS := 260.0

func _ready() -> void:
	_player = _resolve_player_node()
	if _player == null:
		# 延迟重试，避免初始化时序问题
		call_deferred("_retry_get_player")
	pool.setup(GameDB.ENEMY_MAX)
	positions.resize(GameDB.ENEMY_MAX)
	hp.resize(GameDB.ENEMY_MAX)
	speed.resize(GameDB.ENEMY_MAX)
	kind.resize(GameDB.ENEMY_MAX)
	damage.resize(GameDB.ENEMY_MAX)
	_special_cd.resize(GameDB.ENEMY_MAX)
	_stun_time.resize(GameDB.ENEMY_MAX)
	_ai_phase.resize(GameDB.ENEMY_MAX)
	_charger_windup.resize(GameDB.ENEMY_MAX)
	_spitter_windup.resize(GameDB.ENEMY_MAX)
	_freeze_time.resize(GameDB.ENEMY_MAX)
	_visual_scale_mul.resize(GameDB.ENEMY_MAX)
	for _vi in GameDB.ENEMY_MAX:
		_visual_scale_mul[_vi] = 1.0
	_pool_alive_pos.resize(GameDB.ENEMY_MAX)
	for _pi in GameDB.ENEMY_MAX:
		_pool_alive_pos[_pi] = -1
	EventBus.enemy_stunned.connect(_on_enemy_stunned)
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	# 使用 QuadMesh + ShaderMaterial 替代已移除的 texture 属性
	var quad := QuadMesh.new()
	quad.size = Vector2(64, 64)
	_mm.mesh = quad
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.instance_count = GameDB.ENEMY_MAX
	var mat := ShaderMaterial.new()
	mat.shader = _make_enemy_shader()
	var enemy_tex: Texture2D = _resolve_enemy_texture()
	mat.set_shader_parameter("tex", enemy_tex)
	mat.set_shader_parameter("use_enemy_atlas", _enemy_uses_atlas)
	_mm_node.material = mat
	_mm_node.multimesh = _mm
	_mm_node.z_index = 0
	_mm_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_mm_node)
	# 初始化所有实例到屏幕外
	for i in GameDB.ENEMY_MAX:
		_mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(-99999, -99999)))
		_mm.set_instance_color(i, Color(1, 1, 1, 0))
		_mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	# 开局不预铺尸潮；等 game_started 后再少量入场（见 _on_game_started）
	if not EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.connect(_on_game_started)


func _on_game_started() -> void:
	var spawn_center := Vector2.ZERO
	if _player != null:
		spawn_center = _player.global_position
	var initial := 4 if Settings.quality == Settings.Quality.LOW else 5
	for _i in initial:
		var angle := randf() * TAU
		var dist := randf_range(620.0, 920.0)
		spawn_enemy(spawn_center + Vector2(cos(angle), sin(angle)) * dist, randi() % 2)

func _resolve_player_node() -> Node2D:
	var p := get_parent().get_node_or_null(^"Player") as Node2D
	if p != null:
		return p
	return get_tree().get_first_node_in_group("player") as Node2D


func _retry_get_player() -> void:
	if _player != null:
		return
	_player = _resolve_player_node()
	_player_retries += 1
	if _player == null and _player_retries < 10:
		call_deferred("_retry_get_player")

func _register_pool_alive(idx: int) -> void:
	if idx < 0 or idx >= GameDB.ENEMY_MAX or _pool_alive_pos[idx] >= 0:
		return
	_pool_alive_pos[idx] = _pool_alive_list.size()
	_pool_alive_list.append(idx)

func _unregister_pool_alive(idx: int) -> void:
	if idx < 0 or idx >= GameDB.ENEMY_MAX:
		return
	var pos := _pool_alive_pos[idx]
	if pos < 0:
		return
	var last_i := _pool_alive_list[_pool_alive_list.size() - 1]
	_pool_alive_list[pos] = last_i
	_pool_alive_pos[last_i] = pos
	_pool_alive_list.remove_at(_pool_alive_list.size() - 1)
	_pool_alive_pos[idx] = -1

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player_node()
	if _player == null:
		return
	_frame += 1
	_threat_kill_cd = maxf(_threat_kill_cd - delta, 0.0)
	_combo_notify_cd = maxf(_combo_notify_cd - delta, 0.0)
	if _threat_kill_chain_decay > 0.0:
		_threat_kill_chain_decay = maxf(_threat_kill_chain_decay - delta, 0.0)
		if _threat_kill_chain_decay <= 0.0:
			_threat_kill_chain = 0
	if _combo_kill_decay > 0.0:
		_combo_kill_decay = maxf(_combo_kill_decay - delta, 0.0)
		if _combo_kill_decay <= 0.0:
			_combo_kill_count = 0
	
	# 更新敌人属性缩放（随时间增长）
	_elapsed_minutes_cache = elapsed_minutes()
	_enemy_hp_scale = 1.12 + _elapsed_minutes_cache * GameDB.ENDLESS_ENEMY_HP_SCALE_PER_MIN
	_enemy_dmg_scale = 1.08 + _elapsed_minutes_cache * GameDB.ENDLESS_ENEMY_DMG_SCALE_PER_MIN
	_enemy_speed_scale = 1.02 + _elapsed_minutes_cache * GameDB.ENDLESS_ENEMY_SPEED_SCALE_PER_MIN
	
	grid.clear()
	# 双缓冲 active_indices：清空后重用
	active_indices.clear()
	var p := _player.global_position
	var bucket_count := _bucket_count()
	_last_bucket_count = bucket_count
	for b in bucket_count:
		_buckets[b].clear()
	for i in _pool_alive_list:
		grid.insert(i, positions[i])
		if positions[i].distance_to(p) > GameDB.ACTIVE_RADIUS_PX:
			continue
		active_indices.append(i)
		_buckets[i % bucket_count].append(i)
	# 超远距离敌人降频收拢，避免站在边缘时怪群「停住不追」
	if _frame % 3 == 0:
		for i in _pool_alive_list:
			if positions[i].distance_to(p) <= GameDB.ACTIVE_RADIUS_PX * 0.88:
				continue
			var dir_far := (p - positions[i]).normalized()
			positions[i] += dir_far * speed[i] * delta * 3.0
	var update_bucket := _frame % bucket_count
	for i in _buckets[update_bucket]:
		# 冰冻效果
		if _freeze_time[i] > 0.0:
			_freeze_time[i] = maxf(_freeze_time[i] - delta, 0.0)
			continue
		if _stun_time[i] > 0.0:
			_stun_time[i] = maxf(_stun_time[i] - delta, 0.0)
			continue
		var dir := (p - positions[i]).normalized()
		var k := kind[i]
		_special_cd[i] = max(_special_cd[i] - delta, 0.0)
		match k:
			3: # spitter: keeps distance and applies periodic ranged damage
				var d := positions[i].distance_to(p)
				var side := dir.orthogonal()
				var strafe_mul := 0.35 + 0.22 * sin(_ai_phase[i] * 2.3 + float(i) * 0.37)
				_ai_phase[i] += delta
				if d > 180.0:
					positions[i] += (dir + side * strafe_mul).normalized() * speed[i] * delta
				elif d < SPITTER_KEEP_DIST:
					positions[i] += (-dir + side * strafe_mul * 0.7).normalized() * speed[i] * 0.8 * delta
				else:
					positions[i] += side * speed[i] * 0.28 * delta * sin(_ai_phase[i] * 2.6)
				# 后期spitter攻击更频繁；发射前短蓄力（与冲锋者同色预警，提升中盘可读性）
				var spitter_cd: float = 1.4 - min(_elapsed_minutes_cache * 0.02, 0.4)
				if _spitter_windup[i] > 0.0:
					_spitter_windup[i] = maxf(_spitter_windup[i] - delta, 0.0)
					if _spitter_windup[i] <= 0.0 and d < SPITTER_FIRE_DIST:
						_player_take_damage(damage[i] * 0.8)
						_special_cd[i] = spitter_cd
				elif d < SPITTER_FIRE_DIST and _special_cd[i] <= 0.0:
					_spitter_windup[i] = SPITTER_WINDUP_SEC
					_queue_enemy_telegraph_mark(positions[i], SPITTER_WINDUP_SEC)
			4: # boomer: explode in close range
				positions[i] += dir * speed[i] * 1.1 * delta
				if positions[i].distance_to(p) < BOOMER_EXPLODE_RADIUS:
					_player_take_damage(damage[i] * 1.4)
					kill_enemy(i, 0.0, false, &"")
					_flush_kill_explosion_queue()
					continue
			6: # summoner: periodic spawn helper
				_ai_phase[i] += delta * 0.8
				var orbit := dir.orthogonal() * sin(_ai_phase[i] * 1.8) * 0.28
				positions[i] += (dir * 0.72 + orbit).normalized() * speed[i] * 0.75 * delta
				# 后期召唤师更频繁
				var summon_cd: float = 3.6 - min(_elapsed_minutes_cache * 0.05, 1.2)
				if _special_cd[i] <= 0.0 and alive_count() < 2500:
					_special_cd[i] = summon_cd
					spawn_enemy(positions[i] + _rand_vec(60.0), 0)
					# 后期可能召唤更多小怪
					if _elapsed_minutes_cache > 8 and randf() < 0.35:
						spawn_enemy(positions[i] + _rand_vec(80.0), 1)
					if _elapsed_minutes_cache > 12 and randf() < 0.22:
						spawn_enemy(positions[i] + _rand_vec(72.0), 3)
			7: # charger: dash attack
				# 后期冲刺者更频繁冲刺
				var charger_cd: float = 2.2 - min(_elapsed_minutes_cache * 0.03, 0.6)
				if _charger_windup[i] > 0.0:
					_charger_windup[i] = maxf(_charger_windup[i] - delta, 0.0)
					positions[i] += dir * speed[i] * 0.34 * delta
				elif _special_cd[i] <= 0.0 and positions[i].distance_to(p) < CHARGER_DASH_RANGE:
					_special_cd[i] = charger_cd
					var wind := 0.16 if _elapsed_minutes_cache < 9.0 else 0.12
					_charger_windup[i] = wind
					_queue_enemy_telegraph_mark(positions[i], wind)
				else:
					var dash_mul: float = (2.7 + minf(_elapsed_minutes_cache * 0.04, 0.7)) if _special_cd[i] > charger_cd - 0.08 else 1.0
					positions[i] += dir * speed[i] * dash_mul * delta
			8: # shade: phase movement
				var phase_mul := 1.6 if _frame % 20 < 10 else 0.55
				positions[i] += dir * speed[i] * phase_mul * delta
			_:
				# 基础敌人不再纯直线追踪：加入轻微横移/呼吸波，减轻“运动模式单一”。
				var side := dir.orthogonal()
				_ai_phase[i] += delta * (1.35 + float(k) * 0.06)
				var weave := sin(_ai_phase[i] * (1.7 + float(k) * 0.22) + float(i) * 0.17)
				var forward_mul := 1.0
				var side_mul := 0.0
				match k:
					0:
						forward_mul = 1.08
						side_mul = 0.16
					1:
						forward_mul = 1.22
						side_mul = 0.10
					2:
						forward_mul = 0.92
						side_mul = 0.22
					5:
						forward_mul = 1.0
						side_mul = 0.18
					_:
						forward_mul = 1.0
						side_mul = 0.16
				var move_dir := (dir * forward_mul + side * side_mul * weave).normalized()
				positions[i] += move_dir * speed[i] * delta
		if positions[i].distance_to(p) < CONTACT_RADIUS:
			_player_take_damage(damage[i])
	for i in active_indices:
		# 根据敌人类型设置不同大小（更大差异）
		var k := kind[i]
		var enemy_scale := 1.0
		match k:
			2: enemy_scale = 1.8  # tank - 非常大
			5: enemy_scale = 1.4  # guard - 大
			9: enemy_scale = 2.0  # elite - 巨大
			1: enemy_scale = 0.7  # runner - 很小
			4: enemy_scale = 0.85  # boomer - 小
			3: enemy_scale = 0.9  # spitter - 偏小
			6: enemy_scale = 1.2  # summoner - 中
			7: enemy_scale = 0.9  # charger - 偏小
			8: enemy_scale = 1.1  # shade - 中
		# 受伤时闪烁
		var hp_ratio := hp[i] / float(GameDB.ENEMY_TYPES[k]["hp"])
		var flash := 1.0 if hp_ratio > 0.3 else (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02))
		var dist_to_p := positions[i].distance_to(p)
		var rot := (positions[i] - p).angle() if dist_to_p > 1.0 else 0.0
		enemy_scale *= _visual_scale_mul[i]
		_mm.set_instance_transform_2d(i, Transform2D(rot, Vector2(enemy_scale, enemy_scale), 0.0, positions[i]))
		var base_color: Color = GameDB.ENEMY_TYPES[k]["color"]
		var tint := Color(base_color.r * flash, base_color.g * flash, base_color.b * flash, 1.0)
		if k == 7 and _charger_windup[i] > 0.0:
			var pwr := clampf(_charger_windup[i] / CHARGER_WINDUP_MAX, 0.0, 1.0)
			tint = tint.lerp(Color(1.0, 0.42, 0.25, 1.0), 0.6 + 0.35 * pwr)
		elif k == 3 and _spitter_windup[i] > 0.0:
			var sp_pwr := clampf(_spitter_windup[i] / SPITTER_WINDUP_SEC, 0.0, 1.0)
			tint = tint.lerp(Color(1.0, 0.48, 0.22, 1.0), 0.52 + 0.38 * sp_pwr)
		if Settings.high_contrast_targets and (k == 3 or k == 6 or k == 7 or k == 9):
			var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.013 + float(i))
			tint = tint.lerp(Color(1.0, 0.92, 0.35, 1.0), 0.24)
			tint *= Color(pulse, pulse, pulse, 1.0)
		# 可读性压制：敌群整体降饱和，靠近主角再降对比，给主角轮廓留净空。
		var near_t := 1.0 - clampf((dist_to_p - _READABILITY_NEAR_RADIUS) / maxf(1.0, _READABILITY_FADE_RADIUS - _READABILITY_NEAR_RADIUS), 0.0, 1.0)
		var readability_mul := _readability_enemy_suppression()
		near_t *= readability_mul
		var hsv_h := tint.h
		var hsv_s := maxf(0.0, tint.s * lerpf(0.94, 0.62, near_t))
		var hsv_v := tint.v * lerpf(0.96, 0.68, near_t)
		var alpha := lerpf(0.96, 0.58, near_t)
		tint = Color.from_hsv(hsv_h, hsv_s, hsv_v, alpha)
		_mm.set_instance_color(i, tint)
	_update_boss(delta)
	# 缓存高威胁目标（供 HUD 边缘指示器），降低 UI 侧遍历成本
	_threat_cache_tick += 1
	if _threat_cache_tick % 6 == 0:
		_threat_cache = _build_threat_targets(6)

func elapsed_minutes() -> float:
	var game := get_parent()
	if game and "elapsed" in game:
		return float(game.get("elapsed")) / 60.0
	return 0.0


func _resolve_weapon_telegraph() -> Node:
	if _weapon_telegraph != null and is_instance_valid(_weapon_telegraph):
		return _weapon_telegraph
	var game := get_parent()
	if game == null:
		return null
	_weapon_telegraph = game.get_node_or_null("WeaponTelegraph")
	return _weapon_telegraph


func _queue_enemy_telegraph_mark(pos: Vector2, duration: float) -> void:
	var tg := _resolve_weapon_telegraph()
	if tg == null or not tg.has_method("add_lightning_mark"):
		return
	tg.call("add_lightning_mark", pos, 34.0, maxf(0.08, duration))


func get_threat_targets(max_n: int = 6) -> Array[Dictionary]:
	# Dictionary: {"pos": Vector2, "kind": int, "dist": float, "tag": String}
	if max_n <= 0:
		return []
	if not _threat_cache.is_empty():
		# Return a copy limited to max_n
		var out: Array[Dictionary] = []
		for i in range(mini(max_n, _threat_cache.size())):
			out.append(_threat_cache[i])
		return out
	return _build_threat_targets(max_n)


func _build_threat_targets(max_n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _player == null:
		return out
	var p := _player.global_position
	# 高威胁：远程/召唤/冲刺/精英
	for i in active_indices:
		if not pool.is_alive(i):
			continue
		var k := int(kind[i])
		if not (k == 3 or k == 6 or k == 7 or k == 9):
			continue
		var d := positions[i].distance_to(p)
		var imminent := (k == 7 and _charger_windup[i] > 0.0) or (k == 3 and _spitter_windup[i] > 0.0)
		out.append({
			"pos": positions[i], "kind": k, "dist": d,
			"tag": ("boss" if k == 9 else "threat"), "imminent": imminent
		})
	out.sort_custom(func(a, b):
		var ai := 1 if bool(a.get("imminent", false)) else 0
		var bi := 1 if bool(b.get("imminent", false)) else 0
		if ai != bi:
			return ai > bi
		return float(a.get("dist", 0.0)) < float(b.get("dist", 0.0))
	)
	if out.size() > max_n:
		out = out.slice(0, max_n)
	return out

func spawn_enemy(pos: Vector2, kind_id: int = 0) -> int:
	var idx := pool.alloc()
	if idx == -1:
		return -1
	kind_id = clampi(kind_id, 0, GameDB.ENEMY_TYPES.size() - 1)
	var cfg: Dictionary = GameDB.ENEMY_TYPES[kind_id]
	positions[idx] = pos
	kind[idx] = kind_id
	# 应用属性缩放
	hp[idx] = float(cfg["hp"]) * _enemy_hp_scale
	speed[idx] = (float(cfg["speed"]) + randf_range(-4.0, 6.0)) * _enemy_speed_scale * GameDB.ENEMY_SPEED_GLOBAL_MUL
	damage[idx] = float(cfg["damage"]) * _enemy_dmg_scale
	_special_cd[idx] = randf_range(0.0, 1.4)
	_stun_time[idx] = 0.0
	_ai_phase[idx] = randf() * TAU
	_charger_windup[idx] = 0.0
	_spitter_windup[idx] = 0.0
	_freeze_time[idx] = 0.0
	_visual_scale_mul[idx] = 1.0
	var atlas_slot: int = _enemy_atlas_slot(kind_id)
	_mm.set_instance_custom_data(
		idx,
		Color(float(atlas_slot) / 3.0, float(kind_id) / 9.0, randf() * 0.45 + 0.35, 1.0)
	)
	_mm.set_instance_transform_2d(idx, Transform2D(0.0, positions[idx]))
	# 首帧 _process 之前也要可见；否则实例色保持 _ready 里 alpha=0 会整段「无怪」
	var base_color: Color = cfg["color"]
	_mm.set_instance_color(idx, Color(base_color.r, base_color.g, base_color.b, 1.0))
	_register_pool_alive(idx)
	return idx


func mark_mini_boss(idx: int, wave_index: int) -> void:
	if idx < 0 or idx >= GameDB.ENEMY_MAX:
		return
	_visual_scale_mul[idx] = 1.42 if wave_index == 0 else 1.24
	var k := kind[idx]
	var base_color: Color = GameDB.ENEMY_TYPES[k]["color"]
	_mm.set_instance_color(idx, base_color.lerp(Color(1.0, 0.35, 0.28, 1.0), 0.35))

# ============================================
# SpatialGrid 加速的伤害查询
# ============================================

func _resolve_kill_weapon_for_sweep(explicit: StringName) -> StringName:
	if explicit != &"":
		return explicit
	if _kill_fx_weapon_stack.is_empty():
		return &""
	return _kill_fx_weapon_stack[_kill_fx_weapon_stack.size() - 1]


func apply_damage_circle(center: Vector2, radius: float, dmg: float, weapon_id: StringName = &"") -> int:
	var pushed := false
	if weapon_id != &"":
		_kill_fx_weapon_stack.append(weapon_id)
		pushed = true
	var hits := _apply_damage_circle_sweep(center, radius, dmg, &"")
	while not _pending_kill_explosions.is_empty():
		var e: Dictionary = _pending_kill_explosions.pop_front()
		var ew: StringName = StringName(e.get("weapon", &"explosion_kill"))
		hits += _apply_damage_circle_sweep(e["pos"], e["radius"], e["dmg"], ew)
	if pushed:
		_kill_fx_weapon_stack.pop_back()
	return hits


func _apply_damage_circle_sweep(center: Vector2, radius: float, dmg: float, explicit_weapon: StringName = &"") -> int:
	var sweep_hits := 0
	var kill_w := _resolve_kill_weapon_for_sweep(explicit_weapon)
	var candidates := grid.query_indices(center, radius)
	for i in candidates:
		if not pool.is_alive(i):
			continue
		if positions[i].distance_to(center) <= radius:
			hp[i] -= dmg
			sweep_hits += 1
			if hp[i] <= 0.0:
				var crit_kill := dmg >= maxf(hp[i] + dmg, 1.0) * 1.12 or dmg >= 64.0
				kill_enemy(i, dmg, crit_kill, kill_w)
	return sweep_hits


func _point_segment_distance_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ll := ab.length_squared()
	if ll < 0.0001:
		return p.distance_squared_to(a)
	var t := clampf((p - a).dot(ab) / ll, 0.0, 1.0)
	var proj := a + ab * t
	return p.distance_squared_to(proj)


## 主动技能穿透：线段走廊内每个敌人至多受一次伤害（与 WeaponProjectileLayer 表现解耦）。
func apply_piercing_line_damage(from: Vector2, to: Vector2, half_width: float, damage: float, weapon_id: StringName = &"active_skill", cast_seq: int = 0) -> int:
	var empty := PackedVector2Array()
	return _apply_piercing_line_damage_internal(from, to, half_width, damage, weapon_id, cast_seq, false, empty)


## 与 [method apply_piercing_line_damage] 相同判定，但返回本帧所有受击敌人的世界坐标（用于激光等在敌人身上画命中反馈）。
func apply_piercing_line_damage_with_hit_positions(from: Vector2, to: Vector2, half_width: float, damage: float, weapon_id: StringName = &"active_skill", cast_seq: int = 0) -> PackedVector2Array:
	var out := PackedVector2Array()
	_apply_piercing_line_damage_internal(from, to, half_width, damage, weapon_id, cast_seq, true, out)
	return out


func _apply_piercing_line_damage_internal(from: Vector2, to: Vector2, half_width: float, damage: float, weapon_id: StringName, cast_seq: int, collect_positions: bool, out_hit_positions: PackedVector2Array) -> int:
	var damaged: Dictionary = {}
	var hits := 0
	var seg_len := from.distance_to(to)
	if seg_len < 0.001:
		return 0
	var step := clampf(half_width * 1.1, 10.0, 42.0)
	var n := int(ceil(seg_len / step))
	var r_query := half_width + 46.0
	for s in range(n + 1):
		var t := float(s) / float(maxi(1, n))
		var c := from.lerp(to, t)
		var candidates := grid.query_indices(c, r_query)
		for i in candidates:
			if damaged.get(i, false):
				continue
			if not pool.is_alive(i):
				continue
			var pq: Vector2 = positions[i]
			var d2 := _point_segment_distance_sq(pq, from, to)
			var thr := half_width + 14.0
			if d2 > thr * thr:
				continue
			damaged[i] = true
			if collect_positions:
				out_hit_positions.append(positions[i])
			hp[i] -= damage
			hits += 1
			if weapon_id == &"active_laser":
				var caster_id := _player.get_instance_id() if _player else 0
				EventBus.skill_hit.emit(&"SK_Player_ActiveLaser_01", caster_id, i, cast_seq, &"energy", damage, false, Time.get_ticks_msec())
			if hp[i] <= 0.0:
				var crit_kill := damage >= maxf(hp[i] + damage, 1.0) * 1.12 or damage >= 64.0
				kill_enemy(i, damage, crit_kill, weapon_id)
	while not _pending_kill_explosions.is_empty():
		var e: Dictionary = _pending_kill_explosions.pop_front()
		var ew: StringName = StringName(e.get("weapon", &"explosion_kill"))
		_apply_damage_circle_sweep(e["pos"], e["radius"], e["dmg"], ew)
	return hits


func _flush_kill_explosion_queue() -> void:
	while not _pending_kill_explosions.is_empty():
		var e: Dictionary = _pending_kill_explosions.pop_front()
		var ew: StringName = StringName(e.get("weapon", &"explosion_kill"))
		_apply_damage_circle_sweep(e["pos"], e["radius"], e["dmg"], ew)

func kill_enemy(i: int, hit_power: float = 0.0, crit_kill: bool = false, killing_weapon: StringName = &"") -> void:
	if not pool.is_alive(i):
		return
	var pos := positions[i]
	var k := kind[i]
	_unregister_pool_alive(i)
	_mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(-99999, -99999)))
	_mm.set_instance_color(i, Color(1, 1, 1, 0))
	_mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	_visual_scale_mul[i] = 1.0
	pool.release(i)
	var kind_name := StringName(str(GameDB.ENEMY_TYPES[k]["name"]))
	EventBus.enemy_killed.emit(kind_name)
	_threat_kill_feedback(k, pos)
	_emit_kill_feedback(pos, k, hit_power, crit_kill, killing_weapon)
	# 击杀特效：根据敌人类型播放不同粒子
	var particle_mgr = get_parent().get_node_or_null("ParticleManager")
	if particle_mgr:
		match k:
			4:  # boomer: 爆炸
				particle_mgr.explosion(pos)
			3:  # spitter: 魔法爆发
				particle_mgr.magic_burst(pos)
				particle_mgr.lightning_spark(pos)
			6:  # summoner
				particle_mgr.magic_burst(pos)
			7:  # charger
				particle_mgr.lightning_spark(pos)
				particle_mgr.hit_effect(pos)
			8:  # shade
				particle_mgr.magic_burst(pos)
			9:  # elite
				particle_mgr.magic_burst(pos)
				particle_mgr.explosion(pos)
			2, 5:  # tank/guard: 烟雾
				particle_mgr.hit_effect(pos)
				particle_mgr.smoke(pos)
			_:
				particle_mgr.hit_effect(pos)
	
	# ========== 击杀爆炸被动效果 ==========
	var skill_sys = get_parent().get_node_or_null("SkillSystem")
	if skill_sys and skill_sys.stats.get("explosion_kill_dmg", 0.0) > 0:
		var exp_dmg := float(skill_sys.stats["explosion_kill_dmg"])
		var exp_rad := float(skill_sys.stats["explosion_kill_radius"])
		if exp_dmg > 0:
			_pending_kill_explosions.append({"pos": pos, "radius": exp_rad, "dmg": exp_dmg, "weapon": &"explosion_kill"})
			# 显示爆炸效果
			if particle_mgr:
				particle_mgr.explosion(pos)
			CombatFeedback.shake("heavy", 3.0, 0.1)
	
	var exp_value := 1
	if k == 2 or k == 5:
		exp_value = 2
	elif k == 9:
		exp_value = 4
	var exp_sys = get_parent().get_node_or_null("ExperienceSystem")
	if exp_sys != null:
		exp_sys.spawn_orb(pos, exp_value)


func _threat_kill_feedback(k: int, pos: Vector2) -> void:
	# 仅对高威胁目标给“击杀确认”，避免刷屏
	if not (k == 3 or k == 6 or k == 7 or k == 9):
		return
	if _threat_kill_cd > 0.0:
		return
	_threat_kill_chain += 1
	_threat_kill_chain_decay = 2.2
	# 冷却随连斩略放宽，让“清掉一串威胁”有节奏，但不吵
	_threat_kill_cd = 0.65 if _threat_kill_chain <= 1 else 0.42
	var label := "威胁清除"
	var tier := "subtle"
	var col := Color(1.0, 0.92, 0.35, 0.12)
	match k:
		3:
			label = "清除远程"
			col = Color(0.35, 1.0, 0.62, 0.085)
		6:
			label = "清除召唤"
			col = Color(0.92, 0.45, 1.0, 0.09)
		7:
			label = "清除冲锋"
			col = Color(1.0, 0.56, 0.34, 0.09)
		9:
			label = "清除精英"
			col = Color(1.0, 0.3, 0.22, 0.1)
			tier = "normal"
		_:
			pass
	# 文案尽量短，作为“确认音”而非叙述
	if _threat_kill_chain >= 2 and _threat_kill_chain <= 4:
		NotificationSystem.notify_message("%s ×%d" % [label, _threat_kill_chain], 1.1, "achievement")
	else:
		NotificationSystem.notify_message(label, 0.9, "success")
	CombatFeedback.flash(col, 0.05, tier)
	CombatFeedback.shake("ui", 2.0 if k != 9 else 2.6, 0.06)

func _on_enemy_stunned(world_pos: Vector2, duration: float) -> void:
	var dur := maxf(duration, 0.05)
	# 使用 SpatialGrid 加速
	var candidates := grid.query_indices(world_pos, STUN_RANGE)
	for i in candidates:
		if not pool.is_alive(i):
			continue
		if positions[i].distance_to(world_pos) <= STUN_RANGE:
			_stun_time[i] = maxf(_stun_time[i], dur)

# 冰冻敌人
func freeze_enemy(world_pos: Vector2, duration: float) -> void:
	var dur := maxf(duration, 0.05)
	var candidates := grid.query_indices(world_pos, 80.0)
	for i in candidates:
		if not pool.is_alive(i):
			continue
		if positions[i].distance_to(world_pos) <= 80.0:
			_freeze_time[i] = maxf(_freeze_time[i], dur)
			EventBus.enemy_frozen.emit(positions[i], dur)

func get_closest_enemy_pos(center: Vector2, max_range := INF) -> Variant:
	var nearest: Variant = null
	var best := INF
	var max_range_sq := max_range * max_range
	# 小范围使用 SpatialGrid，大范围退回全量扫描
	if max_range < 800.0:
		var candidates := grid.query_indices(center, max_range)
		for i in candidates:
			if not pool.is_alive(i):
				continue
			var d_sq := positions[i].distance_squared_to(center)
			if d_sq < best and d_sq <= max_range_sq:
				best = d_sq
				nearest = positions[i]
	else:
		for i in _pool_alive_list:
			var d_sq := positions[i].distance_squared_to(center)
			if d_sq < best and d_sq <= max_range_sq:
				best = d_sq
				nearest = positions[i]
	return nearest

func get_enemies_in_radius(center: Vector2, radius: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	# 使用 SpatialGrid 加速
	var candidates := grid.query_indices(center, radius)
	for i in candidates:
		if not pool.is_alive(i):
			continue
		if positions[i].distance_to(center) <= radius:
			result.append(positions[i])
	return result

func get_enemies_in_line(start: Vector2, end: Vector2, width: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var line_dir := (end - start).normalized()
	var line_length := start.distance_to(end)
	
	# 使用包围盒 + SpatialGrid 加速
	var center := (start + end) * 0.5
	var half_len := line_length * 0.5 + width
	var candidates := grid.query_indices(center, half_len)
	
	for i in candidates:
		if not pool.is_alive(i):
			continue
		var pos := positions[i]
		var to_pos := pos - start
		var projection_length := to_pos.dot(line_dir)
		if projection_length < 0 or projection_length > line_length:
			continue
		var projection := start + line_dir * projection_length
		var perpendicular_dist := pos.distance_to(projection)
		if perpendicular_dist <= width:
			result.append(pos)
	
	return result


## 命中反馈用：在某位置附近找到“最高威胁”的敌人 kind
## 返回 -1 表示未找到；9 为 elite；其余见 GameDB.ENEMY_TYPES
func threat_kind_near(world_pos: Vector2, radius: float = 28.0) -> int:
	if radius <= 0.1:
		return -1
	# SpatialGrid 加速：只看附近候选
	var candidates := grid.query_indices(world_pos, radius)
	if candidates.is_empty():
		return -1
	var best_k := -1
	var best_d := INF
	for i in candidates:
		if not pool.is_alive(i):
			continue
		var d := positions[i].distance_to(world_pos)
		if d > radius:
			continue
		var k := int(kind[i])
		# 威胁优先级：elite > charger/summoner/spitter > 其它
		var score := 0
		if k == 9:
			score = 300
		elif k == 7:
			score = 220
		elif k == 6:
			score = 210
		elif k == 3:
			score = 200
		else:
			score = 100
		# 组合：先看 score，再看距离
		var composite := float(score) * 10000.0 - d
		var best_comp := float(best_k) * 10000.0 - best_d
		if best_k == -1 or composite > best_comp:
			best_k = k
			best_d = d
	return best_k

func alive_count() -> int:
	return _pool_alive_list.size() + (1 if _boss_alive else 0)


func clear_all_enemies(silent: bool = true) -> void:
	# 白盒/调参快速迭代：一键清场（默认静默，不触发击杀反馈/掉落）
	_pending_kill_explosions.clear()
	_kill_fx_weapon_stack.clear()
	if _boss_alive:
		_boss_alive = false
		_boss_hp = 0.0
		_boss_hp_max = 0.0
		_boss_pending_t = 0.0
		_boss_pending_radius = 0.0
		_boss_pending_damage = 0.0
		_boss_pending_kind = 0
		_boss_pending_dir = Vector2.ZERO
		if not silent:
			NotificationSystem.notify_message("首领已清除", 1.2, "info")
	var alive_copy := _pool_alive_list.duplicate()
	for idx in alive_copy:
		var i := int(idx)
		if i < 0 or i >= GameDB.ENEMY_MAX:
			continue
		if not pool.is_alive(i):
			continue
		# 释放对象池 + 从存活索引中移除
		pool.release(i)
		_unregister_pool_alive(i)
		# 隐藏实例
		positions[i] = Vector2(-99999, -99999)
		hp[i] = 0.0
		_mm.set_instance_transform_2d(i, Transform2D(0.0, positions[i]))
		_mm.set_instance_color(i, Color(1, 1, 1, 0))
		_mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	# 清空缓存
	active_indices.clear()
	_threat_cache.clear()
	_threat_cache_tick = 0
	if not silent:
		NotificationSystem.notify_message("已清场", 1.2, "success")

# ============================================
# BOSS 系统 - 多类型BOSS + 特殊技能
# ============================================

var _boss_type := 0  # BOSS类型
var _boss_enraged := false  # 狂暴状态
var _boss_lightning_chain_count := 0  # 闪电链跳跃计数

func spawn_boss(pos: Vector2) -> void:
	if _boss_alive:
		return
	_boss_alive = true
	_boss_type = randi() % GameDB.BOSS_TYPES.size()  # 随机选择BOSS类型
	var boss_cfg: Dictionary = GameDB.BOSS_TYPES[_boss_type]
	_boss_hp_max = 3000.0 * float(boss_cfg.get("hp_scale", 1.0))
	_boss_hp = _boss_hp_max
	_boss_pos = pos
	_boss_speed = 46.0 * float(boss_cfg.get("speed_scale", 1.0))
	_boss_attack_cd = 1.2 / float(boss_cfg.get("speed_scale", 1.0))
	_boss_pending_t = 0.0
	_boss_pending_kind = 0
	_boss_enraged = false
	_boss_lightning_chain_count = 0
	
	# 通知BOSS生成，显示BOSS类型名称
	var boss_name := str(boss_cfg.get("name", "暗影巨兽"))
	NotificationSystem.notify_message("首领出现: " + boss_name, 3.0, "warning")
	EventBus.boss_spawned.emit()

func boss_alive() -> bool:
	return _boss_alive

func boss_type() -> int:
	return _boss_type

func boss_hp_ratio() -> float:
	if not _boss_alive:
		return 0.0
	return clampf(_boss_hp / _boss_hp_max, 0.0, 1.0)

func boss_phase() -> int:
	if not _boss_alive:
		return 0
	var r := boss_hp_ratio()
	if r > 0.7:
		return 1
	if r > 0.35:
		return 2
	return 3

func boss_pos() -> Vector2:
	return _boss_pos

func boss_enraged() -> bool:
	return _boss_enraged

func apply_damage_to_boss(center: Vector2, radius: float, dmg: float) -> bool:
	if not _boss_alive:
		return false
	if _boss_pos.distance_to(center) > radius:
		return false
	_boss_hp -= dmg
	
	# 检查狂暴触发（雷霆领主更容易狂暴）
	var enrage_threshold := 0.3
	if _boss_type == 1:  # 雷霆领主
		enrage_threshold = 0.4
	if boss_hp_ratio() <= enrage_threshold and not _boss_enraged:
		_boss_enraged = true
		_boss_speed *= 1.3
		NotificationSystem.notify_message("首领进入狂暴状态！", 2.0, "error")
		CombatFeedback.shake("boss", 6.0, 0.5)
	
	if _boss_hp <= 0.0:
		var phase_kill := boss_phase()
		_boss_alive = false
		EventBus.boss_defeated.emit()
		EventBus.enemy_killed_detailed.emit(_boss_pos, &"boss_phase", 0, phase_kill, &"boss")
		EventBus.play_sfx.emit(&"explosion", _boss_pos)
		EventBus.play_sfx.emit(&"hit", _boss_pos)
		# 胜利由Game.gd统一判断，不在EnemyManager中emit game_over
	return true

func _emit_kill_feedback(pos: Vector2, k: int, hit_power: float, crit_kill: bool, killing_weapon: StringName = &"") -> void:
	var tier := &"normal"
	if k == 3 or k == 6 or k == 7 or k == 9:
		tier = &"threat"
	elif crit_kill or hit_power >= 58.0:
		tier = &"crit"
	_combo_kill_count += 1
	_combo_kill_decay = 1.9
	EventBus.enemy_killed_detailed.emit(pos, tier, _combo_kill_count, 0, killing_weapon)
	if _combo_kill_count >= 3 and _combo_notify_cd <= 0.0:
		NotificationSystem.notify_message("连击 ×%d" % _combo_kill_count, 0.95, "achievement")
		_combo_notify_cd = 0.42
	match tier:
		&"threat":
			EventBus.play_sfx.emit(&"explosion", pos)
		&"crit":
			EventBus.play_sfx.emit(&"hit", pos)
			if _combo_kill_count >= 3:
				EventBus.play_sfx.emit(&"lightning", pos)
		_:
			pass  # 普通击杀不播 hit，减少刺耳连击

# 闪电链技能 - 雷霆领主特殊技能
func boss_lightning_chain() -> void:
	if _boss_type != 1:  # 只有雷霆领主使用
		return
	_boss_lightning_chain_count = 5  # 5次跳跃
	_apply_lightning_chain(_boss_pos, 5)

func _apply_lightning_chain(pos: Vector2, jumps: int) -> void:
	if jumps <= 0:
		return
	var nearest_enemies: Array[int] = []
	var min_dist := 150.0
	for idx in _pool_alive_list:
		var d := positions[idx].distance_to(pos)
		if d < min_dist:
			nearest_enemies.append(idx)
	nearest_enemies.sort_custom(func(a, b): return positions[a].distance_to(pos) < positions[b].distance_to(pos))
	var targets: int = mini(jumps, nearest_enemies.size())
	for i in targets:
		var e_idx := nearest_enemies[i]
		var dmg := 25.0 * (1.0 if not _boss_enraged else 1.5)
		hp[e_idx] -= dmg
		# 视觉效果
		EventBus.enemy_stunned.emit(positions[e_idx], 0.3)
		# 继续链式跳跃
		if i < targets - 1:
			_apply_lightning_chain(positions[e_idx], 1)

func _enemy_atlas_slot(kind_id: int) -> int:
	match kind_id:
		0, 1:
			return 0
		2, 5:
			return 1
		3, 4:
			return 2
		_:
			return 3


func _resolve_enemy_texture() -> Texture2D:
	var atlas_img: Image = GameDB.load_png_if_exists(GameDB.TEX_GEN_ENEMY_ATLAS)
	# Shader 假定横向 4 格、格为正方形：宽必须等于 4×高，否则 UV 错乱 → 中心大块杂色
	if atlas_img != null:
		var aw := atlas_img.get_width()
		var ah := atlas_img.get_height()
		if ah > 0 and aw == 4 * ah:
			_enemy_uses_atlas = true
			return ImageTexture.create_from_image(atlas_img)
	_enemy_uses_atlas = true
	return _make_procedural_enemy_atlas()

func _make_enemy_shader() -> Shader:
	var code := "
shader_type canvas_item;
uniform sampler2D tex;
uniform bool use_enemy_atlas = false;
varying flat vec4 v_cust;

void vertex() {
	v_cust = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 uv = UV;
	float vslot = floor(v_cust.x * 3.01 + 0.001);
	if (use_enemy_atlas) {
		uv.x = vslot * 0.25 + uv.x * 0.25;
	} else {
		float warp = v_cust.y * 0.55 + 0.35;
		uv.x += sin(uv.y * 18.283 + v_cust.x * 40.0) * 0.03 * warp;
		uv.y += cos(uv.x * 17.0 + v_cust.z * 12.0) * 0.02 * warp;
	}
	vec4 t = texture(tex, uv);
	float rim = smoothstep(0.1, 0.48, t.a) * (1.0 - smoothstep(0.52, 0.98, t.a));
	vec3 rim_rgb = vec3(0.08, 0.28, 0.42) * rim * (0.4 + v_cust.y * 0.5);
	// 保留贴图明暗，再用实例色偏染（避免 t≈灰白时整张贴成纯色块）
	vec3 tint = COLOR.rgb;
	vec3 lit = mix(t.rgb, t.rgb * tint, 0.72);
	// 暗部冷色、亮部略提（增加立体感，避免糊成一片）
	float luma = dot(lit, vec3(0.299, 0.587, 0.114));
	lit = mix(lit * vec3(0.92, 0.97, 1.05), lit + vec3(0.04, 0.05, 0.06), smoothstep(0.15, 0.65, luma));
	vec4 base = vec4(lit + rim_rgb, t.a * COLOR.a);
	COLOR = base;
}
"
	var s := Shader.new()
	s.code = code
	return s

func _make_procedural_enemy_atlas() -> Texture2D:
	var frame := 64
	var atlas := Image.create(frame * 4, frame, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var styles: PackedStringArray = ["walker", "runner", "brute", "caster"]
	for i in styles.size():
		var cell := Image.create(frame, frame, false, Image.FORMAT_RGBA8)
		cell.fill(Color(0, 0, 0, 0))
		_draw_enemy_silhouette(cell, styles[i])
		atlas.blit_rect(cell, Rect2i(0, 0, frame, frame), Vector2i(i * frame, 0))
	return ImageTexture.create_from_image(atlas)


func _draw_enemy_silhouette(img: Image, style: String) -> void:
	var size := img.get_width()
	var cx := float(size) / 2.0
	var cy := float(size) / 2.0 + 2.0
	var outline := Color(0.05, 0.05, 0.08, 1.0)
	var body := Color(0.94, 0.92, 0.98, 1.0)
	var dark := Color(0.58, 0.54, 0.66, 1.0)
	var accent := Color(0.82, 0.52, 0.4, 1.0)
	match style:
		"runner":
			cx += 2.0
			_fill_ellipse(img, cx, cy + 18.0, 5.0, 2.0, Color(0, 0, 0, 0.32))
			for y in range(int(cy - 2.0), int(cy + 14.0)):
				var w := 4.0 + absf(float(y) - cy) * 0.15
				for x in range(int(cx - w), int(cx + w + 1.0)):
					if x >= 0 and x < size and y >= 0 and y < size:
						img.set_pixel(x, y, outline if absf(float(x) - cx) > w - 1.2 else dark)
			_fill_circle(img, cx + 5.0, cy - 10.0, 7.0, body)
			_fill_circle(img, cx + 7.0, cy - 12.0, 2.2, Color(0.1, 0.1, 0.14, 1.0))
			for side in [-1.0, 1.0]:
				_fill_triangle(img, cx + side * 8.0, cy + 2.0, cx + side * 14.0, cy + 8.0, cx + side * 6.0, cy + 10.0, accent)
		"brute":
			_fill_ellipse(img, cx, cy + 20.0, 12.0, 3.5, Color(0, 0, 0, 0.35))
			_fill_ellipse(img, cx, cy + 4.0, 16.0, 14.0, outline)
			_fill_ellipse(img, cx, cy + 4.0, 14.0, 12.0, dark)
			_fill_ellipse(img, cx - 3.0, cy + 1.0, 10.0, 8.0, body)
			_fill_circle(img, cx, cy - 10.0, 6.0, body)
			_fill_circle(img, cx - 3.0, cy - 11.0, 1.8, Color(0.1, 0.1, 0.14, 1.0))
			_fill_circle(img, cx + 3.0, cy - 11.0, 1.8, Color(0.1, 0.1, 0.14, 1.0))
			for side in [-1.0, 1.0]:
				_fill_ellipse(img, cx + side * 14.0, cy + 6.0, 5.0, 8.0, dark)
		"caster":
			_fill_ellipse(img, cx, cy + 18.0, 8.0, 2.5, Color(0, 0, 0, 0.32))
			_fill_circle(img, cx, cy + 2.0, 13.0, outline)
			_fill_circle(img, cx, cy + 2.0, 11.0, body)
			_fill_circle(img, cx, cy - 8.0, 5.0, dark)
			_fill_triangle(img, cx, cy - 16.0, cx - 4.0, cy - 22.0, cx + 4.0, cy - 22.0, accent)
			_fill_circle(img, cx - 9.0, cy - 2.0, 3.0, Color(0.45, 0.82, 0.42, 0.85))
			_fill_circle(img, cx + 9.0, cy - 2.0, 3.0, Color(0.45, 0.82, 0.42, 0.85))
		_:  # walker
			_make_enemy_texture_into(img)
	_anti_alias_edges(img)


func _make_enemy_texture_into(img: Image) -> void:
	var size := img.get_width()
	var cx := float(size) / 2.0
	var cy := float(size) / 2.0 + 2.0
	var body := Color(0.94, 0.92, 0.98, 1.0)
	var dark := Color(0.58, 0.54, 0.66, 1.0)
	var light := Color(0.99, 0.98, 1.0, 1.0)
	var outline := Color(0.04, 0.04, 0.07, 1.0)
	var claw := Color(0.82, 0.52, 0.4, 1.0)
	var shadow := Color(0.0, 0.0, 0.0, 0.35)
	var vein := Color(0.45, 0.82, 0.42, 0.45)
	
	# 脚下阴影
	_fill_ellipse(img, cx, cy + 20.0, 9.0, 3.0, shadow)
	
	# === 轮廓描边 ===
	_fill_circle(img, cx, cy - 12.0, 10.0, outline)
	for y in range(int(cy - 4.0), int(cy + 10.0)):
		var w := 9.0 + (float(y) - (cy - 4.0)) * 0.4 + 2.0
		for x in range(int(cx - w), int(cx + w + 1.0)):
			if x >= 0 and x < size and y >= 0 and y < size:
				img.set_pixel(x, y, outline)
	for side_value: float in [-1.0, 1.0]:
		var ax: float = cx + side_value * 11.0
		for y in range(int(cy - 3.0), int(cy + 8.0)):
			for dx in range(-2, 3):
				var px := int(ax + float(dx))
				if px >= 0 and px < size and y >= 0 and y < size:
					img.set_pixel(px, y, outline)
		var lx: float = cx + side_value * 4.5
		for y in range(int(cy + 10.0), int(cy + 18.0)):
			for dx in range(-2, 3):
				var px := int(lx + float(dx))
				if px >= 0 and px < size and y >= 0 and y < size:
					img.set_pixel(px, y, outline)
	
	# === 腿 ===
	for side_value: float in [-1.0, 1.0]:
		var lx: float = cx + side_value * 4.5
		for y in range(int(cy + 10.0), int(cy + 18.0)):
			var px := int(lx)
			if px >= 0 and px < size and y >= 0 and y < size:
				img.set_pixel(px, y, dark)
				if side_value < 0:
					img.set_pixel(px + 1, y, Color(dark.r * 0.8, dark.g * 0.8, dark.b * 0.8, 1.0))
				else:
					img.set_pixel(px - 1, y, Color(dark.r * 0.8, dark.g * 0.8, dark.b * 0.8, 1.0))
		# 爪脚
		for dx in range(-1, 2):
			var px := int(lx + float(dx))
			if px >= 0 and px < size:
				img.set_pixel(px, int(cy + 17.0), dark)
	
	# === 身体/躯干 ===
	for y in range(int(cy - 4.0), int(cy + 10.0)):
		var w := 9.0 + (float(y) - (cy - 4.0)) * 0.4
		for x in range(int(cx - w), int(cx + w + 1.0)):
			if x >= 0 and x < size and y >= 0 and y < size:
				var is_edge: bool = abs(float(x) - cx) > w - 2.0
				if is_edge:
					img.set_pixel(x, y, dark)
				else:
					# 身体渐变
					var shade: float = lerp(1.1, 0.8, (float(y) - (cy - 4.0)) / 14.0)
					img.set_pixel(x, y, Color(body.r * shade, body.g * shade, body.b * shade, 1.0))
	
	for y in range(int(cy + 2.0), int(cy + 8.0)):
		if int(cx) >= 0 and int(cx) < size and y >= 0 and y < size:
			img.set_pixel(int(cx), y, vein)
	
	# === 手臂 + 爪子 ===
	for side_value: float in [-1.0, 1.0]:
		var ax: float = cx + side_value * 11.0
		for y in range(int(cy - 2.0), int(cy + 8.0)):
			var px := int(ax)
			if px >= 0 and px < size and y >= 0 and y < size:
				img.set_pixel(px, y, dark)
				# 手臂内侧亮边
				var inner := int(ax - side_value * 1.0)
				if inner >= 0 and inner < size:
					img.set_pixel(inner, y, Color(dark.r * 1.2, dark.g * 1.2, dark.b * 1.25, 1.0))
		# 爪子（3个尖爪）
		var claw_y := cy + 8.0
		for dx in range(-1, 2):
			var px := int(ax + float(dx))
			if px >= 0 and px < size:
				img.set_pixel(px, int(claw_y), claw)
		var tip_x := int(ax + side_value * 2.0)
		if tip_x >= 0 and tip_x < size:
			img.set_pixel(tip_x, int(claw_y + 1.0), claw)
	
	# === 头部 ===
	_fill_circle(img, cx, cy - 12.0, 9.0, light)
	# 头部暗面
	_fill_circle(img, cx, cy - 12.0, 9.0, Color(light.r * 0.7, light.g * 0.7, light.b * 0.72, 1.0), true)
	# 头部亮面
	_fill_circle(img, cx - 1.5, cy - 15.0, 5.0, Color(light.r * 1.1, light.g * 1.05, light.b * 1.05, 1.0))
	
	_fill_circle(img, cx - 5.0, cy - 20.0, 2.4, dark)
	_fill_circle(img, cx + 5.0, cy - 20.0, 2.4, dark)
	
	_fill_circle(img, cx - 3.8, cy - 12.0, 3.2, Color(1, 1, 1, 1))
	_fill_circle(img, cx + 3.8, cy - 12.0, 3.2, Color(1, 1, 1, 1))
	_fill_circle(img, cx - 3.8, cy - 12.0, 1.25, Color(0.1, 0.1, 0.14, 1))
	_fill_circle(img, cx + 3.8, cy - 12.0, 1.25, Color(0.1, 0.1, 0.14, 1))
	
	# 嘴部裂痕
	img.set_pixel(int(cx - 2.0), int(cy - 8.0), Color(0.4, 0.1, 0.1, 0.8))
	img.set_pixel(int(cx), int(cy - 7.0), Color(0.5, 0.15, 0.1, 0.8))
	img.set_pixel(int(cx + 2.0), int(cy - 8.0), Color(0.4, 0.1, 0.1, 0.8))
	
	# 边缘抗锯齿
	_anti_alias_edges(img)


func _make_enemy_texture() -> Texture2D:
	var gen_img: Image = GameDB.load_png_if_exists(GameDB.TEX_GEN_ENEMY_BASE)
	if gen_img != null:
		return ImageTexture.create_from_image(gen_img)
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_make_enemy_texture_into(img)
	return ImageTexture.create_from_image(img)

func _fill_circle(img: Image, cx: float, cy: float, radius: float, col: Color, bottom_half := false) -> void:
	var size := img.get_width()
	for y in range(max(0, int(cy - radius)), min(size, int(cy + radius + 1.0))):
		for x in range(max(0, int(cx - radius)), min(size, int(cx + radius + 1.0))):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if bottom_half and dy < 0:
				continue
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, col)

func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var size := img.get_width()
	for y in range(max(0, int(cy - ry)), min(size, int(cy + ry + 1.0))):
		for x in range(max(0, int(cx - rx)), min(size, int(cx + rx + 1.0))):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.0:
				img.set_pixel(x, y, col)

func _fill_triangle(img: Image, x1: float, y1: float, x2: float, y2: float, x3: float, y3: float, col: Color) -> void:
	var size := img.get_width()
	var min_x := minf(x1, minf(x2, x3))
	var max_x := maxf(x1, maxf(x2, x3))
	var min_y := minf(y1, minf(y2, y3))
	var max_y := maxf(y1, maxf(y2, y3))
	for y in range(max(0, int(min_y)), min(size, int(max_y + 1.0))):
		for x in range(max(0, int(min_x)), min(size, int(max_x + 1.0))):
			if _point_in_triangle(float(x), float(y), x1, y1, x2, y2, x3, y3):
				img.set_pixel(x, y, col)

func _point_in_triangle(px: float, py: float, x1: float, y1: float, x2: float, y2: float, x3: float, y3: float) -> bool:
	var d1 := (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2)
	var d2 := (px - x3) * (y2 - y3) - (x2 - x3) * (py - y3)
	var d3 := (px - x1) * (y3 - y1) - (x3 - x1) * (py - y1)
	var has_neg := (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos := (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)

func _anti_alias_edges(img: Image) -> void:
	var size := img.get_width()
	var copy: Image = img.duplicate()
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var c: Color = copy.get_pixel(x, y)
			if c.a > 0.0:
				var neighbors := 0
				var total_a := 0.0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nc: Color = copy.get_pixel(x + dx, y + dy)
						if nc.a > 0.0:
							neighbors += 1
						total_a += nc.a
				if neighbors > 0 and neighbors < 8:
					var avg_a := total_a / 8.0
					if avg_a < c.a:
						img.set_pixel(x, y, Color(c.r, c.g, c.b, max(c.a * 0.85, avg_a)))

func _rand_vec(radius: float) -> Vector2:
	var a := randf() * TAU
	return Vector2(cos(a), sin(a)) * randf() * radius

func _update_boss(delta: float) -> void:
	if not _boss_alive or _player == null:
		return
	var p := _player.global_position
	var dir := (p - _boss_pos).normalized()
	_boss_pos += dir * _boss_speed * delta
	if _boss_pending_t > 0.0:
		_boss_pending_t -= delta
		if _boss_pending_t <= 0.0:
			match _boss_pending_kind:
				0: # circle
					if _boss_pos.distance_to(p) <= _boss_pending_radius:
						_player_take_damage(_boss_pending_damage)
				1: # dash: reposition then hit
					_boss_pos += _boss_pending_dir * 240.0
					if _boss_pos.distance_to(p) <= _boss_pending_radius:
						_player_take_damage(_boss_pending_damage)
				2: # pulse: 3 quick checks
					for _i in 3:
						if _boss_pos.distance_to(p) <= _boss_pending_radius:
							_player_take_damage(_boss_pending_damage)
				3: # cone: directional check
					var to_p := (_player.global_position - _boss_pos)
					if to_p.length() <= _boss_pending_radius and to_p.normalized().dot(_boss_pending_dir) >= 0.65:
						_player_take_damage(_boss_pending_damage)
			_boss_pending_radius = 0.0
			_boss_pending_damage = 0.0
			_boss_pending_kind = 0
	if _boss_pos.distance_to(p) < BOSS_CONTACT_RADIUS:
		_player_take_damage(BOSS_CONTACT_DMG)
	_boss_attack_cd -= delta
	if _boss_attack_cd <= 0.0:
		_boss_choose_attack(p, dir)

# BOSS混合攻击选择：不再固定每阶段一种攻击，而是按概率混合
func _boss_choose_attack(p: Vector2, dir: Vector2) -> void:
	var hp_ratio := _boss_hp / _boss_hp_max
	var phase := boss_phase()
	var roll := randf()
	
	if phase == 1:
		# 阶段1: 主要冲撞(70%)，偶尔脉冲(30%)
		if roll < 0.7:
			_boss_attack_dash(dir)
		else:
			_boss_attack_pulse(dir)
	elif phase == 2:
		# 阶段2: 冲撞(40%) + 脉冲(35%) + 锥形(25%)
		if roll < 0.4:
			_boss_attack_dash(dir)
		elif roll < 0.75:
			_boss_attack_pulse(dir)
		else:
			_boss_attack_cone(dir)
	else:
		# 阶段3: 高频混合 + 组合技
		if roll < 0.3:
			_boss_attack_dash(dir)
		elif roll < 0.55:
			_boss_attack_pulse(dir)
		elif roll < 0.8:
			_boss_attack_cone(dir)
		else:
			_boss_attack_combo(dir)

func _boss_attack_dash(dir: Vector2) -> void:
	_boss_attack_cd = 1.6
	EventBus.boss_warning.emit(0.35, 0.5)
	_boss_pending_t = 0.5
	_boss_pending_kind = 1
	_boss_pending_dir = dir
	_boss_pending_radius = 120.0
	_boss_pending_damage = 12.0
	EventBus.boss_telegraph.emit(_boss_pending_kind, _boss_pos, _boss_pending_dir, _boss_pending_radius, _boss_pending_t)

func _boss_attack_pulse(dir: Vector2) -> void:
	_boss_attack_cd = 1.2
	EventBus.boss_warning.emit(0.55, 0.6)
	_boss_pending_t = 0.6
	_boss_pending_kind = 2
	_boss_pending_radius = 165.0
	_boss_pending_damage = 9.0
	EventBus.boss_telegraph.emit(_boss_pending_kind, _boss_pos, dir, _boss_pending_radius, _boss_pending_t)

func _boss_attack_cone(dir: Vector2) -> void:
	_boss_attack_cd = 0.8
	EventBus.boss_warning.emit(0.8, 0.7)
	_boss_pending_t = 0.7
	_boss_pending_kind = 3
	_boss_pending_dir = dir
	_boss_pending_radius = 240.0
	_boss_pending_damage = 26.0
	EventBus.boss_telegraph.emit(_boss_pending_kind, _boss_pos, _boss_pending_dir, _boss_pending_radius, _boss_pending_t)

# 组合技：冲撞后接锥形攻击
func _boss_attack_combo(dir: Vector2) -> void:
	_boss_attack_cd = 2.5  # 长冷却
	EventBus.boss_warning.emit(1.0, 1.0)
	# 第一步：冲撞
	_boss_pending_t = 0.5
	_boss_pending_kind = 1
	_boss_pending_dir = dir
	_boss_pending_radius = 140.0
	_boss_pending_damage = 16.0
	EventBus.boss_telegraph.emit(_boss_pending_kind, _boss_pos, _boss_pending_dir, _boss_pending_radius, _boss_pending_t)
	# 冲撞后延迟0.3s接锥形（通过计时器实现）
	var combo_tween := create_tween()
	combo_tween.tween_callback(func():
		if _boss_alive:
			_boss_attack_cone(dir)
	).set_delay(0.8)

func _bucket_count() -> int:
	match Settings.quality:
		Settings.Quality.LOW:
			return 2
		Settings.Quality.HIGH:
			return 4
		_:
			return 3

func debug_bucket_count() -> int:
	return _last_bucket_count

func debug_active_count() -> int:
	return active_indices.size()

func debug_pool_used() -> int:
	return GameDB.ENEMY_MAX - pool.free_list.size()

func apply_knockback(center: Vector2, radius: float, force: float) -> void:
	# 使用 SpatialGrid 加速
	var candidates := grid.query_indices(center, radius)
	for i in candidates:
		if not pool.is_alive(i):
			continue
		var pos := positions[i]
		var dist := pos.distance_to(center)
		if dist <= radius and dist > 0.01:
			var dir := (pos - center).normalized()
			var knock_strength := force * (1.0 - dist / radius)
			positions[i] += dir * knock_strength

# 统一伤害入口：直接调用Player.take_damage()
func _player_take_damage(amount: float) -> void:
	if _player and _player.has_method("take_damage"):
		_player.take_damage(amount)

func _readability_enemy_suppression() -> float:
	match int(Settings.readability_preset):
		Settings.ReadabilityPreset.LOW:
			return 0.55
		Settings.ReadabilityPreset.HIGH:
			return 1.0
		_:
			return 0.9

# ============================================
# 资源清理 - 防止MultiMesh和SpatialGrid泄漏
# ============================================
func _exit_tree() -> void:
	if _mm_node:
		_mm_node.multimesh = null
		_mm_node.queue_free()
	_mm = MultiMesh.new()
	grid.clear()
