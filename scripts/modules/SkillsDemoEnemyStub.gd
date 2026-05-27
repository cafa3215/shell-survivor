extends Node2D
## 仅用于 `SkillsDemo`：EnemyManager 命中路径的最小桩（空命中列表）。

func apply_piercing_line_damage_with_hit_positions(
		_from: Vector2,
		_to: Vector2,
		_half_w: float,
		_dmg: float,
		_source: StringName,
		_cast_seq: int = 0
	) -> PackedVector2Array:
	return PackedVector2Array()
