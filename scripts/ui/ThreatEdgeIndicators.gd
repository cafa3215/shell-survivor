extends Control
class_name ThreatEdgeIndicators

@export var edge_padding := 22.0
@export var arrow_size := 16.0

var _targets: Array[Dictionary] = []
var _player_world := Vector2.ZERO
var _cam_center_world := Vector2.ZERO
var _cam_zoom := Vector2.ONE
var _relief_ratio := 0.0

func _style_color(variation: StringName, fallback: StringName = &"Label.Meta") -> Color:
	var sb := get_theme_stylebox("panel", variation)
	if sb is StyleBoxFlat:
		var flat := sb as StyleBoxFlat
		return flat.border_color if flat.border_color.a > 0.0 else flat.bg_color
	return get_theme_color("font_color", fallback)

func _with_alpha(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func set_relief_ratio(r: float) -> void:
	_relief_ratio = clampf(r, 0.0, 1.0)

func _resolve_game() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.get_node_or_null("EnemyManager") != null and n.get_node_or_null("Player") != null:
			return n
		n = n.get_parent()
	return null

func _process(_delta: float) -> void:
	if not visible:
		return
	if not Settings.high_contrast_targets:
		_targets.clear()
		queue_redraw()
		return
	var game := _resolve_game()
	if game == null:
		return
	var em := game.get_node_or_null("EnemyManager")
	var pl := game.get_node_or_null("Player")
	var cam := get_viewport().get_camera_2d()
	if pl and ("global_position" in pl):
		_player_world = pl.global_position
	if cam:
		_cam_center_world = cam.get_screen_center_position()
		_cam_zoom = cam.zoom
	if em and em.has_method("get_threat_targets"):
		_targets = _filter_targets_for_ui(em.get_threat_targets(6))
	else:
		_targets.clear()
	queue_redraw()

func _filter_targets_for_ui(raw_targets: Array[Dictionary]) -> Array[Dictionary]:
	var bosses: Array[Dictionary] = []
	var elites: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	for t in raw_targets:
		var k := int(t.get("kind", -1))
		if bool(t.get("imminent", false)):
			elites.insert(0, t)
			continue
		if k == 9:
			bosses.append(t)
		elif k == 6 or k == 7 or k == 3:
			elites.append(t)
		else:
			others.append(t)
	bosses.sort_custom(func(a, b): return float(a.get("dist", 99999.0)) < float(b.get("dist", 99999.0)))
	elites.sort_custom(func(a, b): return float(a.get("dist", 99999.0)) < float(b.get("dist", 99999.0)))
	others.sort_custom(func(a, b): return float(a.get("dist", 99999.0)) < float(b.get("dist", 99999.0)))
	var out: Array[Dictionary] = []
	if not bosses.is_empty():
		out.append(bosses[0])
	for e in elites:
		if out.size() >= 2:
			break
		out.append(e)
	if out.is_empty() and not others.is_empty():
		out.append(others[0])
	elif out.size() < 2 and not others.is_empty():
		out.append(others[0])
	# “战局回稳”时 HUD 主动降噪：箭头数量收敛，读图更干净
	if _relief_ratio > 0.34 and out.size() > 1:
		out = out.slice(0, 1)
	return out

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var vp := get_viewport()
	var vs := vp.get_visible_rect().size if vp else Vector2(1152, 648)
	var rel := world_pos - _cam_center_world
	return rel * _cam_zoom + vs * 0.5

func _is_on_screen(p: Vector2, margin := 10.0) -> bool:
	var r := Rect2(Vector2.ZERO, size).grow(-margin)
	return r.has_point(p)

func _clamp_to_edge(p: Vector2) -> Vector2:
	var r := Rect2(Vector2(edge_padding, edge_padding), size - Vector2(edge_padding * 2.0, edge_padding * 2.0))
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))

func _draw_arrow(at: Vector2, dir: Vector2, col: Color) -> void:
	var d := dir.normalized()
	if d.length() < 0.001:
		return
	var right := Vector2(-d.y, d.x)
	var tip := at + d * arrow_size
	var base := at - d * (arrow_size * 0.55)
	var p1 := base + right * (arrow_size * 0.5)
	var p2 := base - right * (arrow_size * 0.5)
	draw_circle(at - d * 2.0, arrow_size * 0.72, _with_alpha(col, 0.1))
	draw_colored_polygon(PackedVector2Array([tip, p1, p2]), col)
	draw_polyline(
		PackedVector2Array([tip, p1, p2, tip]),
		_with_alpha(_style_color(&"PanelScreen", &"Label.Meta"), col.a * 0.35),
		1.4,
		true
	)

func _draw() -> void:
	if size.x < 10 or size.y < 10:
		return
	for t in _targets:
		var wp := t.get("pos", Vector2.ZERO) as Vector2
		var k := int(t.get("kind", -1))
		var dist := float(t.get("dist", 0.0))
		var sp := _world_to_screen(wp)
		if _is_on_screen(sp, 32.0):
			continue
		var edge := _clamp_to_edge(sp)
		var dir := sp - (size * 0.5)
		var col := _with_alpha(_style_color(&"PanelThreat", &"Label.Meta"), 0.85)
		if k == 9:
			col = _with_alpha(_style_color(&"PanelDanger", &"Label.Title"), 0.9)
		elif k == 6:
			col = _with_alpha(_style_color(&"PanelWarning", &"Label.Body"), 0.88)
		elif k == 7:
			col = _with_alpha(_style_color(&"PanelWarning", &"Label.Meta"), 0.88)
		var pulse_amp := lerpf(0.14, 0.06, _relief_ratio)
		var pulse := 0.86 + pulse_amp * sin(Time.get_ticks_msec() * 0.01 + dist * 0.01)
		col = col.darkened(1.0 - pulse)
		if _relief_ratio > 0.01:
			col.a = lerpf(col.a, col.a * 0.62, _relief_ratio)
		_draw_arrow(edge, dir, col)
