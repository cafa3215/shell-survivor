extends SceneTree

## 将 Kenney Particle Pack（CC0）映射到各武器弹体目录。
## 来源：https://github.com/Calinou/kenney-particle-pack

const KENNEY_ROOT := "res://assets/vendor/kenney_particle_pack/"
const OUT_ROOT := "res://assets/game_pack/vfx/projectiles/"

const WEAPON_FRAMES: Dictionary = {
	"kunai": ["trace_01.png", "trace_02.png", "trace_03.png", "trace_04.png"],
	"quantum_ball": ["magic_01.png", "magic_02.png", "magic_03.png", "magic_04.png"],
	"lightning": ["spark_01.png", "spark_02.png", "spark_03.png", "spark_04.png"],
	"active_bolt": ["spark_05.png", "spark_06.png", "spark_07.png", "spark_04.png"],
	"rocket": ["flame_05.png", "flame_06.png", "muzzle_03.png", "trace_05.png"],
	"molotov": ["flame_01.png", "flame_02.png", "flame_03.png", "flame_04.png"],
	"guardian": ["slash_02.png", "slash_03.png", "twirl_01.png", "twirl_02.png"],
	"drone_ab": ["star_05.png", "star_06.png", "light_02.png", "light_03.png"],
	"boomerang": ["twirl_01.png", "twirl_02.png", "twirl_03.png", "twirl_02.png"],
	"frost_aura": ["magic_05.png", "magic_04.png", "magic_03.png", "magic_02.png"],
	"heal_aura": ["star_01.png", "star_02.png", "star_03.png", "star_04.png"],
	"stun_mine": ["symbol_01.png", "symbol_02.png", "circle_03.png", "circle_04.png"],
}


func _init() -> void:
	var ok := 0
	var fail := 0
	for kind in WEAPON_FRAMES.keys():
		var frames: Array = WEAPON_FRAMES[kind]
		var dir_rel := "%s%s" % [OUT_ROOT, kind]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_rel))
		for i in frames.size():
			var src_rel := KENNEY_ROOT + String(frames[i])
			var dst_rel := "%s/frame_%d.png" % [dir_rel, i]
			var src_path := ProjectSettings.globalize_path(src_rel)
			var dst_path := ProjectSettings.globalize_path(dst_rel)
			if not FileAccess.file_exists(src_path):
				push_error("install_kenney_weapon_sprites: missing " + src_rel)
				fail += 1
				continue
			var err := DirAccess.copy_absolute(src_path, dst_path)
			if err == OK:
				ok += 1
			else:
				push_error("install_kenney_weapon_sprites: copy failed %s -> %s (%s)" % [src_rel, dst_rel, str(err)])
				fail += 1
	print("install_kenney_weapon_sprites: copied %d frames, %d failures" % [ok, fail])
	quit(0 if fail == 0 else 1)
