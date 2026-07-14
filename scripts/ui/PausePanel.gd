extends Control
class_name PausePanel

# 暂停面板控制器 - 管理游戏暂停界面

signal resume_pressed
signal restart_pressed
signal menu_pressed

@onready var resume_btn: Button = $MainPanel/ButtonList/ResumeButton
@onready var restart_btn: Button = $MainPanel/ButtonList/RestartButton
@onready var menu_btn: Button = $MainPanel/ButtonList/MenuButton
@onready var button_list: VBoxContainer = $MainPanel/ButtonList
@onready var dim_bg: Panel = $DimBg
@onready var main_panel: Panel = $MainPanel

var _is_visible := false
var _vfx_btn: Button = null
var _perf_guard_btn: Button = null
var _early_flow_btn: Button = null

func _ready() -> void:
	InputManager.bind_instant_tap(resume_btn, func(): resume_pressed.emit())
	InputManager.bind_instant_tap(restart_btn, func(): restart_pressed.emit())
	InputManager.bind_instant_tap(menu_btn, func(): menu_pressed.emit())
	_setup_vfx_button()
	visible = false

func _setup_vfx_button() -> void:
	if button_list == null:
		return
	_vfx_btn = Button.new()
	_vfx_btn.name = "VfxProfileButton"
	_vfx_btn.custom_minimum_size = Vector2(0, 46)
	_vfx_btn.theme_type_variation = &"ButtonSecondary"
	_vfx_btn.pressed.connect(_cycle_vfx_profile)
	button_list.add_child(_vfx_btn)
	_update_vfx_button_text()
	_perf_guard_btn = Button.new()
	_perf_guard_btn.name = "ExtremePerfGuardButton"
	_perf_guard_btn.custom_minimum_size = Vector2(0, 46)
	_perf_guard_btn.theme_type_variation = &"ButtonSecondary"
	_perf_guard_btn.pressed.connect(_toggle_extreme_perf_guard)
	button_list.add_child(_perf_guard_btn)
	_update_perf_guard_button_text()
	_early_flow_btn = Button.new()
	_early_flow_btn.name = "EarlyFlowPresetButton"
	_early_flow_btn.custom_minimum_size = Vector2(0, 46)
	_early_flow_btn.theme_type_variation = &"ButtonSecondary"
	_early_flow_btn.pressed.connect(_cycle_early_flow_preset)
	button_list.add_child(_early_flow_btn)
	_update_early_flow_button_text()

func _cycle_vfx_profile() -> void:
	var next_profile := int(Settings.vfx_profile) + 1
	if next_profile > Settings.VfxProfile.CINEMATIC:
		next_profile = Settings.VfxProfile.COMPETITIVE
	Settings.set_vfx_profile(next_profile)
	_update_vfx_button_text()

func _update_vfx_button_text() -> void:
	if _vfx_btn == null:
		return
	var label := "平衡默认"
	match int(Settings.vfx_profile):
		Settings.VfxProfile.COMPETITIVE:
			label = "竞技清晰"
		Settings.VfxProfile.CINEMATIC:
			label = "电影爽感"
		_:
			label = "平衡默认"
	_vfx_btn.text = "特效风格：%s" % label

func _toggle_extreme_perf_guard() -> void:
	Settings.set_extreme_perf_guard(not Settings.extreme_perf_guard)
	_update_perf_guard_button_text()

func _update_perf_guard_button_text() -> void:
	if _perf_guard_btn == null:
		return
	_perf_guard_btn.text = "高压性能保护：%s" % ("开" if Settings.extreme_perf_guard else "关")


func _cycle_early_flow_preset() -> void:
	var next_preset := int(Settings.early_flow_preset) + 1
	if next_preset > Settings.EarlyFlowPreset.HARDCORE:
		next_preset = Settings.EarlyFlowPreset.SOFT
	Settings.set_early_flow_preset(next_preset)
	_update_early_flow_button_text()


func _update_early_flow_button_text() -> void:
	if _early_flow_btn == null:
		return
	var label := "平衡"
	match int(Settings.early_flow_preset):
		Settings.EarlyFlowPreset.SOFT:
			label = "柔和"
		Settings.EarlyFlowPreset.HARDCORE:
			label = "激进"
		_:
			label = "平衡"
	_early_flow_btn.text = "首局吸引力：%s" % label

func show_pause() -> void:
	if _is_visible:
		return
	_is_visible = true
	visible = true
	_update_vfx_button_text()
	_update_perf_guard_button_text()
	_update_early_flow_button_text()
	
	# 面板缩放动画
	var tween := create_tween().set_trans(UIMotion.TRANS_ENTRANCE).set_ease(UIMotion.EASE_OUT)
	main_panel.scale = Vector2(0.9, 0.9)
	tween.tween_property(main_panel, "scale", Vector2.ONE, UIMotion.MOTION_PANEL)
	
	# 背景脉冲
	var bg_decor1 := $BgDecor1 as Panel
	var bg_decor2 := $BgDecor2 as Panel
	if bg_decor1:
		bg_decor1.visible = true
	if bg_decor2:
		bg_decor2.visible = true

func hide_pause() -> void:
	if not _is_visible:
		return
	_is_visible = false
	
	# 淡出动画
	var tween := create_tween().set_trans(UIMotion.TRANS_GENERAL).set_ease(UIMotion.EASE_IN_OUT)
	tween.tween_property(main_panel, "scale", Vector2(0.95, 0.95), UIMotion.MOTION_UI_TRANSITION)
	
	await tween.finished
	visible = false

func toggle_pause() -> void:
	if _is_visible:
		hide_pause()
	else:
		show_pause()

func _input(event: InputEvent) -> void:
	if not _is_visible:
		return
	# ESC 或 P 键继续
	if event.is_action_pressed("pause"):
		resume_pressed.emit()
