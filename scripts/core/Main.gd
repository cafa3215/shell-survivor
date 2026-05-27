extends Node
class_name Main

@onready var menu_layer: CanvasLayer = $MenuLayer
@onready var pause_layer: CanvasLayer = $PauseLayer
@onready var result_layer: CanvasLayer = $ResultLayer
@onready var animated_bg: ColorRect = $MenuLayer/AnimatedBg

var _game_scene := preload("res://scenes/Game.tscn")
var _game: Node = null
var _result_shown := false
var _upgrade_ui_open := false
var _menu_time := 0.0
var _howto_dialog: AcceptDialog = null
var _map_select_opt: OptionButton = null
var _meta_upgrade_window: Window = null
var _meta_upgrade_scrap_label: Label = null
var _meta_upgrade_rows: VBoxContainer = null
## 防止连点「开始」导致上一局未释放完就叠出新 Game 实例
var _starting_game: bool = false
## 场景切换总锁：防重复触发 restart/menu/start/game_over 竞态
var _scene_transition_busy: bool = false
## 暂停层显示请求序号：用于丢弃过期的 hide/show 异步回调
var _pause_vis_req_id: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _try_smoke_mode_exit():
		return
	if _try_whitebox_entry():
		return
	EventBus.game_over.connect(_on_game_over)
	EventBus.toggle_pause_requested.connect(_on_toggle_pause_requested)
	EventBus.upgrade_ui_state_changed.connect(_on_upgrade_ui_state_changed)
	_bind_buttons()
	RunStats.reset()
	_init_settings_ui()
	_setup_menu_extras()
	_show_menu(true)
	_show_pause(false)
	_show_result(false)

func _bind_buttons() -> void:
	$MenuLayer/Root/Panel/StartButton.pressed.connect(_start_game)
	$MenuLayer/Root/Panel/QuitButton.pressed.connect(func(): get_tree().quit())
	# 美化版暂停面板信号连接
	$PauseLayer/PausePanel.resume_pressed.connect(_resume_game)
	$PauseLayer/PausePanel.restart_pressed.connect(_restart_game)
	$PauseLayer/PausePanel.menu_pressed.connect(_back_to_menu)
	# 美化版结果面板信号连接
	$ResultLayer/ResultPanel.restart_pressed.connect(_restart_game)
	$ResultLayer/ResultPanel.menu_pressed.connect(_back_to_menu)

func _init_settings_ui() -> void:
	var q: OptionButton = $MenuLayer/Root/Panel/SettingsScroll/SettingsContainer/QualityRow/Quality as OptionButton
	q.clear()
	q.add_item("低", Settings.Quality.LOW)
	q.add_item("中", Settings.Quality.MEDIUM)
	q.add_item("高", Settings.Quality.HIGH)
	var qi: int = 1
	if Settings.quality == Settings.Quality.LOW:
		qi = 0
	elif Settings.quality == Settings.Quality.HIGH:
		qi = 2
	q.select(qi)
	q.item_selected.connect(func(_idx: int):
		Settings.set_quality(q.get_selected_id())
	)
	# 音量控制
	var sfx_slider: HSlider = $MenuLayer/Root/Panel/SettingsScroll/SettingsContainer/SfxRow/SfxSlider as HSlider
	var music_slider: HSlider = $MenuLayer/Root/Panel/SettingsScroll/SettingsContainer/MusicRow/MusicSlider as HSlider
	if sfx_slider:
		sfx_slider.value = Settings.sfx_volume * 100.0
		sfx_slider.value_changed.connect(func(v: float):
			Settings.set_sfx_volume(v / 100.0)
		)
	if music_slider:
		music_slider.value = Settings.music_volume * 100.0
		music_slider.value_changed.connect(func(v: float):
			Settings.set_music_volume(v / 100.0)
		)
	var sc := $MenuLayer/Root/Panel/SettingsScroll/SettingsContainer as VBoxContainer
	if sc:
		var map_row := HBoxContainer.new()
		map_row.name = "MapRow"
		var map_label := Label.new()
		map_label.text = "作战区域"
		map_label.custom_minimum_size = Vector2(120, 0)
		map_label.theme_type_variation = &"Label.Body"
		map_row.add_child(map_label)
		var map_opt := OptionButton.new()
		map_opt.name = "MapSelect"
		map_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_opt.theme_type_variation = &"Input.Select"
		for i in GameDB.MAP_TEMPLATES.size():
			var tpl: Dictionary = GameDB.MAP_TEMPLATES[i]
			var t := String(tpl.get("title", tpl.get("id", "地图 %d" % i)))
			map_opt.add_item(t, i)
		_map_select_opt = map_opt
		_refresh_map_unlock_ui()
		map_opt.item_selected.connect(func(_idx: int) -> void:
			Settings.set_selected_map_index(map_opt.get_selected_id())
		)
		map_row.add_child(map_opt)
		sc.add_child(map_row)
		sc.move_child(map_row, 0)
		var vfx_row := HBoxContainer.new()
		vfx_row.name = "VfxProfileRow"
		var vfx_label := Label.new()
		vfx_label.text = "特效风格"
		vfx_label.custom_minimum_size = Vector2(120, 0)
		vfx_row.add_child(vfx_label)
		var vfx_opt := OptionButton.new()
		vfx_opt.name = "VfxProfile"
		vfx_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vfx_opt.add_item("竞技清晰", Settings.VfxProfile.COMPETITIVE)
		vfx_opt.add_item("平衡默认", Settings.VfxProfile.BALANCED)
		vfx_opt.add_item("电影爽感", Settings.VfxProfile.CINEMATIC)
		var vfx_idx := 1
		if Settings.vfx_profile == Settings.VfxProfile.COMPETITIVE:
			vfx_idx = 0
		elif Settings.vfx_profile == Settings.VfxProfile.CINEMATIC:
			vfx_idx = 2
		vfx_opt.select(vfx_idx)
		vfx_opt.item_selected.connect(func(_idx: int) -> void:
			Settings.set_vfx_profile(vfx_opt.get_selected_id())
		)
		vfx_row.add_child(vfx_opt)
		sc.add_child(vfx_row)
		var early_row := HBoxContainer.new()
		early_row.name = "EarlyFlowPresetRow"
		var early_label := Label.new()
		early_label.text = "首局吸引力"
		early_label.custom_minimum_size = Vector2(120, 0)
		early_row.add_child(early_label)
		var early_opt := OptionButton.new()
		early_opt.name = "EarlyFlowPreset"
		early_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		early_opt.add_item("柔和", Settings.EarlyFlowPreset.SOFT)
		early_opt.add_item("平衡", Settings.EarlyFlowPreset.NORMAL)
		early_opt.add_item("激进", Settings.EarlyFlowPreset.HARDCORE)
		var early_idx := 1
		if Settings.early_flow_preset == Settings.EarlyFlowPreset.SOFT:
			early_idx = 0
		elif Settings.early_flow_preset == Settings.EarlyFlowPreset.HARDCORE:
			early_idx = 2
		early_opt.select(early_idx)
		early_opt.item_selected.connect(func(_idx: int) -> void:
			Settings.set_early_flow_preset(early_opt.get_selected_id())
		)
		early_row.add_child(early_opt)
		sc.add_child(early_row)
		var readability_row := HBoxContainer.new()
		readability_row.name = "ReadabilityPresetRow"
		var readability_label := Label.new()
		readability_label.text = "人物可见性"
		readability_label.custom_minimum_size = Vector2(120, 0)
		readability_row.add_child(readability_label)
		var readability_opt := OptionButton.new()
		readability_opt.name = "ReadabilityPreset"
		readability_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readability_opt.add_item("低", Settings.ReadabilityPreset.LOW)
		readability_opt.add_item("中", Settings.ReadabilityPreset.MEDIUM)
		readability_opt.add_item("高", Settings.ReadabilityPreset.HIGH)
		var readability_idx := 1
		if Settings.readability_preset == Settings.ReadabilityPreset.LOW:
			readability_idx = 0
		elif Settings.readability_preset == Settings.ReadabilityPreset.HIGH:
			readability_idx = 2
		readability_opt.select(readability_idx)
		readability_opt.item_selected.connect(func(_idx: int) -> void:
			Settings.set_readability_preset(readability_opt.get_selected_id())
		)
		readability_row.add_child(readability_opt)
		sc.add_child(readability_row)
		var early_hint := Label.new()
		early_hint.name = "EarlyFlowPresetHint"
		early_hint.text = "首局吸引力影响 0-180 秒节奏；人物可见性影响主角标记、敌人压暗和飘字避让。"
		early_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		early_hint.add_theme_font_size_override("font_size", 11)
		early_hint.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
		sc.add_child(early_hint)
		var extreme_cb := CheckBox.new()
		extreme_cb.text = "高压性能保护（敌人暴涨时自动保帧）"
		extreme_cb.button_pressed = Settings.extreme_perf_guard
		extreme_cb.toggled.connect(func(on: bool) -> void:
			Settings.set_extreme_perf_guard(on)
		)
		sc.add_child(extreme_cb)
		var debug_cb := CheckBox.new()
		debug_cb.text = "显示帧率与战斗调试信息"
		debug_cb.button_pressed = Settings.debug_hud
		debug_cb.toggled.connect(func(on: bool) -> void:
			Settings.set_debug_hud(on)
		)
		sc.add_child(debug_cb)
		var motion_cb := CheckBox.new()
		motion_cb.text = "减轻镜头震动"
		motion_cb.button_pressed = Settings.reduce_screen_motion
		motion_cb.toggled.connect(func(on: bool) -> void:
			Settings.set_reduce_screen_motion(on)
		)
		sc.add_child(motion_cb)
		var mouse_move_cb: CheckBox = CheckBox.new()
		mouse_move_cb.text = "电脑端: 鼠标指向移动（更精细走位）"
		mouse_move_cb.button_pressed = Settings.mouse_direct_move
		mouse_move_cb.toggled.connect(func(on: bool) -> void:
			Settings.set_mouse_direct_move(on)
		)
		sc.add_child(mouse_move_cb)
		var contrast_cb: CheckBox = CheckBox.new()
		contrast_cb.text = "高优先级敌人高亮"
		contrast_cb.button_pressed = Settings.high_contrast_targets
		contrast_cb.toggled.connect(func(on: bool) -> void:
			Settings.set_high_contrast_targets(on)
		)
		sc.add_child(contrast_cb)
		var dn_cb: CheckBox = CheckBox.new()
		dn_cb.text = "显示伤害跳字"
		dn_cb.button_pressed = Settings.show_damage_numbers
		dn_cb.toggled.connect(func(on: bool) -> void:
			Settings.set_show_damage_numbers(on)
		)
		sc.add_child(dn_cb)
		var flash_cb: CheckBox = CheckBox.new()
		flash_cb.text = "启用闪屏/闪光"
		flash_cb.button_pressed = Settings.enable_screen_flash
		flash_cb.toggled.connect(func(on: bool) -> void:
			Settings.set_enable_screen_flash(on)
		)
		sc.add_child(flash_cb)
		var part_cb := CheckBox.new()
		part_cb.text = "减少粒子特效（更清爽/更清晰）"
		part_cb.button_pressed = Settings.reduce_particles
		part_cb.toggled.connect(func(on: bool) -> void:
			Settings.set_reduce_particles(on)
		)
		sc.add_child(part_cb)

func _process(delta: float) -> void:
	# 动画化菜单背景
	if menu_layer.visible:
		_menu_time += delta
		if animated_bg and animated_bg.material:
			var mat := animated_bg.material as ShaderMaterial
			mat.set_shader_parameter("time", _menu_time)

func _unhandled_input(event: InputEvent) -> void:
	if _scene_transition_busy:
		return
	if Settings.debug_hud and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		SentryBridge.capture_test_exception()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and _game != null and not result_layer.visible and not _upgrade_ui_open:
		_on_toggle_pause_requested()

func _start_game() -> void:
	if _starting_game or _scene_transition_busy:
		return
	_scene_transition_busy = true
	_starting_game = true
	if _game != null and is_instance_valid(_game):
		var old: Node = _game
		_game = null
		old.queue_free()
		await old.tree_exited
	RunStats.reset()
	_result_shown = false
	_upgrade_ui_open = false
	_game = _game_scene.instantiate()
	add_child(_game)
	move_child(_game, 0)
	get_tree().paused = false
	_show_menu(false)
	_show_pause(false)
	_show_result(false)
	EventBus.game_resumed.emit()
	_starting_game = false
	_scene_transition_busy = false

func _restart_game() -> void:
	if _scene_transition_busy:
		return
	get_tree().paused = false
	_start_game()

func _back_to_menu() -> void:
	if _scene_transition_busy:
		return
	_scene_transition_busy = true
	get_tree().paused = false
	if _game != null and is_instance_valid(_game):
		var old: Node = _game
		_game = null
		old.queue_free()
		await old.tree_exited
	_result_shown = false
	_upgrade_ui_open = false
	_show_menu(true)
	_show_pause(false)
	_show_result(false)
	EventBus.game_resumed.emit()
	_scene_transition_busy = false

func _resume_game() -> void:
	if _scene_transition_busy:
		return
	get_tree().paused = false
	_show_pause(false)
	EventBus.game_resumed.emit()

func _on_toggle_pause_requested() -> void:
	if _scene_transition_busy or _starting_game:
		return
	if _game == null or menu_layer.visible or result_layer.visible or _upgrade_ui_open:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	_show_pause(paused)
	if paused:
		EventBus.game_paused.emit()
	else:
		EventBus.game_resumed.emit()

func _on_upgrade_ui_state_changed(open: bool) -> void:
	_upgrade_ui_open = open
	if open and pause_layer.visible:
		_show_pause(false)

func _on_game_over(win: bool) -> void:
	if _scene_transition_busy:
		return
	if _game == null or _result_shown:
		return
	_scene_transition_busy = true
	_result_shown = true
	_upgrade_ui_open = false
	get_tree().paused = true
	EventBus.game_paused.emit()

	# 检查无尽模式
	var endless_mode := false
	var fusion_ratio: float = RunStats.fusion_damage_ratio()
	if _game and _game.get("elapsed") != null:
		endless_mode = true if _game.get("_endless_mode") else false
	var top_types: Array[String] = RunStats.top_kill_types(3)
	var top_line: String = "击杀最多: " + (", ".join(top_types) if not top_types.is_empty() else "-")
	var top_build: Array[String] = RunStats.top_upgrade_picks(4)
	var build_line: String = "构筑推荐: " + (", ".join(top_build) if not top_build.is_empty() else "-")
	var top_dmg: Array[String] = RunStats.top_damage_sources(4)
	var top_dmg_disp: Array[String] = []
	for s in top_dmg:
		top_dmg_disp.append(GameDB.humanize_damage_source(s))
	var dmg_line: String = "伤害来源: " + (", ".join(top_dmg_disp) if not top_dmg_disp.is_empty() else "-")
	var fusion_line: String = "融合伤害: %.1f%%" % (RunStats.fusion_damage_ratio() * 100.0)
	var top_boss_dmg: Array[String] = RunStats.top_boss_damage_sources(3)
	var top_boss_disp: Array[String] = []
	for s in top_boss_dmg:
		top_boss_disp.append(GameDB.humanize_damage_source(s))
	var boss_dmg_line: String = "首领伤害: " + (", ".join(top_boss_disp) if not top_boss_disp.is_empty() else "-")
	var focus_line: String = "首领专注: %.1f%%" % (RunStats.boss_damage_focus_ratio() * 100.0)
	var diagnosis: Dictionary = _build_run_diagnosis(fusion_ratio)
	var diagnosis_line: String = String(diagnosis.get("text", "诊断: 构筑均衡，无明显短板"))
	var diag_tags: Array[String] = []
	if diagnosis.has("tags"):
		for t in diagnosis["tags"]:
			diag_tags.append(String(t))
	RunStats.set_diagnosis_tags(diag_tags)
	RunStats.finalize_latest_run(win)
	var cleared_map := 0
	if _game != null:
		cleared_map = clampi(int(_game.get("map_index")), 0, maxi(0, GameDB.MAP_TEMPLATES.size() - 1))
	var meta_end: Dictionary = MetaProgress.record_run_ended(win, RunStats.runtime_sec, cleared_map)
	var unlock_line := String(meta_end.get("unlock_line", ""))
	var diag_tags_line: String = "诊断标签: " + (", ".join(diag_tags) if not diag_tags.is_empty() else "健康")
	var recent_hot: Array[String] = RunStats.recent_hot_tag_labels(5)
	var recent_hot_line: String = "近期热门: " + (", ".join(recent_hot) if not recent_hot.is_empty() else "-")
	var recent_preset: Array[String] = RunStats.recent_preset_usage(3)
	var preset_usage_line: String = "近期使用预设: " + (", ".join(recent_preset) if not recent_preset.is_empty() else "-")
	var preset_wr: Array[String] = RunStats.recent_preset_winrates(3)
	var preset_wr_line: String = "预设胜率: " + (", ".join(preset_wr) if not preset_wr.is_empty() else "-")
	var preset_stability: Array[String] = RunStats.recent_preset_stability(3)
	var preset_stability_line: String = "预设稳定性: " + (", ".join(preset_stability) if not preset_stability.is_empty() else "-")
	var preset_recommend_line: String = RunStats.recommended_preset_summary()
	var recent_suggest_line: String = RunStats.recent_primary_suggestion()
	var action_plan: Array[String] = RunStats.recent_action_plan_personalized()
	var plan_line: String = "下一步计划: " + ((" / ").join(action_plan) if not action_plan.is_empty() else "-")
	var preset_line: String = "战术预设: %s" % RunStats.current_tactic_preset_label()
	var boss_ttk: int = RunStats.boss_ttk()
	var boss_line: String = "首领: 未出现"
	if endless_mode:
		boss_line = "首领: 已击杀！进入无尽模式"
	if RunStats.boss_spawn_sec >= 0 and RunStats.boss_defeat_sec < 0:
		boss_line = "首领: 出现于 %02d:%02d，未击败" % [RunStats.boss_spawn_sec / 60, RunStats.boss_spawn_sec % 60]
	elif RunStats.boss_spawn_sec >= 0 and RunStats.boss_defeat_sec >= 0:
		boss_line = "首领: 出现 %02d:%02d  击杀 %02d:%02d  用时%ds  每秒伤害:%.1f" % [
			RunStats.boss_spawn_sec / 60, RunStats.boss_spawn_sec % 60,
			RunStats.boss_defeat_sec / 60, RunStats.boss_defeat_sec % 60,
			boss_ttk,
			RunStats.boss_dps()
		]
	
	# 使用美化版结果面板
	var result_panel = $ResultLayer/ResultPanel
	var recap := ""
	if not win:
		recap = RunStats.build_loss_recap_line()
	var flow_line := ""
	if _game and _game.has_method("pressure_relief_summary_line"):
		flow_line = String(_game.pressure_relief_summary_line())
	var relic_line := ""
	if not RunStats.current_run_relic_id.is_empty():
		var rnm := GameDB.run_relic_display_name(RunStats.current_run_relic_id)
		if not rnm.is_empty():
			relic_line = "遗物：" + rnm
	if not RunStats.current_run_relic_second_id.is_empty():
		var r2 := GameDB.run_relic_display_name(RunStats.current_run_relic_second_id)
		if not r2.is_empty():
			if relic_line.is_empty():
				relic_line = "遗物：" + r2
			else:
				relic_line += " · 宝箱：" + r2
	var result_data := {
		"runtime_sec": RunStats.runtime_sec,
		"kills": RunStats.kills,
		"kpm": RunStats.kpm(),
		"damage_total": int(RunStats.damage_total),
		"boss_line": boss_line,
		"top_line": top_line,
		"build_line": build_line,
		"dmg_line": dmg_line,
		"fusions": RunStats.fusions,
		"fusion_ratio": fusion_ratio,
		"diagnosis": diagnosis_line,
		"recap_line": recap,
		"flow_line": flow_line,
		"unlock_line": unlock_line,
		"scrap_delta": int(meta_end.get("scrap_delta", 0)),
		"scrap_total": int(meta_end.get("scrap_total", 0)),
		"relic_line": relic_line,
	}
	result_panel.show_result(result_data, win)
	
	_show_result(true)
	_show_pause(false)
	_scene_transition_busy = false

func _build_run_diagnosis(fusion_ratio: float) -> Dictionary:
	var notes: Array[String] = []
	var tags: Array[String] = []
	var boss_focus: float = RunStats.boss_damage_focus_ratio()
	var taken_dpm := RunStats.dpm_taken()
	if boss_focus >= 0.72:
		notes.append("首领输出过于单核，建议补副C/持续伤害")
		tags.append("offense_single_core")
	elif boss_focus <= 0.45 and RunStats.damage_to_boss > 0.0:
		notes.append("首领输出分布健康，构筑容错较高")
		tags.append("boss_distribution_good")
	if fusion_ratio < 0.28 and RunStats.fusions > 0:
		notes.append("融合收益偏低，优先补融合关联被动")
		tags.append("fusion_value_low")
	elif fusion_ratio >= 0.5:
		notes.append("融合收益优秀，可维持当前成型路线")
		tags.append("fusion_value_high")
	if taken_dpm >= 95.0:
		notes.append("生存压力偏高，建议提高减伤/移速")
		tags.append("survival_gap")
	elif taken_dpm <= 45.0 and RunStats.runtime_sec >= 300:
		notes.append("生存稳定，可将资源转向进攻")
		tags.append("survival_stable")
	if notes.is_empty():
		notes.append("构筑均衡，无明显短板")
		tags.append("healthy")
	return {
		"text": "诊断: " + " | ".join(notes),
		"tags": tags
	}

func _show_menu(v: bool) -> void:
	menu_layer.visible = v
	if v:
		_refresh_map_unlock_ui()
		_refresh_meta_stats()


func _try_smoke_mode_exit() -> bool:
	for a in OS.get_cmdline_args():
		if a == "--smoke":
			for nm in GameDB.SMOKE_EXPECT_AUTOLOADS:
				if get_node_or_null("/root/" + nm) == null:
					push_error("SMOKE missing autoload: " + nm)
					get_tree().quit(1)
					return true
			print("SMOKE OK (", GameDB.SMOKE_EXPECT_AUTOLOADS.size(), " autoloads)")
			get_tree().quit(0)
			return true
	return false


func _try_whitebox_entry() -> bool:
	for a in OS.get_cmdline_args():
		if a == "--whitebox":
			call_deferred("_open_whitebox_from_args")
			return true
	return false


func _open_whitebox_from_args() -> void:
	get_tree().change_scene_to_file("res://scenes/modules/skills/SkillsWhitebox.tscn")


func _setup_menu_extras() -> void:
	var panel := menu_layer.get_node_or_null("Root/Panel") as Panel
	if panel == null:
		return
	var subtitle := panel.get_node_or_null("Subtitle") as Label
	if subtitle:
		subtitle.text = GameDB.THEME_TAGLINE
	var ver := panel.get_node_or_null("VersionLabel") as Label
	if ver:
		ver.text = "版本 %s" % GameDB.GAME_VERSION
	if panel.get_node_or_null("MetaStatsLabel") == null:
		var ml := Label.new()
		ml.name = "MetaStatsLabel"
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.add_theme_font_size_override("font_size", 14)
		ml.add_theme_color_override("font_color", Color(0.62, 0.76, 0.9, 0.92))
		var quit_btn := panel.get_node_or_null("QuitButton") as Control
		if quit_btn:
			panel.add_child(ml)
			panel.move_child(ml, quit_btn.get_index())
		else:
			panel.add_child(ml)
	if panel.get_node_or_null("HowToButton") == null:
		var hb := Button.new()
		hb.name = "HowToButton"
		hb.text = "玩法说明"
		hb.add_theme_font_size_override("font_size", 16)
		hb.pressed.connect(_open_howto_dialog)
		var start_btn := panel.get_node_or_null("StartButton") as Control
		if start_btn:
			panel.add_child(hb)
			panel.move_child(hb, start_btn.get_index() + 1)
		else:
			panel.add_child(hb)
	if panel.get_node_or_null("MetaUpgradeButton") == null:
		var mb := Button.new()
		mb.name = "MetaUpgradeButton"
		mb.text = "战备强化"
		mb.add_theme_font_size_override("font_size", 16)
		mb.pressed.connect(_open_meta_upgrade_panel)
		var how := panel.get_node_or_null("HowToButton") as Control
		if how:
			panel.add_child(mb)
			panel.move_child(mb, how.get_index() + 1)
		else:
			panel.add_child(mb)
	if panel.get_node_or_null("WhiteboxButton") == null:
		var wb := Button.new()
		wb.name = "WhiteboxButton"
		wb.text = "技能白盒试验场"
		wb.add_theme_font_size_override("font_size", 16)
		wb.pressed.connect(_open_skills_whitebox)
		var meta_btn := panel.get_node_or_null("MetaUpgradeButton") as Control
		if meta_btn:
			panel.add_child(wb)
			panel.move_child(wb, meta_btn.get_index() + 1)
		else:
			panel.add_child(wb)


func _open_skills_whitebox() -> void:
	if _scene_transition_busy or _starting_game:
		return
	_scene_transition_busy = true
	get_tree().paused = false
	if _game != null and is_instance_valid(_game):
		var old: Node = _game
		_game = null
		old.queue_free()
		await old.tree_exited
	_result_shown = false
	_upgrade_ui_open = false
	RunStats.reset()
	_show_menu(false)
	_show_pause(false)
	_show_result(false)
	_scene_transition_busy = false
	get_tree().change_scene_to_file("res://scenes/modules/skills/SkillsWhitebox.tscn")


func _open_meta_upgrade_panel() -> void:
	if _meta_upgrade_window != null and is_instance_valid(_meta_upgrade_window):
		_refresh_meta_upgrade_rows()
		_meta_upgrade_window.popup_centered()
		return
	var w := Window.new()
	w.title = "战备强化"
	w.size = Vector2i(540, 600)
	w.unresizable = true
	w.always_on_top = true
	w.close_requested.connect(func() -> void: w.hide())
	w.exclusive = true
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 14)
	w.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	_meta_upgrade_scrap_label = Label.new()
	_meta_upgrade_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_meta_upgrade_scrap_label)
	var hint := Label.new()
	hint.text = "消耗战备碎片永久提升属性；新开局立即生效（与局内三选一独立）。更多遗物随胜场解锁；标价为「入库」的遗物需先购买才进入开局随机池。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	outer.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	outer.add_child(scroll)
	_meta_upgrade_rows = VBoxContainer.new()
	_meta_upgrade_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meta_upgrade_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(_meta_upgrade_rows)
	add_child(w)
	_meta_upgrade_window = w
	_refresh_meta_upgrade_rows()
	w.popup_centered()


func _refresh_meta_upgrade_rows() -> void:
	if _meta_upgrade_scrap_label:
		_meta_upgrade_scrap_label.text = "战备碎片：%d" % MetaProgress.scrap
	if _meta_upgrade_rows == null:
		return
	for c in _meta_upgrade_rows.get_children():
		c.queue_free()
	for uid in GameDB.META_PERMANENT_UPGRADES.keys():
		var def: Dictionary = GameDB.META_PERMANENT_UPGRADES[uid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := Label.new()
		t.text = String(def["name"])
		t.theme_type_variation = &"Label.Body"
		left.add_child(t)
		var d := Label.new()
		d.text = String(def["desc"])
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 1.0))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		left.add_child(d)
		row.add_child(left)
		var lv := int(MetaProgress.meta_upgrade_levels.get(uid, 0))
		var lv_lab := Label.new()
		lv_lab.text = "Lv %d/%d" % [lv, int(def["max_lv"])]
		lv_lab.custom_minimum_size = Vector2(72, 0)
		row.add_child(lv_lab)
		var btn := Button.new()
		var cost := MetaProgress.meta_upgrade_cost_next(uid)
		if cost < 0:
			btn.text = "已满"
			btn.disabled = true
		else:
			btn.text = "升级 (%d)" % cost
			btn.disabled = MetaProgress.scrap < cost
			var u: String = uid
			btn.pressed.connect(func() -> void: _on_meta_upgrade_buy_pressed(u))
		row.add_child(btn)
		_meta_upgrade_rows.add_child(row)
	var sep_codex := HSeparator.new()
	_meta_upgrade_rows.add_child(sep_codex)
	var codex_title := Label.new()
	codex_title.text = "遗物图鉴（胜场 / 碎片入库 / 是否已进入随机池）"
	codex_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	codex_title.add_theme_font_size_override("font_size", 13)
	_meta_upgrade_rows.add_child(codex_title)
	var relic_keys: Array[String] = []
	for rk in GameDB.RUN_RELICS.keys():
		relic_keys.append(String(rk))
	relic_keys.sort()
	for rid in relic_keys:
		var rdef: Dictionary = GameDB.RUN_RELICS[rid]
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 4)
		var nm := Label.new()
		nm.text = String(rdef.get("name", rid))
		nm.theme_type_variation = &"Label.Body"
		card.add_child(nm)
		var dsc := Label.new()
		dsc.text = String(rdef.get("desc", ""))
		dsc.add_theme_font_size_override("font_size", 11)
		dsc.autowrap_mode = TextServer.AUTOWRAP_WORD
		dsc.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 1.0))
		card.add_child(dsc)
		var st := Label.new()
		st.text = _meta_relic_codex_status_line(rid, rdef)
		st.add_theme_font_size_override("font_size", 11)
		st.autowrap_mode = TextServer.AUTOWRAP_WORD
		if MetaProgress.is_run_relic_unlocked_for_pool(rid):
			st.add_theme_color_override("font_color", Color(0.52, 0.88, 0.62, 1.0))
		else:
			st.add_theme_color_override("font_color", Color(0.88, 0.72, 0.55, 1.0))
		card.add_child(st)
		_meta_upgrade_rows.add_child(card)
	var sep := HSeparator.new()
	_meta_upgrade_rows.add_child(sep)
	var relic_title := Label.new()
	relic_title.text = "遗物入库（碎片一次性，永久加入开局随机池）"
	relic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_title.add_theme_font_size_override("font_size", 13)
	_meta_upgrade_rows.add_child(relic_title)
	var any_relic_shop := false
	for rid in GameDB.RUN_RELICS.keys():
		var rdef: Dictionary = GameDB.RUN_RELICS[rid]
		var sc := int(rdef.get("scrap_unlock", 0))
		if sc <= 0:
			continue
		any_relic_shop = true
		var rrow := HBoxContainer.new()
		rrow.add_theme_constant_override("separation", 12)
		var rleft := VBoxContainer.new()
		rleft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rt := Label.new()
		rt.text = String(rdef.get("name", rid))
		rt.theme_type_variation = &"Label.Body"
		rleft.add_child(rt)
		var rd := Label.new()
		rd.text = String(rdef.get("desc", ""))
		rd.add_theme_font_size_override("font_size", 12)
		rd.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 1.0))
		rd.autowrap_mode = TextServer.AUTOWRAP_WORD
		rleft.add_child(rd)
		rrow.add_child(rleft)
		var rbtn := Button.new()
		var unlocked := bool(MetaProgress.run_relic_scrap_unlocked.get(rid, false))
		if unlocked:
			rbtn.text = "已入库"
			rbtn.disabled = true
		else:
			rbtn.text = "入库 (%d)" % sc
			rbtn.disabled = MetaProgress.scrap < sc
			var rrid: String = String(rid)
			rbtn.pressed.connect(func() -> void: _on_meta_relic_unlock_pressed(rrid))
		rrow.add_child(rbtn)
		_meta_upgrade_rows.add_child(rrow)
	if not any_relic_shop:
		relic_title.visible = false
		sep.visible = false


func _meta_relic_codex_status_line(rid: String, rdef: Dictionary) -> String:
	if MetaProgress.is_run_relic_unlocked_for_pool(rid):
		return "已加入开局随机池"
	var parts: Array[String] = []
	var need_w := int(rdef.get("unlock_min_wins", 0))
	if MetaProgress.wins_total < need_w:
		parts.append("胜场 %d / %d（未达标）" % [MetaProgress.wins_total, need_w])
	else:
		parts.append("胜场已满足（门槛 %d 胜）" % need_w)
	var sc := int(rdef.get("scrap_unlock", 0))
	if sc > 0:
		if bool(MetaProgress.run_relic_scrap_unlocked.get(rid, false)):
			parts.append("碎片入库：已支付")
		else:
			parts.append("碎片入库：未支付（%d 战备碎片）" % sc)
	return " · ".join(parts)


func _on_meta_relic_unlock_pressed(rid: String) -> void:
	if MetaProgress.try_purchase_run_relic_unlock(rid):
		EventBus.play_sfx.emit(&"upgrade_pick", Vector2.ZERO)
		_refresh_meta_upgrade_rows()
		_refresh_meta_stats()


func _on_meta_upgrade_buy_pressed(uid: String) -> void:
	if MetaProgress.try_purchase_meta_upgrade(uid):
		EventBus.play_sfx.emit(&"upgrade_pick", Vector2.ZERO)
		_refresh_meta_upgrade_rows()
		_refresh_meta_stats()


func _refresh_map_unlock_ui() -> void:
	if _map_select_opt == null or not is_instance_valid(_map_select_opt):
		return
	var n := GameDB.MAP_TEMPLATES.size()
	if n <= 0:
		return
	var last_i := n - 1
	var upto := clampi(MetaProgress.unlocked_map_upto, 0, last_i)
	if Settings.selected_map_index > upto:
		Settings.set_selected_map_index(upto)
	for i in n:
		_map_select_opt.set_item_disabled(i, i > upto)
	var sel := clampi(Settings.selected_map_index, 0, upto)
	_map_select_opt.select(sel)


func _refresh_meta_stats() -> void:
	var panel := menu_layer.get_node_or_null("Root/Panel") as Panel
	if panel == null:
		return
	var ml := panel.get_node_or_null("MetaStatsLabel") as Label
	if ml:
		ml.text = MetaProgress.summary_line() + "\n" + RunStats.menu_next_run_hint()


func _open_howto_dialog() -> void:
	if _howto_dialog != null and is_instance_valid(_howto_dialog):
		_howto_dialog.queue_free()
		_howto_dialog = null
	var dlg := AcceptDialog.new()
	dlg.title = GameDB.HOWTO_TITLE
	var body := ""
	for i in range(GameDB.HOWTO_STEPS.size()):
		body += "%d) %s\n" % [i + 1, String(GameDB.HOWTO_STEPS[i])]
	dlg.dialog_text = body.strip_edges()
	dlg.ok_button_text = "知道了"
	add_child(dlg)
	dlg.popup_centered_ratio(0.55)
	dlg.confirmed.connect(_close_howto_dialog.bind(dlg))
	dlg.close_requested.connect(_close_howto_dialog.bind(dlg))
	_howto_dialog = dlg


func _close_howto_dialog(dlg: Node) -> void:
	if _howto_dialog == dlg:
		_howto_dialog = null
	if dlg and is_instance_valid(dlg):
		dlg.queue_free()

func _show_pause(v: bool) -> void:
	_pause_vis_req_id += 1
	var req_id := _pause_vis_req_id
	if v:
		pause_layer.visible = true
		$PauseLayer/PausePanel.show_pause()
	else:
		$PauseLayer/PausePanel.hide_pause()
		# process_always：在 get_tree().paused 时仍能走完隐藏流程（例如升级 UI 顶掉暂停层）
		await get_tree().create_timer(0.3, true).timeout
		if req_id != _pause_vis_req_id:
			return
		pause_layer.visible = false

func _show_result(v: bool) -> void:
	result_layer.visible = v
