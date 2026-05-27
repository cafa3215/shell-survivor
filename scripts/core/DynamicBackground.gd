extends Node2D
class_name DynamicBackground

# ============================================
# 动态背景 - 废土草地 + 碎石路面（弹壳特工队式大地图）
# ============================================

var _star_particles: GPUParticles2D
var _ambient_particles: GPUParticles2D
var _nebula_particles: GPUParticles2D
var _time := 0.0
var _player: Node2D
var _prev_player_pos := Vector2.ZERO
var _tile_offset := Vector2.ZERO

# 地面瓦片纹理（大纹理平铺）
var _ground_sprite: Sprite2D
var _ground_sprite2: Sprite2D
var _ground_sprite3: Sprite2D
var _ground_sprite4: Sprite2D

# 环境光效
var _player_light: Sprite2D
## 慢漂移雾层（提升地图纵深与精美度）
var _fog_sprites: Array[Sprite2D] = []

func _ready() -> void:
	_create_ground()
	_create_atmospheric_fog()
	_create_star_field()
	_create_ambient_particles()
	_create_nebula()
	_create_player_light()
	_apply_visual_quality()
	if not EventBus.graphics_quality_changed.is_connected(_on_graphics_quality_changed):
		EventBus.graphics_quality_changed.connect(_on_graphics_quality_changed)
	call_deferred("_find_player")


func _on_graphics_quality_changed(_q: int) -> void:
	_apply_visual_quality()

func _find_player() -> void:
	_player = get_parent().get_node_or_null(^"Player") as Node2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player:
		_prev_player_pos = _player.global_position

func _process(delta: float) -> void:
	_time += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_parent().get_node_or_null(^"Player") as Node2D
		if _player == null:
			_player = get_tree().get_first_node_in_group("player") as Node2D
	
	# 地面随玩家移动（2x2平铺覆盖）
	if _player and is_instance_valid(_player):
		var p := _player.global_position
		_tile_offset = p
		# 平铺纹理跟随（确保无缝覆盖）
		var tile_size := 1800.0
		if _ground_sprite:
			_ground_sprite.global_position = Vector2(
				floor(p.x / tile_size) * tile_size,
				floor(p.y / tile_size) * tile_size
			)
		if _ground_sprite2:
			_ground_sprite2.global_position = Vector2(
				floor(p.x / tile_size) * tile_size + tile_size,
				floor(p.y / tile_size) * tile_size
			)
		if _ground_sprite3:
			_ground_sprite3.global_position = Vector2(
				floor(p.x / tile_size) * tile_size,
				floor(p.y / tile_size) * tile_size + tile_size
			)
		if _ground_sprite4:
			_ground_sprite4.global_position = Vector2(
				floor(p.x / tile_size) * tile_size + tile_size,
				floor(p.y / tile_size) * tile_size + tile_size
			)
		if _fog_sprites.size() == 4:
			var drift := Vector2(sin(_time * 0.38) * 95.0, cos(_time * 0.31) * 72.0)
			var p2 := p + drift * 0.18
			_fog_sprites[0].global_position = Vector2(floor(p2.x / tile_size) * tile_size, floor(p2.y / tile_size) * tile_size)
			_fog_sprites[1].global_position = Vector2(floor(p2.x / tile_size) * tile_size + tile_size, floor(p2.y / tile_size) * tile_size)
			_fog_sprites[2].global_position = Vector2(floor(p2.x / tile_size) * tile_size, floor(p2.y / tile_size) * tile_size + tile_size)
			_fog_sprites[3].global_position = Vector2(floor(p2.x / tile_size) * tile_size + tile_size, floor(p2.y / tile_size) * tile_size + tile_size)
		# 环境光跟随玩家
		if _player_light:
			_player_light.global_position = p
		
		_prev_player_pos = p

func _create_ground() -> void:
	var tile_size := 1800
	var img: Image
	var gen: Image = GameDB.load_png_if_exists(GameDB.TEX_GEN_GROUND)
	if gen != null:
		img = gen.duplicate()
		if img.get_width() != tile_size or img.get_height() != tile_size:
			img.resize(tile_size, tile_size, Image.INTERPOLATE_LANCZOS)
	else:
		img = Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_fill_procedural_ground_tile(img, tile_size)
	
	var tex := ImageTexture.create_from_image(img)
	_apply_ground_sprites(tex)

func _fill_procedural_ground_tile(img: Image, tile_size: int) -> void:
	# 1080p 写实向：连贯噪声湿沥青 / 冷混凝土（无外部贴图；先低分辨率生成再 Lanczos 放大）
	var macro := 384
	var noise_macro := FastNoiseLite.new()
	noise_macro.seed = randi()
	noise_macro.frequency = 0.014
	noise_macro.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_macro.fractal_octaves = 4
	noise_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var noise_warp := FastNoiseLite.new()
	noise_warp.seed = noise_macro.seed ^ 3346428310
	noise_warp.frequency = 0.055
	noise_warp.fractal_octaves = 3
	noise_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var noise_fine := FastNoiseLite.new()
	noise_fine.seed = noise_macro.seed + 9973
	noise_fine.frequency = 0.28
	noise_fine.noise_type = FastNoiseLite.TYPE_PERLIN
	var small := Image.create(macro, macro, false, Image.FORMAT_RGBA8)
	for y in range(macro):
		for x in range(macro):
			var m := noise_macro.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var w := noise_warp.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var f := noise_fine.get_noise_2d(float(x), float(y)) * 0.12
			var br := 0.11 + m * 0.07 + (w - 0.5) * 0.04 + f
			var bg := 0.112 + m * 0.065 + (w - 0.5) * 0.035 + f * 0.95
			var bb := 0.118 + m * 0.058 + (w - 0.5) * 0.032 + f * 0.9
			var nx := float(x) / float(macro)
			var ny := float(y) / float(macro)
			var sheen := pow(sin(nx * TAU * 2.4 + ny * 0.9) * 0.5 + 0.5, 14.0) * 0.055
			br += sheen
			bg += sheen * 0.98
			bb += sheen * 0.96
			small.set_pixel(x, y, Color(br, bg, bb, 1.0))
	small.resize(tile_size, tile_size, Image.INTERPOLATE_LANCZOS)
	img.blit_rect(small, Rect2i(0, 0, tile_size, tile_size), Vector2i(0, 0))
	var wear := FastNoiseLite.new()
	wear.seed = noise_macro.seed + 404
	wear.frequency = 0.022
	for _i in range(140):
		var px := randi() % tile_size
		var py := randi() % tile_size
		if wear.get_noise_2d(float(px), float(py)) > 0.32:
			var c: Color = img.get_pixel(px, py)
			img.set_pixel(px, py, Color(c.r * 0.92, c.g * 0.93, c.b * 0.94, 1.0))
	var seam := Color(0.09, 0.095, 0.105, 1.0)
	var step := 360
	for x in range(0, tile_size, step):
		for y in range(tile_size):
			var c2: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c2.r * 0.96 + seam.r * 0.04, c2.g * 0.96 + seam.g * 0.04, c2.b * 0.96 + seam.b * 0.04, 1.0))
	for y in range(0, tile_size, step):
		for x in range(tile_size):
			var c3: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c3.r * 0.96 + seam.r * 0.04, c3.g * 0.96 + seam.g * 0.04, c3.b * 0.96 + seam.b * 0.04, 1.0))

func _make_fog_overlay_texture() -> ImageTexture:
	var sz := 384
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(sz) * 0.5
	var cy := float(sz) * 0.5
	for y in range(sz):
		for x in range(sz):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var d := sqrt(dx * dx + dy * dy) / (float(sz) * 0.48)
			var n := sin(float(x) * 0.09 + float(y) * 0.07) * 0.5 + 0.5
			# 压低雾浓度，避免与角色脚下光叠成一片灰青
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 1.85) * (0.035 + n * 0.032)
			img.set_pixel(x, y, Color(0.18, 0.19, 0.21, a))
	return ImageTexture.create_from_image(img)

func _create_atmospheric_fog() -> void:
	var fog_tex := _make_fog_overlay_texture()
	var tile_size := 1800.0
	var scale_f := tile_size / 384.0
	for _i in 4:
		var s := Sprite2D.new()
		s.texture = fog_tex
		s.z_index = -12
		s.centered = true
		s.scale = Vector2(scale_f, scale_f)
		s.modulate = Color(1, 1, 1, 0.22)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(s)
		_fog_sprites.append(s)

func _apply_ground_sprites(tex: ImageTexture) -> void:
	# 2x2平铺覆盖
	_ground_sprite = Sprite2D.new()
	_ground_sprite.texture = tex
	_ground_sprite.z_index = -20
	_ground_sprite.centered = true
	_ground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_ground_sprite)
	
	_ground_sprite2 = Sprite2D.new()
	_ground_sprite2.texture = tex
	_ground_sprite2.z_index = -20
	_ground_sprite2.centered = true
	_ground_sprite2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_ground_sprite2)
	
	_ground_sprite3 = Sprite2D.new()
	_ground_sprite3.texture = tex
	_ground_sprite3.z_index = -20
	_ground_sprite3.centered = true
	_ground_sprite3.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_ground_sprite3)
	
	_ground_sprite4 = Sprite2D.new()
	_ground_sprite4.texture = tex
	_ground_sprite4.z_index = -20
	_ground_sprite4.centered = true
	_ground_sprite4.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_ground_sprite4)

func _create_player_light() -> void:
	# 极轻脚下环境提亮（小范围、低饱和，避免盖住角色轮廓）
	_player_light = Sprite2D.new()
	_player_light.z_index = -8
	
	var size := 384
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := float(size) / 2.0
	for y in range(size):
		for x in range(size):
			var dx := float(x) - center
			var dy := float(y) - center
			var d := sqrt(dx * dx + dy * dy) / center
			if d <= 1.0:
				var alpha := pow(1.0 - d, 3.6) * 0.045
				img.set_pixel(x, y, Color(0.18, 0.2, 0.24, alpha))
	
	_player_light.texture = ImageTexture.create_from_image(img)
	_player_light.scale = Vector2(1.35, 1.35)
	_player_light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_player_light)

func _create_star_field() -> void:
	_star_particles = GPUParticles2D.new()
	_star_particles.amount = 80
	_star_particles.lifetime = 10.0
	_star_particles.explosiveness = 0.0
	_star_particles.randomness = 0.7
	_star_particles.local_coords = false
	_star_particles.z_index = -15
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1600, 1100, 0)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.5
	mat.scale_max = 2.0
	
	# 星星颜色更暗更自然
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.62, 0.68, 0.78, 0.0))
	gradient.set_color(1, Color(0.88, 0.9, 0.94, 0.16))
	gradient.add_point(0.5, Color(0.76, 0.82, 0.9, 0.07))
	
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	_star_particles.process_material = mat
	_star_particles.texture = _make_star_texture()
	add_child(_star_particles)

func _create_nebula() -> void:
	_nebula_particles = GPUParticles2D.new()
	_nebula_particles.amount = 8
	_nebula_particles.lifetime = 15.0
	_nebula_particles.explosiveness = 0.0
	_nebula_particles.randomness = 0.4
	_nebula_particles.local_coords = false
	_nebula_particles.z_index = -18
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1400, 900, 0)
	mat.direction = Vector3(1, 0.3, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 20.0
	mat.scale_max = 50.0
	
	# 星云颜色更暗
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.12, 0.1, 0.06, 0.0))
	gradient.set_color(1, Color(0.12, 0.1, 0.06, 0.0))
	gradient.add_point(0.3, Color(0.22, 0.2, 0.12, 0.028))
	gradient.add_point(0.6, Color(0.2, 0.18, 0.1, 0.022))
	
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	_nebula_particles.process_material = mat
	_nebula_particles.texture = _make_nebula_texture()
	add_child(_nebula_particles)

func _create_ambient_particles() -> void:
	_ambient_particles = GPUParticles2D.new()
	_ambient_particles.amount = 25
	_ambient_particles.lifetime = 6.0
	_ambient_particles.explosiveness = 0.0
	_ambient_particles.randomness = 0.8
	_ambient_particles.local_coords = false
	_ambient_particles.z_index = -3
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1800, 1200, 0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -3, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.5
	
	# 尘埃颜色更暗
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.42, 0.44, 0.48, 0.0))
	gradient.set_color(1, Color(0.5, 0.52, 0.55, 0.0))
	gradient.add_point(0.3, Color(0.48, 0.5, 0.54, 0.045))
	gradient.add_point(0.7, Color(0.5, 0.52, 0.56, 0.024))
	
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	_ambient_particles.process_material = mat
	_ambient_particles.texture = _make_particle_texture()
	add_child(_ambient_particles)

func _make_star_texture() -> Texture2D:
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
				var alpha := 1.0 - (d / radius)
				alpha = pow(alpha, 1.5)
				img.set_pixel(x, y, Color(0.82, 0.86, 0.92, alpha))
	return ImageTexture.create_from_image(img)

func _make_nebula_texture() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := float(size) / 2.0
	var radius := center - 1.0
	for y in range(size):
		for x in range(size):
			var dx := float(x) - center
			var dy := float(y) - center
			var d := sqrt(dx * dx + dy * dy)
			if d <= radius:
				var alpha := pow(1.0 - d / radius, 2.0) * 0.15
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)

func _make_particle_texture() -> Texture2D:
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
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * 0.5))
	return ImageTexture.create_from_image(img)

func _apply_visual_quality() -> void:
	if _star_particles == null or _ambient_particles == null or _nebula_particles == null:
		return
	match Settings.quality:
		Settings.Quality.LOW:
			_star_particles.amount = 22
			_ambient_particles.amount = 7
			_nebula_particles.amount = 0
			_nebula_particles.emitting = false
			_nebula_particles.visible = false
			if _player_light:
				_player_light.scale = Vector2(2.4, 2.4)
			_set_fog_alpha(0.07)
		Settings.Quality.MEDIUM:
			_star_particles.amount = 48
			_ambient_particles.amount = 14
			_nebula_particles.amount = 4
			_nebula_particles.emitting = true
			_nebula_particles.visible = true
			if _player_light:
				_player_light.scale = Vector2(2.7, 2.7)
			_set_fog_alpha(0.12)
		Settings.Quality.HIGH:
			_star_particles.amount = 84
			_ambient_particles.amount = 24
			_nebula_particles.amount = 8
			_nebula_particles.emitting = true
			_nebula_particles.visible = true
			if _player_light:
				_player_light.scale = Vector2(3.0, 3.0)
			_set_fog_alpha(0.16)
	if Settings.reduce_particles:
		_star_particles.amount = int(round(float(_star_particles.amount) * 0.6))
		_ambient_particles.amount = int(round(float(_ambient_particles.amount) * 0.55))
		_nebula_particles.amount = int(round(float(_nebula_particles.amount) * 0.5))
		_set_fog_alpha(0.06 if Settings.quality == Settings.Quality.LOW else 0.09)


func _set_fog_alpha(a: float) -> void:
	for s in _fog_sprites:
		if s and is_instance_valid(s):
			var c: Color = s.modulate
			c.a = a
			s.modulate = c
