extends Node
# InputManager (Autoload) - 通过 Autoload 访问，无需 class_name
# - Keyboard movement (digital)
# - Mobile TouchJoystick movement (analog, with snap + strength curve)

# ============================
# State: move
# ============================
static var touch_vector: Vector2 = Vector2.ZERO # smoothed: direction * strength (0..1)
static var touch_vector_raw: Vector2 = Vector2.ZERO # raw: direction * strength (0..1)
static var touch_active: bool = false
static var touch_strength: float = 0.0
static var touch_radius: float = 70.0
static var touch_smoothing: float = 0.22 # 0 = no smoothing, higher = more responsive
static var touch_release_smoothing: float = 0.12
static var touch_releasing: bool = false

# ============================
# State: aim (reserved)
# ============================
static var aim_vector: Vector2 = Vector2.ZERO
static var aim_active: bool = false
static var aim_strength: float = 0.0

# ============================
# Aim / Fire modes
# ============================
# 自动武器仍只读 get_aim_direction()；「主动技能」由 ActiveSkillManager 监听 project.godot 的 active_skill（默认 R / 鼠标右键），勿在此处改 auto_fire。
static var auto_fire: bool = true
static var aim_mode: AimMode = AimMode.AUTO

enum AimMode {
	AUTO,      # auto aim nearest enemy
	SEMI_AUTO, # touch aim or mouse aim
	MANUAL     # mouse aim
}

# ============================
# TouchJoystick settings
# ============================
static var snap_enabled: bool = true
static var snap_threshold: float = 0.22
static var snap_strength: float = 0.72

# Response tuning (thumb feel)
static var move_deadzone_ratio: float = 0.14
static var move_low_end_boost: float = 0.22
static var move_low_end_gamma: float = 1.35
static var move_anchor_follow_ratio: float = 0.28

static var hud_owns_move_joystick: bool = false
static var fixed_joystick_mode: bool = false
static var use_floating_joystick: bool = false

# Touch IDs (multi-touch)
static var move_touch_id: int = -1
static var aim_touch_id: int = -1

# Joystick anchor (screen space)
static var joystick_screen_anchor: Vector2 = Vector2.ZERO
static var joystick_has_anchor: bool = false
static var joystick_following: bool = false
static var joystick_base_pos: Vector2 = Vector2.ZERO
static var joystick_current_pos: Vector2 = Vector2.ZERO

# HUD-provided move zone + radius (screen space)
static var move_zone_screen_rect: Rect2 = Rect2()
static var move_joystick_radius: float = 70.0

# ----------------------------
# Public: setters
# ----------------------------
static func set_touch_vector(v: Vector2, active: bool, strength := -1.0) -> void:
	touch_vector_raw = v
	touch_active = active
	if active:
		touch_releasing = false
	if strength < 0.0:
		touch_strength = clampf(v.length(), 0.0, 1.0)
	else:
		touch_strength = clampf(strength, 0.0, 1.0)
	# If we just became active, snap smoothed state to raw to avoid startup lag.
	if active and touch_vector == Vector2.ZERO and v.length() > 0.001:
		touch_vector = v

static func set_aim_vector(v: Vector2, active: bool, strength := 1.0) -> void:
	aim_vector = v
	aim_active = active
	aim_strength = clampf(strength, 0.0, 1.0)

static func set_aim_mode(mode: AimMode) -> void:
	aim_mode = mode
	auto_fire = (mode == AimMode.AUTO)

static func set_hud_move_joystick_owner(active: bool) -> void:
	hud_owns_move_joystick = active
	fixed_joystick_mode = active
	if active:
		use_floating_joystick = false

static func set_floating_joystick_enabled(on: bool) -> void:
	use_floating_joystick = on and not hud_owns_move_joystick

static func set_move_joystick_snap(enabled: bool, threshold := 0.22, strength := 0.72) -> void:
	snap_enabled = enabled
	snap_threshold = clampf(threshold, 0.0, 0.95)
	snap_strength = clampf(strength, 0.0, 1.0)

static func set_move_joystick_response(deadzone_ratio := 0.14, low_end_boost := 0.22, low_end_gamma := 1.35) -> void:
	move_deadzone_ratio = clampf(deadzone_ratio, 0.0, 0.6)
	move_low_end_boost = clampf(low_end_boost, 0.0, 0.6)
	move_low_end_gamma = clampf(low_end_gamma, 0.6, 3.0)

static func set_move_joystick_anchor_follow(ratio := 0.28) -> void:
	move_anchor_follow_ratio = clampf(ratio, 0.0, 0.8)

# ----------------------------
# Movement: unified API
# ----------------------------
# Returns an analog vector where length is 0..1 (keyboard returns normalized).
# IMPORTANT: do NOT normalize touch output (keeps strength sensing).
static func get_move_vector() -> Vector2:
	var kb := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if kb.length() > 0.01:
		return kb.normalized()

	if (touch_active or touch_releasing) and touch_vector.length() > 0.01:
		var strength := clampf(touch_strength, 0.0, 1.0)
		var dir := touch_vector.normalized()
		if snap_enabled and strength <= snap_threshold + 0.08:
			dir = _apply_direction_snap(dir, strength).normalized()
		var mag := clampf(_move_strength_curve(strength), 0.0, 1.0)
		return dir * mag

	if Settings.mouse_direct_move and is_pc():
		var mv := _pc_mouse_move_vector()
		if mv.length() > 0.01:
			return mv

	return Vector2.ZERO

static func _pc_mouse_move_vector() -> Vector2:
	var loop := Engine.get_main_loop()
	if loop == null:
		return Vector2.ZERO
	var tree := loop as SceneTree
	if tree == null:
		return Vector2.ZERO
	var viewport := tree.root.get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var vp_rect := viewport.get_visible_rect()
	var center := vp_rect.size * 0.5
	var mouse_pos := viewport.get_mouse_position()
	var d := mouse_pos - center
	var deadzone := 18.0
	var len := d.length()
	if len <= deadzone:
		return Vector2.ZERO
	var dir := d / maxf(len, 0.001)
	var mag := clampf((len - deadzone) / 240.0, 0.0, 1.0)
	return dir * mag

static func get_move_analog_magnitude() -> float:
	var kb := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if kb.length() > 0.01:
		return clampf(kb.length() / sqrt(2.0), 0.0, 1.0)
	if touch_active or touch_releasing:
		return clampf(_move_strength_curve(touch_strength), 0.0, 1.0)
	return 0.0

static func _move_strength_curve(strength: float) -> float:
	# 0..1 in, 0..1 out. Tuned for light-thumb control on mobile.
	var s: float = clampf(strength, 0.0, 1.0)
	if s <= 0.0:
		return 0.0
	# Ease-out curve (gamma) with a small low-end boost so walking feels responsive.
	var eased: float = 1.0 - pow(1.0 - s, move_low_end_gamma)
	return clampf(eased + move_low_end_boost * (1.0 - s), 0.0, 1.0)

# ----------------------------
# TouchJoystick math (HUD can feed touches)
# ----------------------------
static func configure_move_joystick(zone_screen_rect: Rect2, radius: float) -> void:
	move_zone_screen_rect = zone_screen_rect
	move_joystick_radius = maxf(radius, 8.0)
	touch_radius = move_joystick_radius

static func move_joystick_zone_contains(screen_pos: Vector2) -> bool:
	if move_zone_screen_rect.size == Vector2.ZERO:
		return false
	# Touch-friendly hit test: allow a small margin outside the rect so thumbs
	# don''t "miss" when landing near the edge (common on mobile).
	if move_zone_screen_rect.has_point(screen_pos):
		return true
	var margin := maxf(12.0, move_joystick_radius * 0.35)
	return move_zone_screen_rect.grow(margin).has_point(screen_pos)

static func move_joystick_touch_begin(screen_pos: Vector2) -> void:
	if fixed_joystick_mode and move_zone_screen_rect.size != Vector2.ZERO:
		joystick_screen_anchor = move_zone_screen_rect.get_center()
		joystick_has_anchor = true
		joystick_base_pos = joystick_screen_anchor
		joystick_following = false
		joystick_current_pos = screen_pos
		return

	var zone := move_zone_screen_rect
	var zone_center := zone.get_center()
	if zone.size == Vector2.ZERO:
		joystick_screen_anchor = screen_pos
	else:
		var pull := 0.55 if is_mobile() else 0.35
		var anchor := zone_center.lerp(screen_pos, pull)
		anchor.x = clampf(anchor.x, zone.position.x + move_joystick_radius, zone.end.x - move_joystick_radius)
		anchor.y = clampf(anchor.y, zone.position.y + move_joystick_radius, zone.end.y - move_joystick_radius)
		joystick_screen_anchor = anchor

	joystick_has_anchor = true
	joystick_base_pos = joystick_screen_anchor
	joystick_following = true
	joystick_current_pos = screen_pos

static func move_joystick_touch_drag(screen_pos: Vector2, deadzone_ratio := 0.14) -> void:
	if not joystick_has_anchor:
		move_joystick_touch_begin(screen_pos)

	joystick_current_pos = screen_pos
	var delta := screen_pos - joystick_screen_anchor
	var r := move_joystick_radius
	var len := delta.length()
	var strength := clampf(len / maxf(r, 0.001), 0.0, 1.0)

	# Thumb adsorption: if finger drags outside radius, move joystick base slightly
	# toward the finger to keep movement direction stable on mobile.
	if len > r and move_anchor_follow_ratio > 0.001:
		var overshoot := len - r
		var pull := clampf(overshoot / maxf(r, 0.001), 0.0, 1.0) * move_anchor_follow_ratio
		if pull > 0.0:
			joystick_screen_anchor = joystick_screen_anchor.lerp(screen_pos, pull)
			joystick_base_pos = joystick_screen_anchor
			delta = screen_pos - joystick_screen_anchor
			len = delta.length()
			strength = clampf(len / maxf(r, 0.001), 0.0, 1.0)

	if len > r:
		delta = delta / len * r
		len = r

	# Prefer configured deadzone unless caller overrides.
	var dzr := deadzone_ratio
	if absf(deadzone_ratio - 0.14) < 0.0001:
		dzr = move_deadzone_ratio
	var dz := dzr * r
	var dir := Vector2.ZERO
	if len > dz:
		dir = delta.normalized()
	else:
		# Ensure magnitude reads as zero within deadzone.
		strength = 0.0

	# Store direction*strength; snap/curve applied once in get_move_vector()
	set_touch_vector(dir * strength, true, strength)

static func move_joystick_touch_end() -> void:
	joystick_has_anchor = false
	joystick_following = false
	joystick_screen_anchor = Vector2.ZERO
	# Keep a tiny release buffer to avoid abrupt stop feeling on mobile.
	touch_active = false
	touch_releasing = true
	touch_vector_raw = Vector2.ZERO
	touch_strength = 0.0
	move_touch_id = -1

# ----------------------------
# Floating joystick input (optional, left half screen)
# ----------------------------
static func _floating_zone(screen_size: Vector2) -> Rect2:
	var w := screen_size.x * 0.48
	return Rect2(Vector2(0, 88), Vector2(w, screen_size.y - 96.0))

func _input(event: InputEvent) -> void:
	if hud_owns_move_joystick or not use_floating_joystick:
		return

	var vp := get_viewport()
	if vp == null:
		return

	var ssize: Vector2 = vp.get_visible_rect().size
	configure_move_joystick(_floating_zone(ssize), touch_radius)

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if move_touch_id != -1:
				return
			if not move_joystick_zone_contains(st.position):
				return
			move_touch_id = st.index
			move_joystick_touch_begin(st.position)
			move_joystick_touch_drag(st.position)
			vp.set_input_as_handled()
		else:
			if st.index == move_touch_id:
				move_joystick_touch_end()
				move_touch_id = -1
				vp.set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == move_touch_id:
			move_joystick_touch_drag(sd.position)
			vp.set_input_as_handled()

func _process(delta: float) -> void:
	# Smooth raw touch vector for stable mobile movement while keeping strength sensing.
	# NOTE: keyboard movement bypasses this path (get_move_vector returns kb normalized).
	if not touch_active and not touch_releasing:
		touch_vector = Vector2.ZERO
		touch_vector_raw = Vector2.ZERO
		return
	var a := touch_smoothing if touch_active else touch_release_smoothing
	a = clampf(a, 0.0, 1.0)
	# Convert smoothing feel into time-based lerp (stable across FPS).
	var t := 1.0 - pow(1.0 - a, delta * 60.0)
	touch_vector = touch_vector.lerp(touch_vector_raw, t)
	if touch_releasing and touch_vector.length() <= 0.01:
		touch_vector = Vector2.ZERO
		touch_vector_raw = Vector2.ZERO
		touch_releasing = false

# ----------------------------
# Snap helpers
# ----------------------------
static func _apply_direction_snap(dir: Vector2, strength: float) -> Vector2:
	if dir.length() < 0.001:
		return dir
	var angle: float = dir.angle()
	var snapped_angle: float = round(angle / (PI / 4.0)) * (PI / 4.0)
	var snapped: Vector2 = Vector2.from_angle(snapped_angle)

	# More aggressive snapping at very low strength
	var t := clampf(1.0 - snap_strength, 0.0, 1.0)
	if strength <= snap_threshold:
		t *= 0.25
	return snapped.lerp(dir.normalized(), t)

# ----------------------------
# Aim API (existing)
# ----------------------------
func get_aim_direction(player_pos: Vector2, nearest_enemy_pos: Vector2 = Vector2.ZERO) -> Vector2:
	match aim_mode:
		AimMode.AUTO:
			if nearest_enemy_pos != Vector2.ZERO:
				return (nearest_enemy_pos - player_pos).normalized()
			return Vector2.RIGHT
		AimMode.SEMI_AUTO:
			if aim_active and aim_vector.length() > 0.01:
				return aim_vector.normalized()
			var viewport: Viewport = Engine.get_main_loop().root.get_viewport()
			if viewport:
				var mouse_pos: Vector2 = viewport.get_mouse_position()
				var d: Vector2 = player_pos.direction_to(mouse_pos)
				if d.length() > 0.01:
					return d
			return Vector2.RIGHT
		AimMode.MANUAL:
			var viewport2: Viewport = Engine.get_main_loop().root.get_viewport()
			if viewport2:
				var mouse_pos2: Vector2 = viewport2.get_mouse_position()
				var d2: Vector2 = player_pos.direction_to(mouse_pos2)
				if d2.length() > 0.01:
					return d2
			return Vector2.RIGHT
	return Vector2.RIGHT

func should_fire() -> bool:
	return auto_fire

static func get_joystick_knob_offset_pixels(radius: float) -> Vector2:
	if not touch_active:
		return Vector2.ZERO
	var r := maxf(radius, 1.0)
	# Use smoothed vector for visuals so the knob looks stable.
	var raw := touch_vector * r
	if raw.length() > r:
		raw = raw.normalized() * r
	return raw

static func get_move_joystick_base_screen_pos() -> Vector2:
	# HUD can query this to draw base visuals that follow the anchor.
	if joystick_has_anchor:
		return joystick_base_pos
	return Vector2.ZERO

static func get_joystick_knob_position(base_pos: Vector2, radius: float) -> Vector2:
	return base_pos + get_joystick_knob_offset_pixels(radius)

static func update_joystick_base(touch_pos: Vector2, screen_size: Vector2) -> void:
	if joystick_following:
		var min_x := 80.0
		var max_x := screen_size.x * 0.4
		var min_y := screen_size.y * 0.5
		var max_y := screen_size.y - 80.0
		joystick_base_pos.x = clampf(touch_pos.x, min_x, max_x)
		joystick_base_pos.y = clampf(touch_pos.y, min_y, max_y)

static func reset_joystick() -> void:
	touch_vector = Vector2.ZERO
	touch_vector_raw = Vector2.ZERO
	touch_active = false
	touch_releasing = false
	touch_strength = 0.0
	move_touch_id = -1
	joystick_following = false
	joystick_has_anchor = false
	joystick_screen_anchor = Vector2.ZERO

static func reset_aim() -> void:
	aim_vector = Vector2.ZERO
	aim_active = false
	aim_strength = 0.0
	aim_touch_id = -1

static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

static func is_pc() -> bool:
	return OS.has_feature("pc") or OS.has_feature("windows") or OS.has_feature("macos") or OS.has_feature("linux")

static func auto_select_aim_mode() -> void:
	if is_mobile():
		set_aim_mode(AimMode.AUTO)
		use_floating_joystick = not hud_owns_move_joystick
	else:
		set_aim_mode(AimMode.SEMI_AUTO)
		use_floating_joystick = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset_joystick()
		reset_aim()

func _ready() -> void:
	# Mobile-first defaults: enable floating movement joystick unless UI overrides ownership.
	# Keeps PC keyboard input untouched while making mobile control work by default.
	auto_select_aim_mode()
	if is_mobile() and not hud_owns_move_joystick:
		set_floating_joystick_enabled(true)
		# Sensible thumb feel defaults (can be tuned later via Settings / UI).
		set_move_joystick_snap(true, 0.22, 0.72)
		set_move_joystick_response(0.14, 0.22, 1.35)
