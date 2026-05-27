extends Label
class_name DamageNumber

# ============================================
# 伤害跳字 - 打击感视觉反馈
# ============================================

var _velocity := Vector2.ZERO
var _gravity := 150.0
var _lifetime := 0.0
var _max_lifetime := 0.8
var _initial_position := Vector2.ZERO
var _is_critical := false
const _PLAYER_CLEAR_RADIUS := 64.0

func _ready() -> void:
	z_index = 100
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func setup(amount: float, position: Vector2, is_crit := false) -> void:
	_is_critical = is_crit
	visible = true
	set_process(true)
	scale = Vector2.ONE
	var spawn_pos := _resolve_spawn_position(position)
	global_position = spawn_pos
	_initial_position = spawn_pos
	
	# 根据伤害值调整大小
	var size_scale := 1.0
	if amount > 100:
		size_scale = 1.3
	elif amount > 50:
		size_scale = 1.1
	
	# 暴击更大
	if is_crit:
		size_scale *= 1.4
	
	# 设置文字
	text = str(int(amount))
	theme_type_variation = &"Label.DamageCrit" if is_crit else &"Label.DamageNormal"
	
	# 随机初速度（向上飘）
	var angle := randf_range(-PI * 0.3, PI * 0.3) - PI / 2
	var speed := randf_range(60.0, 100.0)
	if is_crit:
		speed *= 1.3
	
	_velocity = Vector2(cos(angle), sin(angle)) * speed
	
	# 动画（使用简单的lerp，避免tween回调问题）
	_lifetime = 0.0

func _resolve_spawn_position(position: Vector2) -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var clear_radius := _player_clear_radius_scaled()
	if player == null:
		return position + Vector2(randf_range(-8.0, 8.0), randf_range(-26.0, -14.0))
	var to_hit := position - player.global_position
	if to_hit.length() < clear_radius:
		var side := signf(to_hit.x)
		if absf(side) < 0.1:
			side = -1.0 if randf() < 0.5 else 1.0
		var offset := Vector2(22.0 * side, -34.0 + randf_range(-6.0, 4.0))
		return player.global_position + offset
	return position + Vector2(randf_range(-10.0, 10.0), randf_range(-24.0, -10.0))

func _player_clear_radius_scaled() -> float:
	match int(Settings.readability_preset):
		Settings.ReadabilityPreset.LOW:
			return _PLAYER_CLEAR_RADIUS * 0.72
		Settings.ReadabilityPreset.HIGH:
			return _PLAYER_CLEAR_RADIUS * 1.35
		_:
			return _PLAYER_CLEAR_RADIUS

func _process(delta: float) -> void:
	# 物理移动
	_velocity.y += _gravity * delta
	global_position += _velocity * delta
	
	_lifetime += delta
	
	# 缩放：ease-out 弹出 → ease-in 回落（Godot ease 负值偏出、正值偏入）
	var scale_target := 1.0
	if _lifetime < 0.085:
		var t0 := clampf(_lifetime / 0.085, 0.0, 1.0)
		scale_target = lerpf(0.82, 1.22, ease(t0, -2.35))
	elif _lifetime < _max_lifetime:
		var t1 := clampf((_lifetime - 0.085) / (_max_lifetime - 0.085), 0.0, 1.0)
		scale_target = lerpf(1.22, 1.0, ease(t1, 1.55))
	scale = Vector2.ONE * scale_target
	
	if _lifetime > 0.28:
		# Step final convergence: keep timing, remove alpha styling path.
		pass
	
	if _lifetime >= _max_lifetime:
		visible = false
		set_process(false)
