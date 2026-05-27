extends Camera2D
class_name CameraShake

# ============================================
# 屏幕震动系统 - 打击感增强
# ============================================

@export var default_shake_strength := 5.0
@export var default_shake_duration := 0.3
@export var shake_decay := 8.0

var _shake_strength := 0.0
var _shake_duration := 0.0
var _shake_timer := 0.0
var _random_offset := Vector2.ZERO
var _original_position := Vector2.ZERO
var _smoothed_offset := Vector2.ZERO

func _ready() -> void:
	_original_position = position
	# Game.gd forwards EventBus.screen_shake to this node; avoid double subscription.

func _process(delta: float) -> void:
	if _shake_timer > 0:
		_shake_timer -= delta
		
		# 计算当前震动强度（随时间衰减）
		var current_strength := _shake_strength * (_shake_timer / _shake_duration)
		
		# 生成随机偏移
		_random_offset = Vector2(
			randf_range(-current_strength, current_strength),
			randf_range(-current_strength, current_strength)
		)
		# 相机抖动只作用于 offset，避免与跟随平滑/父节点位移叠加导致“视角异常”。
		_smoothed_offset = _smoothed_offset.lerp(_random_offset, clampf(delta * 22.0, 0.0, 1.0))
		offset = _smoothed_offset
		
		# 震动结束
		if _shake_timer <= 0:
			offset = Vector2.ZERO
			_random_offset = Vector2.ZERO
			_smoothed_offset = Vector2.ZERO

func shake(strength: float = -1.0, duration: float = -1.0) -> void:
	var s := strength if strength > 0 else default_shake_strength
	var d := duration if duration > 0 else default_shake_duration
	if Settings.reduce_screen_motion:
		s *= 0.32
		d *= 0.75
	
	# 如果当前震动更强，不覆盖
	if _shake_timer > 0 and s < _shake_strength * (_shake_timer / _shake_duration):
		return
	
	_shake_strength = s
	_shake_duration = d
	_shake_timer = d
