extends SceneTree

## 生成 game_pack 核心贴图（主角 / 地面 / 敌人 atlas），解决「只有 .import、无源 PNG」导致骨架/灰底。

const OUT_DIR := "res://assets/game_pack/textures"


func _init() -> void:
	var ok := 0
	var total := 0
	total += 1
	if _write_png("%s/player_chibi.png" % OUT_DIR, _make_player_chibi(512, 512)):
		ok += 1
	total += 1
	if _write_png("%s/player_run_strip.png" % OUT_DIR, _make_player_run_strip(256, 256)):
		ok += 1
	total += 1
	if _write_png("%s/ground_tile.png" % OUT_DIR, _build_ground_tile(1800, 1800)):
		ok += 1
	total += 1
	if _write_png("%s/enemy_atlas.png" % OUT_DIR, _make_enemy_atlas(64)):
		ok += 1
	print("emit_game_pack_textures: wrote %d/%d" % [ok, total])
	quit(0 if ok == total else 1)


func _write_png(rel_path: String, img: Image) -> bool:
	var abs_path := ProjectSettings.globalize_path(rel_path)
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("emit_game_pack_textures: save failed %s err=%s" % [rel_path, str(err)])
		return false
	return true


func _make_player_chibi(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(w) * 0.5
	var cy := float(h) * 0.56
	var outline := Color(0.02, 0.05, 0.12, 1.0)
	var armor := Color(0.12, 0.42, 0.58, 1.0)
	var armor_hi := Color(0.28, 0.78, 0.92, 1.0)
	var accent := Color(0.95, 0.55, 0.18, 1.0)
	var visor := Color(0.35, 0.98, 1.0, 0.95)
	var boot := Color(0.06, 0.08, 0.14, 1.0)
	_fill_ellipse(img, cx, cy + h * 0.18, w * 0.16, h * 0.05, Color(0, 0.1, 0.18, 0.35))
	# 披风/能源背包
	_draw_round_rect(img, cx - w * 0.17, cy + h * 0.02, w * 0.34, h * 0.12, w * 0.04, outline)
	_draw_round_rect(img, cx - w * 0.15, cy + h * 0.03, w * 0.30, h * 0.10, w * 0.03, Color(0.08, 0.16, 0.24, 1.0))
	_draw_round_rect(img, cx - w * 0.04, cy + h * 0.05, w * 0.08, h * 0.03, w * 0.01, accent)
	# 腿甲
	for side: float in [-1.0, 1.0]:
		var lx: float = cx + side * w * 0.08
		_draw_round_rect(img, lx - w * 0.055, cy + h * 0.12, w * 0.11, h * 0.18, w * 0.025, outline)
		_draw_round_rect(img, lx - w * 0.045, cy + h * 0.13, w * 0.09, h * 0.16, w * 0.02, boot)
	# 躯干
	_draw_round_rect(img, cx - w * 0.13, cy - h * 0.02, w * 0.26, h * 0.18, w * 0.05, outline)
	_draw_round_rect(img, cx - w * 0.115, cy - h * 0.015, w * 0.23, h * 0.16, w * 0.04, armor)
	_draw_round_rect(img, cx - w * 0.05, cy + h * 0.01, w * 0.10, h * 0.05, w * 0.015, armor_hi)
	# 肩甲
	for side: float in [-1.0, 1.0]:
		var sx: float = cx + side * w * 0.17
		_fill_circle(img, sx, cy - h * 0.01, w * 0.07, outline)
		_fill_circle(img, sx, cy - h * 0.01, w * 0.058, armor_hi if side > 0 else armor)
	# 头盔
	_fill_circle(img, cx, cy - h * 0.12, w * 0.13, outline)
	_fill_circle(img, cx, cy - h * 0.12, w * 0.11, armor)
	_fill_circle(img, cx, cy - h * 0.125, w * 0.075, visor)
	_fill_circle(img, cx - w * 0.02, cy - h * 0.13, w * 0.018, Color(1, 1, 1, 0.55))
	# 武器侧挂
	_draw_round_rect(img, cx + w * 0.12, cy + h * 0.02, w * 0.05, h * 0.14, w * 0.012, outline)
	_draw_round_rect(img, cx + w * 0.125, cy + h * 0.03, w * 0.035, h * 0.12, w * 0.01, accent)
	return img


func _make_player_run_strip(frame_w: int, frame_h: int) -> Image:
	var strip := Image.create(frame_w * 3, frame_h, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in 3:
		var frame := _make_player_chibi(frame_w, frame_h)
		var lean := float(i - 1) * 0.04
		if absf(lean) > 0.001:
			for y in frame_h:
				for x in frame_w:
					var src_x := clampi(x + int(round(float(i - 1) * 6.0)), 0, frame_w - 1)
					strip.set_pixel(i * frame_w + x, y, frame.get_pixel(src_x, y))
		else:
			strip.blit_rect(frame, Rect2i(0, 0, frame_w, frame_h), Vector2i(i * frame_w, 0))
	return strip


func _build_ground_tile(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var macro := 384
	var noise := FastNoiseLite.new()
	noise.seed = 12045
	noise.frequency = 0.018
	noise.fractal_octaves = 4
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var small := Image.create(macro, macro, false, Image.FORMAT_RGBA8)
	for y in macro:
		for x in macro:
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var br := 0.18 + n * 0.12
			var bg := 0.20 + n * 0.11
			var bb := 0.24 + n * 0.10
			small.set_pixel(x, y, Color(br, bg, bb, 1.0))
	small.resize(size, size, Image.INTERPOLATE_LANCZOS)
	img.blit_rect(small, Rect2i(0, 0, size, size), Vector2i(0, 0))
	var seam := Color(0.10, 0.12, 0.16, 1.0)
	var step := 360
	for x in range(0, size, step):
		for y in size:
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, c.lerp(seam, 0.08))
	for y in range(0, size, step):
		for x in size:
			var c2: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, c2.lerp(seam, 0.08))
	# 随机高光块
	for _i in 80:
		var px := randi() % size
		var py := randi() % size
		var c3: Color = img.get_pixel(px, py)
		img.set_pixel(px, py, Color(c3.r * 1.06, c3.g * 1.05, c3.b * 1.04, 1.0))
	return img


func _make_enemy_atlas(frame: int) -> Image:
	var atlas := Image.create(frame * 4, frame, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var styles: PackedStringArray = ["walker", "runner", "brute", "caster"]
	for i in styles.size():
		var cell := Image.create(frame, frame, false, Image.FORMAT_RGBA8)
		cell.fill(Color(0, 0, 0, 0))
		_draw_enemy_silhouette(cell, styles[i])
		atlas.blit_rect(cell, Rect2i(0, 0, frame, frame), Vector2i(i * frame, 0))
	return atlas


func _draw_enemy_silhouette(img: Image, style: String) -> void:
	var size := img.get_width()
	var cx := float(size) * 0.5
	var cy := float(size) * 0.58
	var outline := Color(0.05, 0.02, 0.08, 1.0)
	var body := Color(0.82, 0.22, 0.28, 1.0)
	match style:
		"runner":
			body = Color(0.95, 0.42, 0.18, 1.0)
			_fill_ellipse(img, cx + 4, cy, size * 0.14, size * 0.22, outline)
			_fill_ellipse(img, cx + 4, cy, size * 0.11, size * 0.18, body)
		"brute":
			body = Color(0.55, 0.28, 0.82, 1.0)
			_fill_ellipse(img, cx, cy, size * 0.24, size * 0.26, outline)
			_fill_ellipse(img, cx, cy, size * 0.20, size * 0.22, body)
		"caster":
			body = Color(0.22, 0.78, 0.62, 1.0)
			_fill_circle(img, cx, cy - 4, size * 0.13, outline)
			_fill_circle(img, cx, cy - 4, size * 0.10, body)
			for a in 4:
				var ang := float(a) * TAU / 4.0 + 0.2
				var sp := Vector2(cos(ang), sin(ang)) * size * 0.16
				_fill_circle(img, cx + sp.x, cy - 4 + sp.y, size * 0.03, body)
		_:
			_fill_ellipse(img, cx, cy, size * 0.16, size * 0.24, outline)
			_fill_ellipse(img, cx, cy, size * 0.13, size * 0.20, body)


func _fill_circle(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var rr := int(ceil(r))
	for y in range(int(cy) - rr, int(cy) + rr + 1):
		for x in range(int(cx) - rr, int(cx) + rr + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx := float(x) - cx
			var dy := float(y) - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, col)


func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in range(int(cy - ry), int(cy + ry) + 1):
		for x in range(int(cx - rx), int(cx + rx) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx := (float(x) - cx) / maxf(rx, 0.001)
			var dy := (float(y) - cy) / maxf(ry, 0.001)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)


func _draw_round_rect(img: Image, x: float, y: float, w: float, h: float, r: float, col: Color) -> void:
	_fill_rect(img, x + r, y, w - 2.0 * r, h, col)
	_fill_rect(img, x, y + r, w, h - 2.0 * r, col)
	_fill_circle(img, x + r, y + r, r, col)
	_fill_circle(img, x + w - r, y + r, r, col)
	_fill_circle(img, x + r, y + h - r, r, col)
	_fill_circle(img, x + w - r, y + h - r, r, col)


func _fill_rect(img: Image, x: float, y: float, w: float, h: float, col: Color) -> void:
	for py in range(int(y), int(y + h) + 1):
		for px in range(int(x), int(x + w) + 1):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, col)
