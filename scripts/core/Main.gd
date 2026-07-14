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
	_configure_menu_input_layers()
	RunStats.reset()
	_init_settings_ui()
	_setup_menu_extras()
	call_deferred("_deferred_apply_ui_font")
	call_deferred("_relayout_menu_panel")
	if not get_viewport().size_changed.is_connected(_relayout_menu_panel):
		get_viewport().size_changed.connect(_relayout_menu_panel)
	_show_menu(true)
	_show_pause(false)
	_show_result(false)

func _deferred_apply_ui_font() -> void:
	if UiFont:
		UiFont.patch_control_tree(self)
		if menu_layer:
			UiFont.patch_control_tree(menu_layer)


func _configure_menu_input_layers() -> void:
	for node_name in ["AnimatedBg", "BgGlow1", "BgGlow2"]:
		var node := menu_layer.get_node_or_null(node_name)
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var root := menu_layer.get_node_or_null("Root") as Control
	if root:
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _bind_buttons() -> void:
	InputManager.bind_instant_tap($MenuLayer/Root/Panel/Margin/VBox/StartButton, _start_game)
	InputManager.bind_instant_tap($MenuLayer/Root/Panel/Margin/VBox/QuitButton, func(): get_tree().quit())
	# 美化版暂停面板信号连接
	$PauseLayer/PausePanel.resume_pressed.connect(_resume_game)
	$PauseLayer/PausePanel.restart_pressed.connect(_restart_game)
	$PauseLayer/PausePanel.menu_pressed.connect(_back_to_menu)
	# 美化版结果面板信号连接
	$ResultLayer/ResultPanel.restart_pressed.connect(_restart_game)
	$ResultLayer/ResultPanel.menu_pressed.connect(_back_to_menu)

func _init_settings_ui() -> void:
	var q: OptionButton = $MenuLayer/Root/Panel/Margin/VBox/SettingsScroll/SettingsContainer/QualityRow/Quality as OptionButton
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
	var sfx_slider: HSlider = $MenuLayer/Root/Panel/Margin/VBox/SettingsScroll/SettingsContainer/SfxRow/SfxSlider as HSlider
	var music_slider: HSlider = $MenuLayer/Root/Panel/Margin/VBox/SettingsScroll/SettingsContainer/MusicRow/MusicSlider as HSlider
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
	var sc := $MenuLayer/Root/Panel/Margin/VBox/SettingsScroll/SettingsContainer as VBoxContainer
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
			var stars := MetaProgress.get_map_stars(i)
			map_opt.add_item("%s · %s" % [t, GameDB.map_mastery_stars_text(stars)], i)
		_map_select_opt = map_opt
		_refresh_map_unlock_ui()
		map_opt.item_selected.connect(func(_idx: int) -> void:
			Settings.set_selected_map_index(map_opt.get_selected_id())
		)
		map_row.add_child(map_opt)
		sc.add_child(map_row)
		sc.move_child(map_row, 0)
		var mode_row := HBoxContainer.new()
		mode_row.name = "RunModeRow"
		var mode_label := Label.new()
		mode_label.text = "单局模式"
		mode_label.custom_minimum_size = Vector2(120, 0)
		mode_label.theme_type_variation = &"Label.Body"
		mode_row.add_child(mode_label)
		var mode_opt := OptionButton.new()
		mode_opt.name = "RunModeSelect"
		mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_opt.theme_type_variation = &"Input.Select"
		var mode_ids: Array[String] = []
		for mode_id in GameDB.RUN_MODES.keys():
			var mid := String(mode_id)
			if GameDB.is_demo_build() and mid != "trial":
				continue
			var mode_cfg: Dictionary = GameDB.RUN_MODES[mode_id]
			mode_ids.append(mid)
			mode_opt.add_item(String(mode_cfg.get("label", mid)))
		if GameDB.is_demo_build():
			Settings.set_selected_run_mode("trial")
		var mode_sel := 0
		for mi in mode_ids.size():
			if mode_ids[mi] == Settings.selected_run_mode:
				mode_sel = mi
				break
		mode_opt.select(mode_sel)
		mode_opt.disabled = GameDB.is_demo_build()
		mode_opt.item_selected.connect(func(idx: int) -> void:
			if GameDB.is_demo_build():
				Settings.set_selected_run_mode("trial")
				return
			if idx >= 0 and idx < mode_ids.size():
				Settings.set_selected_run_mode(mode_ids[idx])
		)
		mode_row.add_child(mode_opt)
		sc.add_child(mode_row)
		sc.move_child(mode_row, 0)
		var diff_row := HBoxContainer.new()
		diff_row.name = "DifficultyRow"
		var diff_label := Label.new()
		diff_label.text = "难度"
		diff_label.custom_minimum_size = Vector2(120, 0)
		diff_label.theme_type_variation = &"Label.Body"
		diff_row.add_child(diff_label)
		var diff_opt := OptionButton.new()
		diff_opt.name = "DifficultySelect"
		diff_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		diff_opt.theme_type_variation = &"Input.Select"
		var diff_ids: Array[String] = []
		for did in GameDB.DIFFICULTY_TIERS.keys():
			var dcfg: Dictionary = GameDB.DIFFICULTY_TIERS[did]
			diff_ids.append(String(did))
			diff_opt.add_item(String(dcfg.get("label", did)))
		var diff_sel := 0
		for di in diff_ids.size():
			if diff_ids[di] == Settings.selected_difficulty:
				diff_sel = di
				break
		diff_opt.select(diff_sel)
		diff_opt.item_selected.connect(func(idx: int) -> void:
			if idx >= 0 and idx < diff_ids.size():
				Settings.set_selected_difficulty(diff_ids[idx])
		)
		diff_row.add_child(diff_opt)
		sc.add_child(diff_row)
		sc.move_child(diff_row, 0)
		var chal_row := HBoxContainer.new()
		chal_row.name = "ChallengeRow"
		var chal_label := Label.new()
		chal_label.text = "挑战契约"
		chal_label.custom_minimum_size = Vector2(120, 0)
		chal_label.theme_type_variation = &"Label.Body"
		chal_row.add_child(chal_label)
		var chal_opt := OptionButton.new()
		chal_opt.name = "ChallengeSelect"
		chal_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chal_opt.theme_type_variation = &"Input.Select"
		var chal_ids: Array[String] = []
		for cid in GameDB.CHALLENGE_CONTRACTS.keys():
			var ccfg: Dictionary = GameDB.CHALLENGE_CONTRACTS[cid]
			chal_ids.append(String(cid))
			var scrap_m := float(ccfg.get("scrap_mul", 1.0))
			var label := String(ccfg.get("label", cid))
			if scrap_m > 1.01:
				label += " (×%.2f 碎片)" % scrap_m
			chal_opt.add_item(label)
		var chal_sel := 0
		for ci in chal_ids.size():
			if chal_ids[ci] == Settings.selected_challenge:
				chal_sel = ci
				break
		chal_opt.select(chal_sel)
		chal_opt.item_selected.connect(func(idx: int) -> void:
			if idx >= 0 and idx < chal_ids.size():
				Settings.set_selected_challenge(chal_ids[idx])
		)
		chal_row.add_child(chal_opt)
		sc.add_child(chal_row)
		sc.move_child(chal_row, 0)
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
	var run_ctx: Dictionary = {}
	if _game != null and _game.has_method("build_run_end_context"):
		run_ctx = _game.build_run_end_context()
	var meta_end: Dictionary = MetaProgress.record_run_ended(
		win,
		RunStats.runtime_sec,
		cleared_map,
		run_ctx
	)
	run_ctx["map_stars"] = MetaProgress.get_map_stars(cleared_map)
	var ach_fresh: Array[String] = AchievementService.evaluate_run_end(win, run_ctx)
	var unlock_line := String(meta_end.get("unlock_line", ""))
	var mastery_lines_raw: Array = meta_end.get("mastery_lines", [])
	var mastery_line := ""
	if not mastery_lines_raw.is_empty():
		var ml_parts: Array[String] = []
		for ln in mastery_lines_raw:
			ml_parts.append(String(ln))
		mastery_line = " · ".join(ml_parts)
	var scrap_mul := float(meta_end.get("scrap_mul", 1.0))
	if scrap_mul > 1.01:
		unlock_line = (("难度/契约碎片 ×%.2f。" % scrap_mul) + (" " + unlock_line if not unlock_line.is_empty() else "")).strip_edges()
	if not ach_fresh.is_empty():
		var ach_names: Array[String] = []
		for aid in ach_fresh:
			var adef: Dictionary = GameDB.STEAM_ACHIEVEMENTS.get(aid, {})
			ach_names.append(String(adef.get("name", aid)))
		var ach_bit := "成就：" + (" / ").join(ach_names)
		unlock_line = (ach_bit + (" · " + unlock_line if not unlock_line.is_empty() else "")).strip_edges()
	var recent_suggest_line: String = RunStats.recent_primary_suggestion()
	var action_plan: Array[String] = RunStats.recent_action_plan_personalized()
	var plan_line: String = "下一步计划: " + ((" / ").join(action_plan) if not action_plan.is_empty() else "-")
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
		"mastery_line": mastery_line,
		"scrap_delta": int(meta_end.get("scrap_delta", 0)),
		"scrap_total": int(meta_end.get("scrap_total", 0)),
		"scrap_mul": scrap_mul,
		"relic_line": relic_line,
		"suggest_line": recent_suggest_line,
		"plan_line": plan_line,
		"next_run_hint": RunStats.menu_next_run_hint(),
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
	InputManager.set_menu_mode(v)
	if v:
		_refresh_map_unlock_ui()
		_refresh_meta_stats()
		call_deferred("_relayout_menu_panel")


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
	var subtitle := panel.get_node_or_null("Margin/VBox/Subtitle") as Label
	if subtitle:
		subtitle.text = GameDB.THEME_TAGLINE
	var ver := panel.get_node_or_null("Margin/VBox/VersionLabel") as Label
	if ver:
		ver.text = GameDB.version_line()
	var how := panel.get_node_or_null("Margin/VBox/ExtraButtons/HowToButton") as Button
	if how:
		InputManager.bind_instant_tap(how, _open_howto_dialog)
	var meta := panel.get_node_or_null("Margin/VBox/ExtraButtons/MetaUpgradeButton") as Button
	if meta:
		InputManager.bind_instant_tap(meta, _open_meta_upgrade_panel)
	var wb := panel.get_node_or_null("Margin/VBox/ExtraButtons/WhiteboxButton") as Button
	if wb:
		InputManager.bind_instant_tap(wb, _open_skills_whitebox)


func _relayout_menu_panel() -> void:
	var panel := menu_layer.get_node_or_null("Root/Panel") as Control
	if panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var pw := clampf(minf(vp.x - 24.0, 520.0), 320.0, 520.0)
	var ph := clampf(minf(vp.y - 28.0, 640.0), 460.0, 640.0)
	panel.offset_left = -pw * 0.5
	panel.offset_right = pw * 0.5
	panel.offset_top = -ph * 0.5
	panel.offset_bottom = ph * 0.5
	if InputManager.is_touch_ui():
		var touch_min_h := 52.0
		for node_name in ["StartButton", "QuitButton"]:
			var btn := panel.get_node_or_null("Margin/VBox/" + node_name) as Button
			if btn:
				btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, touch_min_h)
		var extra := panel.get_node_or_null("Margin/VBox/ExtraButtons") as HBoxContainer
		if extra:
			for child in extra.get_children():
				if child is Button:
					(child as Button).custom_minimum_size.y = maxf((child as Button).custom_minimum_size.y, 46.0)
	var ml := panel.get_node_or_null("Margin/VBox/MetaStatsLabel") as Label
	if ml:
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var avail_w := maxf(280.0, pw - 28.0)
		var fs := ml.get_theme_font_size("font_size")
		if fs <= 0:
			fs = 14
		var font := ml.get_theme_font("font")
		var text_h := 52.0
		if font:
			text_h = font.get_multiline_string_size(
				ml.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				avail_w,
				fs
			).y + 8.0
		ml.custom_minimum_size = Vector2(0.0, clampf(text_h, 48.0, 128.0))


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
	var mastery_title := Label.new()
	mastery_title.text = "—— 地图精通（称号进度，无永久数值膨胀）——"
	mastery_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta_upgrade_rows.add_child(mastery_title)
	var star_sum := MetaProgress.total_map_mastery_stars()
	var star_cap := GameDB.MAP_TEMPLATES.size() * 3
	var mastery_prog := Label.new()
	mastery_prog.text = "完成度：%d / %d★" % [star_sum, star_cap]
	mastery_prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mastery_prog.add_theme_font_size_override("font_size", 12)
	mastery_prog.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95, 1.0))
	_meta_upgrade_rows.add_child(mastery_prog)
	for mi in GameDB.MAP_TEMPLATES.size():
		var mtpl: Dictionary = GameDB.MAP_TEMPLATES[mi]
		var mrow := Label.new()
		mrow.text = "%s  %s" % [
			String(mtpl.get("title", mtpl.get("id", "地图"))),
			GameDB.map_mastery_stars_text(MetaProgress.get_map_stars(mi))
		]
		mrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_meta_upgrade_rows.add_child(mrow)
	_append_meta_codex_section(
		"融合图鉴（局内激活过即勾选）",
		_meta_fusion_codex_rows()
	)
	_append_meta_codex_section(
		"五流派专精图鉴（点过一级即勾选）",
		_meta_school_codex_rows()
	)
	var sep_intel := HSeparator.new()
	_meta_upgrade_rows.add_child(sep_intel)
	var intel := Label.new()
	intel.text = "局内情报：升级时可花碎片重抽(%d) / 排除(%d)，每局各一次。" % [
		GameDB.RUN_SCRAP_REROLL_COST, GameDB.RUN_SCRAP_BAN_COST
	]
	intel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta_upgrade_rows.add_child(intel)
	var sep2 := HSeparator.new()
	_meta_upgrade_rows.add_child(sep2)
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


func _append_meta_codex_section(title_text: String, rows: Array) -> void:
	if _meta_upgrade_rows == null:
		return
	var sep := HSeparator.new()
	_meta_upgrade_rows.add_child(sep)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	_meta_upgrade_rows.add_child(title)
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		var nm := Label.new()
		nm.text = String(row.get("name", ""))
		nm.theme_type_variation = &"Label.Body"
		card.add_child(nm)
		var st := Label.new()
		var seen := bool(row.get("seen", false))
		st.text = "已见过" if seen else "未解锁（再开一局尝试）"
		st.add_theme_font_size_override("font_size", 11)
		st.add_theme_color_override(
			"font_color",
			Color(0.52, 0.88, 0.62, 1.0) if seen else Color(0.88, 0.72, 0.55, 1.0)
		)
		card.add_child(st)
		_meta_upgrade_rows.add_child(card)


func _meta_fusion_codex_rows() -> Array:
	var out: Array = []
	var keys: Array[String] = []
	for fid in GameDB.FUSIONS.keys():
		keys.append(String(fid))
	keys.sort()
	for fid in keys:
		var fdef: Dictionary = GameDB.FUSIONS[fid]
		var wid := String(fdef.get("weapon", ""))
		var wname := wid
		if GameDB.WEAPONS.has(wid):
			wname = String(GameDB.WEAPONS[wid].get("name", wid))
		out.append({
			"name": "%s · %s" % [wname, String(fdef.get("desc", fid))],
			"seen": bool(MetaProgress.fusions_seen.get(fid, false)),
		})
	return out


func _meta_school_codex_rows() -> Array:
	var out: Array = []
	for pid in GameDB.SCHOOL_MASTERY_IDS:
		var pdef: Dictionary = GameDB.PASSIVES.get(pid, {}) as Dictionary
		out.append({
			"name": String(pdef.get("name", pid)),
			"seen": bool(MetaProgress.school_mastery_seen.get(pid, false)),
		})
	return out


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
		if i < GameDB.MAP_TEMPLATES.size():
			var tpl: Dictionary = GameDB.MAP_TEMPLATES[i]
			var t := String(tpl.get("title", tpl.get("id", "地图 %d" % i)))
			_map_select_opt.set_item_text(i, "%s · %s" % [t, GameDB.map_mastery_stars_text(MetaProgress.get_map_stars(i))])
	var sel := clampi(Settings.selected_map_index, 0, upto)
	_map_select_opt.select(sel)


func _refresh_meta_stats() -> void:
	var panel := menu_layer.get_node_or_null("Root/Panel") as Panel
	if panel == null:
		return
	var ml := panel.get_node_or_null("Margin/VBox/MetaStatsLabel") as Label
	if ml:
		var demo_line := "Demo：锁定试炼模式" if GameDB.is_demo_build() else GameDB.version_line()
		var goal := MetaProgress.next_goal_line()
		var hint := RunStats.menu_next_run_hint()
		# 永久强化满级后优先展示收藏/挑战目标，不再只剩战术 hint
		if MetaProgress.is_meta_upgrades_maxed():
			hint = goal
		else:
			hint = goal + "\n" + hint
		ml.text = MetaProgress.summary_line() + "\n" + AchievementService.summary_line() + "\n" + hint + "\n" + demo_line
		call_deferred("_relayout_menu_panel")


func _open_howto_dialog() -> void:
	if _howto_dialog != null and is_instance_valid(_howto_dialog):
		_howto_dialog.queue_free()
		_howto_dialog = null
	var dlg := AcceptDialog.new()
	dlg.title = GameDB.HOWTO_TITLE
	var body := ""
	if GameDB.is_demo_build():
		body += "【Demo】本包锁定「试炼 · 5 分钟」。完整版开放标准 10 分钟 / 持久 18 分钟与挑战契约。\n\n"
	for i in range(GameDB.HOWTO_STEPS.size()):
		body += "%d) %s\n" % [i + 1, String(GameDB.HOWTO_STEPS[i])]
	body += "\n—— 商店一句话 ——\n" + GameDB.STORE_PAGE_BLURB
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
