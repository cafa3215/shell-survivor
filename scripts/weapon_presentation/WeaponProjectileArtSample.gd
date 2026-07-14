class_name WeaponProjectileArtSample
extends RefCounted

## 小样 ·「能量拖尾 Energy Trail v3」
## 参考：苦无 STL 轮廓 + 呱呱素材 gg-tx 青蓝发光条带拖尾
## 语法：柔光晕 + 条带尾迹 + 亮核（非像素块、非细线）· 仅供预览

const STYLE_ID := "energy_trail_v3"
const TEX_SIZE := 192
const SUPER := 4
const CANVAS := TEX_SIZE * SUPER


static func style_id() -> String:
	return STYLE_ID


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
			_bloom(img, _c(80, 80), 36.0, Color.WHITE, 0.35)
	img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_LANCZOS)
	return img


# ── 苦无：STL 宽刃 + 青蓝能量丝带尾迹 ─────────────────────────
static func _draw_kunai(img: Image, frame: int) -> void:
	var pal := _pal("kunai")
	var phase := float(frame % 4)
	var wob := (phase - 1.5) * 0.6
	_trail_streaks(img, _c(118, 78 + wob), pal.trail, 7, 52.0, phase)
	_ribbon(img, _c(92, 64 + wob * 0.5), Vector2(-1, -0.22), pal.base, 38.0, 5.0, phase)
	_ribbon(img, _c(92, 96 - wob * 0.5), Vector2(-1, 0.22), pal.base, 38.0, 5.0, phase + 0.5)
	_bloom(img, _c(100, 80), 32.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.55), 0.9)
	var blade := PackedVector2Array([
		_c(152, 80 + wob * 0.1), _c(108, 56 + wob), _c(58, 80 + wob * 0.08), _c(108, 104 - wob),
	])
	_fill_poly(img, blade, Color(pal.base.r, pal.base.g, pal.base.b, 0.82))
	_fill_poly(img, _inset(blade, 0.18), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.72))
	_fill_poly(img, PackedVector2Array([
		_c(138, 80), _c(112, 64), _c(86, 80), _c(112, 96),
	]), Color(0.05, 0.12, 0.22, 0.65))
	_bloom(img, _c(46, 80), 14.0, Color(1.0, 0.88, 0.45, 0.75), 0.55)
	_soft_disc(img, _c(46, 80), 9.0, Color(1.0, 0.95, 0.7, 0.88))
	_fill_poly(img, PackedVector2Array([
		_c(12, 70), _c(36, 66), _c(36, 94), _c(12, 90),
	]), Color(0.38, 0.26, 0.16, 0.9))
	_core(img, _c(146, 80 + wob * 0.08), 5.5)


# ── 量子球：能量球 + 轨道丝 ───────────────────────────────────
static func _draw_quantum(img: Image, frame: int) -> void:
	var pal := _pal("quantum_ball")
	var pulse := (float(frame % 4) - 1.5) * 1.2
	_trail_streaks(img, _c(80, 80), pal.trail, 5, 28.0, pulse)
	_bloom(img, _c(80, 80), 44.0 + pulse, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.5), 0.85)
	for i in range(6):
		var ang := TAU * float(i) / 6.0 + pulse * 0.08
		var nx := 80.0 + cos(ang) * (30.0 + pulse * 0.15)
		var ny := 80.0 + sin(ang) * (30.0 + pulse * 0.15)
		_line(img, _c(80, 80), _c(nx, ny), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.45), 2.2 * float(SUPER))
		_bloom(img, _c(nx, ny), 7.0, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.8), 0.6)
	_soft_disc(img, _c(80, 80), 22.0 + pulse * 0.1, Color(pal.base.r, pal.base.g, pal.base.b, 0.78))
	_soft_disc(img, _c(80, 80), 14.0, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.65))
	_core(img, _c(80, 80), 9.0 + pulse * 0.2)


# ── 雷电：锯齿束 + 电丝尾迹 ───────────────────────────────────
static func _draw_lightning(img: Image, frame: int) -> void:
	var pal := _pal("lightning")
	var off := (float(frame % 4) - 1.5) * 1.8
	_trail_streaks(img, _c(70, 70 + off * 0.2), pal.trail, 6, 40.0, off)
	_bloom(img, _c(78, 78), 40.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.58), 0.9)
	var bolt := PackedVector2Array([
		_c(56 + off, 22), _c(82 + off * 0.3, 22), _c(68 - off * 0.2, 52),
		_c(104 + off * 0.15, 52), _c(50 - off * 0.4, 132), _c(74 + off * 0.3, 74),
		_c(54 - off * 0.15, 74),
	])
	_fill_poly(img, bolt, Color(pal.base.r, pal.base.g, pal.base.b, 0.88))
	_fill_poly(img, _inset(bolt, 0.2), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.92))
	_fill_poly(img, PackedVector2Array([
		_c(94 + off * 0.1, 56), _c(116, 44), _c(110, 64),
	]), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.85))
	_core(img, _c(58 + off * 0.15, 26), 4.5)


# ── 火箭：弹体 + 橙焰条带 ─────────────────────────────────────
static func _draw_rocket(img: Image, frame: int) -> void:
	var pal := _pal("rocket")
	var flame := 14.0 + float(frame % 4) * 4.5
	_trail_streaks(img, _c(34, 80), pal.trail, 8, flame * 2.2, float(frame % 4))
	_bloom(img, _c(28, 80), 16.0 + flame * 0.35, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.62), 0.85)
	_fill_poly(img, PackedVector2Array([
		_c(10, 80), _c(26, 80 - flame * 0.5), _c(26, 80 + flame * 0.5),
	]), Color(1.0, 0.75, 0.28, 0.92))
	var body := PackedVector2Array([
		_c(38, 80), _c(78, 58), _c(118, 80), _c(78, 102),
	])
	_fill_poly(img, body, Color(pal.base.r, pal.base.g, pal.base.b, 0.85))
	_fill_poly(img, PackedVector2Array([
		_c(100, 80), _c(138, 80), _c(120, 64), _c(120, 96),
	]), Color(1.0, 0.92, 0.62, 0.9))
	_core(img, _c(128, 80), 5.0)


# ── 燃烧瓶：瓶 + 火丝 ─────────────────────────────────────────
static func _draw_molotov(img: Image, frame: int) -> void:
	var pal := _pal("molotov")
	var flick := float(frame % 4)
	_trail_streaks(img, _c(80, 24 - flick), Color(1.0, 0.55, 0.15, 0.8), 4, 18.0, flick)
	_bloom(img, _c(80, 80), 34.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.38), 0.7)
	_round_rect(img, _c(58, 58), _c(102, 110), 9.0, Color(pal.base.r, pal.base.g, pal.base.b, 0.88))
	_round_rect(img, _c(66, 46), _c(94, 62), 5.0, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.9))
	_bloom(img, _c(80, 22 - flick * 0.6), 11.0 + flick, Color(1.0, 0.62, 0.18, 0.88), 0.75)
	_core(img, _c(80, 18 - flick), 5.0)


# ── 回旋镖：V 翼 + 弧光尾迹 ───────────────────────────────────
static func _draw_boomerang(img: Image, frame: int) -> void:
	var pal := _pal("boomerang")
	var swing := (float(frame % 4) - 1.5) * 2.2
	_ribbon(img, _c(100, 48 + swing), Vector2(-0.9, -0.35), pal.base, 42.0, 4.5, swing)
	_ribbon(img, _c(100, 112 - swing), Vector2(-0.9, 0.35), pal.base, 42.0, 4.5, swing + 0.4)
	_bloom(img, _c(80, 80), 36.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.42), 0.8)
	var upper := PackedVector2Array([
		_c(26, 50 + swing), _c(126, 34 + swing * 0.3), _c(114, 58 + swing * 0.2), _c(36, 68 + swing),
	])
	var lower := PackedVector2Array([
		_c(26, 110 - swing), _c(126, 126 - swing * 0.3), _c(114, 102 - swing * 0.2), _c(36, 92 - swing),
	])
	_fill_poly(img, upper, Color(pal.base.r, pal.base.g, pal.base.b, 0.86))
	_fill_poly(img, lower, Color(pal.base.r, pal.base.g, pal.base.b, 0.86))
	_core(img, _c(78 + swing * 0.1, 80), 6.0)


# ── 无人机：机体 + 旋翼光点尾迹 ───────────────────────────────
static func _draw_drone(img: Image, frame: int) -> void:
	var pal := _pal("drone_ab")
	var spin := float(frame % 4) * 0.14
	_bloom(img, _c(80, 80), 38.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.4), 0.75)
	for i in range(4):
		var ang := PI * 0.25 + TAU * float(i) / 4.0 + spin
		var end := Vector2(cos(ang), sin(ang)) * 46.0
		var hub := Vector2(80, 80)
		_trail_streaks(img, _c(hub.x + end.x * 0.55, hub.y + end.y * 0.55), pal.trail, 3, 16.0, spin + float(i))
		_bloom(img, _c(hub.x + end.x, hub.y + end.y), 9.0, Color(pal.base.r, pal.base.g, pal.base.b, 0.82), 0.55)
	_round_rect(img, _c(64, 64), _c(96, 96), 11.0, Color(pal.base.r, pal.base.g, pal.base.b, 0.88))
	_soft_disc(img, _c(80, 78), 12.0, Color(0.12, 0.32, 0.55, 0.9))
	_core(img, _c(80, 78), 4.5)


# ── 守卫者：盾 + 金环脉冲 ─────────────────────────────────────
static func _draw_guardian(img: Image, frame: int) -> void:
	var pal := _pal("guardian")
	var pulse := (float(frame % 4) - 1.5) * 1.0
	_bloom(img, _c(80, 80), 40.0 + pulse, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.45), 0.8)
	var shield := PackedVector2Array([
		_c(80, 22 - pulse), _c(120, 80), _c(80, 138 + pulse), _c(40, 80),
	])
	_fill_poly(img, shield, Color(pal.base.r, pal.base.g, pal.base.b, 0.8))
	_fill_poly(img, _inset(shield, 0.15), Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.55))
	_core(img, _c(80, 80), 7.0)


# ── 冰霜：雪花 + 冷雾丝 ─────────────────────────────────────────
static func _draw_frost(img: Image, frame: int) -> void:
	var pal := _pal("frost_aura")
	var t := float(frame % 4)
	_bloom(img, _c(80, 80), 40.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.48), 0.85)
	for i in range(6):
		var ang := TAU * float(i) / 6.0 + t * 0.06
		var tip := Vector2(cos(ang), sin(ang))
		var side := tip.orthogonal()
		var hub := Vector2(80, 80)
		_ribbon(img, _c(hub.x + tip.x * 20.0, hub.y + tip.y * 20.0), tip * -0.35 + side * 0.15, pal.base, 22.0, 3.0, t + float(i))
		_bloom(img, _c(hub.x + tip.x * 44.0, hub.y + tip.y * 44.0), 5.5, Color(pal.glow.r, pal.glow.g, pal.glow.b, 0.85), 0.5)
	_core(img, _c(80, 80), 6.0)


# ── 治疗：十字 + 绿环 ─────────────────────────────────────────
static func _draw_heal(img: Image, frame: int) -> void:
	var pal := _pal("heal_aura")
	var t := float(frame % 4)
	_bloom(img, _c(80, 80), 36.0 + t * 0.4, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.42), 0.8)
	_round_rect(img, _c(70, 44), _c(90, 116), 6.0, Color(1.0, 1.0, 1.0, 0.9))
	_round_rect(img, _c(44, 70), _c(116, 90), 6.0, Color(1.0, 1.0, 1.0, 0.9))
	_soft_disc(img, _c(80, 80), 30.0, Color(pal.base.r, pal.base.g, pal.base.b, 0.35))
	_core(img, _c(80, 80), 8.0)


# ── 地雷：刺六角 + 紫核闪烁 ─────────────────────────────────────
static func _draw_mine(img: Image, frame: int) -> void:
	var pal := _pal("stun_mine")
	var blink := 0.5 + 0.5 * sin(float(frame) * PI * 0.5)
	_bloom(img, _c(80, 80), 36.0, Color(pal.trail.r, pal.trail.g, pal.trail.b, 0.38), 0.75)
	_fill_poly(img, _hex(80, 80, 34.0), Color(pal.base.r, pal.base.g, pal.base.b, 0.82))
	for i in range(6):
		var ang := TAU * float(i) / 6.0
		var tip := Vector2(cos(ang), sin(ang))
		_fill_poly(img, PackedVector2Array([
			_cv(Vector2(80, 80) + tip * 28.0),
			_cv(Vector2(80, 80) + tip * 42.0 + tip.orthogonal() * 5.0),
			_cv(Vector2(80, 80) + tip * 42.0 - tip.orthogonal() * 5.0),
		]), Color(pal.deep.r, pal.deep.g, pal.deep.b, 0.9))
	_core(img, _c(80, 80), 8.0 * blink)


# ── 统一能量语法 ───────────────────────────────────────────────
static func _trail_streaks(img: Image, tip: Vector2, col: Color, count: int, length: float, phase: float) -> void:
	var dir := Vector2.LEFT
	var side := dir.orthogonal()
	for i in range(count):
		var t := float(i) / float(maxi(1, count - 1))
		var y_off := (t - 0.5) * 14.0 + sin(phase + t * 3.2) * 3.0
		var start := tip + dir * (8.0 + t * 6.0) + side * y_off
		var len := length * (0.55 + (1.0 - t) * 0.45)
		var w := (2.8 - t * 1.2) * float(SUPER)
		var alpha := col.a * (0.35 + (1.0 - t) * 0.45)
		_line(img, start, start + dir * len, Color(col.r, col.g, col.b, alpha), w)


static func _ribbon(img: Image, anchor: Vector2, flow: Vector2, col: Color, length: float, width: float, phase: float) -> void:
	var n := flow.normalized()
	var side := n.orthogonal() * width * float(SUPER)
	var pts := PackedVector2Array()
	var segs := 6
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var wave := sin(phase * 1.4 + t * 4.5) * 3.5 * float(SUPER)
		var p := anchor + n * (t * length * float(SUPER)) + side * (t * 0.35) + side.orthogonal() * wave
		pts.append(p)
	for i in range(segs):
		var a := pts[i]
		var b := pts[i + 1]
		var w := width * (1.0 - float(i) / float(segs) * 0.55) * float(SUPER)
		var s := (b - a).orthogonal().normalized() * w
		_fill_poly(img, PackedVector2Array([a + s, b + s, b - s, a - s]), Color(col.r, col.g, col.b, col.a * (0.55 - float(i) * 0.06)))


static func _bloom(img: Image, center: Vector2, radius: float, col: Color, strength: float = 1.0) -> void:
	_soft_disc(img, center, radius, Color(col.r, col.g, col.b, col.a * strength))
	_soft_disc(img, center, radius * 0.55, Color(col.r * 1.08, col.g * 1.08, col.b * 1.08, col.a * strength * 0.65))


static func _core(img: Image, center: Vector2, radius: float) -> void:
	_soft_disc(img, center, radius, Color(1.0, 1.0, 0.98, 0.95))
	_soft_disc(img, center, radius * 0.45, Color(1.0, 1.0, 1.0, 1.0))


# ── 几何工具 ─────────────────────────────────────────────────
static func _c(x: float, y: float) -> Vector2:
	return Vector2(x * float(SUPER), y * float(SUPER))


static func _cv(v: Vector2) -> Vector2:
	return _c(v.x, v.y)


static func _pal(kind: String) -> Dictionary:
	var key := kind
	if key == "active_bolt":
		key = "lightning"
	var th := WeaponVisualRegistry.theme(key)
	var sec: Color = th.get("secondary", Color(0.25, 0.25, 0.35))
	return {
		"deep": sec.darkened(0.32),
		"base": th.get("primary", Color.WHITE),
		"glow": th.get("accent", Color.WHITE),
		"trail": th.get("trail", Color.WHITE),
	}


static func _hex(cx: float, cy: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := -PI * 0.5 + TAU * float(i) / 6.0
		pts.append(_c(cx + cos(ang) * r, cy + sin(ang) * r))
	return pts


static func _inset(pts: PackedVector2Array, t: float) -> PackedVector2Array:
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
				_blend(img, x, y, col)


static func _round_rect(img: Image, p0: Vector2, p1: Vector2, radius: float, fill: Color) -> void:
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
				_blend(img, x, y, fill)


static func _line(img: Image, a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var dir := b - a
	var len := dir.length()
	if len < 0.5:
		return
	dir /= len
	var side := dir.orthogonal() * width * 0.5
	_fill_poly(img, PackedVector2Array([a + side, b + side, b - side, a - side]), col)


static func _soft_disc(img: Image, center: Vector2, radius: float, col: Color) -> void:
	var r_i := int(ceil(radius)) + 2
	for y in range(int(center.y) - r_i, int(center.y) + r_i + 1):
		for x in range(int(center.x) - r_i, int(center.x) + r_i + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d := Vector2(float(x) + 0.5 - center.x, float(y) + 0.5 - center.y).length()
			if d > radius:
				continue
			var edge := clampf((radius - d) / 3.2, 0.0, 1.0)
			_blend(img, x, y, Color(col.r, col.g, col.b, col.a * edge))


static func _blend(img: Image, x: int, y: int, col: Color) -> void:
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
