extends Node2D
class_name PlayerBodyRig

## 俯视角色躯体骨架：Bone2D 层级 + 分块 Polygon2D 皮肤（可日后换图）。
## 由 Player 每帧传入速度/姿态，驱动朝向、待机动画、跑步摆动与倾斜。

const _FACING_EPS := 0.12

var _skeleton: Skeleton2D
var _visual_scale: float = 1.0

# 骨骼（局部旋转由动画驱动）
var _hip: Bone2D
var _spine: Bone2D
var _chest: Bone2D
var _head: Bone2D
var _arm_l_u: Bone2D
var _arm_l_l: Bone2D
var _arm_r_u: Bone2D
var _arm_r_l: Bone2D
var _leg_l_u: Bone2D
var _leg_l_l: Bone2D
var _leg_r_u: Bone2D
var _leg_r_l: Bone2D

## 右手末端：武器应挂在此节点下（世界坐标随摆臂动）
var hand_r_socket: Node2D

var _run_phase: float = 0.0
var _idle_t: float = 0.0
var _bob_smoothed: float = 0.0
var _last_flip_sign: float = 1.0
var _facing_mul: float = 1.0

# 发光层（能量条/扫描线等）的“呼吸闪烁”
var _glow_polys: Array[Polygon2D] = []
var _glow_pulse_strength: float = 1.0
var _all_polys: Array[Polygon2D] = []
var _photo_parts: Array[Sprite2D] = []
var _photo_part_map: Dictionary = {}
var _photo_mode: bool = false
var _ground_shadow: Polygon2D
var _sway_shoulder_l: float = 0.0
var _sway_shoulder_r: float = 0.0
var _sway_tabard: float = 0.0

enum RigForm { BASE, AWAKENED }
var _form: RigForm = RigForm.BASE
var _base_only: Array[Polygon2D] = []
var _awakened_only: Array[Polygon2D] = []

# 与 Player 常量对齐
const _RUN_ANIM_FPS: float = 11.0
const _RUN_ANIM_MIN_SPEED: float = 20.0
const _LEAN_MAX_RAD: float = 0.12
const _LEAN_FOLLOW: float = 0.18
enum MotionDetailPreset { LIGHT, MEDIUM, STRONG }
@export var motion_detail_preset: MotionDetailPreset = MotionDetailPreset.MEDIUM
@export_range(0.6, 1.8, 0.05) var motion_detail_strength: float = 1.0


func _ready() -> void:
	_build_rig()
	call_deferred("set_form", RigForm.BASE)


func set_form(form: RigForm) -> void:
	_form = form
	if _photo_mode:
		return
	var awakened := form == RigForm.AWAKENED
	_glow_pulse_strength = 1.25 if awakened else 0.75
	for p: Polygon2D in _base_only:
		if is_instance_valid(p):
			p.visible = not awakened
	for p: Polygon2D in _awakened_only:
		if is_instance_valid(p):
			p.visible = awakened


func get_weapon_mount_parent() -> Node2D:
	return hand_r_socket


func _build_rig() -> void:
	_ground_shadow = Polygon2D.new()
	_ground_shadow.name = "GroundShadow"
	_ground_shadow.polygon = PackedVector2Array([
		Vector2(-16, 18), Vector2(-10, 24), Vector2(0, 27), Vector2(10, 24), Vector2(16, 18),
		Vector2(10, 13), Vector2(0, 11), Vector2(-10, 13)
	])
	_ground_shadow.color = Color(0.0, 0.0, 0.0, 0.26)
	_ground_shadow.z_index = -4
	add_child(_ground_shadow)

	_skeleton = Skeleton2D.new()
	_skeleton.name = "Skeleton2D"
	add_child(_skeleton)
	# 进一步提升占屏与清晰度：在战斗密集场景中保持主体可辨识。
	_visual_scale = 1.78

	# 先在离树状态搭好完整骨骼链，再一次性挂到 Skeleton2D，避免逐段 add_child 触发无效 rest 逆变换。
	_hip = Bone2D.new()
	_hip.name = "Hip"

	_spine = _add_bone(_hip, "Spine", Vector2(0, -10))
	_chest = _add_bone(_spine, "Chest", Vector2(0, -10))
	# 比例修正：抬高头部挂点并缩小头盔，避免“头大身短”。
	_head = _add_bone(_chest, "Head", Vector2(0, -13))

	# 比例修正：手臂加长，解决“手短”问题。
	_arm_l_u = _add_bone(_chest, "ArmLU", Vector2(-12, -4))
	_arm_l_l = _add_bone(_arm_l_u, "ArmLL", Vector2(-11, 2))
	_arm_r_u = _add_bone(_chest, "ArmRU", Vector2(12, -4))
	_arm_r_l = _add_bone(_arm_r_u, "ArmRL", Vector2(11, 2))

	hand_r_socket = Node2D.new()
	hand_r_socket.name = "HandRSocket"
	_arm_r_l.add_child(hand_r_socket)
	hand_r_socket.position = Vector2(10, 1)

	_leg_l_u = _add_bone(_hip, "LegLU", Vector2(-6, 7))
	_leg_l_l = _add_bone(_leg_l_u, "LegLL", Vector2(0, 9))
	_leg_r_u = _add_bone(_hip, "LegRU", Vector2(6, 7))
	_leg_r_l = _add_bone(_leg_r_u, "LegRL", Vector2(0, 9))

	_skeleton.add_child(_hip)
	_snap_bone_rests(_hip)
	call_deferred("_skin_polygons")
	z_index = 2


func _add_bone(parent: Bone2D, bone_name: String, rel: Vector2) -> Bone2D:
	var b := Bone2D.new()
	b.name = bone_name
	b.position = rel
	parent.add_child(b)
	return b


func _snap_bone_rests(root: Bone2D) -> void:
	for child in root.get_children():
		if child is Bone2D:
			_snap_bone_rests(child as Bone2D)
	root.rest = root.transform


func _skin_polygons() -> void:
	_base_only.clear()
	_awakened_only.clear()
	_glow_polys.clear()
	_all_polys.clear()

	# 黑红武士机甲风（参考图）：深色装甲 + 红色织物/能量点缀 + 红色目镜
	var c_body_dark := Color(0.08, 0.08, 0.1, 1.0)
	var c_body_mid := Color(0.16, 0.16, 0.19, 1.0)
	var c_body_light := Color(0.29, 0.29, 0.33, 1.0)
	var c_steel := Color(0.42, 0.42, 0.48, 1.0)
	var c_energy := Color(1.0, 0.16, 0.22, 0.95) # 红色能量/灯条
	var c_visor := Color(1.0, 0.12, 0.18, 0.95)  # 红色眼罩
	var c_shadow := Color(0.0, 0.0, 0.0, 0.22)
	var c_cloth := Color(0.4, 0.05, 0.08, 1.0)    # 红色布条/围巾
	var c_cloth_dark := Color(0.22, 0.03, 0.05, 1.0)

	# 左右细微色差：同为黑红，但左右在明暗/红色深浅上略有差异，跑动更清晰。
	var c_arm_l := Color(0.24, 0.24, 0.28, 1.0)
	var c_arm_r := Color(0.27, 0.25, 0.3, 1.0)
	var c_leg_l := Color(0.23, 0.23, 0.27, 1.0)
	var c_leg_r := Color(0.26, 0.24, 0.29, 1.0)
	var c_glove_l := Color(0.16, 0.16, 0.19, 1.0)
	var c_glove_r := Color(0.19, 0.18, 0.22, 1.0)
	var c_boot_l := Color(0.13, 0.13, 0.16, 1.0)
	var c_boot_r := Color(0.16, 0.15, 0.19, 1.0)

	# 阴影与下盘推进器风格
	_poly(_hip, "shadow", PackedVector2Array([Vector2(-17, 22), Vector2(17, 22), Vector2(14, 29), Vector2(-14, 29)]), c_shadow)
	_poly(_hip, "hip_frame", PackedVector2Array([Vector2(-14, -3), Vector2(14, -3), Vector2(12, 10), Vector2(0, 13), Vector2(-12, 10)]), c_body_dark)
	_poly(_hip, "waist_ring", PackedVector2Array([Vector2(-12, -2), Vector2(12, -2), Vector2(10, 3), Vector2(-10, 3)]), c_steel)
	var p_reactor := _poly_glow(_hip, "reactor", PackedVector2Array([Vector2(-3, 1), Vector2(3, 1), Vector2(3, 8), Vector2(-3, 8)]), c_energy, 0.9)
	_base_only.append(p_reactor)
	# 红腰带 + 垂布（参考图核心元素）
	_awakened_only.append(_poly(_hip, "obi", PackedVector2Array([Vector2(-12, 1), Vector2(12, 1), Vector2(11, 6), Vector2(-11, 6)]), c_cloth_dark))
	_awakened_only.append(_poly(_hip, "obi_knot", PackedVector2Array([Vector2(-4, 3), Vector2(4, 3), Vector2(3, 8), Vector2(-3, 8)]), c_cloth))
	_awakened_only.append(_poly(_hip, "tabard_front", PackedVector2Array([Vector2(-5, 6), Vector2(5, 6), Vector2(4, 26), Vector2(0, 30), Vector2(-4, 26)]), c_cloth))
	_awakened_only.append(_poly(_hip, "tabard_inner", PackedVector2Array([Vector2(-3, 8), Vector2(3, 8), Vector2(2, 24), Vector2(0, 27), Vector2(-2, 24)]), c_cloth_dark))
	_awakened_only.append(_poly(_hip, "tabard_back", PackedVector2Array([Vector2(-4, 5), Vector2(4, 5), Vector2(3, 18), Vector2(0, 21), Vector2(-3, 18)]), Color(c_cloth.r, c_cloth.g, c_cloth.b, 0.65)))

	# 科幻胸甲：V 型护甲 + 核心光带
	_poly(_chest, "torso_outer", PackedVector2Array([Vector2(-18, -9), Vector2(18, -9), Vector2(16, 13), Vector2(0, 19), Vector2(-16, 13)]), c_body_dark)
	_poly(_chest, "torso_inner", PackedVector2Array([Vector2(-14, -7), Vector2(14, -7), Vector2(13, 10), Vector2(0, 14), Vector2(-13, 10)]), c_body_mid)
	_poly(_chest, "torso_v", PackedVector2Array([Vector2(-10, -4), Vector2(10, -4), Vector2(3, 10), Vector2(-3, 10)]), c_body_light)
	var p_core := _poly_glow(_chest, "core_bar", PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 12), Vector2(-2, 12)]), c_energy, 0.9)
	_base_only.append(p_core)
	_poly(_chest, "rib_l", PackedVector2Array([Vector2(-13, -2), Vector2(-5, -1), Vector2(-5, 8), Vector2(-12, 9)]), c_steel)
	_poly(_chest, "rib_r", PackedVector2Array([Vector2(5, -1), Vector2(13, -2), Vector2(12, 9), Vector2(5, 8)]), c_steel)
	# 装甲碎片化：胸口小板块/螺栓感凹槽
	_poly(_chest, "pect_l_1", PackedVector2Array([Vector2(-13, -6), Vector2(-6, -6), Vector2(-6, -1), Vector2(-12, 0)]), c_body_light)
	_poly(_chest, "pect_r_1", PackedVector2Array([Vector2(6, -6), Vector2(13, -6), Vector2(12, 0), Vector2(6, -1)]), c_body_light)
	_poly(_chest, "pect_l_2", PackedVector2Array([Vector2(-12, 1), Vector2(-6, 1), Vector2(-6, 6), Vector2(-11, 7)]), c_body_mid)
	_poly(_chest, "pect_r_2", PackedVector2Array([Vector2(6, 1), Vector2(12, 1), Vector2(11, 7), Vector2(6, 6)]), c_body_mid)
	_poly_glow(_chest, "groove_l", PackedVector2Array([Vector2(-9, -2), Vector2(-7, -2), Vector2(-7, 6), Vector2(-9, 6)]), c_energy, 0.35)
	_poly_glow(_chest, "groove_r", PackedVector2Array([Vector2(7, -2), Vector2(9, -2), Vector2(9, 6), Vector2(7, 6)]), c_energy, 0.28)
	# 腹部护片（在胸骨上，随上身晃动）
	_poly(_spine, "abd_1", PackedVector2Array([Vector2(-9, 3), Vector2(9, 3), Vector2(7, 10), Vector2(0, 12), Vector2(-7, 10)]), c_body_mid)
	_poly(_spine, "abd_2", PackedVector2Array([Vector2(-7, 4), Vector2(7, 4), Vector2(6, 9), Vector2(0, 11), Vector2(-6, 9)]), c_body_light)
	_poly_glow(_spine, "abd_seam", PackedVector2Array([Vector2(-1.2, 4), Vector2(1.2, 4), Vector2(1.0, 11), Vector2(-1.0, 11)]), c_energy, 0.25)

	# 肩部装甲
	_poly(_arm_l_u, "shoulder_l", PackedVector2Array([Vector2(-9, -6), Vector2(3, -6), Vector2(3, 3), Vector2(-8, 3)]), c_steel)
	_poly(_arm_r_u, "shoulder_r", PackedVector2Array([Vector2(-3, -6), Vector2(9, -6), Vector2(8, 3), Vector2(-3, 3)]), c_steel)
	# B. 可读性符号：常驻红肩章（小尺寸也容易识别轮廓）
	_poly(_arm_l_u, "shoulder_l_mark", PackedVector2Array([Vector2(-7, -4), Vector2(-1, -4), Vector2(-1, -1), Vector2(-7, -1)]), c_energy, 0.8)
	_poly(_arm_r_u, "shoulder_r_mark", PackedVector2Array([Vector2(1, -4), Vector2(7, -4), Vector2(7, -1), Vector2(1, -1)]), c_energy, 0.68)
	# 肩甲尖角（更硬核科幻轮廓）
	_poly(_arm_l_u, "shoulder_l_spike", PackedVector2Array([Vector2(-9, -6), Vector2(-4, -9), Vector2(-1, -6)]), c_body_dark)
	_poly(_arm_r_u, "shoulder_r_spike", PackedVector2Array([Vector2(1, -6), Vector2(4, -9), Vector2(9, -6)]), c_body_dark)

	# 头部：更科幻的头盔 + 观察窗
	_poly(_head, "helm_shell", _circle_poly(0, -2, 12.8, 20), c_body_dark)
	_poly(_head, "helm_plate", _circle_poly(0, -2, 10.4, 20), c_body_mid)
	_poly(_head, "visor", PackedVector2Array([Vector2(-8.5, -5), Vector2(8.5, -5), Vector2(7.5, 3), Vector2(-7.5, 3)]), c_visor)
	var p_scan := _poly_glow(_head, "visor_scan", PackedVector2Array([Vector2(-6.0, -2.5), Vector2(6.0, -2.5), Vector2(5.0, -1.0), Vector2(-5.0, -1.0)]), c_energy, 0.75)
	_base_only.append(p_scan)
	_poly(_head, "visor_glint", PackedVector2Array([Vector2(-7, -4), Vector2(1, -4), Vector2(-1, 0), Vector2(-8, 0)]), Color(0.9, 1.0, 1.0, 0.35))
	# 围巾/领巾（披在胸口上方，俯视也可见）
	_awakened_only.append(_poly(_chest, "scarf", PackedVector2Array([Vector2(-14, -9), Vector2(14, -9), Vector2(9, -2), Vector2(-9, -2)]), c_cloth))
	_awakened_only.append(_poly(_chest, "scarf_fold", PackedVector2Array([Vector2(-10, -8), Vector2(10, -8), Vector2(7, -4), Vector2(-7, -4)]), c_cloth_dark))

	# 背部双刀柄/刀鞘轮廓（俯视用两条斜带表现）
	_awakened_only.append(_poly(_chest, "sheath_1", PackedVector2Array([Vector2(-2, -12), Vector2(2, -12), Vector2(14, -2), Vector2(10, -2)]), c_body_mid))
	_awakened_only.append(_poly(_chest, "sheath_2", PackedVector2Array([Vector2(-2, -12), Vector2(2, -12), Vector2(-10, -2), Vector2(-14, -2)]), c_body_mid))
	_awakened_only.append(_poly_glow(_chest, "sheath_1_mark", PackedVector2Array([Vector2(10, -4), Vector2(13, -4), Vector2(12, -2), Vector2(9, -2)]), c_energy, 0.55))
	_awakened_only.append(_poly_glow(_chest, "sheath_2_mark", PackedVector2Array([Vector2(-13, -4), Vector2(-10, -4), Vector2(-9, -2), Vector2(-12, -2)]), c_energy, 0.45))

	# 左臂：青色系 + 发光缝
	_poly(_arm_l_u, "arm_u_l", PackedVector2Array([Vector2(-6, -3), Vector2(6, -3), Vector2(5, 10), Vector2(-5, 10)]), c_arm_l)
	_poly_glow(_arm_l_u, "arm_u_l_strip", PackedVector2Array([Vector2(-1, -2), Vector2(1, -2), Vector2(1, 8), Vector2(-1, 8)]), c_energy, 0.55)
	_poly(_arm_l_l, "arm_l_l", PackedVector2Array([Vector2(-5, -2), Vector2(5, -2), Vector2(4, 10), Vector2(-4, 10)]), c_arm_l)
	_poly(_arm_l_l, "glove_l", PackedVector2Array([Vector2(-6, 6), Vector2(6, 6), Vector2(6, 13), Vector2(-6, 13)]), c_glove_l)
	_poly(_arm_l_l, "glove_l_knuckle", PackedVector2Array([Vector2(-5, 7), Vector2(5, 7), Vector2(4, 10), Vector2(-4, 10)]), c_steel)
	_poly(_arm_l_l, "glove_l_spike", PackedVector2Array([Vector2(5, 10), Vector2(8, 12), Vector2(4, 12)]), c_body_dark)

	# 右臂：紫色系 + 发光缝
	_poly(_arm_r_u, "arm_u_r", PackedVector2Array([Vector2(-6, -3), Vector2(6, -3), Vector2(5, 10), Vector2(-5, 10)]), c_arm_r)
	_poly_glow(_arm_r_u, "arm_u_r_strip", PackedVector2Array([Vector2(-1, -2), Vector2(1, -2), Vector2(1, 8), Vector2(-1, 8)]), c_energy, 0.45)
	_poly(_arm_r_l, "arm_l_r", PackedVector2Array([Vector2(-5, -2), Vector2(5, -2), Vector2(4, 10), Vector2(-4, 10)]), c_arm_r)
	_poly(_arm_r_l, "glove_r", PackedVector2Array([Vector2(-6, 6), Vector2(6, 6), Vector2(6, 13), Vector2(-6, 13)]), c_glove_r)
	_poly(_arm_r_l, "glove_r_knuckle", PackedVector2Array([Vector2(-5, 7), Vector2(5, 7), Vector2(4, 10), Vector2(-4, 10)]), c_steel)
	_poly(_arm_r_l, "glove_r_spike", PackedVector2Array([Vector2(5, 10), Vector2(8, 12), Vector2(4, 12)]), c_body_dark)

	# 左腿：青色偏冷靴子
	_poly(_leg_l_u, "thigh_l", PackedVector2Array([Vector2(-7, -2), Vector2(7, -2), Vector2(6, 11), Vector2(-6, 11)]), c_leg_l)
	_poly_glow(_leg_l_u, "thigh_l_line", PackedVector2Array([Vector2(-1, 0), Vector2(1, 0), Vector2(1, 9), Vector2(-1, 9)]), c_energy, 0.45)
	# 大腿装甲板块（增加细碎感）
	_poly(_leg_l_u, "thigh_l_plate1", PackedVector2Array([Vector2(-5, -1), Vector2(-1, -1), Vector2(-2, 5), Vector2(-5, 6)]), c_body_mid)
	_poly(_leg_l_u, "thigh_l_plate2", PackedVector2Array([Vector2(1, -1), Vector2(5, -1), Vector2(5, 6), Vector2(2, 5)]), c_body_light)
	_poly(_leg_l_l, "shin_l", PackedVector2Array([Vector2(-6, -2), Vector2(6, -2), Vector2(5, 11), Vector2(-5, 11)]), c_leg_l)
	_poly(_leg_l_l, "boot_l", PackedVector2Array([Vector2(-8, 7), Vector2(8, 7), Vector2(9, 14), Vector2(-9, 14)]), c_boot_l)
	_poly(_leg_l_l, "boot_l_toe", PackedVector2Array([Vector2(7, 10), Vector2(11, 12), Vector2(7, 13)]), c_body_dark)
	_poly(_leg_l_l, "boot_l_heel", PackedVector2Array([Vector2(-7, 10), Vector2(-11, 12), Vector2(-7, 13)]), c_body_dark)
	# 胫甲/膝甲碎片化 + 红色嵌条
	_poly(_leg_l_l, "knee_l", PackedVector2Array([Vector2(-6, -2), Vector2(6, -2), Vector2(5, 2), Vector2(-5, 2)]), c_steel)
	_poly(_leg_l_l, "shin_l_plate", PackedVector2Array([Vector2(-4, 1), Vector2(4, 1), Vector2(3, 8), Vector2(-3, 8)]), c_body_mid)
	_poly_glow(_leg_l_l, "shin_l_seam", PackedVector2Array([Vector2(-1, 2), Vector2(1, 2), Vector2(1, 8), Vector2(-1, 8)]), c_energy, 0.22)

	# 右腿：紫色偏暖靴子
	_poly(_leg_r_u, "thigh_r", PackedVector2Array([Vector2(-7, -2), Vector2(7, -2), Vector2(6, 11), Vector2(-6, 11)]), c_leg_r)
	_poly_glow(_leg_r_u, "thigh_r_line", PackedVector2Array([Vector2(-1, 0), Vector2(1, 0), Vector2(1, 9), Vector2(-1, 9)]), c_energy, 0.35)
	_poly(_leg_r_u, "thigh_r_plate1", PackedVector2Array([Vector2(-5, -1), Vector2(-1, -1), Vector2(-2, 5), Vector2(-5, 6)]), c_body_light)
	_poly(_leg_r_u, "thigh_r_plate2", PackedVector2Array([Vector2(1, -1), Vector2(5, -1), Vector2(5, 6), Vector2(2, 5)]), c_body_mid)
	_poly(_leg_r_l, "shin_r", PackedVector2Array([Vector2(-6, -2), Vector2(6, -2), Vector2(5, 11), Vector2(-5, 11)]), c_leg_r)
	_poly(_leg_r_l, "boot_r", PackedVector2Array([Vector2(-8, 7), Vector2(8, 7), Vector2(9, 14), Vector2(-9, 14)]), c_boot_r)
	_poly(_leg_r_l, "boot_r_toe", PackedVector2Array([Vector2(7, 10), Vector2(11, 12), Vector2(7, 13)]), c_body_dark)
	_poly(_leg_r_l, "boot_r_heel", PackedVector2Array([Vector2(-7, 10), Vector2(-11, 12), Vector2(-7, 13)]), c_body_dark)
	_poly(_leg_r_l, "knee_r", PackedVector2Array([Vector2(-6, -2), Vector2(6, -2), Vector2(5, 2), Vector2(-5, 2)]), c_steel)
	_poly(_leg_r_l, "shin_r_plate", PackedVector2Array([Vector2(-4, 1), Vector2(4, 1), Vector2(3, 8), Vector2(-3, 8)]), c_body_mid)
	_poly_glow(_leg_r_l, "shin_r_seam", PackedVector2Array([Vector2(-1, 2), Vector2(1, 2), Vector2(1, 8), Vector2(-1, 8)]), c_energy, 0.18)


func _circle_poly(cx: float, cy: float, r: float, steps: int) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in range(steps + 1):
		var t := TAU * float(i) / float(steps)
		pts.append(Vector2(cx + cos(t) * r, cy + sin(t) * r))
	return pts


func _poly(parent: Node2D, pname: String, pts: PackedVector2Array, col: Color, a_mul: float = 1.0) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = pname
	poly.polygon = pts
	poly.color = Color(col.r, col.g, col.b, col.a * a_mul)
	# 清晰度优化：开启多边形抗锯齿，边缘更接近“照片感”的平滑轮廓。
	poly.antialiased = true
	poly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(poly)
	_all_polys.append(poly)
	return poly


func set_photo_rig_texture(tex: Texture2D, img_w: int, img_h: int) -> void:
	if tex == null or img_w <= 0 or img_h <= 0:
		return
	_photo_mode = true
	for p: Polygon2D in _all_polys:
		if is_instance_valid(p):
			p.visible = false
	_clear_photo_parts()

	var s := 0.094
	# 背后弱描边：放在底图后，减轻“纸片拼接边缘”。
	_add_photo_part(_spine, "photo_outline", tex, Rect2(img_w * 0.25, img_h * 0.03, img_w * 0.50, img_h * 0.94), Vector2(0, 12), s * 1.045, 2, 0.24)
	var outline := _get_photo_part("photo_outline")
	if outline:
		outline.modulate = Color(0.03, 0.03, 0.04, 0.24)

	# 底图透明度降低，避免把分片细节“盖平”。
	_add_photo_part(_spine, "photo_full_base", tex, Rect2(img_w * 0.25, img_h * 0.03, img_w * 0.50, img_h * 0.94), Vector2(0, 12), s, 3, 0.42)

	# 头部细分：头盔壳 + 面罩，旋转时保留层次。
	_add_photo_part(_head, "photo_head_shell", tex, Rect2(img_w * 0.36, img_h * 0.00, img_w * 0.28, img_h * 0.18), Vector2(0, -8), s, 15)
	_add_photo_part(_head, "photo_head_face", tex, Rect2(img_w * 0.39, img_h * 0.10, img_w * 0.22, img_h * 0.15), Vector2(0, -2), s, 16)

	# 躯干细分：胸、腹、腰、下摆，让“身体骨骼化”更明显。
	_add_photo_part(_chest, "photo_torso_chest", tex, Rect2(img_w * 0.30, img_h * 0.18, img_w * 0.40, img_h * 0.24), Vector2(0, 1), s, 13)
	_add_photo_part(_spine, "photo_torso_abd", tex, Rect2(img_w * 0.33, img_h * 0.40, img_w * 0.34, img_h * 0.14), Vector2(0, 10), s, 12)
	_add_photo_part(_hip, "photo_hip", tex, Rect2(img_w * 0.34, img_h * 0.50, img_w * 0.33, img_h * 0.18), Vector2(0, 15), s, 11)
	_add_photo_part(_hip, "photo_tabard", tex, Rect2(img_w * 0.44, img_h * 0.52, img_w * 0.12, img_h * 0.30), Vector2(0, 22), s, 10)

	# 手臂细分：肩甲 / 上臂 / 前臂 / 手套
	_add_photo_part(_arm_l_u, "photo_shoulder_l", tex, Rect2(img_w * 0.20, img_h * 0.16, img_w * 0.10, img_h * 0.10), Vector2(-2, -1), s, 14)
	_add_photo_part(_arm_r_u, "photo_shoulder_r", tex, Rect2(img_w * 0.70, img_h * 0.16, img_w * 0.10, img_h * 0.10), Vector2(2, -1), s, 14)
	_add_photo_part(_arm_l_u, "photo_arm_l_u", tex, Rect2(img_w * 0.23, img_h * 0.22, img_w * 0.14, img_h * 0.18), Vector2(-1, 4), s, 13)
	_add_photo_part(_arm_l_l, "photo_arm_l_l", tex, Rect2(img_w * 0.22, img_h * 0.39, img_w * 0.14, img_h * 0.18), Vector2(-1, 5), s, 13)
	_add_photo_part(_arm_l_l, "photo_hand_l", tex, Rect2(img_w * 0.22, img_h * 0.56, img_w * 0.12, img_h * 0.11), Vector2(-1, 10), s, 14)
	_add_photo_part(_arm_r_u, "photo_arm_r_u", tex, Rect2(img_w * 0.63, img_h * 0.22, img_w * 0.14, img_h * 0.18), Vector2(1, 4), s, 13)
	_add_photo_part(_arm_r_l, "photo_arm_r_l", tex, Rect2(img_w * 0.64, img_h * 0.39, img_w * 0.14, img_h * 0.18), Vector2(1, 5), s, 13)
	_add_photo_part(_arm_r_l, "photo_hand_r", tex, Rect2(img_w * 0.66, img_h * 0.56, img_w * 0.12, img_h * 0.11), Vector2(1, 10), s, 14)

	# 腿部细分：大腿 / 护膝 / 小腿 / 靴子
	_add_photo_part(_leg_l_u, "photo_thigh_l", tex, Rect2(img_w * 0.37, img_h * 0.58, img_w * 0.14, img_h * 0.16), Vector2(-2, 6), s, 12)
	_add_photo_part(_leg_l_l, "photo_knee_l", tex, Rect2(img_w * 0.37, img_h * 0.72, img_w * 0.12, img_h * 0.08), Vector2(-1, 4), s, 13)
	_add_photo_part(_leg_l_l, "photo_shin_l", tex, Rect2(img_w * 0.36, img_h * 0.78, img_w * 0.13, img_h * 0.13), Vector2(-1, 8), s, 12)
	_add_photo_part(_leg_l_l, "photo_boot_l", tex, Rect2(img_w * 0.35, img_h * 0.90, img_w * 0.15, img_h * 0.10), Vector2(-1, 13), s, 13)
	_add_photo_part(_leg_r_u, "photo_thigh_r", tex, Rect2(img_w * 0.50, img_h * 0.58, img_w * 0.14, img_h * 0.16), Vector2(2, 6), s, 12)
	_add_photo_part(_leg_r_l, "photo_knee_r", tex, Rect2(img_w * 0.51, img_h * 0.72, img_w * 0.12, img_h * 0.08), Vector2(1, 4), s, 13)
	_add_photo_part(_leg_r_l, "photo_shin_r", tex, Rect2(img_w * 0.51, img_h * 0.78, img_w * 0.13, img_h * 0.13), Vector2(1, 8), s, 12)
	_add_photo_part(_leg_r_l, "photo_boot_r", tex, Rect2(img_w * 0.50, img_h * 0.90, img_w * 0.15, img_h * 0.10), Vector2(1, 13), s, 13)


func clear_photo_rig_texture() -> void:
	if not _photo_mode:
		return
	_photo_mode = false
	_clear_photo_parts()
	for p: Polygon2D in _all_polys:
		if is_instance_valid(p):
			p.visible = true
	set_form(_form)


func _add_photo_part(parent: Node2D, part_name: String, tex: Texture2D, region: Rect2, local_pos: Vector2, part_scale: float, z: int, alpha: float = 1.0) -> void:
	if parent == null:
		return
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	var sp := Sprite2D.new()
	sp.name = part_name
	sp.texture = at
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sp.centered = true
	sp.position = local_pos
	sp.scale = Vector2(part_scale, part_scale)
	sp.z_index = z
	sp.modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	parent.add_child(sp)
	_photo_parts.append(sp)
	_photo_part_map[part_name] = sp


func _clear_photo_parts() -> void:
	for sp: Sprite2D in _photo_parts:
		if is_instance_valid(sp):
			sp.queue_free()
	_photo_parts.clear()
	_photo_part_map.clear()


func _get_photo_part(name: String) -> Sprite2D:
	if not _photo_part_map.has(name):
		return null
	var sp := _photo_part_map[name] as Sprite2D
	return sp if is_instance_valid(sp) else null


func _poly_glow(parent: Node2D, pname: String, pts: PackedVector2Array, col: Color, a_mul: float = 1.0) -> Polygon2D:
	var p := _poly(parent, pname, pts, col, a_mul)
	_glow_polys.append(p)
	p.set_meta("glow_base_color", col)
	p.set_meta("glow_base_a_mul", a_mul)
	return p


func apply_visual_state(
	delta: float,
	vel: Vector2,
	dead: bool,
	hit_blend: float,
	attack_blend: float,
	aim_dir: Vector2,
	last_horiz_facing: float,
	dashing: bool = false,
	dash_dir: Vector2 = Vector2.ZERO
) -> void:
	if dead:
		visible = false
		return
	visible = true
	_update_ground_shadow(vel.length())

	# 水平朝向：整身镜像（俯视常用）
	var dir_x := vel.x
	if aim_dir.length_squared() > 0.0004 and attack_blend > 0.2:
		dir_x = aim_dir.x
	elif absf(dir_x) < _FACING_EPS and absf(last_horiz_facing) > 0.01:
		dir_x = last_horiz_facing
	var flip := dir_x < 0.0 if absf(dir_x) > _FACING_EPS else (_last_flip_sign < 0.0)
	_last_flip_sign = -1.0 if flip else 1.0
	_facing_mul = -1.0 if flip else 1.0
	scale = Vector2(_visual_scale * _facing_mul, _visual_scale)

	var moving := vel.length() > _RUN_ANIM_MIN_SPEED
	_idle_t += delta
	_apply_glow_pulse(moving)

	if hit_blend > 0.01:
		var hw := hit_blend
		_spine.rotation = lerp_angle(_spine.rotation, -0.18 * _last_flip_sign * hw, 0.42 * hw)
		_head.rotation = lerp_angle(_head.rotation, 0.12 * hw, 0.32 * hw)
	elif attack_blend > 0.01 and aim_dir.length_squared() > 0.0004:
		var aw := attack_blend
		_arm_r_u.rotation = lerp_angle(_arm_r_u.rotation, -1.05 * _facing_mul, 0.48 * aw)
		_arm_r_l.rotation = lerp_angle(_arm_r_l.rotation, 0.68, 0.42 * aw)
		_spine.rotation = lerp_angle(_spine.rotation, sin(_idle_t * 6.0) * 0.04, 0.28 * aw)
	elif dashing:
		var dir := dash_dir if dash_dir.length_squared() > 0.01 else vel
		if dir.length_squared() < 0.01:
			dir = Vector2(last_horiz_facing, 0.0)
		dir = dir.normalized()
		_run_phase += delta * 12.0
		var swing := sin(_run_phase * PI * 2.0)
		var motion_mul := 0.72 if _photo_mode else 0.92
		_leg_l_u.rotation = swing * 0.42 * motion_mul
		_leg_r_u.rotation = -swing * 0.42 * motion_mul
		_arm_l_u.rotation = -swing * 0.28 * motion_mul
		_arm_r_u.rotation = swing * 0.22 * motion_mul
		var lean := clampf(dir.x * 0.0014, -0.14, 0.14) * _facing_mul
		_spine.rotation = lerp_angle(_spine.rotation, lean + dir.y * 0.08, 0.38)
		_chest.position.y = -9.0 + dir.y * 1.4
		_head.rotation = lerp_angle(_head.rotation, lean * 0.35, 0.3)
	elif moving:
		_run_phase += delta * _RUN_ANIM_FPS * clampf(vel.length() / 175.0, 0.58, 1.35)
		var swing := sin(_run_phase * PI * 2.0)
		var motion_mul := 0.82 if _photo_mode else 1.0
		_leg_l_u.rotation = swing * 0.55 * motion_mul
		_leg_l_l.rotation = absf(swing) * 0.36 * motion_mul
		_leg_r_u.rotation = -swing * 0.55 * motion_mul
		_leg_r_l.rotation = absf(swing) * 0.36 * motion_mul
		_arm_l_u.rotation = -swing * 0.42 * motion_mul
		_arm_l_l.rotation = -0.24 * swing * motion_mul
		_arm_r_u.rotation = swing * 0.35 * motion_mul
		_arm_r_l.rotation = 0.2 * swing * motion_mul
		_bob_smoothed = lerpf(_bob_smoothed, swing * (1.35 if _photo_mode else 1.55), 0.42)
		_chest.position.y = -9.0 + _bob_smoothed * (0.46 if _photo_mode else 0.55)
		var lean := clampf(vel.x * 0.00045, -_LEAN_MAX_RAD, _LEAN_MAX_RAD)
		_spine.rotation = lerpf(_spine.rotation, lean, _LEAN_FOLLOW)
		_head.rotation = lerpf(_head.rotation, -lean * 0.35, 0.25)
		if _photo_mode:
			_apply_secondary_sway(delta, swing, vel.length())
	else:
		_run_phase = 0.0
		_bob_smoothed = lerpf(_bob_smoothed, 0.0, 0.3)
		var breath := sin(_idle_t * 2.05) * 0.09
		_spine.rotation = lerpf(_spine.rotation, breath, 0.2)
		_chest.position.y = -9.0 + breath * 2.0
		_head.rotation = lerpf(_head.rotation, breath * 0.5, 0.2)
		_leg_l_u.rotation = lerpf(_leg_l_u.rotation, 0.0, 0.2)
		_leg_r_u.rotation = lerpf(_leg_r_u.rotation, 0.0, 0.2)
		_leg_l_l.rotation = lerpf(_leg_l_l.rotation, 0.0, 0.2)
		_leg_r_l.rotation = lerpf(_leg_r_l.rotation, 0.0, 0.2)
		_arm_l_u.rotation = lerpf(_arm_l_u.rotation, 0.05, 0.15)
		_arm_r_u.rotation = lerpf(_arm_r_u.rotation, -0.05, 0.15)
		_arm_l_l.rotation = lerpf(_arm_l_l.rotation, 0.0, 0.15)
		_arm_r_l.rotation = lerpf(_arm_r_l.rotation, 0.0, 0.15)
		if _photo_mode:
			_reset_secondary_sway(delta)


func _apply_glow_pulse(moving: bool) -> void:
	# 跑动时频率略快；整体强度轻微变化，避免刺眼。
	var t := _idle_t * (3.4 if moving else 2.2)
	var pulse := 0.72 + 0.28 * (0.5 + 0.5 * sin(t))
	pulse = lerpf(1.0, pulse, _glow_pulse_strength)

	for p: Polygon2D in _glow_polys:
		if not is_instance_valid(p):
			continue
		var base_col: Color = p.get_meta("glow_base_color", p.color)
		var base_a_mul: float = float(p.get_meta("glow_base_a_mul", 1.0))
		p.color = Color(base_col.r, base_col.g, base_col.b, clampf(base_col.a * base_a_mul * pulse, 0.0, 1.0))


func _apply_secondary_sway(delta: float, swing: float, speed: float) -> void:
	var speed_u := clampf(speed / 240.0, 0.0, 1.0)
	var preset_mul := _motion_preset_multiplier()
	var detail_mul := preset_mul * clampf(motion_detail_strength, 0.6, 1.8)
	var shoulder_target := swing * lerpf(0.05, 0.12, speed_u) * detail_mul
	var tabard_target := -swing * lerpf(0.08, 0.18, speed_u) * detail_mul
	_sway_shoulder_l = lerpf(_sway_shoulder_l, shoulder_target * 0.85, 1.0 - exp(-delta * 9.0))
	_sway_shoulder_r = lerpf(_sway_shoulder_r, -shoulder_target, 1.0 - exp(-delta * 9.0))
	_sway_tabard = lerpf(_sway_tabard, tabard_target, 1.0 - exp(-delta * 8.0))

	var shoulder_l := _get_photo_part("photo_shoulder_l")
	if shoulder_l:
		shoulder_l.rotation = _sway_shoulder_l
	var shoulder_r := _get_photo_part("photo_shoulder_r")
	if shoulder_r:
		shoulder_r.rotation = _sway_shoulder_r
	var tabard := _get_photo_part("photo_tabard")
	if tabard:
		tabard.rotation = _sway_tabard
		tabard.position.y = 22.0 + absf(_sway_tabard) * 6.0 * detail_mul


func _reset_secondary_sway(delta: float) -> void:
	_sway_shoulder_l = lerpf(_sway_shoulder_l, 0.0, 1.0 - exp(-delta * 8.0))
	_sway_shoulder_r = lerpf(_sway_shoulder_r, 0.0, 1.0 - exp(-delta * 8.0))
	_sway_tabard = lerpf(_sway_tabard, 0.0, 1.0 - exp(-delta * 7.0))
	var shoulder_l := _get_photo_part("photo_shoulder_l")
	if shoulder_l:
		shoulder_l.rotation = _sway_shoulder_l
	var shoulder_r := _get_photo_part("photo_shoulder_r")
	if shoulder_r:
		shoulder_r.rotation = _sway_shoulder_r
	var tabard := _get_photo_part("photo_tabard")
	if tabard:
		tabard.rotation = _sway_tabard
		tabard.position.y = lerpf(tabard.position.y, 22.0, 1.0 - exp(-delta * 8.0))


func _motion_preset_multiplier() -> float:
	match motion_detail_preset:
		MotionDetailPreset.LIGHT:
			return 0.78
		MotionDetailPreset.STRONG:
			return 1.28
		_:
			return 1.0


func _update_ground_shadow(speed: float) -> void:
	if _ground_shadow == null:
		return
	var u := clampf(speed / 230.0, 0.0, 1.0)
	var sx := lerpf(1.0, 1.2, u)
	var sy := lerpf(1.0, 0.86, u)
	_ground_shadow.scale = Vector2(sx, sy)
	_ground_shadow.position.y = lerpf(0.0, 1.6, u)
	_ground_shadow.color.a = lerpf(0.28, 0.18, u)

func play_dash_scale_punch() -> void:
	var tw := create_tween()
	var b := 1.07
	tw.tween_property(self, "scale", Vector2(_visual_scale * _facing_mul * b, _visual_scale * b), 0.065).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(_visual_scale * _facing_mul, _visual_scale), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
