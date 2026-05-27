class_name WeaponTheme
extends Resource

## 单把武器的「样式载体」主题：配色与特效预设入口（弹道层可再读 projectile_style_id）。

@export var weapon_id: StringName = &""
@export var primary: Color = Color(0.85, 0.92, 1.0, 1.0)
@export var secondary: Color = Color(0.45, 0.55, 0.72, 1.0)
@export var accent: Color = Color(0.35, 0.88, 1.0, 1.0)
## 预留：与弹道/命中层对齐的样式 id（中长期与 WeaponProjectileLayer 解耦）
@export var projectile_style_id: StringName = &""
