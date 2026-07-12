extends "res://scripts/modules/ModuleDemoBase.gd"

@onready var _pm := $ParticleManager as ParticleManager
@onready var _cpu := $CPUParticles as CPUParticles2D
@onready var _status := $CanvasLayer/Center/Panel/VBox/Status as Label
@onready var _amount := $CanvasLayer/Center/Panel/VBox/RowAmount/Amount as HSlider
@onready var _reduce := $CanvasLayer/Center/Panel/VBox/RowToggles/Reduce as CheckBox
@onready var _profile := $CanvasLayer/Center/Panel/VBox/RowProfile/Profile as OptionButton

func _ready() -> void:
	demo_name = "特效模块"
	super._ready()
	_amount.value_changed.connect(_on_amount_changed)
	_reduce.toggled.connect(_on_reduce_toggled)
	_profile.item_selected.connect(_on_profile_selected)

	_profile.clear()
	_profile.add_item("竞技（清晰）", int(Settings.VfxProfile.COMPETITIVE))
	_profile.add_item("平衡（默认）", int(Settings.VfxProfile.BALANCED))
	_profile.add_item("电影（爽感）", int(Settings.VfxProfile.CINEMATIC))

	_amount.value = float(_cpu.amount)
	_reduce.button_pressed = Settings.reduce_particles
	_profile.select(_idx_for_profile(int(Settings.vfx_profile)))
	_update_status("已就绪：可调粒子数量、减粒子开关与特效风格档位。")

func module_self_test() -> bool:
	# 无头门禁用：确保 Settings/ParticleManager 可用且调用不报错。
	if get_node_or_null("/root/Settings") == null:
		return false
	if _pm == null:
		return false
	Settings.set_reduce_particles(true)
	_pm.explosion(Vector2.ZERO)
	Settings.set_reduce_particles(false)
	_pm.hit_effect(Vector2.ZERO)
	return true

func _idx_for_profile(profile: int) -> int:
	for i in _profile.item_count:
		if _profile.get_item_id(i) == profile:
			return i
	return 1

func _on_amount_changed(v: float) -> void:
	_cpu.amount = int(v)
	_update_status("粒子数量：%d" % int(v))

func _on_reduce_toggled(on: bool) -> void:
	Settings.set_reduce_particles(on)
	_update_status("减粒子：%s" % ("开启" if on else "关闭"))

func _on_profile_selected(idx: int) -> void:
	var id := _profile.get_item_id(idx)
	Settings.set_vfx_profile(int(id))
	_update_status("特效风格：已切换")

func _update_status(t: String) -> void:
	_status.text = "状态：" + t

func _process(delta: float) -> void:
	super._process(delta)
	# 循环播放一组代表性粒子，方便肉眼检查减粒子开关是否生效。
	var origin := _pm.global_position
	if Engine.get_frames_drawn() % 45 == 0:
		_pm.explosion(origin + Vector2(0, 40))
	if Engine.get_frames_drawn() % 35 == 0:
		_pm.lightning_spark(origin + Vector2(90, 0))
	if Engine.get_frames_drawn() % 55 == 0:
		_pm.shockwave_ring(origin + Vector2(-90, 0))

