extends Node2D
class_name WeaponTelegraph

# Theme-only telegraph rendering: all colors come from Theme variations.
const TELEGRAPH_THEME := preload("res://assets/themes/cyber_theme.tres")

const V_THREAT := &"PanelThreat"
const V_WARNING := &"PanelWarning"
const V_DANGER := &"PanelDanger"
const HIT_NORMAL := &"normal"
const HIT_CRIT := &"crit"
const HIT_KILL := &"kill"
const HIT_THREAT := &"threat"
const KILL_NORMAL := &"normal"
const KILL_CRIT := &"crit"
const KILL_THREAT := &"threat"
const KILL_BOSS_PHASE := &"boss_phase"
const _ENTITY_PROJECTILE_KINDS := {
	"kunai": true,
	"lightning": true,
	"rocket": true,
	"drone_ab": true,
	"boomerang": true,
	"molotov": true,
	"quantum_ball": true,
}

const _BASE_MAX_HIT_PULSES := 110
const _BASE_MAX_TRAIL_POINTS := 280
const _HIT_STYLE := {
	HIT_NORMAL: {"duration": 0.154, "radius_mul": 0.9, "line_mul": 1.02, "fill": 0.094, "line": 0.58},
	HIT_CRIT: {"duration": 0.206, "radius_mul": 1.1, "line_mul": 1.38, "fill": 0.122, "line": 0.84},
	HIT_KILL: {"duration": 0.24, "radius_mul": 1.3, "line_mul": 1.55, "fill": 0.146, "line": 0.92},
	HIT_THREAT: {"duration": 0.222, "radius_mul": 1.22, "line_mul": 1.48, "fill": 0.136, "line": 0.9}
}
const _TIER_NORMAL := &"normal"
const _TIER_CRIT := &"crit"
const _TIER_THREAT := &"threat"
const _TIER_MUL := {
	_TIER_NORMAL: {"duration": 1.0, "width": 1.0, "fill": 0.92, "line": 1.0},
	_TIER_CRIT: {"duration": 1.06, "width": 1.08, "fill": 0.98, "line": 1.14},
	_TIER_THREAT: {"duration": 1.14, "width": 1.32, "fill": 1.06, "line": 1.32}
}
const _PROFILE_MUL := {
	0: {"duration": 0.92, "width": 0.92, "fill": 0.78, "line": 0.96, "radius": 0.92, "wobble": 0.72},
	1: {"duration": 1.0, "width": 1.0, "fill": 1.0, "line": 1.0, "radius": 1.0, "wobble": 1.0},
	2: {"duration": 1.12, "width": 1.1, "fill": 1.18, "line": 1.08, "radius": 1.1, "wobble": 1.2}
}

# Backward-compat palette used by WeaponSystem hit tinting.
const WEAPON_COLORS := {
	"kunai": {"primary": Color(0.74, 0.9, 1.0, 1.0)},
	"quantum_ball": {"primary": Color(0.72, 0.95, 0.62, 1.0)},
	"lightning": {"primary": Color(0.62, 0.8, 1.0, 1.0)},
	"molotov": {"primary": Color(1.0, 0.56, 0.28, 1.0)},
	"rocket": {"primary": Color(1.0, 0.42, 0.34, 1.0)},
	"guardian": {"primary": Color(0.95, 0.78, 0.42, 1.0)},
	"drone_ab": {"primary": Color(0.8, 0.9, 1.0, 1.0)},
	"boomerang": {"primary": Color(0.95, 0.86, 0.52, 1.0)},
	"stun_mine": {"primary": Color(0.7, 0.84, 1.0, 1.0)},
	"frost_aura": {"primary": Color(0.55, 0.88, 1.0, 1.0)},
	"heal_aura": {"primary": Color(0.45, 1.0, 0.72, 1.0)},
	"explosion_kill": {"primary": Color(1.0, 0.52, 0.22, 1.0)},
	"active_skill": {"primary": Color(0.78, 0.62, 1.0, 1.0)},
	"laser": {"primary": Color(0.45, 0.92, 1.0, 1.0)},
	"boss": {"primary": Color(1.0, 0.38, 0.62, 1.0)}
}

var _rocket_marks: Array[Dictionary] = []
var _burn_marks: Array[Dictionary] = []
var _lightning_marks: Array[Dictionary] = []
var _guardian_marks: Array[Dictionary] = []
var _drone_marks: Array[Dictionary] = []
var _chain_marks: Array[Dictionary] = []
var _lightning_main_beams: Array[Dictionary] = []
var _projectiles: Array[Dictionary] = []
var _frost_aura_marks: Array[Dictionary] = []
var _mine_marks: Array[Dictionary] = []
var _heal_aura_marks: Array[Dictionary] = []
var _trail_history: Array[Dictionary] = []
var _quantum_ripples: Array[Dictionary] = []
var _molotov_flashes: Array[Dictionary] = []
var _hit_pulses: Array[Dictionary] = []
var _kill_bursts: Array[Dictionary] = []
var _kunai_cross_hits: Array[Dictionary] = []
var _lightning_hex_pulses: Array[Dictionary] = []
var _rocket_fans: Array[Dictionary] = []
var _drone_sweeps: Array[Dictionary] = []
var _boomerang_crescents: Array[Dictionary] = []
var _molotov_cones: Array[Dictionary] = []
var _guardian_slices: Array[Dictionary] = []
var _mine_shock_cones: Array[Dictionary] = []
var _runtime_overload_mul := 1.0

func set_runtime_overload_mul(v: float) -> void:
	_runtime_overload_mul = clampf(v, 0.55, 1.0)
var _was_active_last_frame := false

func _ready() -> void:
	if EventBus and EventBus.has_signal("enemy_killed_detailed"):
		EventBus.enemy_killed_detailed.connect(_on_enemy_killed_detailed)

func _process(delta: float) -> void:
	_tick_array(_rocket_marks, delta)
	_tick_array(_burn_marks, delta)
	_tick_array(_lightning_marks, delta)
	_tick_array(_guardian_marks, delta)
	_tick_array(_drone_marks, delta)
	_tick_array(_chain_marks, delta)
	_tick_array(_quantum_ripples, delta)
	_tick_array(_molotov_flashes, delta)
	_tick_array(_lightning_main_beams, delta)
	_tick_array(_frost_aura_marks, delta)
	_tick_array(_mine_marks, delta)
	_tick_array(_heal_aura_marks, delta)
	_tick_array(_trail_history, delta)
	_tick_array(_hit_pulses, delta)
	_tick_array(_kill_bursts, delta)
	_tick_array(_kunai_cross_hits, delta)
	_tick_array(_lightning_hex_pulses, delta)
	_tick_array(_rocket_fans, delta)
	_tick_array(_drone_sweeps, delta)
	_tick_array(_boomerang_crescents, delta)
	_tick_array(_molotov_cones, delta)
	_tick_array(_guardian_slices, delta)
	_tick_array(_mine_shock_cones, delta)
	_tick_projectiles(delta)
	var active := _has_active_fx()
	if active or _was_active_last_frame:
		queue_redraw()
	_was_active_last_frame = active

func _tick_array(items: Array[Dictionary], delta: float) -> void:
	for i in range(items.size() - 1, -1, -1):
		var d := items[i]
		d["time"] = float(d.get("time", 0.0)) - delta
		if float(d["time"]) <= 0.0:
			items.remove_at(i)
		else:
			items[i] = d

func _tick_projectiles(delta: float) -> void:
	for i in range(_projectiles.size() - 1, -1, -1):
		var p := _projectiles[i]
		p["time"] = float(p.get("time", 0.0)) - delta
		if float(p["time"]) <= 0.0:
			_projectiles.remove_at(i)
			continue
		var speed := float(p.get("speed", 600.0))
		var dir: Vector2 = p.get("dir", Vector2.RIGHT)
		var old_pos: Vector2 = p.get("pos", Vector2.ZERO)
		var new_pos := old_pos + dir * speed * delta
		p["pos"] = new_pos
		var t := 0.28
		_capped_append(_trail_history, {
			"pos": old_pos,
			"time": t,
			"max_time": t,
			"variation": _variation_for_weapon(String(p.get("kind", "")))
		}, _BASE_MAX_TRAIL_POINTS)
		_projectiles[i] = p

func add_hit_feedback(pos: Vector2, weapon_kind: String, hit_type: StringName = HIT_NORMAL, intensity: float = 1.0) -> void:
	if pos == Vector2.ZERO:
		return
	var kind := hit_type if _HIT_STYLE.has(hit_type) else HIT_NORMAL
	var style: Dictionary = _HIT_STYLE[kind]
	var c_intensity := clampf(intensity, 0.7, 1.75)
	var tier := _tier_for_hit_type(kind)
	var duration := float(style["duration"]) * (0.94 + c_intensity * 0.22) * _tier_mul(tier, "duration") * _profile_mul("duration")
	var radius := 16.0 * float(style["radius_mul"]) * c_intensity * _profile_mul("radius")
	var line_width := 1.7 * float(style["line_mul"]) * minf(1.22, c_intensity) * _tier_mul(tier, "width")
	var variation := _variation_for_weapon(weapon_kind)
	if kind == HIT_KILL or kind == HIT_THREAT:
		variation = V_DANGER
	elif kind == HIT_CRIT:
		variation = V_WARNING
	_capped_append(_hit_pulses, {
		"pos": pos,
		"time": duration,
		"max_time": maxf(0.06, duration),
		"radius": radius,
		"line_w": line_width,
		"fill_mul": float(style["fill"]),
		"line_mul": float(style["line"]),
		"variation": variation
	}, _BASE_MAX_HIT_PULSES)

func add_kill_feedback(pos: Vector2, tier: StringName, combo_count: int = 0, boss_phase: int = 0, killing_weapon: StringName = &"") -> void:
	if pos == Vector2.ZERO:
		return
	var duration := 0.18
	var ring_scale := 1.0
	var variation: StringName = V_DANGER
	match tier:
		KILL_CRIT:
			duration = 0.2
			ring_scale = 1.1
			variation = V_WARNING
		KILL_THREAT:
			duration = 0.22
			ring_scale = 1.24
			variation = V_DANGER
		KILL_BOSS_PHASE:
			duration = 0.24
			ring_scale = 1.38
			variation = V_DANGER
		_:
			duration = 0.17
	var combo_bonus := clampf(float(combo_count - 2) * 0.04, 0.0, 0.2)
	duration += combo_bonus
	var shards := 2
	if tier == KILL_CRIT:
		shards = 3
	elif tier == KILL_THREAT:
		shards = 4
	elif tier == KILL_BOSS_PHASE:
		shards = 5 + mini(2, boss_phase)
	_capped_append(_kill_bursts, {
		"pos": pos,
		"time": duration,
		"max_time": duration,
		"variation": variation,
		"ring_scale": ring_scale + combo_bonus * 0.6,
		"tier": tier,
		"combo": combo_count,
		"boss_phase": boss_phase,
		"seed": randf() * TAU,
		"shards": shards,
		"weapon": killing_weapon
	}, 64)

func _on_enemy_killed_detailed(pos: Vector2, tier: StringName, combo_count: int, boss_phase: int, killing_weapon: StringName) -> void:
	add_kill_feedback(pos, tier, combo_count, boss_phase, killing_weapon)

func add_rocket_mark(pos: Vector2, radius: float, delay: float) -> void:
	_rocket_marks.append({
		"pos": pos, "radius": radius, "time": delay, "max_time": maxf(0.05, delay), "variation": V_DANGER,
		"pulse_speed": 10.0 + randf() * 6.0
	})

func add_burn_mark(pos: Vector2, radius: float, duration: float) -> void:
	_burn_marks.append({
		"pos": pos, "radius": radius, "time": duration, "max_time": maxf(0.05, duration), "variation": V_DANGER,
		"seed": randf() * TAU
	})

func add_lightning_mark(pos: Vector2, radius: float, delay: float) -> void:
	_lightning_marks.append({"pos": pos, "radius": radius, "time": delay, "max_time": maxf(0.05, delay), "variation": V_WARNING})

func add_guardian_mark(center: Vector2, radius: float, duration: float, blade_count: int = 2, speed_mul: float = 1.0) -> void:
	_guardian_marks.append({
		"center": center, "radius": radius, "time": duration, "max_time": maxf(0.08, duration),
		"phase": 0.0, "speed": 5.8 * speed_mul, "blades": maxi(2, mini(6, blade_count)),
		"variation": V_WARNING
	})

func add_guardian_slice(pos: Vector2, dir: Vector2, radius: float, duration: float) -> void:
	var n := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_capped_append(_guardian_slices, {
		"pos": pos, "dir": n, "radius": maxf(14.0, radius), "time": duration, "max_time": maxf(0.08, duration),
		"variation": V_WARNING
	}, 72)

func add_drone_mark(from_pos: Vector2, to_pos: Vector2, duration: float, beam_width: float = 3.8) -> void:
	_drone_marks.append({
		"from": from_pos, "to": to_pos, "time": duration, "max_time": maxf(0.05, duration),
		"beam_w": maxf(2.0, beam_width), "variation": V_WARNING, "is_drone": true
	})

func add_chain_mark(from_pos: Vector2, to_pos: Vector2, duration: float, _col: Variant = null, line_width := 0.0) -> void:
	_chain_marks.append({
		"from": from_pos, "to": to_pos, "time": duration, "max_time": maxf(0.05, duration),
		"width": line_width, "variation": V_WARNING
	})

func add_quantum_burst_preview(pos: Vector2, radius: float, duration: float) -> void:
	_quantum_ripples.append({
		"pos": pos, "radius": radius, "time": duration, "max_time": maxf(0.08, duration), "variation": V_THREAT,
		"seed": randf() * TAU
	})

func add_quantum_hex_pulse(pos: Vector2, radius: float, duration: float) -> void:
	_capped_append(_lightning_hex_pulses, {
		"pos": pos, "radius": maxf(12.0, radius), "time": duration, "max_time": maxf(0.08, duration),
		"variation": V_THREAT, "seed": randf() * TAU
	}, 72)

func add_molotov_impact_flash(pos: Vector2, radius: float, duration: float) -> void:
	_molotov_flashes.append({
		"pos": pos, "radius": radius, "time": duration, "max_time": maxf(0.06, duration), "variation": V_DANGER,
		"flare_seed": randf() * TAU
	})

func add_molotov_cone(pos: Vector2, dir: Vector2, radius: float, duration: float) -> void:
	var n := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_capped_append(_molotov_cones, {
		"pos": pos, "dir": n, "radius": maxf(18.0, radius), "time": duration, "max_time": maxf(0.08, duration),
		"variation": V_DANGER
	}, 64)

func add_quantum_striker_line(from_pos: Vector2, to_pos: Vector2, duration: float, line_width := 3.2) -> void:
	_chain_marks.append({
		"from": from_pos, "to": to_pos, "time": duration, "max_time": maxf(0.05, duration),
		"width": line_width, "variation": V_THREAT, "is_quantum": true
	})

func add_boomerang_slice_line(from_pos: Vector2, to_pos: Vector2, duration: float, line_width := 3.6) -> void:
	_chain_marks.append({
		"from": from_pos, "to": to_pos, "time": duration, "max_time": maxf(0.05, duration),
		"width": line_width, "variation": V_WARNING, "is_boomerang": true
	})

func add_boomerang_crescent(pos: Vector2, dir: Vector2, duration: float, scale: float = 1.0) -> void:
	var n := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_capped_append(_boomerang_crescents, {
		"pos": pos, "dir": n, "time": duration, "max_time": maxf(0.08, duration),
		"scale": clampf(scale, 0.75, 1.8), "variation": V_WARNING
	}, 72)

func add_drone_pulse_beam(from_pos: Vector2, to_pos: Vector2, duration: float) -> void:
	_chain_marks.append({
		"from": from_pos, "to": to_pos, "time": duration, "max_time": maxf(0.05, duration),
		"width": 3.2, "variation": V_WARNING, "is_drone": true
	})

func add_lightning_chain(from_pos: Vector2, to_pos: Vector2, duration: float) -> void:
	_chain_marks.append({
		"from": from_pos, "to": to_pos, "time": duration, "max_time": maxf(0.05, duration),
		"width": 3.2, "variation": V_WARNING, "is_lightning": true
	})

func add_lightning_main_beam(from_pos: Vector2, to_pos: Vector2, duration: float) -> void:
	_lightning_main_beams.append({
		"from": from_pos, "to": to_pos, "time": duration, "max_time": maxf(0.05, duration), "variation": V_WARNING,
		"is_lightning": true
	})

func add_kunai_trail(from_pos: Vector2, to_pos: Vector2) -> void:
	var d := to_pos - from_pos
	_chain_marks.append({
		"from": from_pos, "to": to_pos, "time": 0.2, "max_time": 0.2,
		"width": 2.4, "variation": V_THREAT, "is_kunai": true
	})
	if d.length() > 0.001:
		var perp := d.normalized().orthogonal()
		_chain_marks.append({
			"from": from_pos + perp * 0.35, "to": to_pos + perp * 0.35, "time": 0.2, "max_time": 0.2,
			"width": 1.6, "variation": V_THREAT, "is_kunai": true
		})
		_chain_marks.append({
			"from": from_pos - perp * 0.35, "to": to_pos - perp * 0.35, "time": 0.2, "max_time": 0.2,
			"width": 1.2, "variation": V_THREAT, "is_kunai": true
		})

func add_kunai_impact_cross(pos: Vector2, dir: Vector2, duration: float, scale: float = 1.0) -> void:
	var n := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_capped_append(_kunai_cross_hits, {
		"pos": pos, "dir": n, "time": duration, "max_time": maxf(0.06, duration),
		"scale": clampf(scale, 0.75, 1.7), "variation": V_THREAT
	}, 56)

func add_lightning_hex_pulse(pos: Vector2, radius: float, duration: float) -> void:
	_capped_append(_lightning_hex_pulses, {
		"pos": pos, "radius": maxf(12.0, radius), "time": duration, "max_time": maxf(0.08, duration),
		"variation": V_WARNING, "seed": randf() * TAU
	}, 52)

func add_rocket_fan(pos: Vector2, dir: Vector2, radius: float, duration: float) -> void:
	var n := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_capped_append(_rocket_fans, {
		"pos": pos, "dir": n, "radius": maxf(16.0, radius), "time": duration, "max_time": maxf(0.08, duration),
		"variation": V_DANGER
	}, 48)

func add_drone_sweep(from_pos: Vector2, to_pos: Vector2, duration: float, width: float = 4.6) -> void:
	_capped_append(_drone_sweeps, {
		"from": from_pos, "to": to_pos, "time": duration, "max_time": maxf(0.08, duration),
		"width": maxf(2.0, width), "variation": V_WARNING
	}, 80)

func add_frost_aura_mark(pos: Vector2, radius: float, duration: float) -> void:
	_frost_aura_marks.append({
		"pos": pos, "radius": radius, "time": duration, "max_time": maxf(0.05, duration), "variation": V_WARNING,
		"seed": randf() * TAU
	})

func add_mine_mark(pos: Vector2, radius: float, duration: float) -> void:
	_mine_marks.append({
		"pos": pos, "radius": radius, "time": duration, "max_time": maxf(0.05, duration), "variation": V_WARNING,
		"seed": randf() * TAU
	})

func add_mine_shock_cone(pos: Vector2, dir: Vector2, radius: float, duration: float) -> void:
	var n := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_capped_append(_mine_shock_cones, {
		"pos": pos, "dir": n, "radius": maxf(14.0, radius), "time": duration, "max_time": maxf(0.08, duration),
		"variation": V_WARNING
	}, 64)

func add_heal_aura_mark(pos: Vector2, radius: float, duration: float) -> void:
	_heal_aura_marks.append({
		"pos": pos, "radius": radius, "time": duration, "max_time": maxf(0.05, duration), "variation": V_THREAT,
		"seed": randf() * TAU
	})

func add_projectile(pos: Vector2, dir: Vector2, kind: String, speed := 600.0, lifetime := 0.35, weapon_lv: int = 1, evolved: bool = false) -> void:
	if _ENTITY_PROJECTILE_KINDS.has(kind):
		return
	_projectiles.append({
		"pos": pos, "dir": dir.normalized(), "kind": kind, "speed": speed, "time": lifetime, "max_time": maxf(0.05, lifetime),
		"weapon_lv": weapon_lv, "evolved": evolved, "variation": _variation_for_weapon(kind)
	})

func _variation_for_weapon(kind: String) -> StringName:
	match kind:
		"rocket", "molotov":
			return V_DANGER
		"lightning", "stun_mine", "guardian", "drone_ab", "laser":
			return V_WARNING
		_:
			return V_THREAT

func _tier_for_hit_type(hit_type: StringName) -> StringName:
	if hit_type == HIT_THREAT or hit_type == HIT_KILL:
		return _TIER_THREAT
	if hit_type == HIT_CRIT:
		return _TIER_CRIT
	return _TIER_NORMAL

func _tier_for_variation(variation: StringName) -> StringName:
	if variation == V_DANGER:
		return _TIER_THREAT
	if variation == V_WARNING:
		return _TIER_CRIT
	return _TIER_NORMAL

func _tier_mul(tier: StringName, key: String) -> float:
	var bucket: Dictionary = _TIER_MUL.get(tier, _TIER_MUL[_TIER_NORMAL])
	return float(bucket.get(key, 1.0)) * _profile_mul(key)

func _profile_mul(key: String) -> float:
	if not Settings:
		return 1.0
	var profile := 1
	if Settings.has_method("get"):
		profile = int(Settings.get("vfx_profile"))
	var bucket: Dictionary = _PROFILE_MUL.get(profile, _PROFILE_MUL[1])
	return float(bucket.get(key, 1.0))

func _fx_budget_mult() -> float:
	if Settings and Settings.reduce_particles:
		return 0.6
	if not Settings:
		return 1.0
	var profile_mul := 1.0
	var vfx_profile := 1
	if Settings.has_method("get"):
		vfx_profile = int(Settings.get("vfx_profile"))
		match vfx_profile:
			0:
				profile_mul = 0.86
			2:
				profile_mul = 1.06
			_:
				profile_mul = 1.0
	match int(Settings.quality):
		0:
			return 0.72 * profile_mul
		2:
			return 1.2 * profile_mul
		_:
			return 1.0 * profile_mul

func _capped_append(items: Array[Dictionary], payload: Dictionary, base_cap: int) -> void:
	var cap := maxi(24, int(round(float(base_cap) * _fx_budget_mult() * _runtime_overload_mul)))
	if items.size() >= cap:
		items.remove_at(0)
	items.append(payload)

func _has_active_fx() -> bool:
	return not _rocket_marks.is_empty() \
		or not _burn_marks.is_empty() \
		or not _lightning_marks.is_empty() \
		or not _guardian_marks.is_empty() \
		or not _drone_marks.is_empty() \
		or not _chain_marks.is_empty() \
		or not _lightning_main_beams.is_empty() \
		or not _projectiles.is_empty() \
		or not _frost_aura_marks.is_empty() \
		or not _mine_marks.is_empty() \
		or not _heal_aura_marks.is_empty() \
		or not _trail_history.is_empty() \
		or not _quantum_ripples.is_empty() \
		or not _molotov_flashes.is_empty() \
		or not _hit_pulses.is_empty() \
		or not _kill_bursts.is_empty() \
		or not _kunai_cross_hits.is_empty() \
		or not _lightning_hex_pulses.is_empty() \
		or not _rocket_fans.is_empty() \
		or not _drone_sweeps.is_empty() \
		or not _boomerang_crescents.is_empty() \
		or not _molotov_cones.is_empty() \
		or not _guardian_slices.is_empty() \
		or not _mine_shock_cones.is_empty()

func _color_for_variation(variation: StringName) -> Color:
	var sb := TELEGRAPH_THEME.get_stylebox("panel", variation)
	if sb is StyleBoxFlat:
		var flat := sb as StyleBoxFlat
		if flat.border_color.a > 0.0:
			return flat.border_color
		return flat.bg_color
	return TELEGRAPH_THEME.get_color("font_color", "Label")

func _with_alpha(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0))


func _weapon_kill_primary(wid: StringName) -> Color:
	var key := String(wid)
	if WEAPON_COLORS.has(key):
		var d: Dictionary = WEAPON_COLORS[key]
		return d["primary"] as Color
	return Color(1.0, 0.58, 0.34, 1.0)


func _draw_mark_circle(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var r := float(mark.get("radius", 10.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var variation := StringName(mark.get("variation", V_THREAT))
	var tier := _tier_for_variation(variation)
	var c := _color_for_variation(variation)
	draw_circle(p, r, _with_alpha(c, a * 0.14 * _tier_mul(tier, "fill")))
	draw_arc(p, r, 0.0, TAU, 36, _with_alpha(c, a * 0.6 * _tier_mul(tier, "line")), 2.0 * _tier_mul(tier, "width"))

func _draw_rocket_mark(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var r := float(mark.get("radius", 16.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var ratio := clampf(t / mt, 0.0, 1.0)
	var progress := 1.0 - ratio
	var c := _color_for_variation(StringName(mark.get("variation", V_DANGER)))
	var pulse_speed := float(mark.get("pulse_speed", 12.0))
	var pulse := 0.78 + 0.22 * sin(progress * pulse_speed * PI)
	var base_fill := 0.1 + 0.07 * (1.0 - ratio)
	draw_circle(p, r * (0.96 + progress * 0.05), _with_alpha(c, base_fill * pulse))
	draw_arc(p, r * (0.98 + progress * 0.16), 0.0, TAU, 40, _with_alpha(c, (0.42 + progress * 0.28) * pulse), 2.2 + progress * 1.3)
	var wedge_count := 3
	var wedge_span := 0.28 + progress * 0.12
	var orbit_r := r * (0.72 + progress * 0.2)
	for i in range(wedge_count):
		var phase := progress * TAU * (0.4 + 0.15 * i) + (TAU / wedge_count) * i
		draw_arc(p, orbit_r, phase, phase + wedge_span, 8, _with_alpha(c, (0.25 + progress * 0.35) * ratio), 2.0)
	draw_circle(p, maxf(3.0, r * 0.18), _with_alpha(c, (0.16 + progress * 0.34) * pulse))

func _draw_beam(mark: Dictionary, width_mul := 1.0) -> void:
	var from_p: Vector2 = mark.get("from", Vector2.ZERO)
	var to_p: Vector2 = mark.get("to", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var variation := StringName(mark.get("variation", V_THREAT))
	var tier := _tier_for_variation(variation)
	var lw := maxf(1.0, float(mark.get("width", mark.get("beam_w", 2.0)))) * width_mul * _tier_mul(tier, "width")
	var c := _color_for_variation(variation)
	draw_line(from_p, to_p, _with_alpha(c, a * 0.58 * _tier_mul(tier, "line")), lw)
	draw_line(from_p, to_p, _with_alpha(c, a * 0.28 * _tier_mul(tier, "fill")), lw + 2.0)

func _draw_lightning_beam(mark: Dictionary, width_mul := 1.0) -> void:
	var from_p: Vector2 = mark.get("from", Vector2.ZERO)
	var to_p: Vector2 = mark.get("to", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var variation := StringName(mark.get("variation", V_WARNING))
	var tier := _tier_for_variation(variation)
	var base_w := maxf(1.0, float(mark.get("width", mark.get("beam_w", 2.4)))) * width_mul * _tier_mul(tier, "width")
	var c := _color_for_variation(variation)
	draw_line(from_p, to_p, _with_alpha(c, a * 0.7 * _tier_mul(tier, "line")), base_w + 0.8)
	draw_line(from_p, to_p, _with_alpha(Color(0.84, 0.95, 1.0, 1.0), a * 0.46 * _tier_mul(tier, "fill")), base_w + 2.6)
	var dir := to_p - from_p
	var len := dir.length()
	if len < 1.0:
		return
	var n := dir / len
	var perp := n.orthogonal()
	var segment_count := mini(8, maxi(3, int(len / 42.0)))
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(from_p)
	for i in range(1, segment_count):
		var k := float(i) / float(segment_count)
		var wobble := sin((k + life * 1.8) * TAU * 2.2) * (3.2 + base_w * 0.72) * _profile_mul("wobble")
		pts.append(from_p + n * (len * k) + perp * wobble)
	pts.append(to_p)
	for i in range(pts.size() - 1):
		var fade := (1.0 - float(i) / float(maxi(1, pts.size() - 1))) * a
		draw_line(pts[i], pts[i + 1], _with_alpha(c, 0.54 * fade * _tier_mul(tier, "line")), maxf(1.0, base_w * 0.72))
	draw_circle(to_p, base_w * 1.15 + 2.0, _with_alpha(Color(0.85, 0.97, 1.0, 1.0), a * 0.5 * _tier_mul(tier, "fill")))

func _draw_kunai_beam(mark: Dictionary) -> void:
	var from_p: Vector2 = mark.get("from", Vector2.ZERO)
	var to_p: Vector2 = mark.get("to", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var c := _color_for_variation(StringName(mark.get("variation", V_THREAT)))
	var lw := maxf(1.0, float(mark.get("width", 2.0)))
	draw_line(from_p, to_p, _with_alpha(c, 0.62 * a), lw)
	draw_line(from_p, to_p, _with_alpha(Color(0.86, 0.97, 1.0, 1.0), 0.35 * a), lw + 1.2)
	var dir := to_p - from_p
	var len := dir.length()
	if len > 4.0:
		var n := dir / len
		var tip := to_p
		var tail := to_p - n * minf(8.0, len * 0.3)
		draw_line(tail, tip, _with_alpha(Color(0.95, 1.0, 1.0, 1.0), 0.48 * a), maxf(1.0, lw + 1.6))

func _draw_molotov_flash(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var r := float(mark.get("radius", 14.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var c := _color_for_variation(StringName(mark.get("variation", V_DANGER)))
	var seed := float(mark.get("flare_seed", 0.0))
	draw_circle(p, r * (0.55 + life * 0.35), _with_alpha(c, 0.22 * a))
	draw_arc(p, r * (0.78 + life * 0.62), 0.0, TAU, 40, _with_alpha(c, 0.86 * a), 2.8 - life * 1.2)
	draw_arc(p, r * (1.1 + life * 0.9), 0.0, TAU, 28, _with_alpha(Color(1.0, 0.82, 0.45, 1.0), 0.35 * a), 1.6)
	for i in range(3):
		var phase := seed + float(i) * TAU / 3.0 + life * (1.8 + 0.35 * i)
		var arc_r := r * (0.45 + life * (0.9 + 0.18 * i))
		draw_arc(p, arc_r, phase, phase + 0.34, 10, _with_alpha(Color(1.0, 0.7, 0.35, 1.0), 0.3 * a), 1.5)

func _draw_burn_mark(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var r := float(mark.get("radius", 14.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var c := _color_for_variation(StringName(mark.get("variation", V_DANGER)))
	draw_circle(p, r, _with_alpha(c, 0.07 + 0.05 * a))
	draw_arc(p, r * (0.98 + 0.02 * sin(life * 7.0)), 0.0, TAU, 44, _with_alpha(c, 0.34 + 0.18 * a), 2.2)
	for i in range(4):
		var phase := seed + float(i) * TAU / 4.0 + life * (0.8 + 0.2 * i)
		draw_arc(p, r * (0.65 + 0.1 * i), phase, phase + 0.23, 8, _with_alpha(Color(1.0, 0.62, 0.28, 1.0), 0.18 * a), 1.1)

func _draw_guardian_mark(mark: Dictionary) -> void:
	var center: Vector2 = mark.get("center", Vector2.ZERO)
	var r := float(mark.get("radius", 18.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var blades := int(mark.get("blades", 2))
	var speed := float(mark.get("speed", 5.8))
	var phase := float(mark.get("phase", 0.0)) + life * speed
	var c := _color_for_variation(StringName(mark.get("variation", V_WARNING)))
	draw_arc(center, r, 0.0, TAU, 48, _with_alpha(c, 0.38 * a), 2.2)
	draw_arc(center, r * 0.72, 0.0, TAU, 36, _with_alpha(c, 0.22 * a), 1.4)
	for i in range(blades):
		var ang := phase + TAU * float(i) / float(maxi(1, blades))
		var tip := center + Vector2(cos(ang), sin(ang)) * r
		var mid := center + Vector2(cos(ang), sin(ang)) * (r * 0.54)
		draw_line(mid, tip, _with_alpha(c, 0.52 * a), 2.2)
		draw_circle(tip, 2.0, _with_alpha(c, 0.55 * a))

func _draw_drone_beam(mark: Dictionary) -> void:
	var from_p: Vector2 = mark.get("from", Vector2.ZERO)
	var to_p: Vector2 = mark.get("to", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var variation := StringName(mark.get("variation", V_WARNING))
	var tier := _tier_for_variation(variation)
	var c := _color_for_variation(variation)
	var w := maxf(1.0, float(mark.get("width", mark.get("beam_w", 3.2)))) * _tier_mul(tier, "width")
	draw_line(from_p, to_p, _with_alpha(c, 0.44 * a * _tier_mul(tier, "line")), w)
	draw_line(from_p, to_p, _with_alpha(Color(0.82, 0.97, 1.0, 1.0), 0.26 * a * _tier_mul(tier, "fill")), w + 2.4)
	draw_circle(to_p, w * 0.75 + 1.8, _with_alpha(c, 0.33 * a * _tier_mul(tier, "fill")))

func _draw_quantum_beam(mark: Dictionary) -> void:
	var from_p: Vector2 = mark.get("from", Vector2.ZERO)
	var to_p: Vector2 = mark.get("to", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var variation := StringName(mark.get("variation", V_THREAT))
	var tier := _tier_for_variation(variation)
	var c := _color_for_variation(variation)
	var w := maxf(1.0, float(mark.get("width", 3.0))) * _tier_mul(tier, "width")
	draw_line(from_p, to_p, _with_alpha(c, 0.56 * a * _tier_mul(tier, "line")), w)
	draw_line(from_p, to_p, _with_alpha(Color(0.78, 1.0, 0.74, 1.0), 0.22 * a * _tier_mul(tier, "fill")), w + 2.2)
	var mid := from_p.lerp(to_p, 0.5)
	draw_circle(mid, w * 0.75 + 1.2, _with_alpha(c, 0.28 * a * _tier_mul(tier, "fill")))

func _draw_boomerang_beam(mark: Dictionary) -> void:
	var from_p: Vector2 = mark.get("from", Vector2.ZERO)
	var to_p: Vector2 = mark.get("to", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var c := _color_for_variation(StringName(mark.get("variation", V_WARNING)))
	var w := maxf(1.0, float(mark.get("width", 3.2)))
	var dir := to_p - from_p
	var len := dir.length()
	draw_line(from_p, to_p, _with_alpha(c, 0.5 * a), w)
	if len > 2.0:
		var n := dir / len
		var perp := n.orthogonal()
		draw_line(from_p + perp * 1.5, to_p + perp * 1.5, _with_alpha(c, 0.18 * a), maxf(1.0, w - 1.0))
		draw_line(from_p - perp * 1.5, to_p - perp * 1.5, _with_alpha(c, 0.14 * a), maxf(1.0, w - 1.2))

func _draw_frost_mark(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var r := float(mark.get("radius", 20.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var c := Color(0.68, 0.9, 1.0, 1.0)
	draw_circle(p, r, _with_alpha(c, 0.06 + 0.04 * a))
	draw_arc(p, r * (0.95 + 0.04 * sin(life * 5.0)), 0.0, TAU, 40, _with_alpha(c, 0.38 * a), 1.8)
	for i in range(3):
		var ang := seed + TAU * float(i) / 3.0 + life * 0.8
		var out := p + Vector2(cos(ang), sin(ang)) * (r * 0.62)
		draw_line(p, out, _with_alpha(c, 0.2 * a), 1.2)

func _draw_mine_mark(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var r := float(mark.get("radius", 18.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var c := _color_for_variation(StringName(mark.get("variation", V_WARNING)))
	var blink := 0.7 + 0.3 * sin(life * 16.0)
	draw_circle(p, r * 0.22, _with_alpha(c, 0.28 * a * blink))
	draw_arc(p, r, 0.0, TAU, 32, _with_alpha(c, 0.42 * a), 2.0)
	draw_arc(p, r * (0.68 + 0.2 * life), 0.0, TAU, 24, _with_alpha(c, 0.24 * a * blink), 1.5)

func _draw_heal_mark(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var r := float(mark.get("radius", 18.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var c := Color(0.36, 1.0, 0.74, 1.0)
	draw_circle(p, r, _with_alpha(c, 0.05 + 0.04 * a))
	draw_arc(p, r * (0.9 + 0.08 * sin(life * 4.0)), 0.0, TAU, 32, _with_alpha(c, 0.34 * a), 1.8)
	for i in range(2):
		var ang := seed + TAU * float(i) / 2.0 + life * 0.65
		var arm := Vector2(cos(ang), sin(ang)) * (r * 0.48)
		draw_line(p - arm, p + arm, _with_alpha(c, 0.22 * a), 1.2)

func _draw_quantum_ripple(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var r := float(mark.get("radius", 16.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var c := Color(0.72, 1.0, 0.72, 1.0)
	draw_circle(p, r * (0.5 + life * 0.2), _with_alpha(c, 0.09 * a))
	draw_arc(p, r * (0.75 + life * 0.55), 0.0, TAU, 34, _with_alpha(c, 0.46 * a), 1.9)
	draw_arc(p, r * (1.05 + life * 0.8), 0.0, TAU, 24, _with_alpha(c, 0.2 * a), 1.2)

func _draw_hit_pulse(mark: Dictionary) -> void:
	var pos: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var variation := StringName(mark.get("variation", V_WARNING))
	var tier := _tier_for_variation(variation)
	var c := _color_for_variation(variation)
	var radius := float(mark.get("radius", 12.0))
	var line_width := float(mark.get("line_w", 2.0)) * _tier_mul(tier, "width")
	var fill_mul := float(mark.get("fill_mul", 0.12))
	var line_mul := float(mark.get("line_mul", 0.6))
	var expand := (1.0 - a) * 10.0
	draw_circle(pos, radius + expand * 0.35, _with_alpha(c, fill_mul * a * _tier_mul(tier, "fill")))
	draw_arc(pos, radius + expand, 0.0, TAU, 30, _with_alpha(c, line_mul * a * _tier_mul(tier, "line")), line_width)
	draw_arc(pos, radius * 0.72 + expand * 0.45, 0.0, TAU, 20, _with_alpha(c, line_mul * a * 0.72 * _tier_mul(tier, "line")), maxf(1.0, line_width * 0.72))

func _draw_kill_weapon_kunai(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"kunai")
	var tier := StringName(mark.get("tier", KILL_NORMAL))
	var base := 12.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius") * (0.85 + life * 0.35)
	var ang := seed * 0.5 + life * 0.4
	var n := Vector2(cos(ang), sin(ang))
	var o := n.orthogonal()
	draw_line(p - n * base, p + n * base, _with_alpha(wm, 0.78 * a), 2.2)
	draw_line(p - o * base * 0.62, p + o * base * 0.62, _with_alpha(wm, 0.6 * a), 1.75)
	var off := 2.8 + life * 1.8
	draw_line(p - n * (base * 0.72) + o * off, p + n * (base * 0.72) + o * off, _with_alpha(wm, 0.38 * a), 1.1)
	draw_line(p - n * (base * 0.66) - o * off, p + n * (base * 0.66) - o * off, _with_alpha(wm, 0.32 * a), 1.0)
	var sq := base * 0.14
	draw_line(p + Vector2(-sq, -sq), p + Vector2(sq, -sq), _with_alpha(Color(1, 1, 1, 1), 0.5 * a), 1.0)
	draw_line(p + Vector2(sq, -sq), p + Vector2(sq, sq), _with_alpha(Color(1, 1, 1, 1), 0.5 * a), 1.0)
	draw_line(p + Vector2(sq, sq), p + Vector2(-sq, sq), _with_alpha(Color(1, 1, 1, 1), 0.5 * a), 1.0)
	draw_line(p + Vector2(-sq, sq), p + Vector2(-sq, -sq), _with_alpha(Color(1, 1, 1, 1), 0.5 * a), 1.0)
	if tier == KILL_CRIT or tier == KILL_THREAT:
		var flash := base * (0.55 + life * 0.5)
		draw_line(p + Vector2(-flash, 0), p + Vector2(flash, 0), _with_alpha(Color(1, 0.86, 0.55, 1), 0.26 * a), 1.15)
		draw_line(p + Vector2(0, -flash * 0.64), p + Vector2(0, flash * 0.64), _with_alpha(Color(1, 0.72, 0.42, 1), 0.22 * a), 1.0)


func _draw_kill_weapon_quantum(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"quantum_ball")
	var r := 13.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius") * (0.9 + life * 0.8)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var ang := seed + TAU * float(i) / 6.0
		pts.append(p + Vector2(cos(ang), sin(ang)) * r)
	for i in range(pts.size()):
		var j := (i + 1) % pts.size()
		draw_line(pts[i], pts[j], _with_alpha(wm, 0.62 * a), 2.0)
		draw_line(p, pts[i], _with_alpha(Color(0.92, 1.0, 0.82, 1.0), 0.24 * a), 1.1)
	var r2 := r * (0.38 + life * 0.12)
	var pts2: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var ang2 := seed + 0.13 + TAU * float(i) / 6.0
		pts2.append(p + Vector2(cos(ang2), sin(ang2)) * r2)
	for i in range(pts2.size()):
		var j2 := (i + 1) % pts2.size()
		draw_line(pts2[i], pts2[j2], _with_alpha(Color(0.88, 1.0, 0.74, 1.0), 0.36 * a), 1.25)


func _draw_kill_weapon_lightning(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"lightning")
	var L := 18.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius") * (0.85 + life * 0.6)
	var dir := Vector2(cos(seed), sin(seed))
	var perp := dir.orthogonal()
	var pts: PackedVector2Array = PackedVector2Array()
	var cur := p - dir * L * 0.5
	pts.append(cur)
	for s in range(5):
		var off := perp * (4.0 + float(s) * 1.6) * (1.0 if s % 2 == 0 else -1.0) * (0.4 + life * 0.5)
		cur = cur + dir * (L / 5.0) + off * 0.35
		pts.append(cur)
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], _with_alpha(wm, 0.74 * a), 2.0)
		draw_line(pts[i], pts[i + 1], _with_alpha(Color(1, 1, 1, 1), 0.22 * a), 0.9)


func _draw_kill_weapon_molotov(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"molotov")
	var up := Vector2.UP.rotated(seed * 0.2)
	var side := up.orthogonal()
	var h := 14.0 + life * 22.0
	for k in range(4):
		var ang := (float(k) - 1.5) * 0.35 + seed * 0.15
		var d := up.rotated(ang)
		var wob := side * (2.0 + float(k) * 1.1) * (0.35 + life * 0.5)
		draw_line(p + wob * 0.2, p + d * h + wob, _with_alpha(wm, (0.55 - float(k) * 0.08) * a), 2.4 - float(k) * 0.35)
		draw_line(p + d * h * 0.45 + wob * 0.5, p + d * h * 0.92 + wob, _with_alpha(Color(1, 0.86, 0.42, 1), 0.38 * a), 1.2)


func _draw_kill_weapon_rocket(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"rocket")
	var fwd := Vector2.RIGHT.rotated(seed)
	var side := fwd.orthogonal()
	var depth := 26.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius") * (0.75 + life * 0.55)
	var half_w := 8.0 + life * 10.0
	var tip := p + fwd * depth
	var b0 := p - side * half_w * 0.35
	var b1 := p + side * half_w * 0.35
	draw_line(b0, tip, _with_alpha(wm, 0.72 * a), 2.3)
	draw_line(b1, tip, _with_alpha(wm, 0.72 * a), 2.3)
	draw_line(b0, b1, _with_alpha(Color(1, 0.74, 0.38, 1), 0.42 * a), 1.4)
	for i in range(3):
		var t2 := float(i + 1) / 4.0
		var y := p.lerp(tip, t2)
		var w := half_w * (1.0 - t2) * 0.9
		draw_line(y - side * w, y + side * w, _with_alpha(Color(1, 0.52, 0.26, 1), 0.32 * a), 1.25)


func _draw_kill_weapon_guardian(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"guardian")
	var r := 16.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius")
	for b in range(3):
		var base_ang := seed + TAU * float(b) / 3.0 + life * 0.8
		var span := deg_to_rad(52.0 + life * 38.0)
		draw_arc(p, r * (0.72 + float(b) * 0.18), base_ang, base_ang + span, 16, _with_alpha(wm, 0.58 * a), 2.3)
		var n := Vector2(cos(base_ang + span * 0.5), sin(base_ang + span * 0.5))
		draw_line(p + n * r * 0.35, p + n * r * 1.05, _with_alpha(Color(1, 0.9, 0.55, 1), 0.36 * a), 1.35)


func _draw_kill_weapon_drone(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"drone_ab")
	var h := Vector2.RIGHT.rotated(seed)
	var v := h.orthogonal()
	var L := 22.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius") * (0.8 + life * 0.4)
	var q := 6.0 + life * 4.0
	var left := p - h * L * 0.5
	var right := p + h * L * 0.5
	draw_line(left - v * q, left + v * q, _with_alpha(wm, 0.7 * a), 2.0)
	draw_line(right - v * q, right + v * q, _with_alpha(wm, 0.7 * a), 2.0)
	draw_line(left, right, _with_alpha(Color(0.92, 0.98, 1, 1), 0.5 * a), 1.4)
	for i in range(4):
		var x := left.lerp(right, 0.2 + float(i) * 0.2)
		draw_line(x - v * 2.5, x + v * 2.5, _with_alpha(wm, 0.34 * a), 1.0)


func _draw_kill_weapon_boomerang(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"boomerang")
	var r := 15.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius") * (0.9 + life * 0.5)
	var a0 := seed - PI * 0.35
	var a1 := seed + PI * 0.85
	draw_arc(p, r, a0, a1, 22, _with_alpha(wm, 0.72 * a), 2.4)
	draw_arc(p, r * 0.82, a0 + 0.08, a1 - 0.18, 18, _with_alpha(Color(1, 0.94, 0.62, 1), 0.36 * a), 1.0)
	var tip := p + Vector2(cos(a1), sin(a1)) * r
	var hilt := p + Vector2(cos(a0), sin(a0)) * r * 0.72
	draw_line(hilt, tip, _with_alpha(Color(1, 0.82, 0.4, 1), 0.34 * a), 1.3)


func _draw_kill_weapon_frost(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"frost_aura")
	var L := 16.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius") * (0.75 + life * 0.45)
	for k in range(6):
		var ang := seed + TAU * float(k) / 6.0
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(p - dir * L * 0.55, p + dir * L * 0.68, _with_alpha(wm, 0.7 * a), 1.9)
		var s1 := dir.rotated(PI * 0.5) * L * 0.28
		var mid := p + dir * L * 0.42
		draw_line(mid - s1, mid + s1, _with_alpha(Color(0.88, 1, 1, 1), 0.42 * a), 1.25)


func _draw_kill_weapon_heal(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"heal_aura")
	var L := 14.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius") * (0.8 + life * 0.35)
	draw_line(p + Vector2(-L, 0), p + Vector2(L, 0), _with_alpha(wm, 0.62 * a), 2.0)
	draw_line(p + Vector2(0, -L * 0.72), p + Vector2(0, L * 0.72), _with_alpha(wm, 0.62 * a), 2.0)
	for i in range(5):
		var ang := seed + TAU * float(i) / 5.0
		var off := Vector2(cos(ang), sin(ang)) * (L * 0.55 + life * 6.0)
		draw_line(p + off * 0.78, p + off, _with_alpha(Color(0.75, 1, 0.86, 1), 0.45 * a), 1.15)


func _draw_kill_weapon_mine(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"stun_mine")
	var s := 11.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius") * (0.9 + life * 0.5)
	draw_line(p + Vector2(-s, -s), p + Vector2(s, s), _with_alpha(wm, 0.76 * a), 2.2)
	draw_line(p + Vector2(-s, s), p + Vector2(s, -s), _with_alpha(wm, 0.76 * a), 2.2)
	var h := Vector2.RIGHT.rotated(seed)
	var v := h.orthogonal()
	var e := s * 1.1
	draw_line(p + h * e + v * e, p + h * e - v * e, _with_alpha(Color(0.85, 0.95, 1, 1), 0.5 * a), 1.8)
	draw_line(p - h * e + v * e, p - h * e - v * e, _with_alpha(Color(0.85, 0.95, 1, 1), 0.5 * a), 1.8)
	draw_line(p + v * e + h * e, p + v * e - h * e, _with_alpha(Color(0.85, 0.95, 1, 1), 0.5 * a), 1.8)
	draw_line(p - v * e + h * e, p - v * e - h * e, _with_alpha(Color(0.85, 0.95, 1, 1), 0.5 * a), 1.8)


func _draw_kill_weapon_explosion_passive(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"explosion_kill")
	var n := 9
	var base := 12.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius")
	for i in range(n):
		var ang := seed + TAU * float(i) / float(n) + life * 0.9
		var dir := Vector2(cos(ang), sin(ang))
		var L := base * (0.62 + 0.55 * life + float(i % 3) * 0.08)
		draw_line(p + dir * (base * 0.12), p + dir * L, _with_alpha(wm, 0.62 * a), 1.85)
		draw_line(p + dir * (L * 0.55) + dir.orthogonal() * 2.6, p + dir * L, _with_alpha(Color(1, 0.78, 0.4, 1), 0.34 * a), 1.1)


func _draw_kill_weapon_active_skill(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var wm := _weapon_kill_primary(&"active_skill")
	var dir := Vector2.RIGHT.rotated(seed)
	var perp := dir.orthogonal()
	var L := 30.0 * float(mark.get("ring_scale", 1.0)) * _profile_mul("radius") * (0.75 + life * 0.35)
	draw_line(p - dir * L * 0.5, p + dir * L * 0.5, _with_alpha(wm, 0.78 * a), 2.6)
	for i in range(7):
		var u := -0.5 + float(i) / 6.0
		var pt := p + dir * (u * L)
		draw_line(pt - perp * 2.8, pt + perp * 2.8, _with_alpha(Color(0.92, 0.82, 1, 1), 0.4 * a), 1.1)


func _draw_kill_weapon_boss(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var phase := int(mark.get("boss_phase", 1))
	var wm := _weapon_kill_primary(&"boss")
	var w := 18.0 + float(phase) * 5.0
	var h := 10.0 + life * 6.0
	for layer in range(2 + mini(phase, 2)):
		var s := 1.0 - float(layer) * 0.14
		var left := p + Vector2(-w * s * 0.55, -h * s * 0.4)
		var right := p + Vector2(w * s * 0.55, -h * s * 0.4)
		draw_line(left, right, _with_alpha(wm, (0.55 - float(layer) * 0.12) * a), 2.2)
		draw_line(left, left + Vector2(0, h * s * 0.9), _with_alpha(Color(1, 0.62, 0.76, 1), (0.42 - float(layer) * 0.08) * a), 1.8)
		draw_line(right, right + Vector2(0, h * s * 0.9), _with_alpha(Color(1, 0.62, 0.76, 1), (0.42 - float(layer) * 0.08) * a), 1.8)
	draw_line(p + Vector2(-w * 0.22, h * 0.1), p + Vector2(w * 0.22, h * 0.1), _with_alpha(Color(1, 0.9, 0.5, 1), 0.38 * a), 1.6)


func _draw_kill_weapon_fallback(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var variation := StringName(mark.get("variation", V_DANGER))
	var c := _color_for_variation(variation)
	var ring_scale := float(mark.get("ring_scale", 1.0))
	var tier := StringName(mark.get("tier", KILL_NORMAL))
	var seed := float(mark.get("seed", 0.0))
	var shards := int(mark.get("shards", 4))
	var combo := int(mark.get("combo", 0))
	var phase := int(mark.get("boss_phase", 0))
	var base_r := 14.0 * ring_scale * _profile_mul("radius")
	var slash_len := base_r * (0.52 + 0.48 * life)
	draw_line(p + Vector2(-slash_len, -slash_len * 0.55), p + Vector2(slash_len, slash_len * 0.55), _with_alpha(Color(1.0, 0.82, 0.52, 1.0), 0.38 * a), 1.35)
	draw_line(p + Vector2(-slash_len * 0.66, slash_len * 0.62), p + Vector2(slash_len * 0.66, -slash_len * 0.62), _with_alpha(c, 0.32 * a), 1.15)
	for i in range(shards):
		var ang := seed + TAU * float(i) / float(maxi(1, shards)) + life * (1.2 + 0.2 * i)
		var dir := Vector2(cos(ang), sin(ang))
		var inner := p + dir * (base_r * (0.22 + 0.15 * life))
		var outer := p + dir * (base_r * (0.86 + 0.78 * life))
		draw_line(inner, outer, _with_alpha(Color(1.0, 0.56, 0.28, 1.0), 0.56 * a), 1.5)
		if combo >= 3:
			var side := dir.orthogonal()
			draw_line(outer - side * 1.8, outer + side * 1.8, _with_alpha(Color(1.0, 0.78, 0.48, 1.0), 0.34 * a), 1.05)
	if tier == KILL_BOSS_PHASE:
		var pulse_count := 2 + maxi(0, phase - 1)
		for i in range(pulse_count):
			var mul := 1.2 + float(i) * 0.26 + life * 0.42
			var a0 := seed + float(i) * 0.4
			draw_arc(p, base_r * mul, a0, a0 + deg_to_rad(110.0), 14, _with_alpha(Color(1.0, 0.42, 0.22, 1.0), 0.26 * a), 1.35)


func _draw_kill_burst(mark: Dictionary) -> void:
	var weapon := StringName(mark.get("weapon", &""))
	match weapon:
		&"kunai":
			_draw_kill_weapon_kunai(mark)
		&"quantum_ball":
			_draw_kill_weapon_quantum(mark)
		&"lightning":
			_draw_kill_weapon_lightning(mark)
		&"molotov":
			_draw_kill_weapon_molotov(mark)
		&"rocket":
			_draw_kill_weapon_rocket(mark)
		&"guardian":
			_draw_kill_weapon_guardian(mark)
		&"drone_ab":
			_draw_kill_weapon_drone(mark)
		&"boomerang":
			_draw_kill_weapon_boomerang(mark)
		&"frost_aura":
			_draw_kill_weapon_frost(mark)
		&"heal_aura":
			_draw_kill_weapon_heal(mark)
		&"stun_mine":
			_draw_kill_weapon_mine(mark)
		&"explosion_kill":
			_draw_kill_weapon_explosion_passive(mark)
		&"active_skill":
			_draw_kill_weapon_active_skill(mark)
		&"boss":
			_draw_kill_weapon_boss(mark)
		_:
			_draw_kill_weapon_fallback(mark)

func _draw_kunai_cross_hit(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var n: Vector2 = mark.get("dir", Vector2.RIGHT)
	var perp := n.orthogonal()
	var scale := float(mark.get("scale", 1.0))
	var c := _color_for_variation(StringName(mark.get("variation", V_THREAT)))
	var major := 10.0 * scale + life * 8.0
	var minor := 6.0 * scale + life * 5.0
	draw_line(p - n * major, p + n * major, _with_alpha(c, 0.72 * a), 2.2)
	draw_line(p - perp * minor, p + perp * minor, _with_alpha(c, 0.54 * a), 1.8)
	# 苦无专属：切片感更强的平行副刃，和其它命中区分。
	var slice_off := 2.0 + life * 1.6
	draw_line(p - n * (major * 0.78) + perp * slice_off, p + n * (major * 0.78) + perp * slice_off, _with_alpha(c, 0.36 * a), 1.15)
	draw_line(p - n * (major * 0.72) - perp * slice_off, p + n * (major * 0.72) - perp * slice_off, _with_alpha(c, 0.3 * a), 1.0)
	draw_circle(p, 2.4 + life * 2.0, _with_alpha(Color(0.92, 1.0, 1.0, 1.0), 0.62 * a))

func _draw_lightning_hex_pulse(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var radius := float(mark.get("radius", 22.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var seed := float(mark.get("seed", 0.0))
	var c := _color_for_variation(StringName(mark.get("variation", V_WARNING)))
	var variation := StringName(mark.get("variation", V_WARNING))
	var points: PackedVector2Array = PackedVector2Array()
	var hex_r := radius * (0.72 + life * 0.62)
	for i in range(6):
		var ang := seed + TAU * float(i) / 6.0
		points.append(p + Vector2(cos(ang), sin(ang)) * hex_r)
	for i in range(points.size()):
		var j := (i + 1) % points.size()
		draw_line(points[i], points[j], _with_alpha(c, 0.52 * a), 1.9)
	# 雷电专属：从中心到六角节点的放电辐条，识别“电击”。
	for v in points:
		draw_line(p, v, _with_alpha(Color(0.72, 0.96, 1.0, 1.0), 0.22 * a), 1.0)
	if variation == V_THREAT:
		# 量子专属（复用该结构）：双层六角+旋转弧，强调“能量阵”。
		var inner_r := radius * (0.34 + life * 0.28)
		var inner: PackedVector2Array = PackedVector2Array()
		for i in range(6):
			var ang2 := seed + 0.22 + TAU * float(i) / 6.0
			inner.append(p + Vector2(cos(ang2), sin(ang2)) * inner_r)
		for i in range(inner.size()):
			var j2 := (i + 1) % inner.size()
			draw_line(inner[i], inner[j2], _with_alpha(Color(0.86, 1.0, 0.8, 1.0), 0.3 * a), 1.2)
		draw_arc(p, radius * (0.46 + life * 0.46), seed + life * 0.8, seed + life * 0.8 + TAU * 0.76, 24, _with_alpha(Color(0.84, 1.0, 0.74, 1.0), 0.26 * a), 1.3)
	else:
		# 降低蓝白内环强度，避免高等级叠加后角色周边“光污染”。
		draw_arc(p, radius * (0.4 + life * 0.7), 0.0, TAU, 24, _with_alpha(Color(0.86, 0.98, 1.0, 1.0), 0.22 * a), 1.25)

func _draw_rocket_fan(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var n: Vector2 = mark.get("dir", Vector2.RIGHT)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var r := float(mark.get("radius", 24.0))
	var c := _color_for_variation(StringName(mark.get("variation", V_DANGER)))
	var half := deg_to_rad(30.0 + life * 11.0)
	var dir_a := n.angle()
	var seg := 14
	var prev := p + Vector2.RIGHT.rotated(dir_a - half) * (r * (0.5 + life * 0.68))
	for i in range(1, seg + 1):
		var k := float(i) / float(seg)
		var ang: float = lerpf(dir_a - half, dir_a + half, k)
		var cur := p + Vector2.RIGHT.rotated(ang) * (r * (0.5 + life * 0.68))
		draw_line(prev, cur, _with_alpha(c, 0.62 * a), 2.0)
		prev = cur
	draw_line(p, p + Vector2.RIGHT.rotated(dir_a - half) * (r * (0.5 + life * 0.68)), _with_alpha(c, 0.45 * a), 1.35)
	draw_line(p, p + Vector2.RIGHT.rotated(dir_a + half) * (r * (0.5 + life * 0.68)), _with_alpha(c, 0.45 * a), 1.35)
	# 火箭专属：爆压星芒，强化“重爆”识别。
	var core := p + n * (r * (0.18 + life * 0.2))
	var burst_r := r * (0.14 + life * 0.16)
	for i in range(4):
		var ba := dir_a + PI * 0.25 * float(i)
		var bd := Vector2(cos(ba), sin(ba))
		draw_line(core - bd * burst_r * 0.55, core + bd * burst_r, _with_alpha(Color(1.0, 0.78, 0.48, 1.0), 0.28 * a), 1.2)

func _draw_drone_sweep(mark: Dictionary) -> void:
	var from_p: Vector2 = mark.get("from", Vector2.ZERO)
	var to_p: Vector2 = mark.get("to", Vector2.ZERO)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var w := maxf(1.0, float(mark.get("width", 4.2)))
	var c := _color_for_variation(StringName(mark.get("variation", V_WARNING)))
	draw_line(from_p, to_p, _with_alpha(c, 0.44 * a), w)
	draw_line(from_p, to_p, _with_alpha(Color(0.86, 0.98, 1.0, 1.0), 0.24 * a), w + 2.0)
	draw_circle(to_p, w * 0.7 + 1.8, _with_alpha(c, 0.32 * a))

func _draw_boomerang_crescent(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var n: Vector2 = mark.get("dir", Vector2.RIGHT)
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var sc := float(mark.get("scale", 1.0))
	var c := _color_for_variation(StringName(mark.get("variation", V_WARNING)))
	var radius := (18.0 + life * 14.0) * sc
	var arc_half := 0.72
	var base_ang := n.angle()
	draw_arc(p, radius, base_ang - arc_half, base_ang + arc_half, 18, _with_alpha(c, 0.6 * a), 2.0)
	draw_arc(p, radius * 0.72, base_ang - arc_half * 0.88, base_ang + arc_half * 0.88, 14, _with_alpha(Color(1.0, 0.86, 0.56, 1.0), 0.32 * a), 1.4)

func _draw_molotov_cone(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var n: Vector2 = mark.get("dir", Vector2.RIGHT)
	var r := float(mark.get("radius", 26.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var c := _color_for_variation(StringName(mark.get("variation", V_DANGER)))
	var half := deg_to_rad(34.0 + life * 8.0)
	var dir_a := n.angle()
	var tip_l := p + Vector2.RIGHT.rotated(dir_a - half) * (r * (0.58 + life * 0.46))
	var tip_r := p + Vector2.RIGHT.rotated(dir_a + half) * (r * (0.58 + life * 0.46))
	draw_line(p, tip_l, _with_alpha(c, 0.34 * a), 1.4)
	draw_line(p, tip_r, _with_alpha(c, 0.34 * a), 1.4)
	draw_arc(p, r * (0.58 + life * 0.46), dir_a - half, dir_a + half, 14, _with_alpha(c, 0.56 * a), 1.8)
	draw_arc(p, r * (0.4 + life * 0.3), dir_a - half * 0.82, dir_a + half * 0.82, 10, _with_alpha(Color(1.0, 0.68, 0.36, 1.0), 0.32 * a), 1.2)

func _draw_guardian_slice(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var n: Vector2 = mark.get("dir", Vector2.RIGHT)
	var r := float(mark.get("radius", 20.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var c := _color_for_variation(StringName(mark.get("variation", V_WARNING)))
	var base := n.angle()
	var half := deg_to_rad(22.0 + life * 8.0)
	draw_arc(p, r * (0.56 + life * 0.5), base - half, base + half, 12, _with_alpha(c, 0.58 * a), 1.8)
	draw_arc(p, r * (0.34 + life * 0.3), base - half * 0.8, base + half * 0.8, 10, _with_alpha(Color(0.96, 0.88, 0.54, 1.0), 0.3 * a), 1.2)

func _draw_mine_shock_cone(mark: Dictionary) -> void:
	var p: Vector2 = mark.get("pos", Vector2.ZERO)
	var n: Vector2 = mark.get("dir", Vector2.RIGHT)
	var r := float(mark.get("radius", 20.0))
	var t := float(mark.get("time", 0.0))
	var mt := maxf(0.01, float(mark.get("max_time", 0.01)))
	var a := clampf(t / mt, 0.0, 1.0)
	var life := 1.0 - a
	var c := _color_for_variation(StringName(mark.get("variation", V_WARNING)))
	var base := n.angle()
	var half := deg_to_rad(20.0 + life * 7.0)
	draw_arc(p, r * (0.5 + life * 0.58), base - half, base + half, 11, _with_alpha(c, 0.56 * a), 1.7)
	draw_arc(p, r * (0.3 + life * 0.36), base - half * 0.76, base + half * 0.76, 8, _with_alpha(Color(0.88, 0.96, 1.0, 1.0), 0.3 * a), 1.1)

func _draw() -> void:
	for m in _rocket_marks:
		_draw_rocket_mark(m)
	for m in _burn_marks:
		_draw_burn_mark(m)
	for m in _lightning_marks:
		_draw_mark_circle(m)
	for m in _frost_aura_marks:
		_draw_frost_mark(m)
	for m in _mine_marks:
		_draw_mine_mark(m)
	for m in _heal_aura_marks:
		_draw_heal_mark(m)
	for m in _quantum_ripples:
		_draw_quantum_ripple(m)
	for m in _molotov_flashes:
		_draw_molotov_flash(m)
	for m in _guardian_marks:
		_draw_guardian_mark(m)
	for m in _drone_marks:
		_draw_drone_beam(m)
	for m in _chain_marks:
		if bool(m.get("is_lightning", false)):
			_draw_lightning_beam(m, 0.95)
		elif bool(m.get("is_kunai", false)):
			_draw_kunai_beam(m)
		elif bool(m.get("is_quantum", false)):
			_draw_quantum_beam(m)
		elif bool(m.get("is_boomerang", false)):
			_draw_boomerang_beam(m)
		elif bool(m.get("is_drone", false)):
			_draw_drone_beam(m)
		else:
			_draw_beam(m, 1.0)
	for m in _lightning_main_beams:
		_draw_lightning_beam(m, 1.3)
	for p in _projectiles:
		var pos: Vector2 = p.get("pos", Vector2.ZERO)
		var c := _color_for_variation(StringName(p.get("variation", V_THREAT)))
		var kind := String(p.get("kind", ""))
		if _ENTITY_PROJECTILE_KINDS.has(kind):
			continue
		var dir: Vector2 = p.get("dir", Vector2.RIGHT)
		if kind == "kunai":
			var n := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
			var perp := n.orthogonal()
			var tip := pos + n * 7.4
			var rear := pos - n * 4.8
			var l := pos + perp * 2.6
			var r := pos - perp * 2.6
			draw_colored_polygon(PackedVector2Array([tip, l, rear, r]), _with_alpha(c, 0.82))
			draw_line(rear, tip, _with_alpha(Color(0.95, 1.0, 1.0, 1.0), 0.5), 1.1)
		elif kind == "rocket":
			var n2 := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
			var perp2 := n2.orthogonal()
			var nose := pos + n2 * 8.6
			var tail := pos - n2 * 6.0
			draw_colored_polygon(PackedVector2Array([nose, pos + perp2 * 2.8, tail, pos - perp2 * 2.8]), _with_alpha(c, 0.85))
			draw_line(tail - n2 * 1.8, tail, _with_alpha(Color(1.0, 0.72, 0.36, 1.0), 0.62), 1.7)
		elif kind == "drone_ab":
			draw_circle(pos, 5.0, _with_alpha(c, 0.7))
			draw_arc(pos, 7.2, 0.0, TAU, 18, _with_alpha(c, 0.34), 1.2)
		else:
			draw_circle(pos, 4.5, _with_alpha(c, 0.7))
	for t in _trail_history:
		var pos2: Vector2 = t.get("pos", Vector2.ZERO)
		var rt := clampf(float(t.get("time", 0.0)) / maxf(0.01, float(t.get("max_time", 0.01))), 0.0, 1.0)
		var c2 := _color_for_variation(StringName(t.get("variation", V_THREAT)))
		draw_circle(pos2, 3.2, _with_alpha(c2, rt * 0.36))
	for h in _hit_pulses:
		_draw_hit_pulse(h)
	for k in _kill_bursts:
		_draw_kill_burst(k)
	for x in _kunai_cross_hits:
		_draw_kunai_cross_hit(x)
	for hx in _lightning_hex_pulses:
		_draw_lightning_hex_pulse(hx)
	for rf in _rocket_fans:
		_draw_rocket_fan(rf)
	for ds in _drone_sweeps:
		_draw_drone_sweep(ds)
	for bc in _boomerang_crescents:
		_draw_boomerang_crescent(bc)
	for mc in _molotov_cones:
		_draw_molotov_cone(mc)
	for gs in _guardian_slices:
		_draw_guardian_slice(gs)
	for ms in _mine_shock_cones:
		_draw_mine_shock_cone(ms)
