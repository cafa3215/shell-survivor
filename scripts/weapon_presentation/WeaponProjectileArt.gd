class_name WeaponProjectileArt
extends RefCounted

## 高清程序弹体（160px，3× 超采样 + Lanczos），深色描边 + 夸张轮廓，密集场景可辨。

const TEX_SIZE := 192
const SUPER := 4
const CANVAS := TEX_SIZE * SUPER
const STROKE := Color(0.02, 0.04, 0.08, 0.96)


static func texture_for_kind(kind: String, frame: int = 0) -> Texture2D:
	return ImageTexture.create_from_image(render_kind(kind, frame))


static func render_kind(kind: String, frame: int = 0) -> Image:
	var img := Image.create(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		"kunai":
			_draw_kunai(img, frame)
		"quantum_ball":
			_draw_quantum(img, frame)
		"lightning", "active_bolt":
			_draw_lightning(img, frame)
		"rocket":
			_draw_rocket(img, frame)
		"molotov":
			_draw_molotov(img, frame)
		"boomerang":
			_draw_boomerang(img, frame)
		"drone_ab":
			_draw_drone(img, frame)
		"guardian":
			_draw_guardian(img, frame)
		"frost_aura":
			_draw_frost(img, frame)
		"heal_aura":
			_draw_heal(img, frame)
		"stun_mine":
			_draw_mine(img, frame)
		_:
			_soft_disc(img, _c(80, 80), 28.0 * float(SUPER), Color(0.9, 0.9, 0.9, 0.8))
	img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_LANCZOS)
	_add_contrast_outline(img)
	return img


static func _add_contrast_outline(img: Image) -> void:
	# 外圈轻量描边，密集场景里轮廓更清晰（非像素块）
	var w := img.get_width()
	var h := img.get_height()
	var copy := img.duplicate()
	for y in range(h):
		for x in range(w):
			if copy.get_pixel(x, y).a > 0.12:
				continue
			var edge := false
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if ox == 0 and oy == 0:
						continue
					var nx := x + ox
					var ny := y + oy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					if copy.get_pixel(nx, ny).a > 0.35:
						edge = true
						break
				if edge:
					break
			if edge:
				img.set_pixel(x, y, Color(0.04, 0.06, 0.1, 0.55))


static func _c(x: float, y: float) -> Vector2:
	return Vector2(x * float(SUPER), y * float(SUPER))


static func _pal(kind: String) -> Dictionary:
	var key := kind
	if key == "active_bolt":
		key = "lightning"
	var th := WeaponVisualRegistry.theme(key)
	var sec: Color = th.get("secondary", Color(0.25, 0.25, 0.35))
	return {
		"deep": sec.darkened(0.28),
		"base": th.get("primary", Color.WHITE),
		"glow": th.get("accent", Color.WHITE),
		"trail": th.get("trail", Color.WHITE),
	}


# ── 苦无：长刃 + 圆护手 + 缠绳刀柄 ─────────────────────────────
static func _draw_kunai(img: Image, frame: int) -> void:
	var pal := _pal("kunai")
	var wob := (float(frame % 4) - 1.5) * 0.6
	_soft_disc(img, _c(80, 80), 36.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.22))
	var blade := PackedVector2Array([
		_c(138, 80 + wob * 0.15),
		_c(92, 58 + wob),
		_c(48, 80 + wob * 0.1),
		_c(92, 102 - wob),
	])
	_fill_poly_stroked(img, blade, pal.base, STROKE, 3.2 * float(SUPER))
	_fill_poly(img, _inset_poly(blade, 0.12), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.78))
	# 血槽
	_fill_poly(img, PackedVector2Array([
		_c(118, 80), _c(96, 68), _c(72, 80), _c(96, 92),
	]), Color(0.08, 0.14, 0.22, 0.55))
	# 圆形护手
	_soft_disc_stroked(img, _c(44, 80), 14.0, pal.deep, STROKE, 2.8 * float(SUPER))
	_soft_disc(img, _c(44, 80), 10.0, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.72))
	# 刀柄 + 缠绳
	_fill_poly_stroked(img, PackedVector2Array([
		_c(18, 72), _c(38, 68), _c(38, 92), _c(18, 88),
	]), pal.deep, STROKE, 2.6 * float(SUPER))
	for i in range(4):
		var yy := 70.0 + float(i) * 5.5
		_fill_poly(img, PackedVector2Array([
			_c(20, yy), _c(36, yy - 1.5), _c(36, yy + 2.5), _c(20, yy + 1.0),
		]), Color(0.85, 0.55, 0.35, 0.75))
	_soft_disc(img, _c(16, 80), 5.5, Color(1.0, 1.0, 1.0, 0.9))


# ── 量子球：大六角 + 轨道节点 + 亮核 ───────────────────────────
static func _draw_quantum(img: Image, frame: int) -> void:
	var pal := _pal("quantum_ball")
	var pulse := (float(frame % 4) - 1.5) * 1.4
	_soft_disc(img, _c(80, 80), 42.0 + pulse, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.32))
	var outer := _hex(80, 80, 44.0 + pulse * 0.12)
	_fill_poly_stroked(img, outer, pal.base, STROKE, 3.4 * float(SUPER))
	_fill_poly(img, _hex(80, 80, 34.0 + pulse * 0.1), Color(pal.deep.r, pal.deep.g, pal.deep.b, 0.88))
	_fill_poly(img, _hex(80, 80, 20.0 + pulse * 0.06), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.92))
	_soft_disc(img, _c(80, 80), 12.0, Color(1.0, 1.0, 0.88, 0.95))
	for i in range(6):
		var ang := TAU * float(i) / 6.0 + pulse * 0.03
		var nx := 80.0 + cos(ang) * 32.0
		var ny := 80.0 + sin(ang) * 32.0
		_line(img, _c(80, 80), _c(nx, ny), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.45), 2.0 * float(SUPER))
		_soft_disc_stroked(img, _c(nx, ny), 7.0, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.95), STROKE, 2.0 * float(SUPER))


# ── 雷电：粗锯齿闪电 + 分叉 ─────────────────────────────────────
static func _draw_lightning(img: Image, frame: int) -> void:
	var pal := _pal("lightning")
	var off := (float(frame % 4) - 1.5) * 1.8
	_soft_disc(img, _c(80, 80), 40.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.38))
	var bolt := PackedVector2Array([
		_c(62 + off, 16), _c(82 + off * 0.4, 16), _c(68 - off * 0.3, 48),
		_c(96 + off * 0.2, 48), _c(52 - off * 0.5, 118), _c(70 + off * 0.4, 68),
		_c(54 - off * 0.25, 68),
	])
	_fill_poly_stroked(img, bolt, pal.base, STROKE, 3.6 * float(SUPER))
	_fill_poly(img, _inset_poly(bolt, 0.18), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.92))
	# 小分叉
	var fork := PackedVector2Array([
		_c(88 + off * 0.15, 52), _c(108, 44), _c(102, 58),
	])
	_fill_poly_stroked(img, fork, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.88), STROKE, 2.4 * float(SUPER))


# ── 火箭：锥形弹头 + 柱体 + 四尾翼 + 长焰 ─────────────────────
static func _draw_rocket(img: Image, frame: int) -> void:
	var pal := _pal("rocket")
	var flame := 14.0 + float(frame % 4) * 4.0
	_soft_disc(img, _c(28, 80), 18.0 + flame * 0.4, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.55))
	_fill_poly(img, PackedVector2Array([
		_c(14, 80), _c(30, 80 - flame * 0.5), _c(30, 80 + flame * 0.5),
	]), Color(1.0, 0.78, 0.32, 0.92))
	_fill_poly(img, PackedVector2Array([
		_c(30, 80 - flame * 0.32), _c(8, 80 - flame * 0.22), _c(8, 80 + flame * 0.22),
		_c(30, 80 + flame * 0.32),
	]), Color(1.0, 0.55, 0.18, 0.85))
	var body := PackedVector2Array([
		_c(38, 80), _c(78, 58), _c(118, 80), _c(78, 102),
	])
	_fill_poly_stroked(img, body, pal.base, STROKE, 3.2 * float(SUPER))
	_fill_poly(img, _inset_poly(body, 0.1), Color(pal.deep.r, pal.deep.g, pal.deep.b, 0.75))
	# 弹头
	_fill_poly_stroked(img, PackedVector2Array([
		_c(96, 80), _c(132, 80), _c(114, 62), _c(114, 98),
	]), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.95), STROKE, 2.8 * float(SUPER))
	# 四尾翼
	for sign in [-1.0, 1.0]:
		_fill_poly(img, PackedVector2Array([
			_c(42, 80 + sign * 22), _c(52, 80 + sign * 32), _c(58, 80 + sign * 14),
		]), pal.deep)
	_fill_round_rect(img, _c(62, 68), _c(88, 92), 4.0, pal.deep, Color(pal.deep.r, pal.deep.g, pal.deep.b, 0.85))


# ── 燃烧瓶：瓶身 + 瓶口 + 火焰 ─────────────────────────────────
static func _draw_molotov(img: Image, frame: int) -> void:
	var pal := _pal("molotov")
	var flick := float(frame % 4)
	_soft_disc(img, _c(80, 80), 34.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.2))
	_fill_round_rect_stroked(img, _c(58, 58), _c(102, 108), 8.0, pal.base, STROKE, 3.0 * float(SUPER))
	_fill_round_rect(img, _c(66, 42), _c(94, 62), 5.0, pal.deep, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.92))
	# 布条
	_fill_poly(img, PackedVector2Array([
		_c(74, 40), _c(86, 40), _c(88, 28 - flick), _c(72, 30 - flick * 0.5),
	]), Color(0.75, 0.62, 0.42, 0.88))
	_soft_disc(img, _c(80, 24 - flick * 0.6), 10.0 + flick, Color(1.0, 0.65, 0.22, 0.88))
	_soft_disc(img, _c(80, 18 - flick), 6.0, Color(1.0, 0.92, 0.55, 0.92))
	_fill_poly(img, PackedVector2Array([
		_c(68, 64), _c(74, 62), _c(74, 96), _c(68, 94),
	]), Color(1.0, 1.0, 1.0, 0.18))


# ── 回旋镖：经典 V 形双翼，尖端朝前 ─────────────────────────────
static func _draw_boomerang(img: Image, frame: int) -> void:
	var pal := _pal("boomerang")
	var swing := (float(frame % 4) - 1.5) * 2.5
	_soft_disc(img, _c(80, 80), 38.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.24))
	var upper := PackedVector2Array([
		_c(28, 52 + swing), _c(118, 38 + swing * 0.3), _c(108, 58 + swing * 0.2), _c(38, 68 + swing),
	])
	var lower := PackedVector2Array([
		_c(28, 108 - swing), _c(118, 122 - swing * 0.3), _c(108, 102 - swing * 0.2), _c(38, 92 - swing),
	])
	_fill_poly_stroked(img, upper, pal.base, STROKE, 3.2 * float(SUPER))
	_fill_poly_stroked(img, lower, pal.base, STROKE, 3.2 * float(SUPER))
	_fill_poly(img, _inset_poly(upper, 0.2), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.72))
	_fill_poly(img, _inset_poly(lower, 0.2), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.72))
	_soft_disc_stroked(img, _c(80 + swing * 0.2, 80), 10.0, pal.deep, STROKE, 2.4 * float(SUPER))


# ── 无人机：十字四旋翼 + 机身 + 镜头 ───────────────────────────
static func _draw_drone(img: Image, frame: int) -> void:
	var pal := _pal("drone_ab")
	var spin := float(frame % 4) * 0.08
	_soft_disc(img, _c(80, 80), 38.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.26))
	for i in range(4):
		var ang := PI * 0.25 + TAU * float(i) / 4.0 + spin
		var arm_end := Vector2(cos(ang), sin(ang)) * 46.0
		var side := arm_end.orthogonal().normalized() * 8.0
		var hub := Vector2(80, 80)
		_fill_poly(img, PackedVector2Array([
			_cv(hub + arm_end * 0.35 + side),
			_cv(hub + arm_end + side * 0.6),
			_cv(hub + arm_end - side * 0.6),
			_cv(hub + arm_end * 0.35 - side),
		]), Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.82))
		_soft_disc_stroked(img, _c(hub.x + arm_end.x, hub.y + arm_end.y), 9.0, pal.base, STROKE, 2.4 * float(SUPER))
	_fill_round_rect_stroked(img, _c(64, 64), _c(96, 96), 10.0, pal.base, STROKE, 3.0 * float(SUPER))
	_soft_disc(img, _c(80, 78), 14.0, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.45))
	_soft_disc(img, _c(80, 78), 8.0, Color(0.12, 0.32, 0.52, 0.92))
	_soft_disc(img, _c(80, 78), 4.0, Color(0.55, 0.95, 1.0, 0.95))
	_fill_poly(img, PackedVector2Array([
		_c(96, 78), _c(112, 72), _c(112, 84),
	]), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.85))


# ── 守卫者：盾形 + 中心纹章 ─────────────────────────────────────
static func _draw_guardian(img: Image, frame: int) -> void:
	var pal := _pal("guardian")
	var pulse := (float(frame % 4) - 1.5) * 1.2
	_soft_disc(img, _c(80, 80), 40.0 + pulse, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.26))
	var shield := PackedVector2Array([
		_c(80, 22 - pulse), _c(118, 80), _c(80, 138 + pulse), _c(42, 80),
	])
	_fill_poly_stroked(img, shield, pal.base, STROKE, 3.4 * float(SUPER))
	_fill_poly(img, _inset_poly(shield, 0.14), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.55))
	_fill_poly(img, PackedVector2Array([
		_c(80, 48), _c(96, 80), _c(80, 112), _c(64, 80),
	]), Color(pal.deep.r, pal.deep.g, pal.deep.b, 0.88))
	_soft_disc(img, _c(80, 80), 8.0, Color(1.0, 0.95, 0.72, 0.9))


# ── 冰霜：六臂雪花 ─────────────────────────────────────────────
static func _draw_frost(img: Image, frame: int) -> void:
	var pal := _pal("frost_aura")
	var t := float(frame % 4)
	_soft_disc(img, _c(80, 80), 40.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.32))
	for i in range(6):
		var ang := TAU * float(i) / 6.0 + t * 0.06
		var tip := Vector2(cos(ang), sin(ang))
		var side := tip.orthogonal()
		var hub := Vector2(80, 80)
		var arm := PackedVector2Array([
			_cv(hub + tip * 14.0),
			_cv(hub + tip * 44.0 + side * 6.0),
			_cv(hub + tip * 44.0 - side * 6.0),
		])
		_fill_poly_stroked(img, arm, pal.base, STROKE, 2.6 * float(SUPER))
		_soft_disc(img, _c(hub.x + tip.x * 44.0, hub.y + tip.y * 44.0), 5.5, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.9))
	_soft_disc_stroked(img, _c(80, 80), 12.0, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.85), STROKE, 2.2 * float(SUPER))


# ── 治疗：绿环 + 粗十字 ─────────────────────────────────────────
static func _draw_heal(img: Image, frame: int) -> void:
	var pal := _pal("heal_aura")
	var t := float(frame % 4)
	_soft_disc(img, _c(80, 80), 38.0 + t, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.3))
	_soft_disc_stroked(img, _c(80, 80), 32.0, Color(pal.base.r, pal.base.g, pal.base.b, 0.62), STROKE, 3.0 * float(SUPER))
	_fill_round_rect_stroked(img, _c(70, 44), _c(90, 116), 6.0, Color(1.0, 1.0, 1.0, 0.92), STROKE, 2.4 * float(SUPER))
	_fill_round_rect_stroked(img, _c(44, 70), _c(116, 90), 6.0, Color(1.0, 1.0, 1.0, 0.92), STROKE, 2.4 * float(SUPER))
	_soft_disc(img, _c(80, 80), 14.0, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.35))


# ── 地雷：带刺六边形 ─────────────────────────────────────────────
static func _draw_mine(img: Image, frame: int) -> void:
	var pal := _pal("stun_mine")
	var blink := 0.5 + 0.5 * sin(float(frame) * PI * 0.5)
	_soft_disc(img, _c(80, 80), 36.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.24))
	_fill_poly_stroked(img, _hex(80, 80, 34.0), pal.base, STROKE, 3.2 * float(SUPER))
	_fill_poly(img, _hex(80, 80, 24.0), Color(pal.deep.r, pal.deep.g, pal.deep.b, 0.88))
	for i in range(6):
		var ang := TAU * float(i) / 6.0
		var tip := Vector2(cos(ang), sin(ang))
		_fill_poly(img, PackedVector2Array([
			_cv(Vector2(80, 80) + tip * 26.0),
			_cv(Vector2(80, 80) + tip * 42.0 + tip.orthogonal() * 5.0),
			_cv(Vector2(80, 80) + tip * 42.0 - tip.orthogonal() * 5.0),
		]), Color(pal.deep.r, pal.deep.g, pal.deep.b, 0.92))
	_soft_disc(img, _c(80, 80), 11.0, Color(pal.glow.r, pal.glow.g, pal.glow.b, blink))
	_soft_disc(img, _c(80, 80), 5.0, Color(1.0, 0.95, 1.0, blink))


# ── 几何 / 绘制工具 ─────────────────────────────────────────────
static func _hex(cx: float, cy: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := -PI * 0.5 + TAU * float(i) / 6.0
		pts.append(_c(cx + cos(ang) * r, cy + sin(ang) * r))
	return pts


static func _inset_poly(pts: PackedVector2Array, t: float) -> PackedVector2Array:
	if pts.is_empty():
		return pts
	var cx := 0.0
	var cy := 0.0
	for p in pts:
		cx += p.x
		cy += p.y
	cx /= float(pts.size())
	cy /= float(pts.size())
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(lerpf(p.x, cx, t), lerpf(p.y, cy, t)))
	return out


static func _scale_poly(pts: PackedVector2Array, scale: float) -> PackedVector2Array:
	if pts.is_empty():
		return pts
	var cx := 0.0
	var cy := 0.0
	for p in pts:
		cx += p.x
		cy += p.y
	cx /= float(pts.size())
	cy /= float(pts.size())
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(cx + (p.x - cx) * scale, cy + (p.y - cy) * scale))
	return out


static func _cv(v: Vector2) -> Vector2:
	return _c(v.x, v.y)


static func _fill_poly_stroked(img: Image, pts: PackedVector2Array, fill: Color, stroke: Color, stroke_w: float) -> void:
	_fill_poly(img, _scale_poly(pts, 1.0 + stroke_w * 0.006), stroke)
	_fill_poly(img, pts, fill)
	_fill_poly(img, _inset_poly(pts, 0.08), Color(fill.r * 1.08, fill.g * 1.08, fill.b * 1.08, fill.a * 0.55))


static func _soft_disc_stroked(img: Image, center: Vector2, radius: float, fill: Color, stroke: Color, stroke_w: float) -> void:
	_soft_disc(img, center, radius + stroke_w * 0.35, stroke)
	_soft_disc(img, center, radius, fill)


static func _fill_round_rect_stroked(img: Image, p0: Vector2, p1: Vector2, radius: float, fill: Color, stroke: Color, stroke_w: float) -> void:
	_fill_round_rect(img, p0 - Vector2(stroke_w * 0.35, stroke_w * 0.35), p1 + Vector2(stroke_w * 0.35, stroke_w * 0.35), radius + stroke_w * 0.2, stroke, stroke)
	_fill_round_rect(img, p0, p1, radius, fill, fill)


static func _fill_poly(img: Image, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var min_x := pts[0].x
	var max_x := pts[0].x
	var min_y := pts[0].y
	var max_y := pts[0].y
	for pt in pts:
		min_x = minf(min_x, pt.x)
		max_x = maxf(max_x, pt.x)
		min_y = minf(min_y, pt.y)
		max_y = maxf(max_y, pt.y)
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(0, int(floor(min_y))), mini(h, int(ceil(max_y)) + 1)):
		for x in range(maxi(0, int(floor(min_x))), mini(w, int(ceil(max_x)) + 1)):
			if _point_in_poly(Vector2(float(x) + 0.5, float(y) + 0.5), pts):
				_blend_pixel(img, x, y, col)


static func _fill_round_rect(img: Image, p0: Vector2, p1: Vector2, radius: float, outline: Color, fill: Color = outline) -> void:
	var x0 := minf(p0.x, p1.x)
	var y0 := minf(p0.y, p1.y)
	var x1 := maxf(p0.x, p1.x)
	var y1 := maxf(p0.y, p1.y)
	var r := radius
	for y in range(int(floor(y0)), int(ceil(y1)) + 1):
		for x in range(int(floor(x0)), int(ceil(x1)) + 1):
			var dx := maxf(0.0, maxf(x0 + r - x, x - (x1 - r)))
			var dy := maxf(0.0, maxf(y0 + r - y, y - (y1 - r)))
			if dx * dx + dy * dy <= r * r:
				_blend_pixel(img, x, y, fill)


static func _line(img: Image, a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var dir := b - a
	var len := dir.length()
	if len < 0.5:
		return
	dir /= len
	var side := dir.orthogonal() * width * 0.5
	var pts := PackedVector2Array([a + side, b + side, b - side, a - side])
	_fill_poly(img, pts, col)


static func _soft_disc(img: Image, center: Vector2, radius: float, col: Color) -> void:
	var r := radius
	var r_i := int(ceil(r)) + 2
	for y in range(int(center.y) - r_i, int(center.y) + r_i + 1):
		for x in range(int(center.x) - r_i, int(center.x) + r_i + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d := Vector2(float(x) + 0.5 - center.x, float(y) + 0.5 - center.y).length()
			if d > r:
				continue
			var edge := clampf((r - d) / 2.5, 0.0, 1.0)
			_blend_pixel(img, x, y, Color(col.r, col.g, col.b, col.a * edge))


static func _blend_pixel(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var dst := img.get_pixel(x, y)
	var a := col.a + dst.a * (1.0 - col.a)
	if a <= 0.0001:
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var r := (col.r * col.a + dst.r * dst.a * (1.0 - col.a)) / a
	var g := (col.g * col.a + dst.g * dst.a * (1.0 - col.a)) / a
	var b := (col.b * col.a + dst.b * dst.a * (1.0 - col.a)) / a
	img.set_pixel(x, y, Color(r, g, b, a))


static func _point_in_poly(p: Vector2, pts: PackedVector2Array) -> bool:
	var inside := false
	var j := pts.size() - 1
	for i in range(pts.size()):
		var pi: Vector2 = pts[i]
		var pj: Vector2 = pts[j]
		if ((pi.y > p.y) != (pj.y > p.y)) and (p.x < (pj.x - pi.x) * (p.y - pi.y) / maxf(0.0001, pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside
