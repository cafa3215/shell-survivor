extends "res://scripts/modules/ModuleDemoBase.gd"

@onready var _title := $CanvasLayer/Panel/VBox/Title as Label
@onready var _desc := $CanvasLayer/Panel/VBox/Desc as Label
@onready var _status := $CanvasLayer/Panel/VBox/Status as Label
@onready var _player := $Player as Node2D

var _rig: PlayerBodyRig
var _phase := 0.0

func _ready() -> void:
	demo_name = "骨骼模块"
	super._ready()
	_title.text = "骨骼模块：躯体骨架与挂点"
	_desc.text = "用于验证：骨骼层级、右手挂点、形态切换与姿态驱动接口在无战局环境下可安全调用。"
	_status.text = "状态：正在查找躯体骨架…"
	call_deferred("_bind_rig")

func _bind_rig() -> void:
	if _player == null:
		_status.text = "状态：玩家节点缺失"
		return
	var vr := _player.get_node_or_null("VisualRoot")
	if vr == null:
		_status.text = "状态：未找到视觉根节点"
		return
	_rig = vr as PlayerBodyRig
	if _rig == null:
		_status.text = "状态：躯体骨架脚本未挂载"
		return
	_status.text = "状态：已绑定，正在循环演示姿态…"

func module_self_test() -> bool:
	if _player == null:
		return false
	var sk := _player.get_node_or_null("VisualRoot/Skeleton2D") as Skeleton2D
	if sk == null:
		return false
	# 关键骨节点：与 PlayerBodyRig._build_rig 命名一致
	for p in ["Hip/Spine/Chest/Head", "Hip/Spine/Chest/ArmRU/ArmRL/HandRSocket"]:
		if sk.get_node_or_null(p) == null:
			return false
	var vr := _player.get_node_or_null("VisualRoot") as PlayerBodyRig
	if vr == null:
		return false
	if not vr.has_method("apply_visual_state") or not vr.has_method("get_weapon_mount_parent"):
		return false
	var sock := vr.get_weapon_mount_parent()
	if sock == null or not is_instance_valid(sock):
		return false
	return true

func _process(delta: float) -> void:
	super._process(delta)
	if _rig == null or not is_instance_valid(_rig):
		return
	_phase += delta
	# 分段时间轴：待机 → 跑动 → 瞄准抬臂 → 受击 → 觉醒形态
	var t := fposmod(_phase, 10.0)
	if t < 2.5:
		_rig.set_form(PlayerBodyRig.RigForm.BASE)
		_rig.apply_visual_state(delta, Vector2.ZERO, false, 0.0, 0.0, Vector2.ZERO, 1.0)
		_status.text = "状态：待机呼吸与微动"
	elif t < 5.0:
		_rig.set_form(PlayerBodyRig.RigForm.BASE)
		_rig.apply_visual_state(delta, Vector2(220, 40), false, 0.0, 0.0, Vector2.ZERO, 1.0)
		_status.text = "状态：跑动摆臂与重心倾斜"
	elif t < 7.0:
		_rig.set_form(PlayerBodyRig.RigForm.BASE)
		var aim := Vector2(1.0, -0.15)
		_rig.apply_visual_state(delta, Vector2.ZERO, false, 0.0, 1.0, aim, 1.0)
		_status.text = "状态：瞄准抬臂（右手前伸）"
	elif t < 8.5:
		_rig.set_form(PlayerBodyRig.RigForm.BASE)
		_rig.apply_visual_state(delta, Vector2(40, 0), false, 1.0, 0.0, Vector2.ZERO, 1.0)
		_status.text = "状态：受击后仰"
	else:
		_rig.set_form(PlayerBodyRig.RigForm.AWAKENED)
		_rig.apply_visual_state(delta, Vector2(160, -20), false, 0.0, 0.0, Vector2.ZERO, -1.0)
		_status.text = "状态：觉醒形态 + 反向跑动镜像"
