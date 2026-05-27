extends "res://scripts/modules/ModuleDemoBase.gd"

const _GAME_SCN := preload("res://scenes/Game.tscn")
const _MAIN_MENU_SCN := "res://scenes/Main_new.tscn"

@onready var _title := $CanvasLayer/Panel/VBox/Title as Label
@onready var _desc := $CanvasLayer/Panel/VBox/Desc as Label
@onready var _status := $CanvasLayer/Panel/VBox/Status as Label
@onready var _btn_tutorial := $CanvasLayer/Panel/VBox/Buttons/BtnTutorial as Button
@onready var _btn_combo := $CanvasLayer/Panel/VBox/Buttons/BtnCombo as Button
@onready var _btn_exam := $CanvasLayer/Panel/VBox/Buttons/BtnExam as Button
@onready var _btn_reset := $CanvasLayer/Panel/VBox/Buttons/BtnReset as Button
@onready var _btn_back := $CanvasLayer/Panel/VBox/Buttons/BtnBack as Button

var _main: Node = null
var _game: Node2D = null
var _em: Node = null
var _player: Node2D = null

var _stage := 0 # 0=idle,1=tutorial,2=combo,3=exam
var _stage_time := 0.0
var _exam_spawn_cd := 0.0
var _status_base := ""
var _status_tick_sec := 0.0
var _auto_stage := 0
var _auto_exit_after := 0.0
var _auto_batch_start := false
var _auto_export_end := false
var _auto_compare_end := false
var _auto_repeat_total := 1
var _auto_repeat_left := 0
var _auto_round_done := 0
var _exam_duration_sec := 30.0
var _whitebox_seed := -1
var _summary_written := false
var _exam_enemy_samples := 0
var _exam_enemy_sum := 0
var _exam_enemy_peak := 0
var _whitebox_tag := ""
var _pressure_level := "mid" # low/mid/high
var _pressure_spawn_mul := 1.0
var _pressure_cd_mul := 1.0
var _session_elapsed_sec := 0.0
var _whitebox_profile := ""
var _session_end_written := false

func _ready() -> void:
	demo_name = "技能白盒试验场"
	super._ready()
	_title.text = "技能白盒试验场：教学/组合/考核"
	_desc.text = "固定刷怪模式验证技能手感与可读性。建议：先按 HUD 的 F11 开始新批次，然后在每个模式结束后 F6 导出快照、F9 对比。"
	_status.text = "状态：正在挂入 Main/Game…"
	_btn_tutorial.pressed.connect(func(): _start_stage(1))
	_btn_combo.pressed.connect(func(): _start_stage(2))
	_btn_exam.pressed.connect(func(): _start_stage(3))
	_btn_reset.pressed.connect(_reset_battle)
	_btn_back.pressed.connect(_back_to_menu)
	_parse_cmdline_options()
	if _whitebox_seed >= 0:
		seed(_whitebox_seed)
	_auto_repeat_left = maxi(1, _auto_repeat_total)
	_auto_round_done = 0
	_summary_written = false
	_exam_enemy_samples = 0
	_exam_enemy_sum = 0
	_exam_enemy_peak = 0
	_session_elapsed_sec = 0.0
	_session_end_written = false
	call_deferred("_build_battle")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		match k.keycode:
			KEY_1:
				_start_stage(1)
				accept_event()
			KEY_2:
				_start_stage(2)
				accept_event()
			KEY_3:
				_start_stage(3)
				accept_event()
			KEY_R:
				_reset_battle()
				accept_event()
			KEY_ESCAPE:
				_back_to_menu()
				accept_event()

func _exit_tree() -> void:
	# 兜底：如果不是正常 completed/timeout 流程离开，仍补一条 session_end 便于审计
	_write_session_end_marker("interrupted")
	if is_instance_valid(_main):
		_main.queue_free()
	_main = null
	_game = null
	_em = null
	_player = null

func _build_battle() -> void:
	var r := get_tree().root
	if r == null:
		_status.text = "状态：无法获取根节点"
		return
	if r.has_node("Main"):
		var old: Node = r.get_node("Main")
		if is_instance_valid(old):
			old.queue_free()
	var main := Node2D.new()
	main.name = "Main"
	_main = main
	r.add_child(main)

	if _GAME_SCN == null:
		_status.text = "状态：Game 场景加载失败"
		return
	var g := _GAME_SCN.instantiate() as Node2D
	if g == null:
		_status.text = "状态：Game 场景实例化失败"
		return
	g.name = "Game"
	main.add_child(g)
	_game = g

	_em = g.get_node_or_null("EnemyManager")
	_player = g.get_node_or_null("Player") as Node2D
	EventBus.game_started.emit()
	_status.text = "状态：就绪。可选择模式（建议先开始新批次 F11）。"
	if _whitebox_seed >= 0:
		_status_base = "状态：就绪（seed=%d）。可选择模式（建议先开始新批次 F11）。" % _whitebox_seed
		_status.text = _status_base
	if _auto_batch_start:
		_call_hud_action("_start_new_balance_batch")
	_write_session_start_marker()
	if _auto_stage > 0:
		call_deferred("_start_stage", _auto_stage)

func _back_to_menu() -> void:
	# 直接切回主菜单场景（避免与当前场景内构建的 Main/Game 根节点冲突）
	if FileAccess.file_exists(_MAIN_MENU_SCN):
		get_tree().change_scene_to_file(_MAIN_MENU_SCN)
	else:
		get_tree().quit()

func _reset_battle() -> void:
	_stage = 0
	_stage_time = 0.0
	_exam_spawn_cd = 0.0
	_status_tick_sec = 0.0
	_status_base = "状态：已清场并重置计时。可重新选择模式。"
	if _em != null and is_instance_valid(_em) and _em.has_method("clear_all_enemies"):
		_em.call("clear_all_enemies", true)
		_status.text = _status_base
		return
	if is_instance_valid(_main):
		_main.queue_free()
	_main = null
	_game = null
	_em = null
	_player = null
	_status.text = "状态：已重置，正在重新挂入 Main/Game…"
	call_deferred("_build_battle")

func _start_stage(s: int) -> void:
	if _game == null or not is_instance_valid(_game):
		_status.text = "状态：Game 未就绪，稍后再试"
		return
	# 每次切模式前先清场，保证环境一致
	if _em != null and is_instance_valid(_em) and _em.has_method("clear_all_enemies"):
		_em.call("clear_all_enemies", true)
	_stage = s
	_stage_time = 0.0
	_exam_spawn_cd = 0.0
	_status_tick_sec = 0.0
	var round_label := ""
	if _auto_stage == 3 and _auto_repeat_total > 1:
		var now_round := _auto_round_done + 1
		round_label = "（第%d/%d轮）" % [now_round, _auto_repeat_total]
	match _stage:
		1:
			_status_base = "状态：教学模式——单体目标（热键 1/2/3 切换，R 清场）（建议练：起手、走位、收束）"
			_spawn_ring(1, 0, 260.0)
		2:
			_status_base = "状态：组合模式——小群混合（热键 1/2/3 切换，R 清场）（建议练：控场、切角、压制）"
			_spawn_ring(6, 0, 320.0)
			_spawn_ring(2, 1, 360.0)
		3:
			_status_base = "状态：考核模式——%.0f秒刷怪%s（压力:%s）（热键 1/2/3 切换，R 清场）（建议结束后导出快照）" % [_exam_duration_sec, round_label, _pressure_level]
			_exam_enemy_samples = 0
			_exam_enemy_sum = 0
			_exam_enemy_peak = 0
			_write_round_marker("round_start")
		_:
			_status_base = "状态：就绪。"
	_status.text = _status_base

func _process(delta: float) -> void:
	super._process(delta)
	_session_elapsed_sec += delta
	_status_tick_sec += delta
	if _auto_exit_after > 0.0 and _session_elapsed_sec >= _auto_exit_after:
		_write_session_end_marker("timeout_exit")
		get_tree().quit(0)
		return
	if _stage == 0:
		if _status and _status_tick_sec >= 0.5:
			_status_tick_sec = 0.0
			_status.text = _status_base if not _status_base.is_empty() else "状态：就绪。"
		return
	_stage_time += delta
	if _stage == 3:
		_run_exam(delta)
		return
	# 教学/组合：每秒刷新一次可观察信息
	if _status and _status_tick_sec >= 1.0:
		_status_tick_sec = 0.0
		var alive := _enemy_alive_count()
		_status.text = "%s  | 敌人:%d  | 用时:%.0fs" % [_status_base, alive, _stage_time]

func _run_exam(delta: float) -> void:
	if _em == null or not is_instance_valid(_em):
		return
	var alive_now := _enemy_alive_count()
	_exam_enemy_samples += 1
	_exam_enemy_sum += alive_now
	_exam_enemy_peak = maxi(_exam_enemy_peak, alive_now)
	_exam_spawn_cd -= delta
	if _exam_spawn_cd <= 0.0:
		_exam_spawn_cd = 1.4 * _pressure_cd_mul
		var n_base := maxi(1, int(round(6.0 * _pressure_spawn_mul)))
		var n_mix := maxi(1, int(round(2.0 * _pressure_spawn_mul)))
		_spawn_ring(n_base, 0, 340.0)
		_spawn_ring(n_mix, 1, 400.0)
		if _stage_time > 12.0:
			var n_heavy := maxi(1, int(round(1.0 * _pressure_spawn_mul)))
			_spawn_ring(n_heavy, 2, 420.0) # 偶尔刷一个更肉的
	if _stage_time >= _exam_duration_sec:
		_stage = 0
		_auto_round_done += 1
		_write_round_marker("round_end")
		_status_base = "状态：考核结束。建议：F6 导出快照，然后用 F9 对比最近两次。"
		_status.text = _status_base
		if _auto_export_end:
			_call_hud_action("_export_skill_eff_snapshot")
		# 自动对比从第 2 轮开始，避免首轮日志噪音（快照不足）
		if _auto_compare_end and _auto_round_done >= 2:
			_call_hud_action("_compare_recent_eff_snapshots")
		if _auto_stage == 3 and _auto_round_done >= _auto_repeat_total and not _summary_written:
			_write_summary_marker()
			_summary_written = true
			_write_session_end_marker("completed")
		if _auto_stage == 3 and _auto_repeat_left > 1:
			_auto_repeat_left -= 1
			call_deferred("_start_stage", 3)
		return
	if _status and _status_tick_sec >= 1.0:
		_status_tick_sec = 0.0
		var left := maxf(0.0, _exam_duration_sec - _stage_time)
		_status.text = "%s  | 敌人:%d  | 峰值:%d  | 剩余:%.0fs  | 总计:%.0fs" % [_status_base, alive_now, _exam_enemy_peak, left, _session_elapsed_sec]

func _spawn_ring(n: int, kind_id: int, radius: float) -> void:
	if n <= 0:
		return
	if _em == null or not is_instance_valid(_em):
		return
	if not _em.has_method("spawn_enemy"):
		return
	var center := Vector2.ZERO
	if _player != null and is_instance_valid(_player):
		center = _player.global_position
	for i in range(n):
		var ang := float(i) / float(maxi(1, n)) * TAU
		var pos := center + Vector2(cos(ang), sin(ang)) * radius
		_em.call("spawn_enemy", pos, kind_id)

func _enemy_alive_count() -> int:
	if _em == null or not is_instance_valid(_em):
		return 0
	if _em.has_method("alive_count"):
		return int(_em.call("alive_count"))
	return 0


func _parse_cmdline_options() -> void:
	var profile := ""
	for a in OS.get_cmdline_args():
		if a == "--whitebox-auto-batch":
			_auto_batch_start = true
		elif a == "--whitebox-auto-export-end":
			_auto_export_end = true
		elif a == "--whitebox-auto-compare-end":
			_auto_compare_end = true
		if a.begins_with("--whitebox-stage="):
			var mode := a.trim_prefix("--whitebox-stage=")
			match mode:
				"tutorial":
					_auto_stage = 1
				"combo":
					_auto_stage = 2
				"exam":
					_auto_stage = 3
				_:
					_auto_stage = 0
		elif a.begins_with("--whitebox-exit-after="):
			_auto_exit_after = maxf(0.0, float(a.trim_prefix("--whitebox-exit-after=")))
		elif a.begins_with("--whitebox-repeat="):
			_auto_repeat_total = maxi(1, int(a.trim_prefix("--whitebox-repeat=")))
		elif a.begins_with("--whitebox-exam-seconds="):
			_exam_duration_sec = maxf(5.0, float(a.trim_prefix("--whitebox-exam-seconds=")))
		elif a.begins_with("--whitebox-seed="):
			_whitebox_seed = int(a.trim_prefix("--whitebox-seed="))
		elif a.begins_with("--whitebox-tag="):
			_whitebox_tag = a.trim_prefix("--whitebox-tag=")
		elif a.begins_with("--whitebox-pressure="):
			var p := a.trim_prefix("--whitebox-pressure=")
			if p == "low":
				_pressure_level = "low"
				_pressure_spawn_mul = 0.7
				_pressure_cd_mul = 1.25
			elif p == "high":
				_pressure_level = "high"
				_pressure_spawn_mul = 1.35
				_pressure_cd_mul = 0.78
			else:
				_pressure_level = "mid"
				_pressure_spawn_mul = 1.0
				_pressure_cd_mul = 1.0
		elif a.begins_with("--whitebox-profile="):
			profile = a.trim_prefix("--whitebox-profile=")
	# 预设只补默认值：显式传参优先于 profile
	if not profile.is_empty():
		_whitebox_profile = profile
		if profile == "quick":
			if _auto_stage == 0:
				_auto_stage = 3
			if _auto_repeat_total <= 1:
				_auto_repeat_total = 2
			if _exam_duration_sec <= 30.0:
				_exam_duration_sec = 20.0
			if _pressure_level == "mid":
				_pressure_level = "low"
				_pressure_spawn_mul = 0.7
				_pressure_cd_mul = 1.25
		elif profile == "stress":
			if _auto_stage == 0:
				_auto_stage = 3
			if _auto_repeat_total <= 1:
				_auto_repeat_total = 5
			if _exam_duration_sec <= 30.0:
				_exam_duration_sec = 45.0
			if _pressure_level == "mid":
				_pressure_level = "high"
				_pressure_spawn_mul = 1.35
				_pressure_cd_mul = 0.78
		else:
			# standard
			if _auto_stage == 0:
				_auto_stage = 3
			if _auto_repeat_total <= 1:
				_auto_repeat_total = 3


func _write_session_start_marker() -> void:
	if _game == null or not is_instance_valid(_game):
		return
	var hud := _game.get_node_or_null("HUD")
	if hud == null or not hud.has_method("write_balance_marker"):
		return
	var fields := {
		"profile": _whitebox_profile,
		"stage": _auto_stage,
		"repeat": _auto_repeat_total,
		"exam_seconds": int(round(_exam_duration_sec)),
		"pressure": _pressure_level,
		"seed": _whitebox_seed,
		"tag_label": _whitebox_tag,
		"auto_batch": _auto_batch_start,
		"auto_export_end": _auto_export_end,
		"auto_compare_end": _auto_compare_end,
		"auto_exit_after": int(round(_auto_exit_after))
	}
	hud.call("write_balance_marker", "whitebox_session_start", fields)


func _write_session_end_marker(reason: String) -> void:
	if _session_end_written:
		return
	var hud: Node = null
	if _game != null and is_instance_valid(_game):
		hud = _game.get_node_or_null("HUD")
	# 兜底：_exit_tree 时 _game 可能已进入释放流程，尝试从根查找当前 HUD
	if hud == null:
		var main := get_tree().root.get_node_or_null("Main")
		if main != null:
			var g := main.get_node_or_null("Game")
			if g != null:
				hud = g.get_node_or_null("HUD")
	if hud == null or not hud.has_method("write_balance_marker"):
		return
	var fields := {
		"reason": reason,
		"elapsed_seconds": int(round(_session_elapsed_sec)),
		"round_done": _auto_round_done,
		"round_total": _auto_repeat_total,
		"tag_label": _whitebox_tag
	}
	hud.call("write_balance_marker", "whitebox_session_end", fields)
	_session_end_written = true


func _call_hud_action(method_name: String) -> void:
	if _game == null or not is_instance_valid(_game):
		return
	var hud := _game.get_node_or_null("HUD")
	if hud == null:
		return
	if hud.has_method(method_name):
		hud.call(method_name)


func _write_round_marker(tag: String) -> void:
	if _auto_stage != 3:
		return
	if _game == null or not is_instance_valid(_game):
		return
	var hud := _game.get_node_or_null("HUD")
	if hud == null or not hud.has_method("write_balance_marker"):
		return
	var fields := {
		"round": _auto_round_done + 1 if tag == "round_start" else _auto_round_done,
		"round_total": _auto_repeat_total,
		"exam_seconds": int(round(_exam_duration_sec)),
		"seed": _whitebox_seed,
		"pressure": _pressure_level
	}
	if not _whitebox_tag.is_empty():
		fields["tag_label"] = _whitebox_tag
	hud.call("write_balance_marker", "whitebox_" + tag, fields)


func _write_summary_marker() -> void:
	if _game == null or not is_instance_valid(_game):
		return
	var hud := _game.get_node_or_null("HUD")
	if hud == null or not hud.has_method("write_balance_marker"):
		return
	var rounds := maxi(1, _auto_round_done)
	var per_round := int(round(_exam_duration_sec))
	var total_sec := rounds * per_round
	var avg_enemy := 0.0
	if _exam_enemy_samples > 0:
		avg_enemy = float(_exam_enemy_sum) / float(_exam_enemy_samples)
	var fields := {
		"round_total": rounds,
		"exam_seconds": per_round,
		"total_seconds": total_sec,
		"seed": _whitebox_seed,
		"pressure": _pressure_level,
		"enemy_avg": "%.2f" % avg_enemy,
		"enemy_peak": _exam_enemy_peak
	}
	if not _whitebox_tag.is_empty():
		fields["tag_label"] = _whitebox_tag
	if hud.has_method("get_latest_eff_summary"):
		var eff: Dictionary = hud.call("get_latest_eff_summary")
		if not eff.is_empty():
			fields["top1_skill"] = String(eff.get("skill_name", "-"))
			fields["top1_eff"] = "%.3f" % float(eff.get("efficiency", 0.0))
			fields["top1_casts"] = int(eff.get("casts", 0))
			fields["top1_scope"] = String(eff.get("scope", ""))
			fields["top1_sort"] = String(eff.get("sort", ""))
			fields["top1_min_casts"] = int(eff.get("min_casts", 0))
	hud.call("write_balance_marker", "whitebox_summary", fields)

func module_self_test() -> bool:
	# 只要求能成功挂载 Main/Game（主动技能会在 game_started 后自绑定）
	return _GAME_SCN != null

