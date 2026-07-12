extends Node2D
class_name WeaponProjectileLayer

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
var _guardian_blades: Array[AnimatedSprite2D] = []
var _aura_sprites: Dictionary = {}
var _mine_sprites: Array[AnimatedSprite2D] = []
var _weapon_mount_sprites: Dictionary = {} # kind -> AnimatedSprite2D
var _weapon_unlock_fx: Array[Dictionary] = []
var _guardian_phase := 0.0
var _runtime_overload_mul := 1.0

func set_runtime_overload_mul(v: float) -> void:
	_runtime_overload_mul = clampf(v, 0.55, 1.0)

const _PROJECTILE_VISUAL_MUL := 1.0

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
	var scale_mul := _base_scale_for_kind(kind)
	scale_mul *= 1.0 + clampf(float(weapon_lv - 1) * 0.03, 0.0, 0.28)
	if evolved:
		scale_mul *= 1.06
	sprite.scale = Vector2.ONE * scale_mul * _PROJECTILE_VISUAL_MUL
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
			return int(round(156.0 * overload))
		_:
			return int(round(120.0 * overload))

func _recycle_oldest_projectile() -> void:
	if _projectiles.is_empty():
		return
	var oldest: Dictionary = _projectiles.pop_front()
	var s := oldest.get("sprite") as AnimatedSprite2D
	if s:
		_free_sprite(s)

func _process(delta: float) -> void:
	_guardian_phase += delta * 5.6
	for i in range(_projectiles.size() - 1, -1, -1):
		var p := _projectiles[i]
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
			sprite.modulate.a = clampf((1.0 - life * 0.62) * alpha_mul, 0.22, 1.0)
			if _is_animated_kind(kind):
				sprite.speed_scale = _anim_speed_for_kind(kind) * (0.92 + sin(phase) * 0.12)
		_projectiles[i] = p
	_update_aura_breathing()
	_update_weapon_unlock_fx(delta)

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
	match kind:
		_KIND_KUNAI:
			return 1.12
		_KIND_ROCKET:
			return 1.32
		_KIND_LIGHTNING:
			return 1.24
		_KIND_QUANTUM:
			return 1.20
		_KIND_GUARDIAN:
			return 1.28
		_KIND_DRONE:
			return 1.18
		_KIND_BOOMERANG:
			return 1.22
		_KIND_MOLOTOV:
			return 1.18
		_KIND_FROST, _KIND_HEAL:
			return 1.30
		_KIND_MINE:
			return 1.14
		_:
			return 1.16

func _modulate_for_kind(kind: String) -> Color:
	# Kenney 原图已分色：只做轻微提亮/偏色，避免 12 种染成同色
	match kind:
		_KIND_KUNAI:
			return Color(1.12, 1.18, 1.25, 1.0)
		_KIND_ROCKET:
			return Color(1.22, 1.08, 0.92, 1.0)
		_KIND_LIGHTNING, _KIND_ACTIVE_BOLT:
			return Color(0.95, 1.22, 1.28, 1.0)
		_KIND_QUANTUM:
			return Color(1.15, 0.95, 1.22, 1.0)
		_KIND_MOLOTOV:
			return Color(1.25, 1.05, 0.88, 1.0)
		_KIND_GUARDIAN:
			return Color(1.2, 1.12, 0.88, 1.0)
		_KIND_DRONE:
			return Color(0.92, 1.15, 1.25, 1.0)
		_KIND_BOOMERANG:
			return Color(1.22, 1.12, 0.82, 1.0)
		_KIND_FROST:
			return Color(0.88, 1.18, 1.28, 0.98)
		_KIND_HEAL:
			return Color(0.88, 1.25, 1.02, 0.98)
		_KIND_MINE:
			return Color(1.15, 0.95, 1.22, 1.0)
		_:
			return Color(1.12, 1.12, 1.12, 1.0)

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
		blade.scale = Vector2.ONE * (1.0 if not evolved else 1.08) * _PROJECTILE_VISUAL_MUL
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
	aura.scale = Vector2.ONE * base_scale * (_PROJECTILE_VISUAL_MUL * 0.72)
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
		m.scale = Vector2.ONE * (1.0 if not evolved else 1.14) * _PROJECTILE_VISUAL_MUL
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
		_active_sprites.append(s)
		return s
	var sprite := AnimatedSprite2D.new()
	sprite.centered = true
	sprite.animation = "default"
	add_child(sprite)
	_active_sprites.append(sprite)
	return sprite

func _free_sprite(sprite: AnimatedSprite2D) -> void:
	sprite.stop()
	sprite.visible = false
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
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

func _frames_for_kind(kind: String) -> SpriteFrames:
	if _frames_cache.has(kind):
		return _frames_cache[kind]
	var external := _load_external_frames(kind)
	if external != null:
		_frames_cache[kind] = external
		return external
	var frames := _new_sprite_frames()
	if _is_animated_kind(kind):
		for i in range(4):
			frames.add_frame("default", _texture_for_kind_frame(kind, i))
	else:
		frames.add_frame("default", _texture_for_kind(kind))
	frames.set_animation_loop("default", true)
	_frames_cache[kind] = frames
	return frames

func _projectiles_dir() -> String:
	return GameDB.ASSET_PACK_PROJECTILES


func _load_external_frames(kind: String) -> SpriteFrames:
	if kind == _KIND_ACTIVE_BOLT:
		var ab := _load_projectile_frames_from_kind(_KIND_ACTIVE_BOLT)
		if ab != null:
			return ab
		return _load_projectile_frames_from_kind(_KIND_LIGHTNING)
	return _load_projectile_frames_from_kind(kind)


func _load_projectile_frames_from_kind(kind: String) -> SpriteFrames:
	var base := "%s%s" % [_projectiles_dir(), kind]
	var p0 := "%s/frame_0.png" % base
	var pdef := "%s/default.png" % base
	if not ResourceLoader.exists(p0) and ResourceLoader.exists(pdef):
		var td := load(pdef) as Texture2D
		if td != null:
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
		if tex == null:
			break
		sf.add_frame("default", tex)
		loaded += 1
	if loaded == 0:
		if ResourceLoader.exists(pdef):
			var t := load(pdef) as Texture2D
			if t != null:
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

func _make_kunai_tex() -> Texture2D:
	var img := _make_img(30)
	var pts := PackedVector2Array([Vector2(26, 15), Vector2(14, 8), Vector2(6, 15), Vector2(14, 22)])
	_fill_polygon(img, pts, Color(0.72, 0.92, 1.0, 1.0))
	img.fill_rect(Rect2i(7, 14, 8, 2), Color(0.9, 1.0, 1.0, 0.9))
	return ImageTexture.create_from_image(img)

func _make_kunai_tex_frame(frame: int) -> Texture2D:
	var img := _make_img(30)
	var shift := float(frame % 4) * 0.45
	var pts := PackedVector2Array([Vector2(26, 15), Vector2(14, 8 - shift), Vector2(6, 15), Vector2(14, 22 + shift)])
	_fill_polygon(img, pts, Color(0.72, 0.92, 1.0, 1.0))
	img.fill_rect(Rect2i(7, 14, 8, 2), Color(0.92, 1.0, 1.0, 0.9))
	return ImageTexture.create_from_image(img)

func _make_lightning_tex() -> Texture2D:
	var img := _make_img(30)
	var pts := PackedVector2Array([Vector2(8, 5), Vector2(17, 5), Vector2(13, 13), Vector2(22, 13), Vector2(10, 25), Vector2(14, 16), Vector2(7, 16)])
	_fill_polygon(img, pts, Color(0.78, 0.92, 1.0, 1.0))
	return ImageTexture.create_from_image(img)

func _make_lightning_tex_frame(frame: int) -> Texture2D:
	var img := _make_img(30)
	var off := float(frame % 4) - 1.5
	var pts := PackedVector2Array([
		Vector2(8 + off * 0.5, 5), Vector2(17 + off * 0.3, 5), Vector2(13 - off * 0.5, 13),
		Vector2(22 + off * 0.2, 13), Vector2(10 - off * 0.4, 25), Vector2(14 + off * 0.4, 16), Vector2(7 - off * 0.3, 16)
	])
	_fill_polygon(img, pts, Color(0.78, 0.92, 1.0, 1.0))
	return ImageTexture.create_from_image(img)

func _make_rocket_tex() -> Texture2D:
	var img := _make_img(34)
	_fill_polygon(img, PackedVector2Array([Vector2(29, 17), Vector2(17, 10), Vector2(7, 17), Vector2(17, 24)]), Color(1.0, 0.55, 0.32, 1.0))
	img.fill_rect(Rect2i(4, 15, 5, 4), Color(1.0, 0.78, 0.45, 0.95))
	return ImageTexture.create_from_image(img)

func _make_rocket_tex_frame(frame: int) -> Texture2D:
	var img := _make_img(34)
	var flame := 4 + int(frame % 4)
	_fill_polygon(img, PackedVector2Array([Vector2(29, 17), Vector2(17, 10), Vector2(7, 17), Vector2(17, 24)]), Color(1.0, 0.55, 0.32, 1.0))
	img.fill_rect(Rect2i(4, 17 - flame / 2, flame + 2, flame), Color(1.0, 0.78, 0.45, 0.95))
	return ImageTexture.create_from_image(img)

func _make_drone_tex() -> Texture2D:
	var img := _make_img(28)
	img.fill_rect(Rect2i(9, 9, 10, 10), Color(0.78, 0.94, 1.0, 0.95))
	img.fill_rect(Rect2i(4, 13, 20, 2), Color(0.72, 0.86, 1.0, 0.75))
	return ImageTexture.create_from_image(img)

func _make_drone_tex_frame(frame: int) -> Texture2D:
	var img := _make_img(28)
	var wing := 4 + int(frame % 3)
	img.fill_rect(Rect2i(9, 9, 10, 10), Color(0.78, 0.94, 1.0, 0.95))
	img.fill_rect(Rect2i(wing, 13, 28 - wing * 2, 2), Color(0.72, 0.86, 1.0, 0.75))
	return ImageTexture.create_from_image(img)

func _make_boomerang_tex() -> Texture2D:
	var img := _make_img(30)
	_fill_polygon(img, PackedVector2Array([Vector2(8, 7), Vector2(22, 7), Vector2(18, 12), Vector2(12, 12)]), Color(1.0, 0.86, 0.45, 0.95))
	_fill_polygon(img, PackedVector2Array([Vector2(8, 23), Vector2(22, 23), Vector2(18, 18), Vector2(12, 18)]), Color(1.0, 0.86, 0.45, 0.95))
	return ImageTexture.create_from_image(img)

func _make_boomerang_tex_frame(frame: int) -> Texture2D:
	var img := _make_img(30)
	var swing := (float(frame % 4) - 1.5) * 0.7
	_fill_polygon(img, PackedVector2Array([Vector2(8, 7 + swing), Vector2(22, 7 - swing), Vector2(18, 12), Vector2(12, 12)]), Color(1.0, 0.86, 0.45, 0.95))
	_fill_polygon(img, PackedVector2Array([Vector2(8, 23 - swing), Vector2(22, 23 + swing), Vector2(18, 18), Vector2(12, 18)]), Color(1.0, 0.86, 0.45, 0.95))
	return ImageTexture.create_from_image(img)

func _make_molotov_tex() -> Texture2D:
	var img := _make_img(30)
	img.fill_rect(Rect2i(11, 8, 8, 14), Color(1.0, 0.6, 0.28, 0.95))
	img.fill_rect(Rect2i(12, 5, 6, 4), Color(1.0, 0.82, 0.48, 0.9))
	return ImageTexture.create_from_image(img)

func _make_molotov_tex_frame(frame: int) -> Texture2D:
	var img := _make_img(30)
	var flare := int(frame % 4)
	img.fill_rect(Rect2i(11, 8, 8, 14), Color(1.0, 0.6, 0.28, 0.95))
	img.fill_rect(Rect2i(12, 5, 6, 4), Color(1.0, 0.82, 0.48, 0.9))
	img.fill_rect(Rect2i(13, 2 + flare, 4, 3 + (3 - flare)), Color(1.0, 0.75, 0.36, 0.82))
	return ImageTexture.create_from_image(img)

func _make_quantum_tex() -> Texture2D:
	var img := _make_img(30)
	_fill_polygon(img, PackedVector2Array([Vector2(15, 4), Vector2(25, 10), Vector2(25, 20), Vector2(15, 26), Vector2(5, 20), Vector2(5, 10)]), Color(0.76, 1.0, 0.7, 0.95))
	return ImageTexture.create_from_image(img)

func _make_quantum_tex_frame(frame: int) -> Texture2D:
	var img := _make_img(30)
	var pulse := (float(frame % 4) - 1.5) * 0.9
	_fill_polygon(img, PackedVector2Array([
		Vector2(15, 4 + pulse * 0.2), Vector2(25 - pulse * 0.2, 10), Vector2(25 - pulse * 0.2, 20),
		Vector2(15, 26 - pulse * 0.2), Vector2(5 + pulse * 0.2, 20), Vector2(5 + pulse * 0.2, 10)
	]), Color(0.76, 1.0, 0.7, 0.95))
	img.fill_rect(Rect2i(13, 13, 4, 4), Color(0.9, 1.0, 0.86, 0.72))
	return ImageTexture.create_from_image(img)

func _make_guardian_tex_frame(frame: int) -> Texture2D:
	var img := _make_img(26)
	var pulse := (float(frame % 4) - 1.5) * 0.45
	_fill_polygon(img, PackedVector2Array([Vector2(23, 13), Vector2(13, 7 - pulse), Vector2(5, 13), Vector2(13, 19 + pulse)]), Color(1.0, 0.86, 0.52, 0.94))
	return ImageTexture.create_from_image(img)

func _make_frost_aura_tex_frame(frame: int) -> Texture2D:
	var img := _make_img(40)
	var thick := 1 + int(frame % 3)
	for i in range(40):
		img.set_pixel(i, 20, Color(0.65, 0.9, 1.0, 0.24))
		img.set_pixel(20, i, Color(0.65, 0.9, 1.0, 0.24))
	for r in range(11, 18, thick):
		_draw_ring(img, Vector2i(20, 20), r, Color(0.66, 0.92, 1.0, 0.3))
	return ImageTexture.create_from_image(img)

func _make_heal_aura_tex_frame(frame: int) -> Texture2D:
	var img := _make_img(40)
	var t := frame % 4
	for i in range(40):
		if i % (2 + t) == 0:
			img.set_pixel(i, 20, Color(0.48, 1.0, 0.72, 0.26))
			img.set_pixel(20, i, Color(0.48, 1.0, 0.72, 0.26))
	_draw_ring(img, Vector2i(20, 20), 14 + t, Color(0.52, 1.0, 0.76, 0.32))
	return ImageTexture.create_from_image(img)

func _make_mine_tex_frame(frame: int) -> Texture2D:
	var img := _make_img(24)
	var blink := 0.6 + 0.35 * sin(float(frame) * PI * 0.5)
	img.fill_rect(Rect2i(7, 7, 10, 10), Color(0.72, 0.86, 1.0, 0.92))
	img.fill_rect(Rect2i(10, 10, 4, 4), Color(1.0, 0.85, 0.5, blink))
	return ImageTexture.create_from_image(img)

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
			_weapon_mount_sprites[kind] = s
		var mount := _weapon_mount_sprites[kind] as AnimatedSprite2D
		if mount == null:
			continue
		var spread := TAU / float(maxi(1, count))
		var ang := base_angle + spread * float(i) + sin(_guardian_phase * 0.6 + float(i)) * 0.04
		var k_rad := radius
		var ang_bias := 0.0
		var rot_bias := PI * 0.5
		var k_scale := 0.7
		var alpha := 0.9
		match kind:
			_KIND_KUNAI:
				k_rad = radius * 0.86
				ang_bias = -0.18
				rot_bias = PI * 0.35
				k_scale = 0.64
			_KIND_ROCKET:
				k_rad = radius * 1.08
				ang_bias = 0.1
				rot_bias = PI * 0.5
				k_scale = 0.78
			_KIND_LIGHTNING:
				k_rad = radius * 0.94
				ang_bias = 0.22
				rot_bias = PI * 0.5
				k_scale = 0.74
				alpha = 0.94
			_KIND_QUANTUM:
				k_rad = radius * 1.02
				ang_bias = -0.05
				rot_bias = PI * 0.5
				k_scale = 0.8
				alpha = 0.95
			_:
				pass
		ang += ang_bias
		var pos := center + Vector2(cos(ang), sin(ang)) * k_rad
		mount.global_position = pos
		mount.rotation = ang + rot_bias
		mount.scale = Vector2.ONE * k_scale * _PROJECTILE_VISUAL_MUL
		mount.modulate = _modulate_for_kind(kind)
		mount.modulate.a = alpha

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
