extends SceneTree

const ArtSample = preload("res://scripts/weapon_presentation/WeaponProjectileArtSample.gd")

## 导出弹体小样（Neon Survivor v2）— 未合入实机

const OUT_DIR := "res://assets/previews/weapon_projectiles/sample_v2"
const COMBAT: PackedStringArray = ["kunai", "quantum_ball", "lightning", "rocket", "boomerang", "drone_ab"]
const WEAPONS: Array[Dictionary] = [
	{"id": "kunai", "name": "苦无", "color": Color(0.55, 0.92, 1.0), "tag": "长刃·金护手·缠绳柄"},
	{"id": "quantum_ball", "name": "量子球", "color": Color(0.62, 1.0, 0.58), "tag": "双六角·轨道节点·亮核"},
	{"id": "lightning", "name": "雷电", "color": Color(0.62, 0.98, 1.0), "tag": "粗锯齿·分叉·电晕"},
	{"id": "rocket", "name": "火箭", "color": Color(1.0, 0.55, 0.28), "tag": "锥头·四翼·双层焰"},
	{"id": "boomerang", "name": "回旋镖", "color": Color(1.0, 0.82, 0.35), "tag": "厚V双翼·握点"},
	{"id": "drone_ab", "name": "无人机", "color": Color(0.72, 0.92, 1.0), "tag": "四旋翼·镜头·天线"},
	{"id": "molotov", "name": "燃烧瓶", "color": Color(1.0, 0.52, 0.22), "tag": "瓶身·布条·火焰"},
	{"id": "guardian", "name": "守卫者", "color": Color(1.0, 0.86, 0.42), "tag": "盾形·纹章"},
	{"id": "frost_aura", "name": "冰霜", "color": Color(0.55, 0.88, 1.0), "tag": "六臂雪花"},
	{"id": "heal_aura", "name": "治疗", "color": Color(0.45, 1.0, 0.62), "tag": "绿环·粗十字"},
	{"id": "stun_mine", "name": "地雷", "color": Color(0.88, 0.55, 1.0), "tag": "刺六角·闪烁核"},
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var sprites: Dictionary = {}
	for w in WEAPONS:
		var kind: String = w["id"]
		var img := ArtSample.render_kind(kind, 0)
		img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, kind]))
		sprites[kind] = img
		for f in range(4):
			var anim := ArtSample.render_kind(kind, f)
			anim.save_png(ProjectSettings.globalize_path("%s/%s_f%d.png" % [OUT_DIR, kind, f]))
	var sheet := _make_sheet(sprites)
	sheet.save_png(ProjectSettings.globalize_path("%s/preview_sheet.png" % OUT_DIR))
	var combat := _make_combat_demo()
	combat.save_png(ProjectSettings.globalize_path("%s/combat_volley_demo.png" % OUT_DIR))
	print("sample_v2 [%s]: %d weapons + sheet + combat demo -> %s" % [
		ArtSample.style_id(), WEAPONS.size(), ProjectSettings.globalize_path(OUT_DIR)
	])
	quit(0)


func _make_sheet(sprites: Dictionary) -> Image:
	var cols := 4
	var rows := int(ceil(float(WEAPONS.size()) / float(cols)))
	var cell_w := 320
	var cell_h := 260
	var pad := 28
	var header := 72
	var w := cols * cell_w + pad * 2
	var h := header + rows * cell_h + pad * 2
	var sheet := Image.create(w, h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.05, 0.06, 0.09, 1.0))
	_label_bar(sheet, pad, 18, w - pad * 2, "Neon Survivor v2 — weapon projectile sample (preview only)")
	for i in range(WEAPONS.size()):
		var info: Dictionary = WEAPONS[i]
		var col := i % cols
		var row := int(i / cols)
		var ox := pad + col * cell_w
		var oy := header + pad + row * cell_h
		var bar: Color = info["color"]
		_fill_rect(sheet, ox + 10, oy + 10, cell_w - 20, cell_h - 20, Color(0.09, 0.1, 0.14, 1.0))
		_fill_rect(sheet, ox + 10, oy + 10, cell_w - 20, 4, bar)
		var spr: Image = sprites[info["id"]]
		var solo := spr.duplicate()
		solo.resize(168, 168, Image.INTERPOLATE_LANCZOS)
		_blit(sheet, solo, ox + 24, oy + 36)
		for v in range(3):
			var mini := ArtSample.render_kind(info["id"], v + 1).duplicate()
			mini.resize(72, 72, Image.INTERPOLATE_LANCZOS)
			_blit(sheet, mini, ox + 178 + v * 42, oy + 52 + v * 12)
	return sheet


func _make_combat_demo() -> Image:
	var w := 960
	var h := 320
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.05, 0.08, 1.0))
	_label_bar(img, 24, 16, w - 48, "Combat volley readability (dark swarm background sim)")
	var slots := COMBAT.size()
	for i in range(slots):
		var kind := COMBAT[i]
		var ox := 40 + i * 150
		var oy := 100
		for j in range(5):
			var p := ArtSample.render_kind(kind, j).duplicate()
			p.resize(56, 56, Image.INTERPOLATE_LANCZOS)
			_blit(img, p, ox + j * 22, oy + j * 8)
		for k in range(40):
			var rx := ox + (k * 17) % 130
			var ry := oy + 90 + (k * 11) % 140
			_fill_rect(img, rx, ry, 6, 6, Color(0.18, 0.22, 0.32, 0.55))
	return img


func _label_bar(img: Image, x: int, y: int, width: int, _text: String) -> void:
	_fill_rect(img, x, y, width, 3, Color(0.35, 0.55, 0.85, 0.85))


func _blit(dst: Image, src: Image, x: int, y: int) -> void:
	for py in range(src.get_height()):
		for px in range(src.get_width()):
			var c := src.get_pixel(px, py)
			if c.a < 0.04:
				continue
			var dx := x + px
			var dy := y + py
			if dx >= 0 and dy >= 0 and dx < dst.get_width() and dy < dst.get_height():
				var bg := dst.get_pixel(dx, dy)
				var a := c.a + bg.a * (1.0 - c.a)
				if a <= 0.0001:
					continue
				dst.set_pixel(dx, dy, Color(
					(c.r * c.a + bg.r * bg.a * (1.0 - c.a)) / a,
					(c.g * c.a + bg.g * bg.a * (1.0 - c.a)) / a,
					(c.b * c.a + bg.b * bg.a * (1.0 - c.a)) / a,
					a
				))


func _fill_rect(img: Image, x: int, y: int, rw: int, rh: int, col: Color) -> void:
	for py in range(y, y + rh):
		for px in range(x, x + rw):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, col)
