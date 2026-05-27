extends Node

## 打击反馈分级：先按类别封顶强度，再交给 CameraShake 做「减轻动效」缩放（R6）
const _SHAKE_CAP := {
	"minion": 2.7,
	"hit": 4.0,
	"heavy": 5.4,
	"boss": 8.8,
	"mega": 6.0,
	"player_hit": 7.2,
	"ui": 3.2,
}


func shake(category: String, strength: float, duration: float) -> void:
	var cap: float = float(_SHAKE_CAP.get(category, 4.0))
	EventBus.screen_shake.emit(minf(strength, cap), duration)


func flash(color: Color, duration: float, tier: String = "normal") -> void:
	var c := color
	match tier:
		"subtle":
			c.a *= 0.75
		"strong":
			c.a = minf(c.a * 1.12, 0.95)
		_:
			pass
	EventBus.screen_flash.emit(c, duration)
