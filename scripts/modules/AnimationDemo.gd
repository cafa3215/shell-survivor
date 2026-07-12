extends "res://scripts/modules/ModuleDemoBase.gd"

@onready var _title := $CanvasLayer/Panel/VBox/Title as Label
@onready var _desc := $CanvasLayer/Panel/VBox/Desc as Label
@onready var _status := $CanvasLayer/Panel/VBox/Status as Label
@onready var _player := $Player as Node2D

var _rig: PlayerBodyRig
var _anim_t := 0.0
var _last_seg := -1
var _punched_in_cycle := false

func _ready() -> void:
	demo_name = "动作模块"
	super._ready()
	_title.text = "动作模块：时间轴与事件点"
	_desc.text = "用于验证：在固定时间轴上组合姿态，并在事件点触发冲刺缩放等动作反馈。"
	_status.text = "状态：正在查找躯体骨架…"
	call_deferred("_bind_rig")

func _bind_rig() -> void:
	if _player == null:
		_status.text = "状态：玩家节点缺失"
		return
	var vr := _player.get_node_or_null("VisualRoot")
	_rig = vr as PlayerBodyRig
	if _rig == null:
		_status.text = "状态：躯体骨架脚本未挂载"
		return
	_status.text = "状态：已绑定，按时间轴循环演示"

func module_self_test() -> bool:
	if _player == null:
		return false
	var sk := _player.get_node_or_null("VisualRoot/Skeleton2D") as Skeleton2D
	if sk == null:
		return false
	for p in ["Hip/Spine/Chest/Head", "Hip/Spine/Chest/ArmRU/ArmRL/HandRSocket"]:
		if sk.get_node_or_null(p) == null:
			return false
	var vr := _player.get_node_or_null("VisualRoot") as PlayerBodyRig
	if vr == null:
		return false
	if not vr.has_method("apply_visual_state"):
		return false
	if not vr.has_method("play_dash_scale_punch"):
		return false
	return true

func _process(delta: float) -> void:
	super._process(delta)
	if _rig == null or not is_instance_valid(_rig):
		return
	_anim_t += delta
	# 约 12 秒一圈：与骨骼演示接近，但强调“时间分段 + 事件点”
	var cyc: float = 12.0
	var u := fposmod(_anim_t, cyc)
	var seg: int
	if u < 2.0:
		seg = 0
	elif u < 4.5:
		seg = 1
	elif u < 7.0:
		seg = 2
	elif u < 8.0:
		seg = 3
	else:
		seg = 4

	if seg != _last_seg:
		_last_seg = seg
		# 每圈一次的冲刺缩放：在段落切换瞬间触发，模拟“关键帧事件”
		if seg == 3 and not _punched_in_cycle:
			_punched_in_cycle = true
			_rig.play_dash_scale_punch()
			_status.text = "状态：事件点：冲刺体缩放"
		if seg == 0:
			# 新一圈开始
			_punched_in_cycle = false

	match seg:
		0:
			_rig.set_form(PlayerBodyRig.RigForm.BASE)
			_rig.apply_visual_state(delta, Vector2.ZERO, false, false, false, Vector2.ZERO, 1.0)
			_status.text = "状态：段落一：待机"
		1:
			_rig.set_form(PlayerBodyRig.RigForm.BASE)
			_rig.apply_visual_state(delta, Vector2(240, 30), false, false, false, Vector2.ZERO, 1.0)
			_status.text = "状态：段落二：跑动"
		2:
			_rig.set_form(PlayerBodyRig.RigForm.AWAKENED)
			var aim := Vector2(1.0, -0.1)
			_rig.apply_visual_state(delta, Vector2(40, 0), false, false, true, aim, 1.0)
			_status.text = "状态：段落三：觉醒瞄准"
		3:
			# 与事件点同段：以小幅移动维持姿态过渡
			_rig.set_form(PlayerBodyRig.RigForm.BASE)
			_rig.apply_visual_state(delta, Vector2(20, 0), false, false, false, Vector2.ZERO, 1.0)
		4:
			_rig.set_form(PlayerBodyRig.RigForm.BASE)
			_rig.apply_visual_state(delta, Vector2(-120, 10), false, true, false, Vector2.ZERO, -1.0)
			_status.text = "状态：段落四：受击后撤"
