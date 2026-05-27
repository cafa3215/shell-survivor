extends Node2D
class_name PlayerVisuals

# ============================================
# 玩家视觉增强 - 引擎光晕 + 移动拖尾 + 无敌闪烁
# ============================================

var _trail_particles: GPUParticles2D
var _engine_glow: Sprite2D
var _readability_ring: Sprite2D
var _direction_arrow: Sprite2D
var _player: Node2D
var _prev_pos := Vector2.ZERO
var _is_moving := false

func _ready() -> void:
	# 延迟获取玩家引用
	call_deferred("_setup")

func _setup() -> void:
	_player = get_parent() as Node2D
	if _player == null:
		return
	_prev_pos = _player.global_position
	_create_engine_glow()
	_create_readability_ring()
	_create_direction_arrow()
	_create_trail()

func _create_engine_glow() -> void:
	_engine_glow = Sprite2D.new()
	_engine_glow.z_index = -2
	# 常驻脚底光圈：用于快速锁定主角位置。
	var size := 160
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := float(size) / 2.0
	for y in range(size):
		for x in range(size):
			var dx := float(x) - center
			var dy := float(y) - center
			var d := sqrt(dx * dx + dy * dy) / center
			if d <= 1.0:
				var alpha := pow(1.0 - d, 3.3) * 0.19
				var r: float = lerp(1.0, 0.9, d)
				var g: float = lerp(0.86, 0.65, d)
				var b: float = lerp(0.34, 0.2, d)
				img.set_pixel(x, y, Color(r, g, b, alpha))
	_engine_glow.texture = ImageTexture.create_from_image(img)
	_engine_glow.scale = Vector2(0.88, 0.88)
	add_child(_engine_glow)

func _create_readability_ring() -> void:
	_readability_ring = Sprite2D.new()
	_readability_ring.z_index = -1
	var size := 132
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := float(size) / 2.0
	for y in range(size):
		for x in range(size):
			var dx := float(x) - center
			var dy := float(y) - center
			var d := sqrt(dx * dx + dy * dy) / center
			if d >= 0.54 and d <= 0.7:
				var t := (d - 0.54) / 0.16
				var alpha := (1.0 - absf(t * 2.0 - 1.0)) * 0.55
				img.set_pixel(x, y, Color(0.1, 0.9, 1.0, alpha))
	_readability_ring.texture = ImageTexture.create_from_image(img)
	_readability_ring.scale = Vector2(1.0, 1.0)
	add_child(_readability_ring)

func _create_direction_arrow() -> void:
	_direction_arrow = Sprite2D.new()
	_direction_arrow.z_index = 3
	var img := Image.create(34, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(24):
		for x in range(34):
			var in_body := x >= 8 and x <= 21 and y >= 9 and y <= 15
			var dx := float(x - 22)
			var dy := absf(float(y - 12))
			var in_head := x >= 18 and x <= 31 and dy <= (float(x - 18) * 0.52)
			if in_body or in_head:
				img.set_pixel(x, y, Color(0.18, 0.92, 1.0, 0.92))
	_direction_arrow.texture = ImageTexture.create_from_image(img)
	_direction_arrow.position = Vector2(0, -38)
	add_child(_direction_arrow)

func _create_trail() -> void:
	_trail_particles = GPUParticles2D.new()
	_trail_particles.amount = 8
	_trail_particles.lifetime = 0.22
	_trail_particles.explosiveness = 0.0
	_trail_particles.randomness = 0.3
	_trail_particles.local_coords = false
	_trail_particles.z_index = -2
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.6
	mat.scale_max = 3.2
	mat.damping_min = 60.0
	mat.damping_max = 100.0
	
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.28, 0.42, 0.38, 0.1))
	gradient.set_color(1, Color(0.06, 0.1, 0.1, 0.0))
	gradient.add_point(0.45, Color(0.16, 0.28, 0.26, 0.05))
	
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	_trail_particles.process_material = mat
	_trail_particles.texture = _make_trail_texture()
	_trail_particles.emitting = false
	add_child(_trail_particles)

func _make_trail_texture() -> Texture2D:
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := float(size) / 2.0
	var radius := center - 0.5
	for y in range(size):
		for x in range(size):
			var dx := float(x) - center
			var dy := float(y) - center
			var d := sqrt(dx * dx + dy * dy)
			if d <= radius:
				var alpha := 1.0 - d / radius
				img.set_pixel(x, y, Color(0.32, 0.48, 0.44, alpha * 0.32))
	return ImageTexture.create_from_image(img)

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var fidelity_mode := false
	if "fidelity_mode_enabled" in _player:
		fidelity_mode = bool(_player.get("fidelity_mode_enabled"))
	
	# 引擎光晕跟随
	if _engine_glow:
		_engine_glow.global_position = _player.global_position
		var readability := _readability_strength()
		var pulse := (0.46 + readability * 0.18) + (0.1 + readability * 0.1) * sin(Time.get_ticks_msec() * 0.0022)
		_engine_glow.modulate.a = pulse * (0.55 if fidelity_mode else 1.0)
	if _readability_ring:
		if fidelity_mode:
			_readability_ring.visible = false
		else:
			_readability_ring.visible = true
			_readability_ring.global_position = _player.global_position
			var readability_ring := _readability_strength()
			var ring_pulse := (0.56 + readability_ring * 0.34) + 0.15 * sin(Time.get_ticks_msec() * 0.0031)
			_readability_ring.modulate = Color(1.0, 1.0, 1.0, ring_pulse)
			_readability_ring.scale = Vector2.ONE * lerpf(0.88, 1.08, readability_ring)
	if _direction_arrow:
		if fidelity_mode:
			_direction_arrow.visible = false
		else:
			_direction_arrow.visible = true
			_direction_arrow.global_position = _player.global_position + Vector2(0, -34)
			if _player.has_node("WeaponMount"):
				var mount := _player.get_node("WeaponMount") as Node2D
				_direction_arrow.rotation = mount.global_rotation
			else:
				_direction_arrow.rotation = 0.0
			var arrow_alpha := lerpf(0.35, 0.82, _readability_strength())
			_direction_arrow.modulate = Color(1, 1, 1, arrow_alpha)
	
	# 拖尾 - 只在移动时发射
	if _trail_particles:
		var current_pos := _player.global_position
		var speed := (current_pos - _prev_pos).length()
		_is_moving = speed > 2.0
		_trail_particles.emitting = _is_moving
		_trail_particles.global_position = current_pos
		_prev_pos = current_pos

func _readability_strength() -> float:
	match int(Settings.readability_preset):
		Settings.ReadabilityPreset.LOW:
			return 0.35
		Settings.ReadabilityPreset.HIGH:
			return 1.0
		_:
			return 0.7
