extends Node2D
## 仅用于 `SkillsDemo`：WeaponTelegraph 反馈入口的最小桩。

func add_hit_feedback(
		_pos: Vector2,
		_weapon_kind: String,
		_hit_type: StringName = &"normal",
		_intensity: float = 1.0
	) -> void:
	pass
