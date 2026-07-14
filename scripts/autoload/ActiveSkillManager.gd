extends Node

## 主动技能：按住持续激光（穿透伤害 + 分层光束表现）；松手后进入冷却。
## 命中反馈画在敌人身上：使用 EnemyManager 返回的受击坐标 + WeaponTelegraph.add_hit_feedback。

const COOLDOWN_SEC := 4.0
const PIERCE_HALF_WIDTH := 22.0
const PIERCE_RANGE := 720.0
const LASER_TICK_SEC := 0.12
const ACTIVE_SKILL_ID: StringName = &"SK_Player_ActiveLaser_01"
## 每 tick 伤害 = max(下限, 基准爆发伤害 * 该系数)，可按手感调数值
const LASER_DMG_PER_TICK_MUL := 0.09
const BASE_DAMAGE := 38.0
const _HIT_FEEDBACK_MAX_PER_TICK := 14
## 每 tick 在敌人身上额外喷的闪电粒子次数上限（与现有 ParticleManager 池共用，偏省性能）
const _LASER_SPARK_MAX_PER_TICK := 4

signal cooldown_visual_changed(remaining_sec: float, total_sec: float, aiming: bool)

var _game: Node2D = null
var _player: Node2D = null
var _cooldown_left := 0.0
var _laser_firing := false
var _laser_tick_left := 0.0
var _laser_sfx_cd := 0.0
var _beam_root: Node2D = null
var _beam_outline: Line2D = null
var _beam_glow: Line2D = null
var _beam_core: Line2D = null
var _cast_seq := 0
var _bind_retry_left := 0.0
var _bind_warned := false
var _touch_hold := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_resumed.connect(_on_game_resumed)
	EventBus.game_over.connect(_on_game_over)

func _on_game_started() -> void:
	_bind_warned = false
	call_deferred("_bind_game")

func _on_game_resumed() -> void:
	if _game == null or not is_instance_valid(_game):
		call_deferred("_bind_game")

func _on_game_over(_win: bool) -> void:
	_unbind_game()

func _find_game_node() -> Node2D:
	var main := get_tree().root.get_node_or_null("Main")
	if main:
		var direct := main.get_node_or_null("Game") as Node2D
		if direct:
			return direct
	for child in get_tree().root.get_children():
		if child is Node:
			var nested := (child as Node).get_node_or_null("Game") as Node2D
			if nested:
				return nested
	var grouped := get_tree().get_first_node_in_group("active_game") as Node2D
	return grouped

func bind_to_game(game: Node2D) -> void:
	if game == null or not is_instance_valid(game):
		return
	_unbind_game()
	_game = game
	_player = game.get_node_or_null("Player") as Node2D
	if _player == null:
		push_warning("ActiveSkillManager: Player 未找到")
		return
	_ensure_beam_visual(game)
	_bind_warned = false


func _bind_game() -> void:
	bind_to_game(_find_game_node())
	if _game == null and not _bind_warned:
		_bind_warned = true
		push_warning("ActiveSkillManager: Game 未找到，将在对局中重试绑定")

func _unbind_game() -> void:
	_touch_hold = false
	_laser_firing = false
	_laser_tick_left = 0.0
	_laser_sfx_cd = 0.0
	_hide_beam()
	if _beam_root and is_instance_valid(_beam_root):
		_beam_root.queue_free()
	_beam_root = null
	_beam_outline = null
	_beam_glow = null
	_beam_core = null
	_game = null
	_player = null
	cooldown_visual_changed.emit(0.0, COOLDOWN_SEC, false)

func _ensure_beam_visual(game: Node2D) -> void:
	if _beam_root and is_instance_valid(_beam_root):
		return
	var holder := game.get_node_or_null("World")
	if holder == null:
		holder = game
	_beam_root = Node2D.new()
	_beam_root.name = "ActiveSkillLaserBeam"
	_beam_root.z_index = 500
	holder.add_child(_beam_root)
	# 底层深色描边（假外轮廓，不依赖 shader）
	_beam_outline = Line2D.new()
	_beam_outline.name = "Outline"
	_beam_outline.width = 19.0
	_beam_outline.default_color = Color(0.04, 0.1, 0.2, 0.9)
	_beam_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	_beam_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_outline.z_index = 0
	_beam_root.add_child(_beam_outline)
	_beam_glow = Line2D.new()
	_beam_glow.name = "Glow"
	_beam_glow.width = 13.0
	_beam_glow.default_color = Color(0.22, 0.78, 1.0, 0.4)
	_beam_glow.joint_mode = Line2D.LINE_JOINT_ROUND
	_beam_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_glow.z_index = 1
	_beam_root.add_child(_beam_glow)
	_beam_core = Line2D.new()
	_beam_core.name = "Core"
	_beam_core.width = 4.0
	_beam_core.default_color = Color(0.9, 0.98, 1.0, 1.0)
	_beam_core.joint_mode = Line2D.LINE_JOINT_ROUND
	_beam_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_core.z_index = 2
	_beam_root.add_child(_beam_core)

func _process(delta: float) -> void:
	if _game == null or not is_instance_valid(_game) or _player == null or not is_instance_valid(_player):
		_bind_retry_left -= delta
		if _bind_retry_left <= 0.0:
			_bind_retry_left = 0.75
			_bind_game()
		return
	if get_tree().paused:
		_touch_hold = false
		_stop_laser_visual_only()
		cooldown_visual_changed.emit(_cooldown_left, COOLDOWN_SEC, false)
		return
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	var can_use := _cooldown_left <= 0.0
	var want_fire := _is_active_skill_pressed()

	if want_fire and can_use:
		if not _laser_firing:
			_laser_tick_left = 0.0
			_cast_seq += 1
			var caster_id := _player.get_instance_id() if _player else 0
			EventBus.skill_cast_start.emit(ACTIVE_SKILL_ID, caster_id, _cast_seq, Time.get_ticks_msec())
		_laser_firing = true
		_update_beam_points()
		_laser_tick_left -= delta
		if _laser_tick_left <= 0.0:
			_laser_tick_left = LASER_TICK_SEC
			var caster_id := _player.get_instance_id() if _player else 0
			EventBus.skill_active.emit(ACTIVE_SKILL_ID, caster_id, _cast_seq, Engine.get_process_frames(), Time.get_ticks_msec())
			_apply_laser_tick()
		_laser_sfx_cd -= delta
		if _laser_sfx_cd <= 0.0:
			var origin := _player.global_position if _player else Vector2.ZERO
			EventBus.play_sfx.emit(&"lightning", origin)
			_laser_sfx_cd = 0.38
	else:
		if _laser_firing:
			var caster_id := _player.get_instance_id() if _player else 0
			EventBus.skill_end.emit(ACTIVE_SKILL_ID, caster_id, _cast_seq, &"finished", Time.get_ticks_msec())
			_cooldown_left = COOLDOWN_SEC
		_laser_firing = false
		_stop_laser_visual_only()

	cooldown_visual_changed.emit(_cooldown_left, COOLDOWN_SEC, want_fire and can_use)

func _stop_laser_visual_only() -> void:
	_hide_beam()

func _get_mouse_world() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.ZERO
	var vp := _player.get_viewport()
	if vp == null:
		return _player.global_position
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()

func _get_beam_target_world() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.ZERO
	var from: Vector2 = _player.global_position
	if InputManager.is_touch_ui():
		if InputManager.aim_active and InputManager.aim_vector.length_squared() > 0.01:
			return from + InputManager.aim_vector.normalized() * PIERCE_RANGE
		if _game:
			var em := _game.get_node_or_null("EnemyManager")
			if em and em.has_method("get_closest_enemy_pos"):
				var nearest: Variant = em.call("get_closest_enemy_pos", from, PIERCE_RANGE)
				if nearest is Vector2:
					return nearest
		return from + Vector2.RIGHT * PIERCE_RANGE
	return _get_mouse_world()

func _beam_endpoints() -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	if _player == null:
		return out
	var from: Vector2 = _player.global_position
	var target := _get_beam_target_world()
	var dir := target - from
	var to: Vector2
	if dir.length_squared() < 4.0:
		dir = Vector2.RIGHT * 40.0
		to = from + dir.normalized() * minf(dir.length(), PIERCE_RANGE)
	else:
		to = from + dir.normalized() * minf(dir.length(), PIERCE_RANGE)
	out[0] = from
	out[1] = to
	return out

func _update_beam_points() -> void:
	if _beam_root == null or _beam_outline == null or _beam_glow == null or _beam_core == null:
		return
	var ends := _beam_endpoints()
	var from: Vector2 = ends[0]
	var to: Vector2 = ends[1]
	var lf: Vector2 = _beam_root.to_local(from)
	var lt: Vector2 = _beam_root.to_local(to)
	_beam_outline.clear_points()
	_beam_glow.clear_points()
	_beam_core.clear_points()
	_beam_outline.add_point(lf)
	_beam_outline.add_point(lt)
	_beam_glow.add_point(lf)
	_beam_glow.add_point(lt)
	_beam_core.add_point(lf)
	_beam_core.add_point(lt)
	_beam_root.visible = true

func _hide_beam() -> void:
	if _beam_root and is_instance_valid(_beam_root):
		_beam_root.visible = false
	if _beam_outline:
		_beam_outline.clear_points()
	if _beam_glow:
		_beam_glow.clear_points()
	if _beam_core:
		_beam_core.clear_points()

func _apply_laser_tick() -> void:
	if _player == null or _game == null:
		return
	var ends := _beam_endpoints()
	var from: Vector2 = ends[0]
	var to: Vector2 = ends[1]
	var dmg := maxf(2.0, _scaled_damage() * LASER_DMG_PER_TICK_MUL)
	var em := _game.get_node_or_null("EnemyManager") as EnemyManager
	if em == null:
		return
	var hit_positions := em.apply_piercing_line_damage_with_hit_positions(from, to, PIERCE_HALF_WIDTH, dmg, &"active_laser", _cast_seq)
	var wt := _game.get_node_or_null("WeaponTelegraph") as WeaponTelegraph
	if wt:
		var n := mini(hit_positions.size(), _HIT_FEEDBACK_MAX_PER_TICK)
		for i in range(n):
			wt.add_hit_feedback(hit_positions[i], "laser", WeaponTelegraph.HIT_NORMAL, 0.9)
	_spawn_laser_hit_sparks(hit_positions)

func _spawn_laser_hit_sparks(hit_positions: PackedVector2Array) -> void:
	if hit_positions.is_empty():
		return
	var pm := _game.get_node_or_null("ParticleManager")
	if pm == null or not pm.has_method("lightning_spark"):
		return
	var cap := mini(hit_positions.size(), _LASER_SPARK_MAX_PER_TICK)
	var tint := Color(0.62, 0.92, 1.0, 0.88)
	for i in range(cap):
		pm.lightning_spark(hit_positions[i], tint)

func _scaled_damage() -> float:
	var mul := 1.0
	if _game and _game.has_node("SkillSystem"):
		var st: Dictionary = _game.get_node("SkillSystem").stats
		mul += float(st.get("atk_bonus", 0.0))
	return BASE_DAMAGE * mul

func get_cooldown_ratio() -> float:
	if COOLDOWN_SEC <= 0.0:
		return 1.0
	return clampf(1.0 - _cooldown_left / COOLDOWN_SEC, 0.0, 1.0)


func is_bound() -> bool:
	return _game != null and is_instance_valid(_game) and _player != null and is_instance_valid(_player)


func set_touch_hold(active: bool) -> void:
	_touch_hold = active


func _is_active_skill_pressed() -> bool:
	if _touch_hold:
		return true
	if Input.is_action_pressed("active_skill"):
		return true
	if Input.is_physical_key_pressed(KEY_R):
		return true
	if Input.is_key_pressed(KEY_R):
		return true
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
