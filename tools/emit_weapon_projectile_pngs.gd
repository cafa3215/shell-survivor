extends SceneTree

## 为 WeaponProjectileLayer 生成可读性更好的占位弹体 PNG（64×64，带描边）。

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
		var img := _make_sprite(kind)
		for frame in 4:
			var framed := img.duplicate()
			if frame > 0:
				framed = _nudge_frame(framed, kind, frame)
			var path_rel := "%s/frame_%d.png" % [dir_rel, frame]
			if framed.save_png(ProjectSettings.globalize_path(path_rel)) == OK:
				ok += 1
			else:
				push_error("emit_weapon_projectile_pngs: failed " + path_rel)
	print("emit_weapon_projectile_pngs: wrote %d png files" % ok)
	quit(0 if ok == KINDS.size() * 4 else 1)


func _make_sprite(kind: String) -> Image:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(size) * 0.5
	var cy := float(size) * 0.5
	match kind:
		"kunai":
			_draw_poly(img, PackedVector2Array([
				Vector2(52, 32), Vector2(30, 18), Vector2(14, 32), Vector2(30, 46)
			]), Color(0.08, 0.12, 0.18, 1.0), Color(0.55, 0.92, 1.0, 1.0))
		"lightning", "active_bolt":
			_draw_poly(img, PackedVector2Array([
				Vector2(18, 10), Vector2(36, 10), Vector2(28, 28), Vector2(46, 28), Vector2(22, 54), Vector2(30, 34), Vector2(16, 34)
			]), Color(0.06, 0.14, 0.22, 1.0), Color(0.62, 0.98, 1.0, 1.0))
		"rocket":
			_draw_poly(img, PackedVector2Array([
				Vector2(54, 32), Vector2(34, 18), Vector2(12, 32), Vector2(34, 46)
			]), Color(0.18, 0.08, 0.04, 1.0), Color(1.0, 0.55, 0.28, 1.0))
			_fill_rect(img, 8, 28, 10, 8, Color(1.0, 0.78, 0.35, 0.95))
		"molotov":
			_fill_round_rect(img, 24, 16, 16, 28, 4, Color(0.16, 0.08, 0.04, 1.0), Color(1.0, 0.52, 0.22, 1.0))
			_fill_round_rect(img, 26, 10, 12, 8, 2, Color(0.12, 0.06, 0.02, 1.0), Color(1.0, 0.82, 0.42, 1.0))
		"quantum_ball":
			_fill_circle(img, cx, cy, 18, Color(0.08, 0.1, 0.18, 1.0), Color(0.72, 0.42, 1.0, 1.0))
			_fill_circle(img, cx, cy, 10, Color(0, 0, 0, 0), Color(0.92, 0.82, 1.0, 0.85))
		"guardian":
			_draw_poly(img, PackedVector2Array([
				Vector2(32, 8), Vector2(48, 32), Vector2(32, 56), Vector2(16, 32)
			]), Color(0.12, 0.1, 0.04, 1.0), Color(1.0, 0.86, 0.42, 1.0))
		"drone_ab":
			_fill_round_rect(img, 20, 24, 24, 16, 4, Color(0.08, 0.12, 0.18, 1.0), Color(0.72, 0.92, 1.0, 1.0))
			_fill_rect(img, 8, 30, 48, 4, Color(0.55, 0.82, 1.0, 0.85))
		"boomerang":
			_draw_poly(img, PackedVector2Array([
				Vector2(14, 16), Vector2(50, 16), Vector2(42, 24), Vector2(22, 24)
			]), Color(0.14, 0.1, 0.02, 1.0), Color(1.0, 0.82, 0.35, 1.0))
			_draw_poly(img, PackedVector2Array([
				Vector2(14, 48), Vector2(50, 48), Vector2(42, 40), Vector2(22, 40)
			]), Color(0.14, 0.1, 0.02, 1.0), Color(1.0, 0.82, 0.35, 1.0))
		"frost_aura":
			_fill_circle(img, cx, cy, 20, Color(0.06, 0.12, 0.18, 1.0), Color(0.55, 0.88, 1.0, 0.82))
			for a in 6:
				var ang := float(a) * TAU / 6.0
				_fill_circle(img, cx + cos(ang) * 14.0, cy + sin(ang) * 14.0, 4, Color(0, 0, 0, 0), Color(0.82, 0.98, 1.0, 0.9))
		"heal_aura":
			_fill_circle(img, cx, cy, 20, Color(0.04, 0.14, 0.08, 1.0), Color(0.45, 1.0, 0.62, 0.82))
			_fill_rect(img, 28, 18, 8, 28, Color(0.82, 1.0, 0.88, 0.95))
			_fill_rect(img, 18, 28, 28, 8, Color(0.82, 1.0, 0.88, 0.95))
		"stun_mine":
			_fill_circle(img, cx, cy, 16, Color(0.12, 0.08, 0.16, 1.0), Color(0.88, 0.55, 1.0, 1.0))
			_fill_circle(img, cx, cy, 6, Color(0, 0, 0, 0), Color(1.0, 0.92, 1.0, 0.9))
		_:
			_fill_circle(img, cx, cy, 14, Color(0.1, 0.1, 0.1, 1.0), Color(0.9, 0.9, 0.9, 1.0))
	img.resize(96, 96, Image.INTERPOLATE_NEAREST)
	return img


func _nudge_frame(img: Image, kind: String, frame: int) -> Image:
	var shift := float(frame - 1) * 0.6
	if kind == "rocket":
		var flame := 6 + frame * 2
		_fill_rect(img, 6, 32 - flame / 2, flame + 4, flame, Color(1.0, 0.72, 0.28, 0.92))
	elif kind == "drone_ab":
		var wing := 10 + frame * 3
		_fill_rect(img, wing, 30, 64 - wing * 2, 4, Color(0.62, 0.86, 1.0, 0.88))
	return img


func _draw_poly(img: Image, pts: PackedVector2Array, outline: Color, fill: Color) -> void:
	_fill_polygon(img, pts, outline)
	var inset := PackedVector2Array()
	for p in pts:
		inset.append(Vector2(lerpf(p.x, 32.0, 0.12), lerpf(p.y, 32.0, 0.12)))
	_fill_polygon(img, inset, fill)


func _fill_polygon(img: Image, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var min_x := 9999
	var min_y := 9999
	var max_x := 0
	var max_y := 0
	for p in pts:
		min_x = mini(min_x, int(p.x))
		min_y = mini(min_y, int(p.y))
		max_x = maxi(max_x, int(p.x))
		max_y = maxi(max_y, int(p.y))
	for y in range(mini(min_y, img.get_height() - 1), maxi(max_y, 0) + 1):
		for x in range(mini(min_x, img.get_width() - 1), maxi(max_x, 0) + 1):
			if _point_in_poly(Vector2(x, y), pts):
				img.set_pixel(x, y, col)


func _point_in_poly(p: Vector2, pts: PackedVector2Array) -> bool:
	var inside := false
	var j := pts.size() - 1
	for i in pts.size():
		var pi: Vector2 = pts[i]
		var pj: Vector2 = pts[j]
		if ((pi.y > p.y) != (pj.y > p.y)) and (p.x < (pj.x - pi.x) * (p.y - pi.y) / maxf(0.001, pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside


func _fill_circle(img: Image, cx: float, cy: float, r: float, outline: Color, fill: Color) -> void:
	for y in range(int(cy - r - 2), int(cy + r + 3)):
		for x in range(int(cx - r - 2), int(cx + r + 3)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d := Vector2(x - cx, y - cy).length()
			if d <= r:
				img.set_pixel(x, y, fill if d <= r - 2.0 else outline)


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, col)


func _fill_round_rect(img: Image, x: int, y: int, w: int, h: int, r: int, outline: Color, fill: Color) -> void:
	_fill_rect(img, x + r, y, w - 2 * r, h, outline)
	_fill_rect(img, x, y + r, w, h - 2 * r, outline)
	_fill_circle(img, x + r, y + r, r, outline, fill)
	_fill_circle(img, x + w - r, y + r, r, outline, fill)
	_fill_circle(img, x + r, y + h - r, r, outline, fill)
	_fill_circle(img, x + w - r, y + h - r, r, outline, fill)
