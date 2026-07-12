extends Node2D
class_name ExperienceSystem

# ============================================
# 经验球系统 - MultiMesh渲染 + 对象池 + 活跃索引
# ============================================

var pool := PoolManager.new()
var orb_pos: PackedVector2Array
var orb_val: PackedInt32Array
var _merge_timer := 0.0
var _orb_alive_list: PackedInt32Array = []
var _orb_alive_pos: PackedInt32Array = []

# MultiMesh渲染
var _mm := MultiMesh.new()
var _mm_node := MultiMeshInstance2D.new()

# 缓存引用
var _player: Node2D
var _particle_mgr: Node2D
var _magnet_surge_t := 0.0

# 常量
const PICKUP_RADIUS_LOW := 190.0
const PICKUP_RADIUS_NORMAL := 170.0
const COLLECT_RADIUS := 18.0

func _ready() -> void:
	_player = get_parent().get_node("Player")
	_particle_mgr = get_parent().get_node_or_null("ParticleManager")
	pool.setup(GameDB.EXP_ORB_MAX)
	orb_pos.resize(GameDB.EXP_ORB_MAX)
	orb_val.resize(GameDB.EXP_ORB_MAX)
	_orb_alive_pos.resize(GameDB.EXP_ORB_MAX)
	for _oi in GameDB.EXP_ORB_MAX:
		_orb_alive_pos[_oi] = -1
	
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.instance_count = 0
	_mm.use_colors = true
	_mm.instance_count = GameDB.EXP_ORB_MAX
	# 使用 QuadMesh + ShaderMaterial 替代已移除的 texture 属性
	var quad := QuadMesh.new()
	quad.size = Vector2(24, 24)
	_mm.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = _make_orb_shader()
	mat.set_shader_parameter("tex", _make_orb_texture())
	_mm_node.material = mat
	_mm_node.multimesh = _mm
	_mm_node.z_index = -1
	_mm_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_mm_node)
	
	for i in GameDB.EXP_ORB_MAX:
		_mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(-99999, -99999)))
		_mm.set_instance_color(i, Color(0.2, 1.0, 0.5, 0.0))
	if not EventBus.level_up.is_connected(_on_level_up_magnet):
		EventBus.level_up.connect(_on_level_up_magnet)

func _on_level_up_magnet(_lv: int) -> void:
	_magnet_surge_t = GameDB.SURVIVOR_LEVELUP_MAGNET_SEC

func _register_orb(idx: int) -> void:
	if idx < 0 or idx >= GameDB.EXP_ORB_MAX or _orb_alive_pos[idx] >= 0:
		return
	_orb_alive_pos[idx] = _orb_alive_list.size()
	_orb_alive_list.append(idx)

func _unregister_orb(idx: int) -> void:
	if idx < 0 or idx >= GameDB.EXP_ORB_MAX:
		return
	var pos := _orb_alive_pos[idx]
	if pos < 0:
		return
	var last_i := _orb_alive_list[_orb_alive_list.size() - 1]
	_orb_alive_list[pos] = last_i
	_orb_alive_pos[last_i] = pos
	_orb_alive_list.remove_at(_orb_alive_list.size() - 1)
	_orb_alive_pos[idx] = -1

func _process(delta: float) -> void:
	if _player == null:
		return
	if _magnet_surge_t > 0.0:
		_magnet_surge_t = maxf(0.0, _magnet_surge_t - delta)
	var p: Vector2 = _player.global_position
	
	# 定期合并远处经验球
	_merge_timer -= delta
	if _merge_timer <= 0.0:
		_merge_timer = 0.6 if Settings.quality == Settings.Quality.LOW else 1.2
		_merge_far_orbs(p)
	
	# 仅遍历存活实例（duplicate 避免拾取时修改列表导致迭代异常）
	var orb_snap := _orb_alive_list.duplicate()
	var pickup := PICKUP_RADIUS_LOW if Settings.quality == Settings.Quality.LOW else PICKUP_RADIUS_NORMAL
	if _magnet_surge_t > 0.0:
		pickup *= GameDB.SURVIVOR_LEVELUP_MAGNET_MULT
	# 拾取半径被动加成
	var skill_sys = get_parent().get_node_or_null("SkillSystem")
	if skill_sys and skill_sys.stats.has("pickup_range"):
		pickup += float(skill_sys.stats["pickup_range"])
	
	for idx in orb_snap:
		var d := orb_pos[idx].distance_to(p)
		
		# 磁吸效果
		if d < pickup:
			var pull_speed := 280.0 + (pickup - d) * 2.5
			orb_pos[idx] = orb_pos[idx].move_toward(p, delta * pull_speed)
		
		# 拾取：磁吸后需用新距离判定，避免本帧已吸入范围内却未拾取
		var d_after := orb_pos[idx].distance_to(p)
		if d_after < COLLECT_RADIUS:
			var g := get_parent()
			if g != null and g.has_method("is_curse_blocking_xp_pickup") and bool(g.call("is_curse_blocking_xp_pickup")):
				var outward := orb_pos[idx] - p
				if outward.length() < 2.0:
					outward = Vector2.RIGHT.rotated(randf() * TAU)
				orb_pos[idx] = p + outward.normalized() * (COLLECT_RADIUS + 10.0)
				continue
			EventBus.xp_collected.emit(orb_val[idx])
			
			if _particle_mgr:
				_particle_mgr.exp_collect(orb_pos[idx])
			
			_unregister_orb(idx)
			pool.release(idx)
			_mm.set_instance_transform_2d(idx, Transform2D(0.0, Vector2(-99999, -99999)))
			continue
		
		# 更新MultiMesh渲染
		# 缓慢呼吸 + 轻微旋转：易读、减少频闪
		var pulse := 0.78 + 0.22 * sin(Time.get_ticks_msec() * 0.0038 + float(idx) * 0.71)
		var scale := 1.08 + float(mini(orb_val[idx], 10)) * 0.09
		var rot := sin(Time.get_ticks_msec() * 0.0024 + float(idx) * 1.1) * 0.12
		var transform := Transform2D(rot, Vector2(scale, scale), 0.0, orb_pos[idx])
		_mm.set_instance_transform_2d(idx, transform)
		
		var color: Color
		if orb_val[idx] >= 4:
			color = Color(1.0, 0.88, 0.35, pulse)  # 大金豆
		elif orb_val[idx] >= 2:
			color = Color(0.62, 0.52, 1.0, pulse)  # 紫豆（高价值）
		else:
			color = Color(0.35, 0.95, 1.0, pulse)  # 青蓝豆（弹壳式经验）
		_mm.set_instance_color(idx, color)

func spawn_orb(pos: Vector2, v: int) -> void:
	var idx := pool.alloc()
	if idx == -1:
		_absorb_into_nearest(pos, v)
		return
	orb_pos[idx] = pos
	orb_val[idx] = v
	_register_orb(idx)

func _absorb_into_nearest(pos: Vector2, v: int) -> void:
	var best := INF
	var best_i := -1
	for idx in _orb_alive_list:
		var d := orb_pos[idx].distance_squared_to(pos)
		if d < best:
			best = d
			best_i = idx
	if best_i != -1:
		orb_val[best_i] += v

func _merge_far_orbs(player_pos: Vector2) -> void:
	if Settings.quality != Settings.Quality.LOW:
		return
	var far := 520.0
	var keep := -1
	var merge_snap := _orb_alive_list.duplicate()
	for idx in merge_snap:
		if orb_pos[idx].distance_to(player_pos) > far:
			if keep == -1:
				keep = idx
			else:
				orb_val[keep] += orb_val[idx]
				_unregister_orb(idx)
				pool.release(idx)
				_mm.set_instance_transform_2d(idx, Transform2D(0.0, Vector2(-99999, -99999)))

func _make_orb_shader() -> Shader:
	var code := "
shader_type canvas_item;
uniform sampler2D tex;
void fragment() {
	COLOR = texture(tex, UV) * COLOR;
}
"
	var s := Shader.new()
	s.code = code
	return s

func _make_orb_texture() -> Texture2D:
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := float(size) / 2.0
	var radius := center - 1.0
	# 菱形外观 + 内部发光
	for y in range(size):
		for x in range(size):
			var dx: float = abs(float(x) - center)
			var dy: float = abs(float(y) - center)
			var diamond_d: float = dx + dy
			if diamond_d <= radius:
				var alpha: float = 1.0 - (diamond_d / radius) * 0.5
				var core_x: float = float(x) - center
				var core_y: float = float(y) - center
				var core_d: float = sqrt(core_x * core_x + core_y * core_y)
				if core_d < 3.0:
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
				else:
					img.set_pixel(x, y, Color(0.55, 0.92, 1.0, alpha * 0.75))
	return ImageTexture.create_from_image(img)

# ============================================
# 资源清理 - 防止经验球泄漏
# ============================================
func _exit_tree() -> void:
	if _mm_node:
		_mm_node.multimesh = null
		_mm_node.queue_free()
	_mm = MultiMesh.new()
