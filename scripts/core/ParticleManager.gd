extends Node2D
class_name ParticleManager

# ============================================
# 粒子特效管理器 - GPUParticles2D 对象池
# ============================================

# 粒子类型定义
enum ParticleType {
	EXPLOSION,
	BLOOD_HIT,
	FIRE_BURN,
	LIGHTNING_SPARK,
	MAGIC_BURST,
	SMOKE,
	BUFF_AURA,
	LEVEL_UP,
	EXP_COLLECT,
	# 分批专属 VFX（首批：kunai / rocket）
	KUNAI_GLINT,
	ROCKET_EMBER,
	## 快速外扩环：量子/重击/地雷等「记忆点」
	SHOCKWAVE_RING,
}

# 预定义粒子材质
var _particle_materials: Dictionary = {}
var _particle_pool: Dictionary = {}
var _active_particles: Array[GPUParticles2D] = []
var _max_pool_per_type := 10
var _particle_tex_cache: Dictionary = {}
var _fallback_circle_particle_tex: Texture2D

func _ready() -> void:
	_create_particle_materials()

func _create_particle_materials() -> void:
	# 爆炸粒子
	_particle_materials[ParticleType.EXPLOSION] = _create_explosion_material()
	
	# 血液/击中粒子
	_particle_materials[ParticleType.BLOOD_HIT] = _create_hit_material()
	
	# 燃烧粒子
	_particle_materials[ParticleType.FIRE_BURN] = _create_fire_material()
	
	# 雷电粒子
	_particle_materials[ParticleType.LIGHTNING_SPARK] = _create_lightning_material()
	
	# 魔法爆发
	_particle_materials[ParticleType.MAGIC_BURST] = _create_magic_material()
	
	# 经验收集
	_particle_materials[ParticleType.EXP_COLLECT] = _create_exp_material()
	
	# 升级特效
	_particle_materials[ParticleType.LEVEL_UP] = _create_levelup_material()
	
	# 烟雾粒子
	_particle_materials[ParticleType.SMOKE] = _create_smoke_material()
	
	# 增益光环
	_particle_materials[ParticleType.BUFF_AURA] = _create_buff_aura_material()
	# 武器专属（工程可承受：独立材质 + 对象池，无逐武器 shader）
	_particle_materials[ParticleType.KUNAI_GLINT] = _create_kunai_glint_material()
	_particle_materials[ParticleType.ROCKET_EMBER] = _create_rocket_ember_material()
	_particle_materials[ParticleType.SHOCKWAVE_RING] = _create_shockwave_ring_material()

func _create_explosion_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 28
	particles.lifetime = 0.48
	particles.speed_scale = 1.2
	
	# Process material
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 95.0
	mat.initial_velocity_max = 210.0
	mat.gravity = Vector3(0, 45, 0)
	mat.scale_min = 2.2
	mat.scale_max = 5.0
	mat.angular_velocity_min = -4.5
	mat.angular_velocity_max = 4.5
	mat.radial_accel_min = 40.0
	mat.radial_accel_max = 120.0
	mat.color = Color(1.0, 0.55, 0.2, 0.88)
	mat.color_ramp = _create_color_ramp(Color(0.9, 0.6, 0.2), Color(0.5, 0.1, 0.02))
	
	particles.process_material = mat
	particles.texture = _load_particle_texture("explosion_chunk")
	
	return particles

func _create_hit_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.amount = 14
	particles.lifetime = 0.28
	particles.speed_scale = 1.65
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 88.0
	mat.initial_velocity_min = 75.0
	mat.initial_velocity_max = 155.0
	mat.gravity = Vector3(0, 220, 0)
	mat.scale_min = 1.1
	mat.scale_max = 3.0
	mat.angular_velocity_min = -7.0
	mat.angular_velocity_max = 7.0
	mat.color = Color(0.92, 0.35, 0.12, 0.78)
	mat.color_ramp = _create_color_ramp(Color(0.8, 0.4, 0.2), Color(0.4, 0.08, 0.0))
	
	particles.process_material = mat
	particles.texture = _load_particle_texture("spark_shard")
	
	return particles

func _create_fire_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = false
	particles.amount = 10
	particles.lifetime = 0.7
	particles.explosiveness = 0.2
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 10.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, -20, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(0.9, 0.4, 0.08, 0.6)
	mat.color_ramp = _create_color_ramp(Color(0.9, 0.5, 0.15), Color(0.4, 0.08, 0.0))
	
	particles.process_material = mat
	particles.texture = _load_particle_texture("explosion_chunk")
	
	return particles

func _create_lightning_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 44
	particles.lifetime = 0.26
	particles.speed_scale = 2.15
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 170.0
	mat.initial_velocity_max = 340.0
	mat.scale_min = 1.1
	mat.scale_max = 3.0
	mat.angular_velocity_min = -14.0
	mat.angular_velocity_max = 14.0
	mat.radial_accel_min = -60.0
	mat.radial_accel_max = 180.0
	mat.color = Color(0.55, 0.78, 1.0, 0.82)
	mat.color_ramp = _create_color_ramp(Color(0.6, 0.8, 1.0), Color(0.2, 0.35, 0.7))
	
	particles.process_material = mat
	particles.texture = _load_particle_texture("lightning_seg")
	
	return particles

func _create_magic_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.7
	particles.amount = 52
	particles.lifetime = 0.58
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 20.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 72.0
	mat.initial_velocity_min = 65.0
	mat.initial_velocity_max = 130.0
	mat.gravity = Vector3(0, 38, 0)
	mat.scale_min = 2.4
	mat.scale_max = 6.2
	mat.angular_velocity_min = -5.5
	mat.angular_velocity_max = 5.5
	mat.radial_accel_min = -90.0
	mat.radial_accel_max = 140.0
	mat.color = Color(0.62, 0.5, 1.0, 0.72)
	mat.color_ramp = _create_magic_prismatic_ramp()
	
	particles.process_material = mat
	particles.texture = _load_particle_texture("spark_shard")
	
	return particles

func _create_exp_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.5
	particles.amount = 10
	particles.lifetime = 0.3
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 50, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(0.2, 1.0, 0.5, 1.0)
	
	particles.process_material = mat
	particles.texture = _load_particle_texture("spark_shard")
	
	return particles

func _create_levelup_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.6
	particles.amount = 28
	particles.lifetime = 0.9
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 30.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0, 25, 0)
	mat.scale_min = 2.5
	mat.scale_max = 6.0
	mat.color = Color(0.8, 0.7, 0.2, 0.7)
	mat.color_ramp = _create_color_ramp(Color(0.9, 0.8, 0.4), Color(0.6, 0.35, 0.08))
	
	particles.process_material = mat
	particles.texture = _load_particle_texture("spark_shard")
	
	return particles

func _create_magic_prismatic_ramp() -> GradientTexture1D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.62, 0.18, 0.95))
	gradient.add_point(0.32, Color(1.0, 0.35, 0.65, 0.88))
	gradient.add_point(0.55, Color(0.35, 0.92, 0.55, 0.78))
	gradient.add_point(0.78, Color(0.45, 0.55, 1.0, 0.65))
	gradient.set_color(1, Color(0.15, 0.35, 0.95, 0.28))
	var tex: GradientTexture1D = GradientTexture1D.new()
	tex.gradient = gradient
	return tex

func _create_color_ramp(start_color: Color, end_color: Color) -> GradientTexture1D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, start_color)
	gradient.set_color(1, end_color)
	gradient.add_point(0.5, start_color.lerp(end_color, 0.5))
	var tex: GradientTexture1D = GradientTexture1D.new()
	tex.gradient = gradient
	return tex

func spawn_particles(type: ParticleType, position: Vector2, duration := -1.0, modulate: Color = Color.WHITE) -> GPUParticles2D:
	# R8/R6：减少粒子 = 入口节流；依类型做不同保留率，保留“关键记忆点”
	if Settings.reduce_particles:
		var keep := 1.0
		match type:
			ParticleType.LEVEL_UP, ParticleType.EXPLOSION:
				keep = 0.8
			ParticleType.LIGHTNING_SPARK, ParticleType.MAGIC_BURST:
				keep = 0.55
			ParticleType.BLOOD_HIT, ParticleType.SMOKE, ParticleType.EXP_COLLECT:
				keep = 0.4
			ParticleType.FIRE_BURN:
				keep = 0.3
			ParticleType.KUNAI_GLINT, ParticleType.ROCKET_EMBER:
				keep = 0.6
			ParticleType.SHOCKWAVE_RING:
				keep = 0.68
			_:
				keep = 0.5
		if randf() > keep:
			return null
	var particles: GPUParticles2D
	
	# 从对象池获取
	if _particle_pool.has(type) and _particle_pool[type].size() > 0:
		particles = _particle_pool[type].pop_back()
		particles.visible = true
	else:
		particles = _particle_materials[type].duplicate()
		add_child(particles)
	
	particles.global_position = position
	particles.modulate = modulate
	particles.emitting = true
	particles.restart()
	
	_active_particles.append(particles)
	
	# 自动回收
	var auto_duration := particles.lifetime if duration < 0 else duration
	get_tree().create_timer(auto_duration).timeout.connect(_return_to_pool.bind(particles, type))
	
	return particles

func _return_to_pool(particles: GPUParticles2D, type: ParticleType) -> void:
	if not is_instance_valid(particles):
		return
	
	particles.emitting = false
	particles.visible = false
	particles.modulate = Color.WHITE
	
	# 从活跃列表移除
	for i in range(_active_particles.size() - 1, -1, -1):
		if _active_particles[i] == particles:
			_active_particles.remove_at(i)
			break
	
	# 回收到对象池
	if not _particle_pool.has(type):
		_particle_pool[type] = []
	
	if _particle_pool[type].size() < _max_pool_per_type:
		_particle_pool[type].append(particles)
	else:
		particles.queue_free()

# 常用特效快捷方法
func explosion(pos: Vector2, tint: Color = Color.WHITE) -> void:
	spawn_particles(ParticleType.EXPLOSION, pos, -1.0, tint)

func hit_effect(pos: Vector2, tint: Color = Color.WHITE) -> void:
	spawn_particles(ParticleType.BLOOD_HIT, pos, -1.0, tint)

func fire_burn(pos: Vector2, duration: float) -> void:
	var p := spawn_particles(ParticleType.FIRE_BURN, pos, duration)
	if p == null:
		return
	p.one_shot = false
	p.emitting = true

func lightning_spark(pos: Vector2, tint: Color = Color.WHITE) -> void:
	spawn_particles(ParticleType.LIGHTNING_SPARK, pos, -1.0, tint)

func magic_burst(pos: Vector2, tint: Color = Color.WHITE) -> void:
	spawn_particles(ParticleType.MAGIC_BURST, pos, -1.0, tint)

func level_up_effect(pos: Vector2) -> void:
	spawn_particles(ParticleType.LEVEL_UP, pos)

func exp_collect(pos: Vector2) -> void:
	spawn_particles(ParticleType.EXP_COLLECT, pos)


func _get_fallback_particle_tex() -> Texture2D:
	if _fallback_circle_particle_tex != null:
		return _fallback_circle_particle_tex
	_fallback_circle_particle_tex = _make_particle_texture()
	return _fallback_circle_particle_tex


func _load_particle_texture(tex_name: String) -> Texture2D:
	if _particle_tex_cache.has(tex_name):
		return _particle_tex_cache[tex_name]
	var path := GameDB.ASSET_PACK_PARTICLES + tex_name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex != null:
		_particle_tex_cache[tex_name] = tex
		return tex
	return _get_fallback_particle_tex()


func _make_particle_texture() -> Texture2D:
	var size := 32
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
				var alpha := pow(1.0 - d / radius, 1.5)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)

# ============================================
# 资源清理 - 防止粒子泄漏
# ============================================
func _exit_tree() -> void:
	# 清理所有活跃粒子
	for particles in _active_particles:
		if is_instance_valid(particles):
			particles.queue_free()
	_active_particles.clear()
	
	# 清理对象池中的粒子
	for type_key in _particle_pool:
		for particles in _particle_pool[type_key]:
			if is_instance_valid(particles):
				particles.queue_free()
	_particle_pool.clear()
	
	# 清理预定义材质
	_particle_materials.clear()

func _create_smoke_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.3
	particles.amount = 12
	particles.lifetime = 1.2
	particles.speed_scale = 0.8
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, -20, 0)
	mat.scale_min = 5.0
	mat.scale_max = 12.0
	mat.color = Color(0.4, 0.45, 0.5, 0.4)
	mat.color_ramp = _create_color_ramp(Color(0.5, 0.55, 0.6, 0.5), Color(0.2, 0.22, 0.25, 0.0))
	
	particles.process_material = mat
	particles.texture = _load_particle_texture("smoke_blob")
	return particles

func _create_kunai_glint_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.88
	particles.amount = 14
	particles.lifetime = 0.18
	particles.speed_scale = 1.65
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 90.0
	mat.initial_velocity_max = 220.0
	mat.gravity = Vector3(0, 120, 0)
	mat.scale_min = 0.8
	mat.scale_max = 2.0
	mat.color = Color(0.35, 0.95, 1.0, 0.75)
	mat.color_ramp = _create_color_ramp(Color(0.85, 1.0, 1.0, 0.9), Color(0.05, 0.45, 0.85, 0.15))
	particles.process_material = mat
	particles.texture = _load_particle_texture("spark_shard")
	return particles


func _create_rocket_ember_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.82
	particles.amount = 22
	particles.lifetime = 0.42
	particles.speed_scale = 1.1
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 55.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 160.0
	mat.gravity = Vector3(0, 90, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.5
	mat.color = Color(1.0, 0.55, 0.12, 0.85)
	mat.color_ramp = _create_color_ramp(Color(1.0, 0.85, 0.35, 0.9), Color(0.45, 0.08, 0.02, 0.12))
	particles.process_material = mat
	particles.texture = _load_particle_texture("explosion_chunk")
	return particles


func _create_shockwave_ring_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.94
	particles.amount = 40
	particles.lifetime = 0.34
	particles.speed_scale = 1.4
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.emission_ring_height = 2.0
	mat.emission_ring_radius = 10.0
	mat.emission_ring_inner_radius = 7.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 18.0
	mat.initial_velocity_min = 140.0
	mat.initial_velocity_max = 260.0
	mat.gravity = Vector3(0, 10, 0)
	mat.scale_min = 1.6
	mat.scale_max = 3.6
	mat.angular_velocity_min = -4.0
	mat.angular_velocity_max = 4.0
	mat.radial_accel_min = 80.0
	mat.radial_accel_max = 220.0
	mat.color = Color(1.0, 0.95, 0.78, 0.82)
	mat.color_ramp = _create_color_ramp(Color(1.0, 1.0, 0.92, 0.92), Color(0.4, 0.65, 1.0, 0.1))
	particles.process_material = mat
	particles.texture = _load_particle_texture("shock_ring")
	return particles


func _create_buff_aura_material() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = false
	particles.amount = 18
	particles.lifetime = 0.6
	particles.explosiveness = 0.1
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 25.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, -15, 0)
	mat.scale_min = 3.0
	mat.scale_max = 6.0
	mat.color = Color(0.2, 0.8, 1.0, 0.4)
	mat.color_ramp = _create_color_ramp(Color(0.3, 0.9, 1.0, 0.6), Color(0.1, 0.4, 0.8, 0.0))
	
	particles.process_material = mat
	particles.texture = _load_particle_texture("spark_shard")
	return particles

func smoke(pos: Vector2) -> void:
	spawn_particles(ParticleType.SMOKE, pos)


func kunai_glint(pos: Vector2, tint: Color = Color.WHITE) -> void:
	spawn_particles(ParticleType.KUNAI_GLINT, pos, -1.0, tint)


func rocket_embers(pos: Vector2, tint: Color = Color.WHITE) -> void:
	spawn_particles(ParticleType.ROCKET_EMBER, pos, -1.0, tint)


func shockwave_ring(pos: Vector2, tint: Color = Color.WHITE) -> void:
	spawn_particles(ParticleType.SHOCKWAVE_RING, pos, -1.0, tint)


func buff_aura(pos: Vector2, duration: float) -> void:
	var p := spawn_particles(ParticleType.BUFF_AURA, pos, duration)
	if p == null:
		return
	p.one_shot = false
	p.emitting = true