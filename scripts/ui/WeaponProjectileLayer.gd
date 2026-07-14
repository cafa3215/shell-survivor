extends Node2D
class_name WeaponProjectileLayer

const WeaponProjectileArt = preload("res://scripts/weapon_presentation/WeaponProjectileArt.gd")

const _KIND_KUNAI := "kunai"
const _KIND_QUANTUM := "quantum_ball"
const _KIND_LIGHTNING := "lightning"
const _KIND_ROCKET := "rocket"
const _KIND_MOLOTOV := "molotov"
const _KIND_DRONE := "drone_ab"
const _KIND_BOOMERANG := "boomerang"
const _KIND_GUARDIAN := "guardian"
const _KIND_FROST := "frost_aura"
const _KIND_HEAL := "heal_aura"
const _KIND_MINE := "stun_mine"
const _KIND_ACTIVE_BOLT := "active_bolt"

var _projectiles: Array[Dictionary] = []
var _pool: Array[AnimatedSprite2D] = []
var _active_sprites: Array[AnimatedSprite2D] = []
var _tex_cache: Dictionary = {}
var _frames_cache: Dictionary = {}
var _kind_tex_mul: Dictionary = {} # 外置大图相对程序 192px 的缩放补偿
var _guardian_blades: Array[AnimatedSprite2D] = []
var _aura_sprites: Dictionary = {}
var _mine_sprites: Array[AnimatedSprite2D] = []
var _weapon_mount_sprites: Dictionary = {} # kind -> AnimatedSprite2D
var _weapon_unlock_fx: Array[Dictionary] = []
var _guardian_phase := 0.0
var _runtime_overload_mul := 1.0
var _rim_shader: Shader = null

func set_runtime_overload_mul(v: float) -> void:
	_runtime_overload_mul = clampf(v, 0.55, 1.0)

const _PROJECTILE_VISUAL_MUL := 1.52
## 外置 AI 弹体目标屏高（对齐 EnemyManager QuadMesh 64px）
const _EXTERNAL_TARGET_PX := 56.0
const _SPRITE_Z_INDEX := 14
## 武器挂载光晕（Carrier 识别层）
var _mount_glow_phase := 0.0

func spawn_projectile(kind: String, from_pos: Vector2, dir: Vector2, speed: float, lifetime: float, weapon_lv: int = 1, evolved: bool = false) -> void:
	if _projectiles.size() >= _max_projectiles_for_profile():
		_recycle_oldest_projectile()
	var n_dir := dir.normalized()
	if n_dir.length() <= 0.001:
		n_dir = Vector2.RIGHT
	var sprite := _alloc_sprite()
	sprite.sprite_frames = _frames_for_kind(kind)
	sprite.play("default")
	sprite.speed_scale = _anim_speed_for_kind(kind)
	sprite.global_position = from_pos
	sprite.rotation = n_dir.angle()
	sprite.visible = true
	sprite.modulate = _modulate_for_kind(kind)
	_apply_rim_material(sprite, kind)
	sprite.scale = _projectile_scale_vec(kind, weapon_lv, evolved)
	_projectiles.append({
		"kind": kind,
		"pos": from_pos,
		"dir": n_dir,
		"speed": speed,
		"time": maxf(0.05, lifetime),
		"max_time": maxf(0.05, lifetime),
		"sprite": sprite,
		"phase": randf() * TAU,
		"lv": weapon_lv,
		"evolved": evolved
	})


func spawn_projectile_bezier(kind: String, p0: Vector2, p1: Vector2, p2: Vector2, lifetime: float, weapon_lv: int = 1, evolved: bool = false) -> void:
	if _projectiles.size() >= _max_projectiles_for_profile():
		_recycle_oldest_projectile()
	var sprite := _alloc_sprite()
	sprite.sprite_frames = _frames_for_kind(kind)
	sprite.play("default")
	sprite.speed_scale = _anim_speed_for_kind(kind)
	sprite.global_position = p0
	var init_dir := (p1 - p0).normalized() if p0.distance_to(p1) > 0.5 else Vector2.RIGHT
	sprite.rotation = init_dir.angle()
	sprite.visible = true
	sprite.modulate = _modulate_for_kind(kind)
	_apply_rim_material(sprite, kind)
	sprite.scale = _projectile_scale_vec(kind, weapon_lv, evolved)
	_projectiles.append({
		"kind": kind,
		"path": "bezier",
		"p0": p0,
		"p1": p1,
		"p2": p2,
		"time": maxf(0.05, lifetime),
		"max_time": maxf(0.05, lifetime),
		"sprite": sprite,
		"phase": randf() * TAU,
		"lv": weapon_lv,
		"evolved": evolved
	})


func spawn_projectile_bezier_cubic(kind: String, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, lifetime: float, weapon_lv: int = 1, evolved: bool = false) -> void:
	if _projectiles.size() >= _max_projectiles_for_profile():
		_recycle_oldest_projectile()
	var sprite := _alloc_sprite()
	sprite.sprite_frames = _frames_for_kind(kind)
	sprite.play("default")
	sprite.speed_scale = _anim_speed_for_kind(kind)
	sprite.global_position = p0
	var init_dir := (p1 - p0).normalized() if p0.distance_to(p1) > 0.5 else Vector2.RIGHT
	sprite.rotation = init_dir.angle()
	sprite.visible = true
	sprite.modulate = _modulate_for_kind(kind)
	_apply_rim_material(sprite, kind)
	sprite.scale = _projectile_scale_vec(kind, weapon_lv, evolved)
	_projectiles.append({
		"kind": kind,
		"path": "bezier_cubic",
		"p0": p0,
		"p1": p1,
		"p2": p2,
		"p3": p3,
		"time": maxf(0.05, lifetime),
		"max_time": maxf(0.05, lifetime),
		"sprite": sprite,
		"phase": randf() * TAU,
		"lv": weapon_lv,
		"evolved": evolved
	})


func spawn_bezier_volley(kind: String, p0: Vector2, p1: Vector2, p2: Vector2, lifetime: float, count: int = 3, weapon_lv: int = 1, evolved: bool = false) -> void:
	var slots := clampi(count, 1, 6)
	for i in range(slots):
		if _projectiles.size() >= _max_projectiles_for_profile():
			_recycle_oldest_projectile()
		var sprite := _alloc_sprite()
		sprite.sprite_frames = _frames_for_kind(kind)
		sprite.play("default")
		sprite.speed_scale = _anim_speed_for_kind(kind)
		sprite.global_position = p0
		var init_dir := (p1 - p0).normalized() if p0.distance_to(p1) > 0.5 else Vector2.RIGHT
		sprite.rotation = init_dir.angle()
		sprite.visible = true
		sprite.modulate = _modulate_for_kind(kind)
		_apply_rim_material(sprite, kind)
		var head_scale := 1.0 + (1.0 - float(i) / float(maxi(1, slots - 1))) * 0.24
		sprite.scale = _projectile_scale_vec(kind, weapon_lv, evolved, head_scale)
		var start_t := float(i) / float(slots) * 0.3
		_projectiles.append({
			"kind": kind,
			"path": "bezier",
			"p0": p0,
			"p1": p1,
			"p2": p2,
			"time": maxf(0.05, lifetime),
			"max_time": maxf(0.05, lifetime),
			"sprite": sprite,
			"phase": randf() * TAU + float(i) * 0.55,
			"lv": weapon_lv,
			"evolved": evolved,
			"start_t": start_t,
			"spawn_delay": float(i) * 0.014
		})


func spawn_bezier_cubic_volley(kind: String, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, lifetime: float, count: int = 3, weapon_lv: int = 1, evolved: bool = false) -> void:
	var slots := clampi(count, 1, 6)
	for i in range(slots):
		if _projectiles.size() >= _max_projectiles_for_profile():
			_recycle_oldest_projectile()
		var sprite := _alloc_sprite()
		sprite.sprite_frames = _frames_for_kind(kind)
		sprite.play("default")
		sprite.speed_scale = _anim_speed_for_kind(kind)
		sprite.global_position = p0
		var init_dir := (p1 - p0).normalized() if p0.distance_to(p1) > 0.5 else Vector2.RIGHT
		sprite.rotation = init_dir.angle()
		sprite.visible = true
		sprite.modulate = _modulate_for_kind(kind)
		_apply_rim_material(sprite, kind)
		var head_scale := 1.0 + (1.0 - float(i) / float(maxi(1, slots - 1))) * 0.24
		sprite.scale = _projectile_scale_vec(kind, weapon_lv, evolved, head_scale)
		var start_t := float(i) / float(slots) * 0.3
		_projectiles.append({
			"kind": kind,
			"path": "bezier_cubic",
			"p0": p0,
			"p1": p1,
			"p2": p2,
			"p3": p3,
			"time": maxf(0.05, lifetime),
			"max_time": maxf(0.05, lifetime),
			"sprite": sprite,
			"phase": randf() * TAU + float(i) * 0.55,
			"lv": weapon_lv,
			"evolved": evolved,
			"start_t": start_t,
			"spawn_delay": float(i) * 0.014
		})


func spawn_line_salvo(kind: String, from_pos: Vector2, to_pos: Vector2, lifetime: float, segments: int = 5, weapon_lv: int = 1, evolved: bool = false) -> void:
	var delta_v := to_pos - from_pos
	var dist := delta_v.length()
	if dist < 3.0:
		return
	var dir := delta_v / dist
	var slots := clampi(segments, 3, 8)
	for i in range(slots):
		if _projectiles.size() >= _max_projectiles_for_profile():
			_recycle_oldest_projectile()
		var t_slot := float(i) / float(maxi(1, slots - 1))
		var seg_life := lifetime * (1.0 - t_slot * 0.16)
		var speed := dist / maxf(0.07, seg_life * 0.88)
		var start := from_pos.lerp(to_pos, t_slot * 0.07)
		var sprite := _alloc_sprite()
		sprite.sprite_frames = _frames_for_kind(kind)
		sprite.play("default")
		sprite.speed_scale = _anim_speed_for_kind(kind)
		sprite.global_position = start
		sprite.rotation = dir.angle()
		sprite.visible = true
		sprite.modulate = _modulate_for_kind(kind)
		_apply_rim_material(sprite, kind)
		var head_scale := 1.08 if i == slots - 1 else 0.94
		sprite.scale = _projectile_scale_vec(kind, weapon_lv, evolved, head_scale)
		_projectiles.append({
			"kind": kind,
			"pos": start,
			"dir": dir,
			"speed": speed,
			"time": maxf(0.05, seg_life),
			"max_time": maxf(0.05, seg_life),
			"sprite": sprite,
			"phase": randf() * TAU + float(i) * 0.8,
			"lv": weapon_lv,
			"evolved": evolved,
			"spawn_delay": float(i) * 0.018
		})


func _bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2


func _bezier_tangent(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return 2.0 * u * (p1 - p0) + 2.0 * t * (p2 - p1)


func _cubic_bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3


func _cubic_bezier_tangent(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return 3.0 * u * u * (p1 - p0) + 6.0 * u * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)

func _max_projectiles_for_profile() -> int:
	var overload := _runtime_overload_mul
	if Settings and Settings.reduce_particles:
		return int(round(80.0 * overload))
	if not Settings:
		return int(round(120.0 * overload))
	var vfx_profile := 1
	if Settings.has_method("get"):
		vfx_profile = int(Settings.get("vfx_profile"))
	match vfx_profile:
		0:
			return int(round(84.0 * overload))
		2:
			return int(round(192.0 * overload))
		_:
			return int(round(144.0 * overload))

func _recycle_oldest_projectile() -> void:
	if _projectiles.is_empty():
		return
	var oldest: Dictionary = _projectiles.pop_front()
	var s := oldest.get("sprite") as AnimatedSprite2D
	if s:
		_free_sprite(s)

func _process(delta: float) -> void:
	_guardian_phase += delta * 5.6
	_mount_glow_phase += delta * 4.2
	for i in range(_projectiles.size() - 1, -1, -1):
		var p := _projectiles[i]
		var spawn_delay := float(p.get("spawn_delay", 0.0))
		if spawn_delay > 0.0:
			p["spawn_delay"] = spawn_delay - delta
			_projectiles[i] = p
			continue
		var left := float(p.get("time", 0.0)) - delta
		if left <= 0.0:
			var s := p.get("sprite") as AnimatedSprite2D
			if s:
				_free_sprite(s)
			_projectiles.remove_at(i)
			continue
		p["time"] = left
		var kind := String(p.get("kind", _KIND_KUNAI))
		var pos: Vector2 = p.get("pos", Vector2.ZERO)
		var dir: Vector2 = p.get("dir", Vector2.RIGHT)
		var speed := float(p.get("speed", 600.0))
		var phase := float(p.get("phase", 0.0)) + delta * 8.0
		p["phase"] = phase
		var life := 1.0 - left / maxf(0.01, float(p.get("max_time", 0.01)))
		if String(p.get("path", "")) == "bezier_cubic":
			var st_c := float(p.get("start_t", 0.0))
			var t_c := st_c + (1.0 - st_c) * clampf(life, 0.0, 1.0)
			var p0c: Vector2 = p.get("p0", Vector2.ZERO)
			var p1c: Vector2 = p.get("p1", Vector2.ZERO)
			var p2c: Vector2 = p.get("p2", Vector2.ZERO)
			var p3c: Vector2 = p.get("p3", Vector2.ZERO)
			pos = _cubic_bezier_point(p0c, p1c, p2c, p3c, t_c)
			var tangent_c := _cubic_bezier_tangent(p0c, p1c, p2c, p3c, t_c)
			if tangent_c.length_squared() > 0.0004:
				dir = tangent_c.normalized()
			var side_c := dir.orthogonal()
			match kind:
				_KIND_KUNAI:
					pos += side_c * sin(phase * 1.2) * (0.6 + float(p.get("lv", 1)) * 0.06)
				_KIND_BOOMERANG:
					pos += side_c * sin(phase * 1.35 + t_c * PI) * 1.2
				_:
					pos += side_c * sin(phase) * 0.28
		elif String(p.get("path", "")) == "bezier":
			var st_b := float(p.get("start_t", 0.0))
			var t := st_b + (1.0 - st_b) * clampf(life, 0.0, 1.0)
			var p0: Vector2 = p.get("p0", Vector2.ZERO)
			var p1: Vector2 = p.get("p1", Vector2.ZERO)
			var p2: Vector2 = p.get("p2", Vector2.ZERO)
			pos = _bezier_point(p0, p1, p2, t)
			var tangent := _bezier_tangent(p0, p1, p2, t)
			if tangent.length_squared() > 0.0004:
				dir = tangent.normalized()
			var side_b := dir.orthogonal()
			match kind:
				_KIND_KUNAI:
					pos += side_b * sin(phase * 1.35) * (0.8 + float(p.get("lv", 1)) * 0.08) * (1.0 - absf(t - 0.5) * 1.6)
				_KIND_ROCKET:
					pos += side_b * sin(phase * 0.75) * 0.45 * t
				_KIND_MOLOTOV:
					pos += Vector2(0.0, sin(phase * 0.9) * 0.6) + side_b * sin(phase * 1.1) * 0.35
				_KIND_BOOMERANG:
					pos += side_b * sin(phase * 1.5 + t * PI) * 1.4
				_:
					pos += side_b * sin(phase * 1.1) * 0.35
		else:
			var step := dir * speed * delta
			match kind:
				_KIND_KUNAI:
					var side := dir.orthogonal()
					# 苦无：更偏“高速直冲”，保留轻微抖动强化金属感。
					pos += step * 1.08 + side * sin(phase * 1.2) * (1.2 + float(p.get("lv", 1)) * 0.12) * delta * 12.0
				_KIND_QUANTUM:
					# 量子弹：螺旋推进，强调“能量体”感。
					var side_q := dir.orthogonal()
					var lv_q := float(p.get("lv", 1))
					var pulse_q := 0.88 + sin(phase * 0.7) * 0.16
					pos += step * pulse_q + side_q * sin(phase * 1.65) * (1.6 + lv_q * 0.22)
				_KIND_LIGHTNING:
					var side_l := dir.orthogonal()
					# 闪电弹：加强锯齿跳跃感，贴近“链电抽打”观感。
					var zig_a: float = sign(sin(phase * 5.6))
					var zig_b: float = sin(phase * 2.8) * 0.9
					pos += step * 1.22 + side_l * (zig_a * 2.4 + zig_b * 1.6)
				_KIND_ROCKET:
					# 火箭：持续加速 + 轻微尾焰摆动，避免“木直线”。
					var acc := 1.0 + life * 0.36
					var side_r := dir.orthogonal()
					pos += step * acc + side_r * sin(phase * 0.9) * 0.55
				_KIND_MOLOTOV:
					# 燃烧瓶：前段上扬后段下坠，形成可读抛物线。
					var side_m := dir.orthogonal()
					var lift := (1.0 - life) * 4.0 - life * 9.0
					pos += step * 0.88 + side_m * sin(phase * 0.9) * 0.8 + Vector2(0.0, lift)
				_KIND_BOOMERANG:
					var side_b := dir.orthogonal()
					pos += step * (0.86 + sin(life * PI) * 0.26) + side_b * sin(phase * 1.4) * 2.2
				_KIND_DRONE:
					var side_d := dir.orthogonal()
					pos += step * 0.82 + side_d * sin(phase * 1.8) * 1.2
				_KIND_ACTIVE_BOLT:
					pos += step
				_:
					pos += step
		p["pos"] = pos
		var sprite := p.get("sprite") as AnimatedSprite2D
		if sprite:
			sprite.global_position = pos
			sprite.rotation = dir.angle() + _rotation_offset_for_kind(kind, phase)
			var alpha_mul := _alpha_mul_for_kind(kind, life, phase)
			sprite.modulate.a = clampf((1.0 - life * 0.48) * alpha_mul, 0.58, 1.0)
			if _is_animated_kind(kind):
				sprite.speed_scale = _anim_speed_for_kind(kind) * (0.92 + sin(phase) * 0.12)
		_projectiles[i] = p
	_update_aura_breathing()
	_update_weapon_unlock_fx(delta)
	if not _weapon_mount_sprites.is_empty():
		queue_redraw()

func play_weapon_unlock_fx(kind: String, center: Vector2) -> void:
	# 新武器获取时的环身入场演出：先看到“武器本体”再进入常态挂载。
	for i in range(3):
		var s := _alloc_sprite()
		s.sprite_frames = _frames_for_kind(kind)
		s.play("default")
		s.visible = true
		s.global_position = center
		s.rotation = TAU * float(i) / 3.0
		s.scale = Vector2.ONE * 0.34
		s.modulate = _modulate_for_kind(kind)
		s.modulate.a = 0.0
		_weapon_unlock_fx.append({
			"sprite": s,
			"center": center,
			"time": 0.52,
			"max_time": 0.52,
			"angle": TAU * float(i) / 3.0,
			"radius": 30.0 + float(i) * 5.0
		})

func _update_weapon_unlock_fx(delta: float) -> void:
	for i in range(_weapon_unlock_fx.size() - 1, -1, -1):
		var fx: Dictionary = _weapon_unlock_fx[i]
		var left: float = float(fx.get("time", 0.0)) - delta
		var max_t: float = maxf(0.01, float(fx.get("max_time", 0.01)))
		var life: float = clampf(1.0 - left / max_t, 0.0, 1.0)
		var center: Vector2 = fx.get("center", Vector2.ZERO) as Vector2
		var ang: float = float(fx.get("angle", 0.0)) + life * 3.8
		var rad: float = float(fx.get("radius", 30.0)) * (0.35 + life * 0.95)
		var s: AnimatedSprite2D = fx.get("sprite") as AnimatedSprite2D
		if s:
			s.global_position = center + Vector2(cos(ang), sin(ang)) * rad
			s.rotation = ang + PI * 0.5
			s.scale = Vector2.ONE * (0.34 + life * 0.48)
			var fade_in := clampf(life / 0.24, 0.0, 1.0)
			var fade_out := clampf((1.0 - life) / 0.76, 0.0, 1.0)
			s.modulate.a = minf(fade_in, fade_out)
		if left <= 0.0:
			if s:
				_free_sprite(s)
			_weapon_unlock_fx.remove_at(i)
		else:
			fx["time"] = left
			_weapon_unlock_fx[i] = fx

func _base_scale_for_kind(kind: String) -> float:
	return WeaponVisualRegistry.projectile_scale(kind)


func _tex_size_mul_for_kind(kind: String) -> float:
	return float(_kind_tex_mul.get(kind, 1.0))


func _uses_external_tex(kind: String) -> bool:
	return _tex_size_mul_for_kind(kind) < 0.99


func _visual_mul_for_kind(kind: String) -> float:
	if _uses_external_tex(kind):
		return _tex_size_mul_for_kind(kind)
	return _PROJECTILE_VISUAL_MUL


func _projectile_scale_vec(kind: String, weapon_lv: int = 1, evolved: bool = false, head_scale: float = 1.0) -> Vector2:
	var mul := _base_scale_for_kind(kind)
	mul *= 1.0 + clampf(float(weapon_lv - 1) * 0.03, 0.0, 0.28)
	if evolved:
		mul *= 1.06
	mul *= _visual_mul_for_kind(kind)
	mul *= head_scale
	return Vector2.ONE * mul

func _modulate_for_kind(kind: String) -> Color:
	var key := kind
	if kind == _KIND_ACTIVE_BOLT:
		key = _KIND_LIGHTNING
	var th := WeaponVisualRegistry.theme(key)
	var pri: Color = th.get("primary", Color.WHITE)
	var acc: Color = th.get("accent", pri)
	return Color(
		lerpf(pri.r, acc.r, 0.22),
		lerpf(pri.g, acc.g, 0.22),
		lerpf(pri.b, acc.b, 0.22),
		1.0
	)

func _rotation_offset_for_kind(kind: String, phase: float) -> float:
	match kind:
		_KIND_KUNAI:
			return phase * 0.55 + sin(phase * 1.4) * 0.08
		_KIND_LIGHTNING:
			return sin(phase * 3.8) * 0.24
		_KIND_QUANTUM:
			return phase * 0.42
		_KIND_ROCKET:
			return sin(phase * 0.8) * 0.03
		_:
			return 0.0

func _alpha_mul_for_kind(kind: String, life: float, phase: float) -> float:
	match kind:
		_KIND_LIGHTNING:
			return 1.04 + sin(phase * 3.4) * 0.24
		_KIND_ROCKET:
			return 0.98 + (1.0 - life) * 0.16
		_KIND_QUANTUM:
			return 0.94 + sin(phase * 1.8) * 0.14
		_:
			return 1.0

func sync_guardian_blades(center: Vector2, radius: float, count: int, evolved: bool) -> void:
	var need := maxi(0, count)
	while _guardian_blades.size() < need:
		var s := _alloc_sprite()
		s.sprite_frames = _frames_for_kind(_KIND_GUARDIAN)
		s.play("default")
		s.visible = true
		_guardian_blades.append(s)
	while _guardian_blades.size() > need:
		var rem: AnimatedSprite2D = _guardian_blades.pop_back()
		_free_sprite(rem)
	for i in range(_guardian_blades.size()):
		var ang := _guardian_phase + TAU * float(i) / float(maxi(1, _guardian_blades.size()))
		var pos := center + Vector2(cos(ang), sin(ang)) * radius
		var blade := _guardian_blades[i]
		blade.global_position = pos
		blade.rotation = ang + PI * 0.5
		blade.visible = true
		blade.scale = Vector2.ONE * (1.0 if not evolved else 1.08) * _visual_mul_for_kind(_KIND_GUARDIAN)
		blade.modulate = _modulate_for_kind(_KIND_GUARDIAN)

func sync_aura(kind: String, center: Vector2, radius: float, visible: bool, evolved: bool) -> void:
	if not _aura_sprites.has(kind):
		var s := _alloc_sprite()
		s.sprite_frames = _frames_for_kind(kind)
		s.play("default")
		_aura_sprites[kind] = s
	var aura := _aura_sprites[kind] as AnimatedSprite2D
	if aura == null:
		return
	aura.visible = visible
	if not visible:
		return
	aura.global_position = center
	aura.rotation = 0.0
	var base_scale := clampf(radius / 36.0, 0.8, 6.2)
	if evolved:
		base_scale *= 1.08
	aura.scale = Vector2.ONE * base_scale * _visual_mul_for_kind(kind) * 0.72
	match kind:
		_KIND_FROST:
			aura.modulate = _modulate_for_kind(_KIND_FROST)
			aura.modulate.a = 0.52
		_KIND_HEAL:
			aura.modulate = _modulate_for_kind(_KIND_HEAL)
			aura.modulate.a = 0.48
		_:
			aura.modulate = Color(1.0, 1.0, 1.0, 0.5)

func sync_mines(positions: Array[Vector2], evolved: bool) -> void:
	while _mine_sprites.size() < positions.size():
		var s := _alloc_sprite()
		s.sprite_frames = _frames_for_kind(_KIND_MINE)
		s.play("default")
		_mine_sprites.append(s)
	while _mine_sprites.size() > positions.size():
		var rem: AnimatedSprite2D = _mine_sprites.pop_back()
		_free_sprite(rem)
	for i in range(positions.size()):
		var m := _mine_sprites[i]
		m.visible = true
		m.global_position = positions[i]
		m.rotation = 0.0
		m.scale = Vector2.ONE * (1.0 if not evolved else 1.14) * _visual_mul_for_kind(_KIND_MINE)
		m.modulate = _modulate_for_kind(_KIND_MINE)

func clear_runtime_entities() -> void:
	sync_guardian_blades(Vector2.ZERO, 0.0, 0, false)
	for fx in _weapon_unlock_fx:
		var sx := fx.get("sprite") as AnimatedSprite2D
		if sx:
			_free_sprite(sx)
	_weapon_unlock_fx.clear()
	for k in _weapon_mount_sprites.keys():
		var ws := _weapon_mount_sprites[k] as AnimatedSprite2D
		if ws:
			_free_sprite(ws)
	_weapon_mount_sprites.clear()
	for k in _aura_sprites.keys():
		var s := _aura_sprites[k] as AnimatedSprite2D
		if s:
			_free_sprite(s)
	_aura_sprites.clear()
	sync_mines([], false)

func _alloc_sprite() -> AnimatedSprite2D:
	if not _pool.is_empty():
		var s: AnimatedSprite2D = _pool.pop_back()
		s.z_index = _SPRITE_Z_INDEX
		_active_sprites.append(s)
		return s
	var sprite := AnimatedSprite2D.new()
	sprite.centered = true
	sprite.animation = "default"
	sprite.z_index = _SPRITE_Z_INDEX
	add_child(sprite)
	_active_sprites.append(sprite)
	return sprite

func _free_sprite(sprite: AnimatedSprite2D) -> void:
	sprite.stop()
	sprite.visible = false
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	sprite.material = null
	sprite.scale = Vector2.ONE
	sprite.speed_scale = 1.0
	var idx := _active_sprites.find(sprite)
	if idx >= 0:
		_active_sprites.remove_at(idx)
	_pool.append(sprite)

func _is_animated_kind(kind: String) -> bool:
	return kind == _KIND_KUNAI \
		or kind == _KIND_LIGHTNING \
		or kind == _KIND_ROCKET \
		or kind == _KIND_DRONE \
		or kind == _KIND_BOOMERANG \
		or kind == _KIND_MOLOTOV \
		or kind == _KIND_QUANTUM \
		or kind == _KIND_GUARDIAN \
		or kind == _KIND_FROST \
		or kind == _KIND_HEAL \
		or kind == _KIND_MINE

func _anim_speed_for_kind(kind: String) -> float:
	match kind:
		_KIND_KUNAI:
			return 14.0
		_KIND_LIGHTNING:
			return 18.0
		_KIND_ROCKET:
			return 11.0
		_KIND_DRONE:
			return 9.0
		_KIND_BOOMERANG:
			return 10.0
		_KIND_MOLOTOV:
			return 8.0
		_KIND_QUANTUM:
			return 12.0
		_KIND_GUARDIAN:
			return 8.0
		_KIND_FROST:
			return 6.0
		_KIND_HEAL:
			return 6.0
		_KIND_MINE:
			return 7.0
		_:
			return 8.0

func _new_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if not frames.has_animation("default"):
		frames.add_animation("default")
	return frames

func _register_frames(kind: String, frames: SpriteFrames) -> SpriteFrames:
	var tex := frames.get_frame_texture("default", 0) as Texture2D
	if tex != null:
		var sz := float(maxi(tex.get_width(), tex.get_height()))
		_kind_tex_mul[kind] = _EXTERNAL_TARGET_PX / sz if sz >= 128.0 else 1.0
	else:
		_kind_tex_mul[kind] = 1.0
	_frames_cache[kind] = frames
	return frames


func _frames_for_kind(kind: String) -> SpriteFrames:
	if _frames_cache.has(kind):
		return _frames_cache[kind]
	# 优先 AI / 外置 HD 弹体；缺失或占位图过小时回退程序绘制。
	var external := _load_external_frames(kind)
	if external != null:
		return _register_frames(kind, external)
	var frames := _new_sprite_frames()
	if _is_animated_kind(kind):
		for i in range(4):
			frames.add_frame("default", _texture_for_kind_frame(kind, i))
	else:
		frames.add_frame("default", _texture_for_kind(kind))
	frames.set_animation_loop("default", true)
	return _register_frames(kind, frames)

func _projectiles_dir() -> String:
	return GameDB.ASSET_PACK_PROJECTILES


func _load_external_frames(kind: String) -> SpriteFrames:
	if kind == _KIND_ACTIVE_BOLT:
		var ab := _load_projectile_frames_from_kind(_KIND_ACTIVE_BOLT)
		if ab != null:
			return ab
		return _load_projectile_frames_from_kind(_KIND_LIGHTNING)
	return _load_projectile_frames_from_kind(kind)


func _is_hd_projectile_texture(tex: Texture2D) -> bool:
	return tex != null and tex.get_width() >= 96 and tex.get_height() >= 96


func _load_projectile_frames_from_kind(kind: String) -> SpriteFrames:
	var base := "%s%s" % [_projectiles_dir(), kind]
	var p0 := "%s/frame_0.png" % base
	var pdef := "%s/default.png" % base
	if not ResourceLoader.exists(p0) and ResourceLoader.exists(pdef):
		var td := load(pdef) as Texture2D
		if _is_hd_projectile_texture(td):
			var sf1 := _new_sprite_frames()
			sf1.add_frame("default", td)
			sf1.set_animation_loop("default", true)
			return sf1
	var sf := _new_sprite_frames()
	var loaded := 0
	for i in range(16):
		var p := "%s/frame_%d.png" % [base, i]
		if not ResourceLoader.exists(p):
			break
		var tex := load(p) as Texture2D
		if tex == null or not _is_hd_projectile_texture(tex):
			break
		sf.add_frame("default", tex)
		loaded += 1
	if loaded == 0:
		if ResourceLoader.exists(pdef):
			var t := load(pdef) as Texture2D
			if _is_hd_projectile_texture(t):
				sf.add_frame("default", t)
				loaded = 1
	if loaded == 0:
		return null
	sf.set_animation_loop("default", true)
	return sf

func _texture_for_kind_frame(kind: String, frame: int) -> Texture2D:
	match kind:
		_KIND_KUNAI:
			return _make_kunai_tex_frame(frame)
		_KIND_LIGHTNING:
			return _make_lightning_tex_frame(frame)
		_KIND_ROCKET:
			return _make_rocket_tex_frame(frame)
		_KIND_DRONE:
			return _make_drone_tex_frame(frame)
		_KIND_BOOMERANG:
			return _make_boomerang_tex_frame(frame)
		_KIND_MOLOTOV:
			return _make_molotov_tex_frame(frame)
		_KIND_QUANTUM:
			return _make_quantum_tex_frame(frame)
		_KIND_GUARDIAN:
			return _make_guardian_tex_frame(frame)
		_KIND_FROST:
			return _make_frost_aura_tex_frame(frame)
		_KIND_HEAL:
			return _make_heal_aura_tex_frame(frame)
		_KIND_MINE:
			return _make_mine_tex_frame(frame)
		_:
			return _texture_for_kind(kind)

func _texture_for_kind(kind: String) -> Texture2D:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var tex: Texture2D
	match kind:
		_KIND_KUNAI:
			tex = _make_kunai_tex()
		_KIND_LIGHTNING:
			tex = _make_lightning_tex()
		_KIND_ACTIVE_BOLT:
			tex = _make_lightning_tex()
		_KIND_ROCKET:
			tex = _make_rocket_tex()
		_KIND_DRONE:
			tex = _make_drone_tex()
		_KIND_BOOMERANG:
			tex = _make_boomerang_tex()
		_KIND_MOLOTOV:
			tex = _make_molotov_tex()
		_:
			tex = _make_quantum_tex()
	_tex_cache[kind] = tex
	return tex

func _make_img(size: int = 32) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	return img

func _theme_colors(kind: String) -> Dictionary:
	var key := kind
	if key == _KIND_ACTIVE_BOLT:
		key = _KIND_LIGHTNING
	var th := WeaponVisualRegistry.theme(key)
	var sec: Color = th.get("secondary", Color(0.25, 0.25, 0.35))
	return {
		"deep": sec.darkened(0.18),
		"base": th.get("primary", Color.WHITE),
		"glow": th.get("accent", Color.WHITE),
		"trail": th.get("trail", Color.WHITE),
	}

func _poly_regular(cx: float, cy: float, r: float, sides: int, rot: float = -PI * 0.5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var ang := rot + TAU * float(i) / float(sides)
		pts.append(Vector2(cx + cos(ang) * r, cy + sin(ang) * r))
	return pts

func _ensure_rim_shader() -> Shader:
	if _rim_shader == null:
		_rim_shader = load("res://assets/shaders/weapon_rim.gdshader") as Shader
	return _rim_shader

func _should_use_rim() -> bool:
	if Settings and Settings.reduce_particles:
		return false
	if Settings == null:
		return true
	var vfx := 1
	if Settings.has_method("get"):
		vfx = int(Settings.get("vfx_profile"))
	return vfx >= 1

func _apply_rim_material(sprite: AnimatedSprite2D, kind: String, strength: float = 0.48) -> void:
	if not _should_use_rim():
		sprite.material = null
		return
	var sh := _ensure_rim_shader()
	if sh == null:
		return
	var mat := sprite.material as ShaderMaterial
	if mat == null or mat.shader != sh:
		mat = ShaderMaterial.new()
		mat.shader = sh
		sprite.material = mat
	var acc := WeaponVisualRegistry.accent(kind if kind != _KIND_ACTIVE_BOLT else _KIND_LIGHTNING)
	mat.set_shader_parameter("rim_color", acc)
	mat.set_shader_parameter("rim_power", 2.35)
	mat.set_shader_parameter("pulse_speed", 2.2 + randf() * 1.1)
	mat.set_shader_parameter("rim_strength", strength)

func _make_kunai_tex() -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_KUNAI, 0)

func _make_kunai_tex_frame(frame: int) -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_KUNAI, frame)

func _make_lightning_tex() -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_LIGHTNING, 0)

func _make_lightning_tex_frame(frame: int) -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_LIGHTNING, frame)

func _make_rocket_tex() -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_ROCKET, 0)

func _make_rocket_tex_frame(frame: int) -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_ROCKET, frame)

func _make_drone_tex() -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_DRONE, 0)

func _make_drone_tex_frame(frame: int) -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_DRONE, frame)

func _make_boomerang_tex() -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_BOOMERANG, 0)

func _make_boomerang_tex_frame(frame: int) -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_BOOMERANG, frame)

func _make_molotov_tex() -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_MOLOTOV, 0)

func _make_molotov_tex_frame(frame: int) -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_MOLOTOV, frame)

func _make_quantum_tex() -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_QUANTUM, 0)

func _make_quantum_tex_frame(frame: int) -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_QUANTUM, frame)

func _make_guardian_tex_frame(frame: int) -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_GUARDIAN, frame)

func _make_frost_aura_tex_frame(frame: int) -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_FROST, frame)

func _make_heal_aura_tex_frame(frame: int) -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_HEAL, frame)

func _make_mine_tex_frame(frame: int) -> Texture2D:
	return WeaponProjectileArt.texture_for_kind(_KIND_MINE, frame)

func _draw_ring(img: Image, c: Vector2i, r: int, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(0, c.y - r - 1), mini(h, c.y + r + 2)):
		for x in range(maxi(0, c.x - r - 1), mini(w, c.x + r + 2)):
			var d := absf(Vector2(float(x - c.x), float(y - c.y)).length() - float(r))
			if d <= 0.75:
				img.set_pixel(x, y, col)

func _update_aura_breathing() -> void:
	for k in _aura_sprites.keys():
		var s := _aura_sprites[k] as AnimatedSprite2D
		if s == null or not s.visible:
			continue
		var base_a := 0.45
		if k == _KIND_FROST:
			base_a = 0.42
		elif k == _KIND_HEAL:
			base_a = 0.46
		s.modulate.a = clampf(base_a + sin(Time.get_ticks_msec() * 0.006) * 0.08, 0.24, 0.72)

func clear_weapon_mounts() -> void:
	for k in _weapon_mount_sprites.keys():
		var old := _weapon_mount_sprites[k] as AnimatedSprite2D
		if old:
			_free_sprite(old)
	_weapon_mount_sprites.clear()


func sync_weapon_mounts(center: Vector2, active_weapons: Array[String], aim_dir: Vector2) -> void:
	# 隐藏已经失活的挂件
	for k in _weapon_mount_sprites.keys():
		if not active_weapons.has(String(k)):
			var old := _weapon_mount_sprites[k] as AnimatedSprite2D
			if old:
				_free_sprite(old)
			_weapon_mount_sprites.erase(k)
	var count := active_weapons.size()
	if count <= 0:
		return
	var base_angle := aim_dir.angle()
	var radius := 40.0 + minf(float(count), 7.0) * 2.5
	for i in range(count):
		var kind := active_weapons[i]
		if not _weapon_mount_sprites.has(kind):
			var s := _alloc_sprite()
			s.sprite_frames = _frames_for_kind(kind)
			s.play("default")
			s.visible = true
			_apply_rim_material(s, kind, 0.38)
			_weapon_mount_sprites[kind] = s
		var mount := _weapon_mount_sprites[kind] as AnimatedSprite2D
		if mount == null:
			continue
		var spread := TAU / float(maxi(1, count))
		var ang := base_angle + spread * float(i) + sin(_guardian_phase * 0.6 + float(i)) * 0.04
		var k_rad := radius
		var ang_bias := 0.0
		var rot_bias := PI * 0.5
		var k_scale := WeaponVisualRegistry.mount_scale(kind)
		var alpha := 0.9
		match kind:
			_KIND_KUNAI:
				k_rad = radius * 0.92
				ang_bias = -0.18
				rot_bias = PI * 0.35
				k_scale = 0.82
			_KIND_ROCKET:
				k_rad = radius * 1.12
				ang_bias = 0.1
				rot_bias = PI * 0.5
				k_scale = 0.96
			_KIND_LIGHTNING:
				k_rad = radius * 0.98
				ang_bias = 0.22
				rot_bias = PI * 0.5
				k_scale = 0.9
				alpha = 0.96
			_KIND_QUANTUM:
				k_rad = radius * 1.06
				ang_bias = -0.05
				rot_bias = PI * 0.5
				k_scale = 0.94
				alpha = 0.96
			_KIND_MOLOTOV:
				k_rad = radius * 1.0
				ang_bias = 0.14
				k_scale = 0.88
			_KIND_GUARDIAN:
				k_rad = radius * 1.04
				k_scale = 0.92
			_KIND_BOOMERANG:
				k_rad = radius * 1.02
				k_scale = 0.9
			_KIND_DRONE:
				k_rad = radius * 0.96
				k_scale = 0.86
			_KIND_MINE:
				k_rad = radius * 0.9
				k_scale = 0.8
			_:
				pass
		ang += ang_bias
		var pos := center + Vector2(cos(ang), sin(ang)) * k_rad
		mount.global_position = pos
		mount.rotation = ang + rot_bias
		mount.scale = Vector2.ONE * k_scale * _visual_mul_for_kind(kind)
		mount.modulate = _modulate_for_kind(kind)
		mount.modulate.a = alpha

func _draw() -> void:
	for k in _weapon_mount_sprites.keys():
		var mount := _weapon_mount_sprites[k] as AnimatedSprite2D
		if mount == null or not mount.visible:
			continue
		var local_p := to_local(mount.global_position)
		var kind := String(k)
		var th := WeaponVisualRegistry.theme(kind)
		var pri: Color = th.get("primary", Color.WHITE)
		var sec: Color = th.get("secondary", pri.darkened(0.35))
		var acc: Color = th.get("accent", pri)
		var pulse := 0.86 + 0.14 * sin(_mount_glow_phase + float(_weapon_mount_sprites.keys().find(k)) * 0.7)
		var r := 18.0 * mount.scale.x
		draw_circle(local_p, r * 1.42, Color(sec.r, sec.g, sec.b, 0.12 * pulse))
		draw_circle(local_p, r * 1.02, Color(pri.r, pri.g, pri.b, 0.11 * pulse))
		match WeaponVisualRegistry.silhouette(kind):
			"hex":
				_draw_mount_hex(local_p, r * 0.92, acc, pulse)
			"bolt":
				_draw_mount_zig(local_p, r * 0.88, acc, pulse)
			"crescent":
				draw_arc(local_p, r * 0.95, -0.8, 0.8, 14, Color(acc.r, acc.g, acc.b, 0.28 * pulse), 2.2)
			"rocket":
				draw_line(local_p + Vector2(-r * 0.35, 0), local_p + Vector2(r * 0.55, 0), Color(acc.r, acc.g, acc.b, 0.32 * pulse), 2.0)
			"shield":
				draw_arc(local_p, r * 0.82, PI * 0.15, PI * 0.85, 16, Color(acc.r, acc.g, acc.b, 0.26 * pulse), 2.4)
			"ring", "cross":
				draw_arc(local_p, r * 0.78, 0.0, TAU, 24, Color(acc.r, acc.g, acc.b, 0.22 * pulse), 1.6)
			_:
				draw_arc(local_p, r * 1.08, _mount_glow_phase * 0.35, _mount_glow_phase * 0.35 + TAU * 0.38, 16, Color(acc.r, acc.g, acc.b, 0.2 * pulse), 1.5)


func _draw_mount_hex(center: Vector2, radius: float, col: Color, pulse: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var ang := TAU * float(i) / 6.0 - PI * 0.5
		pts.append(center + Vector2(cos(ang), sin(ang)) * radius)
	for i in range(pts.size()):
		var j := (i + 1) % pts.size()
		draw_line(pts[i], pts[j], Color(col.r, col.g, col.b, 0.34 * pulse), 1.8)


func _draw_mount_zig(center: Vector2, radius: float, col: Color, pulse: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(-radius * 0.35, -radius * 0.55),
		center + Vector2(radius * 0.15, -radius * 0.15),
		center + Vector2(-radius * 0.05, radius * 0.05),
		center + Vector2(radius * 0.35, radius * 0.62),
	])
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(col.r, col.g, col.b, 0.36 * pulse), 2.0)

func _fill_polygon(img: Image, points: PackedVector2Array, col: Color) -> void:
	if points.size() < 3:
		return
	var min_x := points[0].x
	var max_x := points[0].x
	var min_y := points[0].y
	var max_y := points[0].y
	for pt in points:
		min_x = minf(min_x, pt.x)
		max_x = maxf(max_x, pt.x)
		min_y = minf(min_y, pt.y)
		max_y = maxf(max_y, pt.y)
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(0, int(floor(min_y))), mini(h, int(ceil(max_y)) + 1)):
		for x in range(maxi(0, int(floor(min_x))), mini(w, int(ceil(max_x)) + 1)):
			if _point_in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), points):
				img.set_pixel(x, y, col)

func _point_in_polygon(p: Vector2, points: PackedVector2Array) -> bool:
	var inside := false
	var j := points.size() - 1
	for i in range(points.size()):
		var pi := points[i]
		var pj := points[j]
		var hit := ((pi.y > p.y) != (pj.y > p.y)) and (p.x < (pj.x - pi.x) * (p.y - pi.y) / maxf(0.0001, (pj.y - pi.y)) + pi.x)
		if hit:
			inside = not inside
		j = i
	return inside
