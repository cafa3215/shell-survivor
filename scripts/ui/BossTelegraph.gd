extends Node2D
class_name BossTelegraph

const TELEGRAPH_THEME := preload("res://assets/themes/cyber_theme.tres")
const V_THREAT := &"PanelThreat"
const V_WARNING := &"PanelWarning"
const V_DANGER := &"PanelDanger"

var _active := false
var _kind := 0
var _origin := Vector2.ZERO
var _dir := Vector2.RIGHT
var _radius := 120.0
var _t := 0.0
var _t_max := 0.5
var _variation: StringName = V_THREAT

func _ready() -> void:
	EventBus.boss_telegraph.connect(_on_boss_telegraph)
	set_process(true)

func _process(delta: float) -> void:
	if not _active:
		return
	_t -= delta
	if _t <= 0.0:
		_active = false
	queue_redraw()

func _on_boss_telegraph(kind: int, origin: Vector2, dir: Vector2, radius: float, duration: float) -> void:
	_active = true
	_kind = kind
	_origin = origin
	_dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_radius = radius
	_t = duration
	_t_max = max(duration, 0.05)
	_variation = _variation_for_kind(kind)
	queue_redraw()

func _variation_for_kind(kind: int) -> StringName:
	if kind >= 4:
		return V_DANGER
	if kind >= 2:
		return V_WARNING
	return V_THREAT

func _theme_color() -> Color:
	var sb := TELEGRAPH_THEME.get_stylebox("panel", _variation)
	if sb is StyleBoxFlat:
		var flat := sb as StyleBoxFlat
		if flat.border_color.a > 0.0:
			return flat.border_color
		return flat.bg_color
	return TELEGRAPH_THEME.get_color("font_color", "Label")

func _draw() -> void:
	if not _active:
		return
	var col := _theme_color()
	match _kind:
		3: # cone
			var a := acos(0.65)
			var pts := PackedVector2Array()
			pts.append(_origin)
			var steps := 20
			for i in range(steps + 1):
				var t: float = -a + (2.0 * a * float(i) / float(steps))
				var v: Vector2 = _dir.rotated(t) * _radius
				pts.append(_origin + v)
			draw_colored_polygon(pts, col)
		_:
			draw_circle(_origin, _radius, col)
