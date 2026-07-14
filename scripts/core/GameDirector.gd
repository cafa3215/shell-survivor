extends Node
class_name GameDirector

## 导演系统：动态压力 / 经验补偿 / 战局回稳（从 Game.gd 拆出）

var director_mul := 1.0
var xp_bonus_mul := 1.0
var pressure_relief := 0.0

var _director_tick := 0.0
var _director_phase_flags: Dictionary = {}
var _pressure_relief_decay_per_sec := 28.0
var _threat_relief_combo := 0
var _threat_relief_combo_decay := 0.0
var _threat_relief_notif_cd := 0.0
var _threat_relief_events_total := 0
var _threat_relief_peak_combo := 0
var _spawn_perf_mul := 1.0
var _spawn_perf_tick := 0.0
var _spawn_perf_notif_cd := 0.0

var _game: Node = null


func bind(game: Node) -> void:
	_game = game


func _run_time_sec() -> float:
	if _game != null and "run_time_seconds" in _game:
		return float(_game.run_time_seconds)
	return float(GameDB.run_time_for_mode())


func _boss_time_sec() -> float:
	if _game != null and "boss_spawn_time" in _game:
		return float(_game.boss_spawn_time)
	return GameDB.boss_spawn_time_for_mode()


func tick(delta: float, elapsed: float, level: int, ended: bool, boss_spawned: bool, endless_mode: bool) -> void:
	tick_spawn_perf_guard(delta)
	if pressure_relief > 0.0:
		pressure_relief = maxf(pressure_relief - _pressure_relief_decay_per_sec * delta, 0.0)
	if _threat_relief_combo_decay > 0.0:
		_threat_relief_combo_decay -= delta
		if _threat_relief_combo_decay <= 0.0:
			_threat_relief_combo = 0
	if _threat_relief_notif_cd > 0.0:
		_threat_relief_notif_cd = maxf(_threat_relief_notif_cd - delta, 0.0)

	_director_tick += delta
	if _director_tick >= 1.0:
		_director_tick = 0.0
		_update_director(elapsed, level, boss_spawned, endless_mode)
		RunStats.add_director_sample(director_mul, xp_bonus_mul)
	if not ended:
		_tick_director_phase_callouts(elapsed)


func pressure_relief_ratio() -> float:
	return clampf(pressure_relief / 260.0, 0.0, 1.0)


func pressure_relief_summary_line() -> String:
	if _threat_relief_events_total <= 0:
		return "节奏复盘：本局较少触发“清关键威胁→降压”窗口。"
	if _threat_relief_peak_combo >= 4:
		return "节奏复盘：成功稳住战局（关键威胁清除 %d 次，最高连稳 ×%d）。" % [_threat_relief_events_total, _threat_relief_peak_combo]
	if _threat_relief_peak_combo >= 2:
		return "节奏复盘：中盘有过回稳（关键威胁清除 %d 次，最高连稳 ×%d）。" % [_threat_relief_events_total, _threat_relief_peak_combo]
	return "节奏复盘：有局部回稳（关键威胁清除 %d 次），连稳窗口仍可提升。" % _threat_relief_events_total


func maybe_threat_relief_on_kill(kind_s: String, elapsed: float) -> void:
	var boss_t := _boss_time_sec()
	if elapsed < _run_time_sec() * 0.33 or elapsed > boss_t:
		return
	if director_mul < 1.14:
		return
	var is_threat := kind_s == "spitter" or kind_s == "summoner" or kind_s == "charger" or kind_s == "elite"
	if not is_threat:
		return
	var add := 44.0
	if kind_s == "elite":
		add = 78.0
	pressure_relief = clampf(pressure_relief + add, 0.0, 260.0)
	_threat_relief_events_total += 1
	_threat_relief_combo += 1
	_threat_relief_peak_combo = maxi(_threat_relief_peak_combo, _threat_relief_combo)
	_threat_relief_combo_decay = 2.6
	if _threat_relief_combo == 2:
		CombatFeedback.shake("ui", 2.05, 0.06)
		CombatFeedback.flash(Color(0.85, 1.0, 0.62, 0.08), 0.05, "subtle")
	elif _threat_relief_combo == 3:
		if _threat_relief_notif_cd <= 0.0:
			NotificationSystem.notify_message("战局回稳：威胁被你清掉了。", 1.35, "achievement")
			_threat_relief_notif_cd = 3.2
		CombatFeedback.shake("hit", 2.5, 0.07)
		CombatFeedback.flash(Color(0.62, 1.0, 0.78, 0.12), 0.06, "subtle")
	elif _threat_relief_combo >= 4:
		CombatFeedback.shake("hit", 2.9, 0.075)
		CombatFeedback.flash(Color(0.72, 1.0, 0.9, 0.12), 0.06, "subtle")


func target_enemy_count(elapsed: float, level: int, endless_mode: bool) -> int:
	var run_t := _run_time_sec()
	var early_span := run_t * 0.222
	var ramp_end := run_t * 0.417
	# 前段：稀疏入场，给摸索窗口
	if not endless_mode and elapsed < ramp_end:
		if elapsed < early_span * 0.375:
			return int(round(lerpf(8.0, 32.0, elapsed / maxf(early_span * 0.375, 1.0))))
		return int(round(lerpf(32.0, 110.0, (elapsed - early_span * 0.375) / maxf(ramp_end - early_span * 0.375, 1.0))))
	var base_target := 680
	var time_bonus := int(GameDB.director_alive_pressure_minutes(elapsed, run_t) * 95.0)
	var level_bonus := level * 18
	var target := base_target + time_bonus + level_bonus - int(round(pressure_relief))
	var mid_start := run_t * 0.444
	var mid_end := run_t * 0.889
	if elapsed >= mid_start and elapsed <= mid_end:
		var mid_u := clampf((elapsed - mid_start) / maxf(mid_end - mid_start, 1.0), 0.0, 1.0)
		var pl := _game.get_node_or_null("Player")
		var hp_ratio := 1.0
		if pl:
			hp_ratio = float(pl.hp) / maxf(1.0, float(pl.max_hp))
		var cushion := int(round(lerpf(156.0, 60.0, mid_u)))
		if hp_ratio < 0.55:
			cushion += 30
		target -= cushion
	if endless_mode:
		var endless_u := _endless_runtime_minutes(elapsed, endless_mode)
		if endless_u >= 8.0:
			target = int(round(float(target) * 0.86))
		elif endless_u >= 5.0:
			target = int(round(float(target) * 0.93))
	target = maxi(72, target)
	match Settings.quality:
		Settings.Quality.LOW:
			return int(target * 0.8)
		Settings.Quality.HIGH:
			return int(target * 1.3)
		_:
			return target


func spawn_perf_multiplier() -> float:
	return _spawn_perf_mul


func _endless_runtime_minutes(elapsed: float, endless_mode: bool) -> float:
	if not endless_mode:
		return 0.0
	return maxf(0.0, elapsed - _boss_time_sec()) / 60.0


func _update_director(elapsed: float, level: int, boss_spawned: bool, endless_mode: bool) -> void:
	var pl := _game.get_node_or_null("Player")
	if pl == null:
		return
	var player_hp_ratio := float(pl.hp) / float(pl.max_hp)
	var level_target := int(round(GameDB.director_expected_level(elapsed, _run_time_sec())))
	var behind_level: int = maxi(0, level_target - level)
	var ahead_level: int = maxi(0, level - level_target)
	var target := 1.0
	var boss_t := _boss_time_sec()
	var to_boss := boss_t - elapsed

	if player_hp_ratio < 0.25:
		target -= 0.25
	elif player_hp_ratio < 0.45:
		target -= 0.12
	if player_hp_ratio > 0.9:
		target += 0.15
	if ahead_level >= 3:
		target += 0.15
	elif behind_level >= 3:
		target -= 0.12

	var u_prog := GameDB.run_progress_normalized(elapsed, _run_time_sec())
	target += GameDB.director_time_pressure_add(u_prog)
	if to_boss <= _run_time_sec() * 0.167 and to_boss > 0.0:
		var prep_u := clampf((_run_time_sec() * 0.167 - to_boss) / (_run_time_sec() * 0.167), 0.0, 1.0)
		target -= 0.08 * prep_u
		if behind_level >= 2:
			target -= 0.05
	var rec_start := _run_time_sec() * 0.5
	var rec_end := _run_time_sec() * 0.611
	if elapsed >= rec_start and elapsed <= rec_end:
		var rec_u := clampf((elapsed - rec_start) / maxf(rec_end - rec_start, 1.0), 0.0, 1.0)
		target -= lerpf(0.10, 0.05, rec_u)
	if boss_spawned and not endless_mode and elapsed <= boss_t + _run_time_sec() * 0.167:
		var post_boss_u := clampf((elapsed - boss_t) / maxf(_run_time_sec() * 0.167, 1.0), 0.0, 1.0)
		target -= 0.04 * (1.0 - post_boss_u)
	if endless_mode:
		target += 0.14
	var dir_max := 1.84 if endless_mode else 1.66
	target = clampf(target, 0.65, dir_max)
	var early_cap_end := _run_time_sec() * 0.222
	if elapsed < early_cap_end:
		var early_cap := lerpf(0.88, 1.06, elapsed / maxf(early_cap_end, 1.0))
		target = minf(target, early_cap)
	director_mul = lerpf(director_mul, target, 0.15)

	var xp_target := 1.0
	if behind_level >= 2:
		xp_target += 0.05 + minf(0.08, float(behind_level - 2) * 0.025)
	elif ahead_level >= 3:
		xp_target -= minf(0.12, float(ahead_level - 2) * 0.035)
	if player_hp_ratio < 0.35:
		xp_target += 0.06
	elif player_hp_ratio > 0.9:
		xp_target -= 0.06
	if to_boss <= _run_time_sec() * 0.167 and to_boss > 0.0 and behind_level >= 2:
		xp_target += 0.06
	if boss_spawned and not endless_mode and elapsed <= boss_t + _run_time_sec() * 0.139:
		xp_target += 0.04
	if endless_mode:
		xp_target += 0.07
	xp_target = clampf(xp_target, 0.82, 1.25)
	xp_bonus_mul = lerpf(xp_bonus_mul, xp_target, 0.2)


func _tick_director_phase_callouts(elapsed: float) -> void:
	var run_t := _run_time_sec()
	if elapsed < run_t * 0.139:
		return
	var checkpoints := [
		["phase_3m", run_t * 0.167, "导演换挡：远程与重装混编开始抬头，别只顾清杂兵。", "warning"],
		["phase_6m", run_t * 0.333, "中盘升压：召唤师与冲锋者登场，优先击杀高威胁单位。", "warning"],
		["phase_8m_windup", run_t * 0.444, "读场提示：脚下橙色蓄力圈 = 即将攻击，先躲再输出。", "info"],
		["phase_9m", run_t * 0.5, "高压阶段：场面会更乱，构筑若未成型请优先保命。", "error"],
	]
	for row in checkpoints:
		var id := String(row[0])
		if _director_phase_flags.get(id, false):
			continue
		if elapsed < float(row[1]):
			continue
		_director_phase_flags[id] = true
		NotificationSystem.notify_message(String(row[2]), 2.4, String(row[3]))
		CombatFeedback.shake("ui", 2.1, 0.07)
		if String(row[3]) == "error":
			CombatFeedback.flash(Color(0.92, 0.3, 0.22, 0.14), 0.08, "subtle")


func tick_spawn_perf_guard(delta: float) -> void:
	_spawn_perf_tick -= delta
	_spawn_perf_notif_cd = maxf(_spawn_perf_notif_cd - delta, 0.0)
	if _spawn_perf_tick > 0.0:
		return
	_spawn_perf_tick = 0.6
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var target_mul := 1.0
	if fps < 32.0:
		target_mul = 0.62
	elif fps < 40.0:
		target_mul = 0.78
	elif fps < 50.0:
		target_mul = 0.9
	_spawn_perf_mul = lerpf(_spawn_perf_mul, target_mul, 0.25)
	if _spawn_perf_mul < 0.82 and _spawn_perf_notif_cd <= 0.0:
		NotificationSystem.notify_message("性能保护：暂时降低刷怪速率，优先保证操作流畅。", 1.1, "warning")
		_spawn_perf_notif_cd = 12.0
