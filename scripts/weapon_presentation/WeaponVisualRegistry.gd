class_name WeaponVisualRegistry
extends RefCounted

## 武器视觉身份注册表：配色 / 弹道 / 挂载参数的单点来源。

const THEMES := {
	"kunai": {
		"primary": Color(0.72, 0.92, 1.0, 1.0),
		"secondary": Color(0.28, 0.52, 0.72, 1.0),
		"accent": Color(0.45, 0.98, 1.0, 1.0),
		"trail": Color(0.55, 0.82, 1.0, 0.72),
		"mount_scale": 0.88,
		"projectile_scale": 1.38,
		"silhouette": "blade",
	},
	"quantum_ball": {
		"primary": Color(0.62, 1.0, 0.58, 1.0),
		"secondary": Color(0.22, 0.62, 0.38, 1.0),
		"accent": Color(0.88, 1.0, 0.72, 1.0),
		"trail": Color(0.48, 0.95, 0.55, 0.68),
		"mount_scale": 0.98,
		"projectile_scale": 1.36,
		"silhouette": "hex",
	},
	"lightning": {
		"primary": Color(0.58, 0.82, 1.0, 1.0),
		"secondary": Color(0.18, 0.38, 0.82, 1.0),
		"accent": Color(0.82, 0.95, 1.0, 1.0),
		"trail": Color(0.42, 0.72, 1.0, 0.75),
		"mount_scale": 0.92,
		"projectile_scale": 1.48,
		"silhouette": "bolt",
	},
	"rocket": {
		"primary": Color(1.0, 0.58, 0.28, 1.0),
		"secondary": Color(0.72, 0.22, 0.12, 1.0),
		"accent": Color(1.0, 0.88, 0.42, 1.0),
		"trail": Color(1.0, 0.62, 0.18, 0.78),
		"mount_scale": 1.04,
		"projectile_scale": 1.52,
		"silhouette": "rocket",
	},
	"molotov": {
		"primary": Color(1.0, 0.52, 0.18, 1.0),
		"secondary": Color(0.62, 0.18, 0.08, 1.0),
		"accent": Color(1.0, 0.78, 0.28, 1.0),
		"trail": Color(1.0, 0.45, 0.12, 0.72),
		"mount_scale": 0.94,
		"projectile_scale": 1.16,
		"silhouette": "bottle",
	},
	"guardian": {
		"primary": Color(1.0, 0.82, 0.42, 1.0),
		"secondary": Color(0.62, 0.42, 0.12, 1.0),
		"accent": Color(1.0, 0.95, 0.68, 1.0),
		"trail": Color(1.0, 0.72, 0.28, 0.68),
		"mount_scale": 1.0,
		"projectile_scale": 1.28,
		"silhouette": "shield",
	},
	"drone_ab": {
		"primary": Color(0.68, 0.88, 1.0, 1.0),
		"secondary": Color(0.22, 0.48, 0.72, 1.0),
		"accent": Color(0.82, 0.98, 1.0, 1.0),
		"trail": Color(0.52, 0.78, 1.0, 0.7),
		"mount_scale": 0.9,
		"projectile_scale": 1.14,
		"silhouette": "drone",
	},
	"boomerang": {
		"primary": Color(1.0, 0.78, 0.28, 1.0),
		"secondary": Color(0.72, 0.48, 0.08, 1.0),
		"accent": Color(1.0, 0.92, 0.55, 1.0),
		"trail": Color(1.0, 0.68, 0.22, 0.72),
		"mount_scale": 0.96,
		"projectile_scale": 1.2,
		"silhouette": "crescent",
	},
	"frost_aura": {
		"primary": Color(0.55, 0.92, 1.0, 1.0),
		"secondary": Color(0.18, 0.52, 0.78, 1.0),
		"accent": Color(0.82, 0.98, 1.0, 1.0),
		"trail": Color(0.42, 0.82, 1.0, 0.62),
		"mount_scale": 0.88,
		"projectile_scale": 1.24,
		"silhouette": "ring",
	},
	"heal_aura": {
		"primary": Color(0.42, 1.0, 0.68, 1.0),
		"secondary": Color(0.12, 0.62, 0.38, 1.0),
		"accent": Color(0.72, 1.0, 0.82, 1.0),
		"trail": Color(0.38, 0.95, 0.62, 0.62),
		"mount_scale": 0.86,
		"projectile_scale": 1.22,
		"silhouette": "cross",
	},
	"stun_mine": {
		"primary": Color(0.78, 0.62, 1.0, 1.0),
		"secondary": Color(0.38, 0.22, 0.72, 1.0),
		"accent": Color(1.0, 0.88, 0.45, 1.0),
		"trail": Color(0.68, 0.52, 1.0, 0.72),
		"mount_scale": 0.84,
		"projectile_scale": 1.08,
		"silhouette": "mine",
	},
}


static func theme(kind: String) -> Dictionary:
	return THEMES.get(kind, THEMES["kunai"])


static func primary(kind: String) -> Color:
	return theme(kind).get("primary", Color.WHITE)


static func secondary(kind: String) -> Color:
	return theme(kind).get("secondary", Color(0.3, 0.3, 0.35))


static func accent(kind: String) -> Color:
	return theme(kind).get("accent", Color.WHITE)


static func trail(kind: String) -> Color:
	return theme(kind).get("trail", primary(kind))


static func mount_scale(kind: String) -> float:
	return float(theme(kind).get("mount_scale", 0.9))


static func projectile_scale(kind: String) -> float:
	return float(theme(kind).get("projectile_scale", 1.15))


static func silhouette(kind: String) -> String:
	return String(theme(kind).get("silhouette", "blade"))
