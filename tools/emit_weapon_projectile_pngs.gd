extends SceneTree

## 导出与实机一致的 HD 弹体 PNG（WeaponProjectileArt）

const WeaponProjectileArt = preload("res://scripts/weapon_presentation/WeaponProjectileArt.gd")
const OUT_ROOT := "res://assets/game_pack/vfx/projectiles"
const KINDS: PackedStringArray = [
	"kunai", "quantum_ball", "lightning", "rocket", "molotov",
	"guardian", "drone_ab", "boomerang", "frost_aura", "stun_mine", "heal_aura", "active_bolt"
]


func _init() -> void:
	var ok := 0
	for kind in KINDS:
		var dir_rel := "%s/%s" % [OUT_ROOT, kind]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_rel))
		for frame in 4:
			var img := WeaponProjectileArt.render_kind(kind, frame)
			var path_rel := "%s/frame_%d.png" % [dir_rel, frame]
			if img.save_png(ProjectSettings.globalize_path(path_rel)) == OK:
				ok += 1
			else:
				push_error("emit_weapon_projectile_pngs: failed " + path_rel)
	print("emit_weapon_projectile_pngs: wrote %d hd png files" % ok)
	quit(0 if ok == KINDS.size() * 4 else 1)
