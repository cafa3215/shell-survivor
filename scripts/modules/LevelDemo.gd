extends "res://scripts/modules/ModuleDemoBase.gd"

@onready var _title := $CanvasLayer/Panel/VBox/Title as Label
@onready var _desc := $CanvasLayer/Panel/VBox/Desc as Label
@onready var _status := $CanvasLayer/Panel/VBox/Status as Label
@onready var _nav_region := $World/NavigationRegion2D as NavigationRegion2D
@onready var _walker := $World/Walker as CharacterBody2D
@onready var _agent := $World/Walker/NavigationAgent2D as NavigationAgent2D

## 可走矩形（世界坐标，与地编演示根一致）
const WALK_RECT := Rect2(32.0, 32.0, 736.0, 536.0)
const WALK_SPEED := 220.0

var _waypoints: Array[Vector2] = []
var _wp_i := 0
var _dwell := 0.0

func _ready() -> void:
	demo_name = "地编模块"
	super._ready()
	_title.text = "地编模块：可走区域与寻路"
	_desc.text = "用于验证：导航多边形烘焙、静态障碍、代理沿路径移动（最小闭环）。"
	_status.text = "状态：正在烘焙导航…"
	_waypoints = [
		Vector2(WALK_RECT.position.x + 80.0, WALK_RECT.position.y + WALK_RECT.size.y * 0.5),
		Vector2(WALK_RECT.position.x + WALK_RECT.size.x - 80.0, WALK_RECT.position.y + WALK_RECT.size.y * 0.5),
		Vector2(WALK_RECT.position.x + WALK_RECT.size.x - 80.0, WALK_RECT.position.y + WALK_RECT.size.y - 80.0),
		Vector2(WALK_RECT.position.x + 80.0, WALK_RECT.position.y + WALK_RECT.size.y - 80.0),
	]
	_bake_navigation()
	_walker.global_position = _waypoints[0]
	_agent.path_desired_distance = 8.0
	_agent.target_desired_distance = 12.0
	_agent.avoidance_enabled = false
	call_deferred("_begin_patrol")

func _bake_navigation() -> void:
	var poly := NavigationPolygon.new()
	poly.clear()
	# 外轮廓（矩形可走区）
	var outer := PackedVector2Array([
		WALK_RECT.position,
		WALK_RECT.position + Vector2(WALK_RECT.size.x, 0.0),
		WALK_RECT.position + WALK_RECT.size,
		WALK_RECT.position + Vector2(0.0, WALK_RECT.size.y),
	])
	poly.add_outline(outer)
	# 内洞：须与外轮廓绕向相反（外顺时针则洞为逆时针）
	var hole := PackedVector2Array([
		Vector2(340, 200),
		Vector2(340, 360),
		Vector2(460, 360),
		Vector2(460, 200),
	])
	poly.add_outline(hole)
	# Godot 4.x：make_polygons_from_outlines 已弃用；待迁 NavigationServer2D.parse_source_geometry 等新烘焙路径时替换此处。
	poly.make_polygons_from_outlines()
	_nav_region.navigation_polygon = poly

func _begin_patrol() -> void:
	_wp_i = 0
	_dwell = 0.0
	_agent.target_position = _waypoints[_wp_i]
	_status.text = "状态：巡逻已启动"

func module_self_test() -> bool:
	if _nav_region == null or _nav_region.navigation_polygon == null:
		return false
	var rid: RID = _nav_region.get_region_rid()
	if not rid.is_valid():
		return false
	var map_rid: RID = NavigationServer2D.region_get_map(rid)
	if not map_rid.is_valid():
		return false
	# 勿用矩形中心：中心落在内洞障碍内，最近可走点会较远导致误判
	var probe: Vector2 = _waypoints[0]
	var closest: Vector2 = NavigationServer2D.map_get_closest_point(map_rid, probe)
	if closest.distance_to(probe) > 24.0:
		return false
	if _agent == null:
		return false
	_agent.target_position = _waypoints[mini(1, _waypoints.size() - 1)]
	NavigationServer2D.map_force_sync(map_rid)
	if _agent.get_current_navigation_path().is_empty():
		return false
	return true

func _physics_process(delta: float) -> void:
	if _walker == null or _agent == null:
		return
	if _dwell > 0.0:
		_dwell -= delta
		_walker.velocity = Vector2.ZERO
		_walker.move_and_slide()
		return
	var next: Vector2 = _agent.get_next_path_position()
	var to_next: Vector2 = next - _walker.global_position
	if to_next.length() < _agent.path_desired_distance:
		if _agent.is_navigation_finished():
			_wp_i = (_wp_i + 1) % _waypoints.size()
			_agent.target_position = _waypoints[_wp_i]
			_dwell = 0.25
			_status.text = "状态：到达路点 %d" % _wp_i
		_walker.velocity = Vector2.ZERO
	else:
		_walker.velocity = to_next.normalized() * WALK_SPEED
	_walker.move_and_slide()
