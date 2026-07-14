extends SceneTree

const WeaponProjectileArt = preload("res://scripts/weapon_presentation/WeaponProjectileArt.gd")

## 高清弹体预览导出（与实机 WeaponProjectileArt 一致）

const OUT_DIR := "res://assets/previews/weapon_projectiles"
const WEAPONS: Array[Dictionary] = [
	{"id": "kunai", "name": "苦无", "color": Color(0.55, 0.92, 1.0)},
	{"id": "quantum_ball", "name": "量子球", "color": Color(0.62, 1.0, 0.58)},
	{"id": "lightning", "name": "雷电", "color": Color(0.62, 0.98, 1.0)},
	{"id": "rocket", "name": "火箭", "color": Color(1.0, 0.55, 0.28)},
	{"id": "molotov", "name": "燃烧瓶", "color": Color(1.0, 0.52, 0.22)},
	{"id": "boomerang", "name": "回旋镖", "color": Color(1.0, 0.82, 0.35)},
	{"id": "drone_ab", "name": "无人机", "color": Color(0.72, 0.92, 1.0)},
	{"id": "guardian", "name": "守卫者", "color": Color(1.0, 0.86, 0.42)},
	{"id": "frost_aura", "name": "冰霜光环", "color": Color(0.55, 0.88, 1.0)},
	{"id": "heal_aura", "name": "治疗光环", "color": Color(0.45, 1.0, 0.62)},
	{"id": "stun_mine", "name": "眩晕地雷", "color": Color(0.88, 0.55, 1.0)},
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var sprites: Dictionary = {}
	for w in WEAPONS:
		var kind: String = w["id"]
		var img := WeaponProjectileArt.render_kind(kind, 0)
		var solo_path := "%s/%s.png" % [OUT_DIR, kind]
		img.save_png(ProjectSettings.globalize_path(solo_path))
		sprites[kind] = img
	var sheet := _make_sheet(sprites)
	var sheet_path := "%s/preview_sheet.png" % OUT_DIR
	sheet.save_png(ProjectSettings.globalize_path(sheet_path))
	print("weapon_projectile_preview_hd: wrote %d solo + sheet" % WEAPONS.size())
	quit(0)


func _make_sheet(sprites: Dictionary) -> Image:
	var cols := 4
	var rows := int(ceil(float(WEAPONS.size()) / float(cols)))
	var cell_w := 300
	var cell_h := 240
	var pad := 24
	var title_h := 48
	var w := cols * cell_w + pad * 2
	var h := title_h + rows * cell_h + pad * 2
	var sheet := Image.create(w, h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.06, 0.07, 0.1, 1.0))
	for i in range(WEAPONS.size()):
		var info: Dictionary = WEAPONS[i]
		var col := i % cols
		var row := int(i / cols)
		var ox := pad + col * cell_w
		var oy := title_h + pad + row * cell_h
		var bar: Color = info["color"]
		_fill_rect(sheet, ox + 8, oy + 8, cell_w - 16, cell_h - 16, Color(0.1, 0.11, 0.15, 1.0))
		_fill_rect(sheet, ox + 8, oy + 8, cell_w - 16, 3, bar)
		var spr: Image = sprites[info["id"]]
		var solo := spr.duplicate()
		solo.resize(160, 160, Image.INTERPOLATE_LANCZOS)
		_blit(sheet, solo, ox + 16, oy + 28)
		for v in range(3):
			var mini := spr.duplicate()
			mini.resize(96, 96, Image.INTERPOLATE_LANCZOS)
			_blit(sheet, mini, ox + 156 + v * 46, oy + 44 + v * 10)
	return sheet


func _blit(dst: Image, src: Image, x: int, y: int) -> void:
	for py in range(src.get_height()):
		for px in range(src.get_width()):
			var c := src.get_pixel(px, py)
			if c.a < 0.04:
				continue
			var dx := x + px
			var dy := y + py
			if dx >= 0 and dy >= 0 and dx < dst.get_width() and dy < dst.get_height():
				dst.set_pixel(dx, dy, c)


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, col)
