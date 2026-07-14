extends Area2D
class_name Player

# ============================================
# 玩家控制器 - 自动射击 + 虚拟摇杆移动
# HP唯一管理源，Game只读取不写入
# ============================================

# 基础属性
var move_speed := 210.0
var accel := 1320.0
var brake_accel := 1780.0
var turn_accel := 2100.0
## 指数型趋近目标速度（比纯 move_toward 更易做出「顺、不涩」的手感）
const _VEL_RESP_LAMBDA := 14.5
const _VEL_BRAKE_LAMBDA := 21.0
const _VEL_STOP_EPS := 1.15
var max_hp := 100.0
var hp := 100.0
var velocity := Vector2.ZERO

# 状态 — 受击无敌与翻滚无敌分轨（互不覆盖）
var _iframe_hit_t := 0.0
var _iframe_roll_t := 0.0
var is_dead := false

# 冲刺系统
var _dash_active := false
var _dash_timer := 0.0
var _dash_dir := Vector2.ZERO
var _dash_cooldown := 0.0
var _dash_trail_timer := 0.0  # 冲刺残影计时器
var _dash_ui_request := false
var _dash_buffer_t := 0.0
var _dash_cooldown_mul := 1.0
const _DASH_INPUT_BUFFER_SEC := 0.12
const _DASH_MIN_INPUT_LEN := 0.16
const _DASH_FALLBACK_MIN_SPEED := 40.0
const _POST_DASH_KEEP_SPEED := 220.0
## 《重生细胞》式连杀动量：短时提高移速上限（由 Game 写入）
var _kill_momentum_mul := 1.0

# 立绘：待机整图 + 可选横向跑步条带（三帧 region）
var _tex_idle: Texture2D
var _tex_run_strip: Texture2D
var _tex_turn_strip: Texture2D
var _run_frame_w: int = 0
var _run_frame_h: int = 0
var _turn_frame_w: int = 0
var _turn_frame_h: int = 0
var _turn_frame_f: float = 1.0
const _RUN_ANIM_FPS: float = 11.0
var _run_anim_accum: float = 0.0
var _bob_smoothed: float = 0.0
## 待机呼吸相位（仅程序化立绘时叠加轻微起伏）
var _idle_breath_t: float = 0.0
## 俯视角左右翻转：记录水平朝向，低速时保持上次朝向避免抽风
var _last_horiz_facing: float = 1.0
var _facing_smooth_x: float = 1.0
var _saved_sprite_scale := Vector2.ONE
var _tex_attack: Texture2D
var _tex_hit: Texture2D
var _pose_attack_t: float = 0.0
var _pose_hit_t: float = 0.0
const _POSE_ATTACK_SEC: float = 0.14
const _POSE_HIT_SEC: float = 0.22
var _pose_overlay: Sprite2D = null
var _hit_knock_offset: Vector2 = Vector2.ZERO
var _hit_knock_dir: Vector2 = Vector2.ZERO
var _fidelity_motion_blend: float = 0.0
## 外部整帧立绘（非骨架拼贴）：保形模式下避免切换跑步条带导致姿态跳变
var _external_portrait_sprite: bool = false
var _dash_pose_blend: float = 0.0
var _dash_ghost_timer: float = 0.0
var _dash_ghost_layer: Node2D = null
const _DASH_GHOST_INTERVAL := 0.045
const _DASH_LEAN_DEG := 4.8

## 武器挂载：沿自动瞄准方向前伸 + 侧向偏移（俯视「持械手」），与 WeaponSystem.get_auto_weapon_aim_dir / 苦无发射原点一致
const _WEAPON_HAND_ALONG_AIM := 18.0
const _WEAPON_HAND_PERP := 10.0

## 高于此速度播跑步条带（与朝向阈值略分离，减轻「慢挪还在跑」）
const _RUN_ANIM_MIN_SPEED := 20.0
const _LEAN_MAX_PX := 2.8
const _LEAN_FOLLOW := 0.16

# 引用
@onready var weapon_system: Node = get_parent().get_node_or_null("WeaponSystem")
@onready var weapon_mount: Node2D = $WeaponMount
@onready var body_rig: PlayerBodyRig = $VisualRoot
var _use_body_rig: bool = false
## 是否优先使用外部 PNG 立绘（存在时会覆盖 PlayerBodyRig）。
## 默认开启：优先读取 game_pack 自定义角色资源（可在场景中关闭回退骨架）。
@export var prefer_external_sprite: bool = true
## 照片白底去除：将边缘连通的高亮背景做透明。
@export var auto_key_photo_background: bool = false
## 黑底去除：将边缘连通的近黑背景做透明（适配 AI 生成黑底角色图）。
@export var auto_key_dark_background: bool = false
## 外部立绘目标屏幕高度（像素感知）：越大越清晰、越接近原图细节。
@export var external_sprite_target_height: float = 280.0
## 验收通过的项目接入模式：优先保留原始机甲形象，弱化额外视觉加工。
@export var fidelity_mode_enabled: bool = true
## 可手动指定角色参考图（例如：res://1/8a5f2e11af0137a9db2889a0e6124c37.jpg）。
## 留空时会自动尝试读取 res://1 目录中的图片。
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var external_sprite_path_override: String = ""
## 仅这些“被动技能”到达 max_lv 时触发变身（留空则不由被动触发）。
@export var transform_vertex_passives: Array[StringName] = [&"atk_boost", &"crit_chance", &"lifesteal"]
## 仅这些“变异技能”到达 max_lv 时触发变身（留空则不由变异触发）。
@export var transform_vertex_mutations: Array[StringName] = [&"violet_madness", &"violet_overclock"]
## 本局是否只触发一次变身。
@export var transform_once_per_run: bool = true
@onready var skill_system: Node = get_parent().get_node_or_null("SkillSystem")
@onready var enemy_manager: Node = get_parent().get_node_or_null("EnemyManager")
@onready var camera: Camera2D = $Camera2D if has_node("Camera2D") else null
@onready var damage_flash: ColorRect = $FlashLayer/DamageFlash if has_node("FlashLayer/DamageFlash") else null
var _has_transformed_this_run: bool = false
var _run_archetype_id := ""
var _archetype_move_speed_mul := 1.0
## 地图规则场：移速倍率 + 拉力（毒圈/移动安全区）
var _map_move_mul := 1.0
var _map_pull_vel := Vector2.ZERO
var _archetype_kill_heal_flat := 0.0
var _archetype_guardian_fx_cd := 0.0
var _archetype_assault_fx_cd := 0.0
var _depth_shadow: Sprite2D = null
var _energy_edge: Sprite2D = null
const _DEPTH_SHADOW_BASE_OFFSET := Vector2(0.0, 18.0)

func _ready() -> void:
	add_to_group("player")
	InputManager.set_aim_mode(InputManager.AimMode.AUTO)
	InputManager.auto_fire = true
	global_position = Vector2.ZERO
	visible = true
	modulate = Color.WHITE
	# 必须立即开启：若仅等 call_deferred 贴图完成才 set_process(true)，首段帧内无法移动且易误判「卡死」
	set_process(true)
	if damage_flash:
		damage_flash.visible = false
	if not EventBus.dash_requested.is_connected(_on_dash_requested_ui):
		EventBus.dash_requested.connect(_on_dash_requested_ui)
	if not EventBus.skill_vertex_reached.is_connected(_on_skill_vertex_reached):
		EventBus.skill_vertex_reached.connect(_on_skill_vertex_reached)
	_has_transformed_this_run = false
	if body_rig:
		body_rig.set_form(PlayerBodyRig.RigForm.BASE)
	call_deferred("_build_player_texture")
	call_deferred("_ensure_depth_shadow")
	call_deferred("_ensure_dash_ghost_layer")
	call_deferred("_ensure_pose_overlay")
	if not fidelity_mode_enabled:
		call_deferred("_ensure_energy_edge")
	call_deferred("_configure_camera_follow")
	if not get_viewport().size_changed.is_connected(_configure_camera_follow):
		get_viewport().size_changed.connect(_configure_camera_follow)
	rotation = 0.0


func _configure_camera_follow() -> void:
	if camera == null:
		return
	# 相机挂在 Player 下：limit 会把镜头锁在边界内，角色却能继续移动 → 移出屏幕
	camera.limit_enabled = false
	camera.position = Vector2.ZERO
	camera.position_smoothing_enabled = false
	camera.position_smoothing_speed = 0.0


func _on_skill_vertex_reached(kind: StringName, id: StringName) -> void:
	# 仅白名单技能到顶点时触发变身
	var should_transform := false
	if kind == &"passive":
		should_transform = transform_vertex_passives.has(id)
	elif kind == &"mutation":
		should_transform = transform_vertex_mutations.has(id)
	if transform_once_per_run and _has_transformed_this_run:
		return
	if should_transform and body_rig:
		body_rig.set_form(PlayerBodyRig.RigForm.AWAKENED)
		_has_transformed_this_run = true


func _on_dash_requested_ui() -> void:
	_dash_ui_request = true

func set_map_move_field(move_mul: float, pull_vel: Vector2 = Vector2.ZERO) -> void:
	_map_move_mul = clampf(move_mul, 0.45, 1.35)
	_map_pull_vel = pull_vel


func set_kill_momentum_mul(mul: float) -> void:
	_kill_momentum_mul = clampf(mul, 1.0, 1.0 + GameDB.DC_KILL_STREAK_SPEED_CAP)


func set_run_archetype(id: String, cfg: Dictionary) -> void:
	_run_archetype_id = id
	_archetype_move_speed_mul = maxf(0.85, float(cfg.get("move_speed_mul", 1.0)))
	_dash_cooldown_mul = clampf(float(cfg.get("dash_cd_mul", 1.0)), 0.65, 1.25)
	_archetype_kill_heal_flat = maxf(0.0, float(cfg.get("kill_heal_flat", 0.0)))


func get_run_archetype_id() -> String:
	return _run_archetype_id


func get_archetype_kill_heal_flat() -> float:
	return _archetype_kill_heal_flat


func _player_png_has_opaque_sprite(img: Image) -> bool:
	# 过滤误导出 PNG（例如 Draw 绑定错位只剩半透明光晕），避免“看不见人”
	var best := 0.0
	for y in range(0, img.get_height(), 6):
		for x in range(0, img.get_width(), 6):
			best = maxf(best, img.get_pixel(x, y).a)
	return best > 0.75


func _build_player_texture() -> void:
	_external_portrait_sprite = false
	_tex_idle = null
	_tex_run_strip = null
	_tex_turn_strip = null
	_tex_attack = null
	_tex_hit = null
	_run_frame_w = 0
	_run_frame_h = 0
	_turn_frame_w = 0
	_turn_frame_h = 0
	_turn_frame_f = 1.0
	# 仅在显式开启时尝试外部立绘，默认走项目内骨架风格。
	var ext_img: Image = null
	if prefer_external_sprite:
		ext_img = _load_project_player_portrait()
	if ext_img != null and _player_png_has_opaque_sprite(ext_img):
		if auto_key_photo_background or auto_key_dark_background:
			ext_img = _strip_photo_background(ext_img)
		var ext_tex := ImageTexture.create_from_image(ext_img)
		_tex_idle = ext_tex
		_external_portrait_sprite = true
		# 保形立绘与跑步条带姿态/比例易不一致，仅非保形模式才绑定条带动画。
		if not fidelity_mode_enabled:
			_try_bind_run_strip(ext_img)
			_try_bind_turn_strip(ext_img)
		_try_bind_pose_textures(ext_img)
		# 外部角色图使用“整帧驱动”，避免分片拼贴导致的人体割裂感。
		_use_body_rig = false
		if body_rig:
			body_rig.clear_photo_rig_texture()
			body_rig.visible = false
		$Sprite2D.texture = ext_tex
		$Sprite2D.region_enabled = false
		$Sprite2D.visible = true
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var target_h := maxf(72.0, external_sprite_target_height)
		var s := clampf(target_h / maxf(1.0, float(ext_img.get_height())), 0.12, 0.68)
		$Sprite2D.scale = Vector2(s, s)
		_saved_sprite_scale = $Sprite2D.scale
		if EventBus != null:
			NotificationSystem.notify_message("角色渲染：整帧模式", 1.0, "info")
		set_process(true)
		return
	_use_body_rig = true
	if body_rig:
		body_rig.clear_photo_rig_texture()
		body_rig.visible = true
		body_rig.set_form(PlayerBodyRig.RigForm.BASE)
		_has_transformed_this_run = false
		if EventBus != null:
			NotificationSystem.notify_message("角色渲染：回退到骨架模式", 1.2, "warning")
	$Sprite2D.visible = false
	$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Sprite2D.scale = Vector2.ONE
	_saved_sprite_scale = Vector2.ONE
	# 程序化整图立绘已弃用：改用 PlayerBodyRig；以下仍生成小图作占位（兼容旧逻辑判空）
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(size) / 2.0
	var cy := float(size) / 2.0 + 6.0
	var outline := Color(0.03, 0.05, 0.1, 1.0)
	var armor_dark := Color(0.1, 0.13, 0.2, 1.0)
	var armor_mid := Color(0.16, 0.2, 0.3, 1.0)
	var armor_hi := Color(0.26, 0.32, 0.46, 1.0)
	var joint := Color(0.32, 0.38, 0.48, 1.0)
	var accent := Color(0.2, 0.9, 0.98, 1.0)
	var accent_dim := Color(0.12, 0.48, 0.55, 1.0)
	var visor := Color(0.05, 0.62, 0.78, 0.94)
	var visor_hi := Color(0.45, 0.95, 1.0, 0.65)
	var boot := Color(0.05, 0.06, 0.1, 1.0)
	# 脚下柔影
	_fill_ellipse(img, cx, cy + 31.0, 19.0, 8.0, Color(0, 0.12, 0.2, 0.22))
	# 背载模块（壳式能源包）
	_draw_rounded_rect(img, cx - 17.0, cy + 3.0, 34.0, 13.0, 4.0, outline)
	_draw_rounded_rect(img, cx - 15.0, cy + 4.0, 30.0, 10.0, 3.0, armor_dark)
	_draw_rounded_rect(img, cx - 5.0, cy + 6.0, 10.0, 3.0, 1.0, accent_dim)
	_draw_rounded_rect(img, cx - 2.0, cy + 5.0, 4.0, 2.0, 0.8, accent)
	# 腿部装甲
	for side: float in [-1.0, 1.0]:
		var lx: float = cx + side * 8.0
		_draw_rounded_rect(img, lx - 5.5, cy + 17.0, 11.0, 21.0, 3.0, outline)
		_draw_rounded_rect(img, lx - 4.5, cy + 18.0, 9.0, 18.0, 2.5, armor_mid)
		_draw_rounded_rect(img, lx - 3.5, cy + 19.0, 2.5, 14.0, 0.8, armor_hi)
		_draw_rounded_rect(img, lx - 4.5, cy + 28.5, 9.0, 3.5, 1.2, joint)
		_draw_rounded_rect(img, lx - 5.0, cy + 33.0, 10.0, 6.5, 2.5, outline)
		_draw_rounded_rect(img, lx - 4.0, cy + 34.0, 8.0, 4.5, 2.0, boot)
		_draw_rounded_rect(img, lx - 3.0, cy + 37.5, 6.0, 1.4, 0.4, accent)
	# 躯干 / 战术背心
	_draw_rounded_rect(img, cx - 19.0, cy + 3.0, 38.0, 22.0, 6.0, outline)
	_draw_rounded_rect(img, cx - 17.0, cy + 4.5, 34.0, 18.5, 5.0, armor_dark)
	_draw_rounded_rect(img, cx - 1.0, cy + 6.0, 2.0, 14.0, 0.5, accent)
	_draw_rounded_rect(img, cx - 10.0, cy + 6.0, 20.0, 2.0, 1.0, armor_hi)
	# 肩甲
	for side: float in [-1.0, 1.0]:
		var sx: float = cx + side * 20.0
		_draw_rounded_rect(img, sx - 5.0, cy + 3.0, 10.0, 9.0, 2.5, outline)
		_draw_rounded_rect(img, sx - 4.0, cy + 4.0, 8.0, 6.5, 2.0, armor_mid)
	# 前臂与护拳
	for side: float in [-1.0, 1.0]:
		var ax: float = cx + side * 22.0
		_draw_rounded_rect(img, ax - 4.5, cy + 9.0, 9.0, 13.0, 2.5, outline)
		_draw_rounded_rect(img, ax - 3.5, cy + 10.0, 7.0, 10.0, 2.0, armor_mid)
		_draw_rounded_rect(img, ax - 4.0, cy + 18.0, 8.0, 5.0, 2.0, armor_hi)
	# 颈封
	_draw_rounded_rect(img, cx - 9.0, cy - 1.0, 18.0, 6.0, 2.0, joint)
	# 头盔外形
	_draw_circle_filled(img, cx, cy - 18.0, 17.5, outline)
	_draw_circle_filled(img, cx, cy - 18.0, 15.5, armor_dark)
	# 面罩 / 目镜
	_fill_ellipse(img, cx, cy - 13.5, 14.5, 7.5, visor)
	_fill_ellipse(img, cx - 2.0, cy - 15.0, 9.0, 4.5, visor_hi)
	_draw_rounded_rect(img, cx - 10.0, cy - 11.0, 20.0, 1.2, 0.3, accent)
	# 盔顶加强筋
	_draw_rounded_rect(img, cx - 7.0, cy - 35.0, 14.0, 5.0, 2.0, armor_hi)
	_draw_rounded_rect(img, cx - 5.0, cy - 36.0, 10.0, 2.5, 1.0, accent_dim)
	# 侧向通讯天线
	_draw_rounded_rect(img, cx - 20.0, cy - 26.0, 2.0, 9.0, 0.6, armor_hi)
	_draw_circle_filled(img, cx - 19.0, cy - 28.0, 1.8, accent)
	
	var tex := ImageTexture.create_from_image(img)
	_tex_idle = tex
	set_process(true)
	_hook_weapon_to_rig()


func _ensure_depth_shadow() -> void:
	if _depth_shadow != null and is_instance_valid(_depth_shadow):
		return
	_depth_shadow = Sprite2D.new()
	_depth_shadow.name = "DepthShadow"
	_depth_shadow.centered = true
	_depth_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_depth_shadow.z_index = -2
	_depth_shadow.modulate = Color(0.0, 0.0, 0.0, 0.26)
	add_child(_depth_shadow)


func _ensure_energy_edge() -> void:
	if _energy_edge != null and is_instance_valid(_energy_edge):
		return
	_energy_edge = Sprite2D.new()
	_energy_edge.name = "EnergyEdge"
	_energy_edge.centered = true
	_energy_edge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_energy_edge.z_index = -1
	_energy_edge.modulate = Color(1.0, 0.24, 0.24, 0.22)
	add_child(_energy_edge)


func _sync_depth_shadow() -> void:
	if _depth_shadow == null or not is_instance_valid(_depth_shadow):
		return
	var sp: Sprite2D = $Sprite2D
	if _use_body_rig or sp == null or not sp.visible or sp.texture == null:
		_depth_shadow.visible = false
		return
	_depth_shadow.visible = true
	_depth_shadow.texture = sp.texture
	_depth_shadow.region_enabled = sp.region_enabled
	_depth_shadow.region_rect = sp.region_rect
	_depth_shadow.flip_h = sp.flip_h
	_depth_shadow.rotation = 0.0
	var spd_u := clampf(velocity.length() / 260.0, 0.0, 1.0)
	_depth_shadow.position = sp.position + _DEPTH_SHADOW_BASE_OFFSET + Vector2(0.0, spd_u * 2.0)
	if fidelity_mode_enabled:
		_depth_shadow.scale = Vector2(sp.scale.x * 1.01, sp.scale.y * lerpf(0.93, 0.88, spd_u))
		_depth_shadow.modulate = Color(0.0, 0.0, 0.0, lerpf(0.16, 0.12, spd_u))
	else:
		_depth_shadow.scale = Vector2(sp.scale.x * 1.02, sp.scale.y * lerpf(0.86, 0.78, spd_u))
		_depth_shadow.modulate = Color(0.0, 0.0, 0.0, lerpf(0.28, 0.2, spd_u))


func _sync_energy_edge() -> void:
	if fidelity_mode_enabled:
		if _energy_edge != null and is_instance_valid(_energy_edge):
			_energy_edge.visible = false
		return
	if _energy_edge == null or not is_instance_valid(_energy_edge):
		return
	var sp: Sprite2D = $Sprite2D
	if _use_body_rig or sp == null or not sp.visible or sp.texture == null:
		_energy_edge.visible = false
		return
	_energy_edge.visible = true
	_energy_edge.texture = sp.texture
	_energy_edge.region_enabled = sp.region_enabled
	_energy_edge.region_rect = sp.region_rect
	_energy_edge.flip_h = sp.flip_h
	_energy_edge.rotation = 0.0
	_energy_edge.position = sp.position + Vector2(0.0, -1.0)
	_energy_edge.scale = Vector2(sp.scale.x * 1.055, sp.scale.y * 1.055)
	var pulse := 0.72 + 0.28 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009))
	var alpha := lerpf(0.22, 0.42, pulse)
	_energy_edge.modulate = Color(1.0, 0.22, 0.22, alpha)


func _load_project_player_portrait() -> Image:
	# 优先级：
	# 1) 手动指定 external_sprite_path_override
	# 2) 项目资源包 GameDB.TEX_GEN_PLAYER（稳定可控）
	# 3) 不再自动回退参考目录，避免误加载到拼图/截图素材。
	var img := Image.new()
	if not external_sprite_path_override.strip_edges().is_empty():
		var custom_path := external_sprite_path_override.strip_edges()
		if img.load(custom_path) == OK:
			if _is_valid_portrait_image(img):
				print("[Player] 使用自定义角色图: %s" % custom_path)
				return img
			push_warning("自定义角色图尺寸/比例不符合角色资源规范，已忽略: %s" % custom_path)
		push_warning("自定义角色图加载失败: %s" % custom_path)
	var pack_img: Image = GameDB.load_png_if_exists(GameDB.TEX_GEN_PLAYER)
	if pack_img != null:
		if _is_valid_portrait_image(pack_img):
			print("[Player] 使用 game_pack 角色图: %s" % GameDB.TEX_GEN_PLAYER)
			return pack_img
		push_warning("game_pack 角色图尺寸/比例不符合规范: %s" % GameDB.TEX_GEN_PLAYER)
	push_warning("角色立绘加载失败: 自定义/默认路径均不可用")
	return null


func _is_valid_portrait_image(img: Image) -> bool:
	if img == null:
		return false
	var w := img.get_width()
	var h := img.get_height()
	if w < 512 or h < 512:
		return false
	var ratio := float(w) / maxf(1.0, float(h))
	return ratio >= 0.82 and ratio <= 1.22


func _strip_photo_background(src: Image) -> Image:
	# 从边缘做连通域抠图：去除接触边框的近白/近黑背景，保留主体高光与暗部。
	var img: Image = src.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 0 or h <= 0:
		return img

	var visited := PackedByteArray()
	visited.resize(w * h)
	visited.fill(0)
	var q: Array[Vector2i] = []
	var thr_white := 0.93
	# 黑底阈值收窄：仅移除接近纯黑背景，避免吞掉黑色机甲细节。
	var thr_black := 0.018
	var _is_bg := func(c: Color) -> bool:
		if c.a <= 0.01:
			return true
		var is_white := c.r >= thr_white and c.g >= thr_white and c.b >= thr_white
		var is_black := c.r <= thr_black and c.g <= thr_black and c.b <= thr_black
		var near_gray := absf(c.r - c.g) <= 0.018 and absf(c.g - c.b) <= 0.018
		return (auto_key_photo_background and is_white) or (auto_key_dark_background and is_black and near_gray)

	var _try_push := func(x: int, y: int) -> void:
		if x < 0 or y < 0 or x >= w or y >= h:
			return
		var idx: int = y * w + x
		if visited[idx] == 1:
			return
		var c: Color = img.get_pixel(x, y)
		if _is_bg.call(c):
			visited[idx] = 1
			q.append(Vector2i(x, y))

	for x in range(w):
		_try_push.call(x, 0)
		_try_push.call(x, h - 1)
	for y in range(h):
		_try_push.call(0, y)
		_try_push.call(w - 1, y)

	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var head: int = 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		var cur: Color = img.get_pixel(p.x, p.y)
		img.set_pixel(p.x, p.y, Color(cur.r, cur.g, cur.b, 0.0))
		for d: Vector2i in dirs:
			var nx := p.x + d.x
			var ny := p.y + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nidx := ny * w + nx
			if visited[nidx] == 1:
				continue
			var nc := img.get_pixel(nx, ny)
			if _is_bg.call(nc):
				visited[nidx] = 1
				q.append(Vector2i(nx, ny))
	return img


func _try_bind_pose_textures(idle_img: Image) -> void:
	_tex_attack = null
	_tex_hit = null
	var iw := idle_img.get_width()
	var ih := idle_img.get_height()
	var atk_img: Image = GameDB.load_png_if_exists(GameDB.TEX_GEN_PLAYER_ATTACK)
	if atk_img != null and _player_png_has_opaque_sprite(atk_img) and atk_img.get_width() == iw and atk_img.get_height() == ih:
		_tex_attack = ImageTexture.create_from_image(atk_img)
	var hit_img: Image = GameDB.load_png_if_exists(GameDB.TEX_GEN_PLAYER_HIT)
	if hit_img != null and _player_png_has_opaque_sprite(hit_img) and hit_img.get_width() == iw and hit_img.get_height() == ih:
		_tex_hit = ImageTexture.create_from_image(hit_img)


func _try_bind_run_strip(idle_img: Image) -> void:
	var run_img: Image = GameDB.load_png_if_exists(GameDB.TEX_GEN_PLAYER_RUN)
	if run_img == null or not _player_png_has_opaque_sprite(run_img):
		return
	var iw := idle_img.get_width()
	var ih := idle_img.get_height()
	if run_img.get_height() != ih or run_img.get_width() != iw * 3:
		return
	_tex_run_strip = ImageTexture.create_from_image(run_img)
	_run_frame_w = iw
	_run_frame_h = ih


func _try_bind_turn_strip(idle_img: Image) -> void:
	var turn_img: Image = GameDB.load_png_if_exists(GameDB.TEX_GEN_PLAYER_TURN)
	if turn_img == null or not _player_png_has_opaque_sprite(turn_img):
		return
	var iw := idle_img.get_width()
	var ih := idle_img.get_height()
	if turn_img.get_height() != ih or turn_img.get_width() != iw * 3:
		return
	_tex_turn_strip = ImageTexture.create_from_image(turn_img)
	_turn_frame_w = iw
	_turn_frame_h = ih


func is_dashing() -> bool:
	return _dash_active


func _ensure_dash_ghost_layer() -> void:
	if _dash_ghost_layer != null:
		return
	_dash_ghost_layer = Node2D.new()
	_dash_ghost_layer.name = "DashGhostLayer"
	_dash_ghost_layer.z_index = -1
	add_child(_dash_ghost_layer)


func _spawn_dash_sprite_ghost() -> void:
	if _use_body_rig or _dash_ghost_layer == null:
		return
	var src: Sprite2D = $Sprite2D
	if src == null or src.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = src.texture
	ghost.region_enabled = src.region_enabled
	ghost.region_rect = src.region_rect
	ghost.flip_h = src.flip_h
	ghost.scale = src.scale * 0.97
	ghost.rotation = src.rotation
	ghost.global_position = src.global_position
	ghost.modulate = Color(0.42, 0.84, 1.0, 0.38)
	ghost.z_index = -1
	_dash_ghost_layer.add_child(ghost)
	var tw := ghost.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", ghost.scale * 0.9, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(ghost.queue_free)


func _portrait_motion_locked() -> bool:
	return _external_portrait_sprite and fidelity_mode_enabled


func _apply_external_portrait_motion(sp: Sprite2D, delta: float) -> void:
	# 保形立绘：只用缩放呼吸/步态，不用 offset 平移整层。
	sp.offset = Vector2.ZERO
	var moving := velocity.length() > _RUN_ANIM_MIN_SPEED and _fidelity_motion_blend > 0.05
	if moving:
		var step_mul := clampf(velocity.length() / 175.0, 0.52, 1.08)
		_run_anim_accum += delta * _RUN_ANIM_FPS * step_mul * lerpf(0.5, 0.88, _fidelity_motion_blend)
		var step := sin(_run_anim_accum * PI * 2.0)
		var sx := _saved_sprite_scale.x * lerpf(1.0, 1.014, _fidelity_motion_blend) * (1.0 + step * 0.007)
		var sy := _saved_sprite_scale.y * lerpf(1.0, 0.986, _fidelity_motion_blend) * (1.0 - step * 0.005)
		sp.scale = sp.scale.lerp(Vector2(sx, sy), 0.15)
	else:
		_run_anim_accum = lerpf(_run_anim_accum, 0.0, 0.18)
		var breath := sin(_idle_breath_t * 1.85)
		var sx_i := _saved_sprite_scale.x * (1.0 + breath * 0.007)
		var sy_i := _saved_sprite_scale.y * (1.0 - breath * 0.011)
		sp.scale = sp.scale.lerp(Vector2(sx_i, sy_i), 0.13)


func _tick_dash_sprite_fx(sp: Sprite2D, delta: float) -> void:
	var target := 1.0 if _dash_active else 0.0
	_dash_pose_blend = lerpf(_dash_pose_blend, target, delta * (18.0 if _dash_active else 12.0))
	if _dash_active:
		_dash_ghost_timer -= delta
		if _dash_ghost_timer <= 0.0:
			_dash_ghost_timer = _DASH_GHOST_INTERVAL
			_spawn_dash_sprite_ghost()
	elif _dash_ghost_timer > 0.0:
		_dash_ghost_timer = 0.0
	if _dash_pose_blend < 0.01:
		sp.rotation = lerpf(sp.rotation, 0.0, 0.2)
		return
	var dir := _dash_dir
	if dir.length_squared() < 0.01:
		dir = velocity
	if dir.length_squared() < 0.01:
		dir = Vector2(_last_horiz_facing, 0.0)
	dir = dir.normalized()
	if not _portrait_motion_locked():
		var lean_px := Vector2(dir.x * 3.2, dir.y * 1.8) * _dash_pose_blend
		sp.offset += lean_px
		var lean_rot := deg_to_rad(_DASH_LEAN_DEG) * dir.x * _dash_pose_blend
		sp.rotation = lerpf(sp.rotation, lean_rot, 0.28)
	var stretch := Vector2(
		lerpf(1.0, 1.045, _dash_pose_blend),
		lerpf(1.0, 0.94, _dash_pose_blend)
	)
	sp.scale = Vector2(sp.scale.x * stretch.x, sp.scale.y * stretch.y)


func _play_dash_scale_punch() -> void:
	if _use_body_rig and body_rig:
		body_rig.play_dash_scale_punch()
		return
	var sp := $Sprite2D
	if sp == null or _saved_sprite_scale.length_squared() < 0.0001:
		return
	var tw := create_tween()
	tw.tween_property(sp, "scale", _saved_sprite_scale * 1.07, 0.065).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "scale", _saved_sprite_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func notify_weapon_fired(_wid: StringName) -> void:
	if is_dead:
		return
	if _pose_hit_t > 0.0:
		return
	_pose_attack_t = _POSE_ATTACK_SEC


func _pose_envelope(remaining: float, total: float, in_ratio: float, out_ratio: float) -> float:
	if total <= 0.001 or remaining <= 0.0:
		return 0.0
	var elapsed := total - remaining
	var in_t := total * in_ratio
	var out_t := total * out_ratio
	if elapsed < in_t:
		return clampf(elapsed / maxf(in_t, 0.001), 0.0, 1.0)
	if remaining < out_t:
		return clampf(remaining / maxf(out_t, 0.001), 0.0, 1.0)
	return 1.0


func _pose_hit_blend() -> float:
	return _pose_envelope(_pose_hit_t, _POSE_HIT_SEC, 0.24, 0.42)


func _pose_attack_blend() -> float:
	return _pose_envelope(_pose_attack_t, _POSE_ATTACK_SEC, 0.28, 0.45)


func _estimate_hit_direction() -> Vector2:
	if enemy_manager != null and enemy_manager.has_method("get_closest_enemy_pos"):
		var nearest: Variant = enemy_manager.call("get_closest_enemy_pos", global_position, 520.0)
		if nearest is Vector2:
			var away: Vector2 = global_position - nearest
			if away.length_squared() > 16.0:
				return away.normalized()
	if velocity.length_squared() > 144.0:
		return -velocity.normalized()
	return Vector2(-_last_horiz_facing, -0.12).normalized()


func _ensure_pose_overlay() -> void:
	if _pose_overlay != null:
		return
	var sp: Sprite2D = $Sprite2D
	if sp == null:
		return
	_pose_overlay = Sprite2D.new()
	_pose_overlay.name = "PoseOverlay"
	_pose_overlay.z_index = 1
	_pose_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	sp.add_child(_pose_overlay)


func _get_weapon_aim_dir() -> Vector2:
	var aim := Vector2.ZERO
	if weapon_system != null and weapon_system.has_method("get_auto_weapon_aim_dir"):
		aim = weapon_system.call("get_auto_weapon_aim_dir", global_position) as Vector2
	if aim.length_squared() < 0.0004:
		aim = InputManager.get_aim_direction(global_position)
	return aim


func _apply_pose_sprite_fx(sp: Sprite2D, delta: float) -> void:
	_ensure_pose_overlay()
	if _pose_overlay == null:
		return
	_pose_overlay.flip_h = sp.flip_h
	_pose_overlay.scale = sp.scale
	_pose_overlay.rotation = sp.rotation
	_pose_overlay.offset = sp.offset
	var hit_w := _pose_hit_blend()
	var atk_w := 0.0 if hit_w > 0.01 else _pose_attack_blend()
	if hit_w > 0.01:
		_hit_knock_offset = _hit_knock_offset.lerp(_hit_knock_dir * 6.5, 1.0 - exp(-delta * 22.0))
		if not _portrait_motion_locked():
			sp.offset += _hit_knock_offset * hit_w
		if _tex_hit != null:
			_pose_overlay.texture = _tex_hit
			_pose_overlay.region_enabled = false
			_pose_overlay.modulate = Color(1.0, 0.78, 0.78, hit_w * 0.9)
		else:
			_pose_overlay.texture = null
			_pose_overlay.modulate.a = 0.0
			sp.scale = sp.scale.lerp(_saved_sprite_scale * Vector2(1.02, 0.96), hit_w * 0.35)
	elif atk_w > 0.01:
		_hit_knock_offset = _hit_knock_offset.lerp(Vector2.ZERO, 1.0 - exp(-delta * 14.0))
		var aim := _get_weapon_aim_dir()
		if not _portrait_motion_locked() and aim.length_squared() > 0.0004:
			sp.offset += aim.normalized() * 2.8 * atk_w
		if _tex_attack != null:
			_pose_overlay.texture = _tex_attack
			_pose_overlay.region_enabled = false
			_pose_overlay.modulate = Color(1.0, 1.0, 1.0, atk_w * 0.86)
		else:
			_pose_overlay.texture = null
			_pose_overlay.modulate.a = 0.0
		var atk_sx := _saved_sprite_scale.x * lerpf(1.0, 1.018, atk_w)
		var atk_sy := _saved_sprite_scale.y * lerpf(1.0, 0.982, atk_w)
		sp.scale = sp.scale.lerp(Vector2(atk_sx, atk_sy), atk_w * 0.32)
	else:
		_pose_overlay.texture = null
		_pose_overlay.modulate.a = 0.0
		_hit_knock_offset = _hit_knock_offset.lerp(Vector2.ZERO, 1.0 - exp(-delta * 12.0))


func _finish_sprite_visual(sp: Sprite2D, delta: float) -> void:
	_apply_pose_sprite_fx(sp, delta)
	_tick_dash_sprite_fx(sp, delta)


## 投掷/弹道视觉共用：手上武器子节点世界坐标（与 WeaponSystem._weapon_fire_origin 对齐）
func get_weapon_fire_origin() -> Vector2:
	if weapon_mount != null and is_instance_valid(weapon_mount):
		return weapon_mount.global_position
	return global_position


func get_weapon_mount_node() -> Node2D:
	return weapon_mount


func _update_weapon_hand_mount() -> void:
	if weapon_mount == null or not is_instance_valid(weapon_mount):
		return
	if _use_body_rig and body_rig and body_rig.visible:
		if weapon_system == null or not weapon_system.has_method("get_auto_weapon_aim_dir"):
			weapon_mount.rotation = 0.0
			return
		var aim_r: Vector2 = weapon_system.call("get_auto_weapon_aim_dir", global_position) as Vector2
		if aim_r.length_squared() < 0.0001:
			aim_r = Vector2.RIGHT
		aim_r = aim_r.normalized()
		var parent_n := weapon_mount.get_parent() as Node2D
		if parent_n:
			weapon_mount.rotation = aim_r.angle() - parent_n.global_rotation
		else:
			weapon_mount.rotation = aim_r.angle()
		return
	if weapon_system == null or not weapon_system.has_method("get_auto_weapon_aim_dir"):
		weapon_mount.position = Vector2(_WEAPON_HAND_ALONG_AIM, 0.0)
		weapon_mount.rotation = 0.0
		return
	var aim: Vector2 = weapon_system.call("get_auto_weapon_aim_dir", global_position) as Vector2
	if aim.length_squared() < 0.0001:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	var perp := Vector2(-aim.y, aim.x)
	var side_mul := 1.0
	if absf(_last_horiz_facing) > 0.05:
		side_mul = signf(_last_horiz_facing)
	var hand := aim * _WEAPON_HAND_ALONG_AIM + perp * _WEAPON_HAND_PERP * side_mul
	weapon_mount.position = hand
	weapon_mount.rotation = aim.angle()


func _hook_weapon_to_rig() -> void:
	if not _use_body_rig or body_rig == null or weapon_mount == null:
		return
	var sock: Node2D = body_rig.get_weapon_mount_parent()
	if sock == null:
		return
	if weapon_mount.get_parent() != sock:
		weapon_mount.reparent(sock)
	weapon_mount.position = Vector2.ZERO
	weapon_mount.rotation = 0.0
	weapon_mount.z_index = 8


## 俯视角：用左右镜像代替整图旋转，避免「正面小人被拧成八向」的违和感
func _apply_sprite_topdown_facing(sp: Sprite2D, dir: Vector2) -> void:
	sp.rotation = 0.0
	if dir.length_squared() < 100.0:
		if absf(_facing_smooth_x) > 0.05:
			sp.flip_h = _facing_smooth_x < 0.0
		return
	var nx := dir.normalized().x
	if absf(nx) > 0.1:
		# 朝向缓冲：避免左右移动时瞬时翻面导致“突兀”。
		_facing_smooth_x = lerpf(_facing_smooth_x, nx, 0.16 if fidelity_mode_enabled else 0.35)
		if _facing_smooth_x > 0.18:
			sp.flip_h = false
		elif _facing_smooth_x < -0.18:
			sp.flip_h = true


func _update_player_sprite(delta: float) -> void:
	if _use_body_rig and body_rig != null:
		if body_rig.visible:
			var aim_v := Vector2.ZERO
			if weapon_system != null and weapon_system.has_method("get_auto_weapon_aim_dir"):
				aim_v = weapon_system.call("get_auto_weapon_aim_dir", global_position) as Vector2
			if aim_v.length_squared() < 0.0004:
				aim_v = InputManager.get_aim_direction(global_position)
			body_rig.apply_visual_state(
				delta, velocity, is_dead, _pose_hit_blend(), _pose_attack_blend(),
				aim_v, _last_horiz_facing, _dash_active, _dash_dir
			)
			return
	if _tex_idle == null:
		return
	var sp: Sprite2D = $Sprite2D
	if is_dead:
		if sp.texture != _tex_idle:
			sp.texture = _tex_idle
		sp.region_enabled = false
		sp.flip_h = false
		sp.rotation = 0.0
		sp.offset = Vector2.ZERO
		return
	if _pose_hit_t > 0.0:
		_pose_hit_t = maxf(0.0, _pose_hit_t - delta)
	elif _pose_attack_t > 0.0:
		_pose_attack_t = maxf(0.0, _pose_attack_t - delta)
	if fidelity_mode_enabled:
		var moving_u := clampf(velocity.length() / 220.0, 0.0, 1.0)
		_fidelity_motion_blend = lerpf(_fidelity_motion_blend, moving_u, 0.12)
	if _tex_turn_strip != null and not fidelity_mode_enabled:
		var moving_turn := velocity.length() > _RUN_ANIM_MIN_SPEED
		if moving_turn:
			sp.texture = _tex_turn_strip
			sp.region_enabled = true
			var target_f := 1.0
			if velocity.x < -22.0:
				target_f = 0.0
			elif velocity.x > 22.0:
				target_f = 2.0
			_turn_frame_f = lerpf(_turn_frame_f, target_f, 0.38)
			var tfi: int = clampi(int(round(_turn_frame_f)), 0, 2)
			sp.region_rect = Rect2(float(tfi * _turn_frame_w), 0.0, float(_turn_frame_w), float(_turn_frame_h))
			var turn_bob := sin(Time.get_ticks_msec() * 0.012) * 0.72
			sp.offset.y = lerpf(sp.offset.y, turn_bob, 0.28)
			sp.offset.x = lerpf(sp.offset.x, velocity.x * 0.012, 0.24)
			var speed_u := clampf(velocity.length() / 260.0, 0.0, 1.0)
			var sx := _saved_sprite_scale.x * lerpf(1.0, 1.07, speed_u)
			var sy := _saved_sprite_scale.y * lerpf(1.0, 0.90, speed_u)
			sp.scale = sp.scale.lerp(Vector2(sx, sy), 0.18)
			_apply_sprite_topdown_facing(sp, velocity)
			_finish_sprite_visual(sp, delta)
			return
		sp.texture = _tex_idle
		sp.region_enabled = false
		_turn_frame_f = lerpf(_turn_frame_f, 1.0, 0.2)
		_idle_breath_t += delta
		var idle_breath := sin(_idle_breath_t * 2.05) * 0.42
		sp.offset.y = lerpf(sp.offset.y, idle_breath, 0.24)
		sp.offset.x = lerpf(sp.offset.x, 0.0, 0.22)
		sp.scale = sp.scale.lerp(_saved_sprite_scale, 0.2)
		_apply_sprite_topdown_facing(sp, velocity)
		_finish_sprite_visual(sp, delta)
		return
	if fidelity_mode_enabled:
		var move_u := clampf(velocity.length() / 220.0, 0.0, 1.0)
		_idle_breath_t += delta * lerpf(1.0, 1.55, move_u)
		if _external_portrait_sprite:
			sp.texture = _tex_idle
			sp.region_enabled = false
			_apply_external_portrait_motion(sp, delta)
			_apply_sprite_topdown_facing(sp, velocity)
			_finish_sprite_visual(sp, delta)
			return
		if _tex_run_strip != null and velocity.length() > _RUN_ANIM_MIN_SPEED and _fidelity_motion_blend > 0.06:
			sp.texture = _tex_run_strip
			sp.region_enabled = true
			var step_mul := clampf(velocity.length() / 175.0, 0.55, 1.15)
			_run_anim_accum += delta * _RUN_ANIM_FPS * step_mul * lerpf(0.62, 1.0, _fidelity_motion_blend)
			var fi: int = int(_run_anim_accum) % 3
			sp.region_rect = Rect2(float(fi * _run_frame_w), 0.0, float(_run_frame_w), float(_run_frame_h))
			var bob_raw_f := sin(_run_anim_accum * PI) * 0.2 * _fidelity_motion_blend
			_bob_smoothed = lerpf(_bob_smoothed, bob_raw_f, 0.15)
			sp.offset.y = lerpf(sp.offset.y, _bob_smoothed, 0.13)
			var lean_x_f := clampf(velocity.x * 0.0018, -0.55, 0.55)
			sp.offset.x = lerpf(sp.offset.x, lean_x_f, 0.11)
			var sx2f := _saved_sprite_scale.x * lerpf(1.0, 1.01, _fidelity_motion_blend)
			var sy2f := _saved_sprite_scale.y * lerpf(1.0, 0.99, _fidelity_motion_blend)
			sp.scale = sp.scale.lerp(Vector2(sx2f, sy2f), 0.1)
		else:
			sp.texture = _tex_idle
			sp.region_enabled = false
			_run_anim_accum = lerpf(_run_anim_accum, 0.0, 0.18)
			_bob_smoothed = lerpf(_bob_smoothed, 0.0, 0.2)
			var breath_f := sin(_idle_breath_t * 1.8) * lerpf(0.05, 0.1, move_u)
			sp.offset.y = lerpf(sp.offset.y, breath_f + _bob_smoothed, 0.13)
			var glide_x := clampf(velocity.x * 0.0014, -0.45, 0.45)
			sp.offset.x = lerpf(sp.offset.x, glide_x, 0.1)
			sp.scale = sp.scale.lerp(_saved_sprite_scale, 0.16)
		_apply_sprite_topdown_facing(sp, velocity)
		_finish_sprite_visual(sp, delta)
		return
	if _tex_run_strip != null:
		var moving := velocity.length() > _RUN_ANIM_MIN_SPEED
		if moving:
			sp.texture = _tex_run_strip
			sp.region_enabled = true
			var spd := velocity.length()
			var step_mul := clampf(spd / 175.0, 0.58, 1.38)
			_run_anim_accum += delta * _RUN_ANIM_FPS * step_mul
			var fi: int = int(_run_anim_accum) % 3
			sp.region_rect = Rect2(float(fi * _run_frame_w), 0.0, float(_run_frame_w), float(_run_frame_h))
			if fidelity_mode_enabled:
				# 保形模式：小幅度、强过渡，避免“抽动感”。
				var bob_raw_f := sin(_run_anim_accum * PI) * 0.26 * _fidelity_motion_blend
				_bob_smoothed = lerpf(_bob_smoothed, bob_raw_f, 0.18)
				sp.offset.y = lerpf(sp.offset.y, _bob_smoothed, 0.16)
				var lean_x_f := clampf(velocity.x * 0.0024, -0.8, 0.8)
				sp.offset.x = lerpf(sp.offset.x, lean_x_f, 0.14)
				var sx2f := _saved_sprite_scale.x * lerpf(1.0, 1.006, _fidelity_motion_blend)
				var sy2f := _saved_sprite_scale.y * lerpf(1.0, 0.992, _fidelity_motion_blend)
				sp.scale = sp.scale.lerp(Vector2(sx2f, sy2f), 0.13)
			else:
				var bob_raw := sin(_run_anim_accum * PI) * 1.15
				_bob_smoothed = lerpf(_bob_smoothed, bob_raw, 0.38)
				sp.offset.y = _bob_smoothed
				var lean_x := clampf(velocity.x * 0.01, -_LEAN_MAX_PX, _LEAN_MAX_PX)
				sp.offset.x = lerpf(sp.offset.x, lean_x, _LEAN_FOLLOW)
				var speed_u2 := clampf(spd / 260.0, 0.0, 1.0)
				var sx2 := _saved_sprite_scale.x * lerpf(1.0, 1.03, speed_u2)
				var sy2 := _saved_sprite_scale.y * lerpf(1.0, 0.95, speed_u2)
				sp.scale = sp.scale.lerp(Vector2(sx2, sy2), 0.18)
			_apply_sprite_topdown_facing(sp, velocity)
			_finish_sprite_visual(sp, delta)
			return
		sp.texture = _tex_idle
		sp.region_enabled = false
		_run_anim_accum = 0.0
		_bob_smoothed = lerpf(_bob_smoothed, 0.0, 0.24 if fidelity_mode_enabled else 0.35)
		_idle_breath_t += delta
		var breath := sin(_idle_breath_t * 2.05) * (0.16 if fidelity_mode_enabled else 0.42)
		sp.offset.y = _bob_smoothed + breath
		sp.offset.x = lerpf(sp.offset.x, 0.0, 0.16 if fidelity_mode_enabled else 0.22)
		sp.scale = sp.scale.lerp(_saved_sprite_scale, 0.2)
		_apply_sprite_topdown_facing(sp, velocity)
		_finish_sprite_visual(sp, delta)
		return
	sp.texture = _tex_idle
	sp.region_enabled = false
	_idle_breath_t += delta
	var breath2 := sin(_idle_breath_t * 2.05) * 0.42
	sp.offset.x = lerpf(sp.offset.x, 0.0, 0.2)
	sp.offset.y = breath2
	sp.scale = sp.scale.lerp(_saved_sprite_scale, 0.2)
	_apply_sprite_topdown_facing(sp, velocity)
	_finish_sprite_visual(sp, delta)

func _process(delta: float) -> void:
	if is_dead:
		return
	
	if InputManager.aim_mode != InputManager.AimMode.AUTO:
		InputManager.set_aim_mode(InputManager.AimMode.AUTO)
	InputManager.auto_fire = true
	
	if _iframe_hit_t > 0.0:
		_iframe_hit_t -= delta
	if _iframe_roll_t > 0.0:
		_iframe_roll_t -= delta
	if _archetype_guardian_fx_cd > 0.0:
		_archetype_guardian_fx_cd = maxf(0.0, _archetype_guardian_fx_cd - delta)
	if _archetype_assault_fx_cd > 0.0:
		_archetype_assault_fx_cd = maxf(0.0, _archetype_assault_fx_cd - delta)
	
	# 更新冲刺冷却
	if _dash_cooldown > 0.0:
		_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	if _dash_buffer_t > 0.0:
		_dash_buffer_t = maxf(0.0, _dash_buffer_t - delta)
	if _dash_trail_timer > 0.0:
		_dash_trail_timer -= delta
	
	# 冲刺处理
	if _dash_active:
		_dash_timer -= delta
		velocity = _dash_dir * GameDB.DASH_SPEED
		global_position += velocity * delta
		# 冲刺特效 - 留下残影
		if _dash_trail_timer <= 0.0:
			_dash_trail_timer = 0.03  # 每0.03秒生成一个残影
			EventBus.play_sfx.emit(&"dash_trail", global_position)
		if _dash_timer <= 0.0:
			_dash_active = false
			_dash_cooldown = GameDB.DASH_COOLDOWN * _dash_cooldown_mul
			_dash_trail_timer = 0.0
			# 冲刺结束保留一小段动量，避免“急停发涩”。
			velocity = _dash_dir * minf(_POST_DASH_KEEP_SPEED, move_speed * 1.18)
		if absf(_dash_dir.x) > 0.08:
			_last_horiz_facing = signf(_dash_dir.x)
	else:
		# 冲刺：键盘空格 / 触屏 HUD 按钮
		var dash_press := Input.is_action_just_pressed("dash") or _dash_ui_request
		_dash_ui_request = false
		if dash_press:
			_dash_buffer_t = _DASH_INPUT_BUFFER_SEC
		if _dash_buffer_t > 0.0 and _dash_cooldown <= 0.0:
			var move_vec := InputManager.get_move_vector()
			var dash_dir := Vector2.ZERO
			if move_vec.length() >= _DASH_MIN_INPUT_LEN:
				dash_dir = move_vec.normalized()
			elif velocity.length() >= _DASH_FALLBACK_MIN_SPEED:
				dash_dir = velocity.normalized()
			else:
				dash_dir = Vector2(_last_horiz_facing, 0.0).normalized()
			if dash_dir.length_squared() > 0.0001:
				_dash_active = true
				_dash_buffer_t = 0.0
				_dash_timer = GameDB.DASH_DURATION
				_dash_dir = dash_dir
				_iframe_roll_t = maxf(_iframe_roll_t, GameDB.DASH_IFRAMES)
				_play_dash_scale_punch()
				CombatFeedback.shake("hit", 3.0, 0.1)
				EventBus.play_sfx.emit(&"dash_whoosh", global_position)
				if _run_archetype_id == "assault" and _archetype_assault_fx_cd <= 0.0:
					_archetype_assault_fx_cd = 1.4
					EventBus.screen_flash.emit(Color(0.2, 0.92, 1.0, 0.16), 0.08)
					NotificationSystem.notify_message("突击专精：机动爆发", 0.8, "success")
		
		_handle_movement(delta)
	
	_clamp_to_viewport()
	_apply_hp_growth()
	_apply_invuln_modulate()
	_update_player_sprite(delta)
	_sync_depth_shadow()
	_sync_energy_edge()
	_update_weapon_hand_mount()

func _handle_movement(delta: float) -> void:
	var move_bonus := 0.0
	if skill_system and skill_system.stats.has("move_bonus"):
		move_bonus = float(skill_system.stats["move_bonus"])
	
	var target_speed := move_speed * (1.0 + move_bonus) * _kill_momentum_mul
	target_speed *= _archetype_move_speed_mul
	target_speed *= _map_move_mul
	var gp := get_parent()
	if gp != null and gp.has_method("get_curse_move_speed_mul"):
		target_speed *= float(gp.call("get_curse_move_speed_mul"))
	var move_vec := InputManager.get_move_vector()
	
	if move_vec.length() > 0.01:
		# 保留摇杆幅度：让轻推可慢走，重推可全速，避免“全程同速”手感发硬。
		var desired_velocity := move_vec * target_speed
		# 指数趋近：比线性 move_toward 更「顺」，急转向时略加大一步 lambda
		var lam := _VEL_RESP_LAMBDA
		if velocity.length() > 18.0 and velocity.normalized().dot(desired_velocity.normalized()) < 0.25:
			lam = (turn_accel / 1000.0) * 12.0
		var k := 1.0 - exp(-lam * delta)
		velocity = velocity.lerp(desired_velocity, k)
	else:
		var kb := 1.0 - exp(-_VEL_BRAKE_LAMBDA * delta)
		velocity = velocity.lerp(Vector2.ZERO, kb)
		if velocity.length() < _VEL_STOP_EPS:
			velocity = Vector2.ZERO
	# 地图场拉力：即使站桩也会被推/吸，强制改变走位
	if _map_pull_vel.length_squared() > 0.01:
		velocity += _map_pull_vel
	
	global_position += velocity * delta
	if velocity.length() > 12.0 and absf(velocity.x) > 3.5:
		_last_horiz_facing = signf(velocity.x)

func _clamp_to_viewport() -> void:
	if GameDB.UNLIMITED_WORLD_MOVEMENT:
		return
	var min_x := -GameDB.ARENA_HALF_W + GameDB.PLAYER_BOUND_MARGIN
	var max_x := GameDB.ARENA_HALF_W - GameDB.PLAYER_BOUND_MARGIN
	var min_y := -GameDB.ARENA_HALF_H + GameDB.PLAYER_BOUND_MARGIN
	var max_y := GameDB.ARENA_HALF_H - GameDB.PLAYER_BOUND_MARGIN
	var prev := global_position
	global_position.x = clampf(global_position.x, min_x, max_x)
	global_position.y = clampf(global_position.y, min_y, max_y)
	# 贴边时消除“继续顶墙”的速度分量，减少抖动与滑墙抽风。
	if global_position.x <= min_x + 0.001 and velocity.x < 0.0:
		velocity.x = 0.0
	elif global_position.x >= max_x - 0.001 and velocity.x > 0.0:
		velocity.x = 0.0
	if global_position.y <= min_y + 0.001 and velocity.y < 0.0:
		velocity.y = 0.0
	elif global_position.y >= max_y - 0.001 and velocity.y > 0.0:
		velocity.y = 0.0
	if prev != global_position and _dash_active:
		# 冲刺贴边时让轨迹自然结束，避免持续“顶墙位移”。
		_dash_active = false
		_dash_timer = 0.0
		_dash_cooldown = maxf(_dash_cooldown, GameDB.DASH_COOLDOWN * 0.85 * _dash_cooldown_mul)


# 唯一伤害入口：敌人通过此方法造成伤害
# EnemyManager/BOSS 直接调用此方法而非通过信号
func _is_damage_immune() -> bool:
	return _iframe_hit_t > 0.0 or _iframe_roll_t > 0.0


func _apply_invuln_modulate() -> void:
	if _dash_active:
		modulate = Color(0.5, 0.9, 1.0, 0.7)
	elif _iframe_hit_t > 0.0:
		var blink := sin(Time.get_ticks_msec() * 0.018) > 0.0
		modulate = Color(1.0, 0.48, 0.48, 1.0) if blink else Color(1.0, 0.82, 0.82, 0.38)
	elif _iframe_roll_t > 0.0:
		modulate = Color(0.72, 0.92, 1.0, 0.84)
	else:
		modulate = Color.WHITE


func take_damage(amount: float) -> void:
	if is_dead or _is_damage_immune():
		return
	
	# 计算减伤
	var reduction := 0.0
	if skill_system and skill_system.stats.has("dr"):
		reduction = float(skill_system.stats["dr"])

	var actual_damage := maxf(1.0, amount * (1.0 - reduction))
	
	# ========== 护盾系统 ==========
	var skill_sys = get_parent().get_node_or_null("SkillSystem")
	if skill_sys and skill_sys.has_shield_passive():
		var shield: float = skill_sys.get_shield()
		if shield > 0:
			# 先消耗护盾
			if skill_sys.consume_shield(actual_damage):
				# 护盾完全吸收伤害
				EventBus.screen_flash.emit(Color(0.3, 0.6, 1.0, 0.3), 0.1)
				NotificationSystem.notify_message("护盾吸收伤害！", 0.5, "info")
				return
			else:
				# 护盾部分吸收
				var remaining := actual_damage - shield
				skill_sys.consume_shield(shield)
				actual_damage = remaining
				EventBus.screen_flash.emit(Color(0.3, 0.6, 1.0, 0.2), 0.08)

	if _run_archetype_id == "guardian" and _archetype_guardian_fx_cd <= 0.0:
		_archetype_guardian_fx_cd = 1.25
		EventBus.screen_flash.emit(Color(0.35, 0.78, 1.0, 0.18), 0.1)
		NotificationSystem.notify_message("守护专精：稳态抗压", 0.8, "info")
	
	# 实际扣血
	hp -= actual_damage
	_pose_hit_t = _POSE_HIT_SEC
	_pose_attack_t = 0.0
	_hit_knock_dir = _estimate_hit_direction()
	
	# 发射实际伤害事件（仅一次，供HUD/统计使用）
	EventBus.player_damaged.emit(actual_damage)
	
	# 屏幕震动
	if actual_damage > 8:
		var sh := clampf(4.0 + actual_damage * 0.09, 5.0, 8.5)
		CombatFeedback.shake("player_hit", sh, 0.26)
	
	if damage_flash:
		damage_flash.visible = true
		var tween := create_tween()
		tween.tween_property(damage_flash, "modulate:a", 0.0, 0.15)
		tween.tween_callback(func(): damage_flash.visible = false)
	
	_iframe_hit_t = GameDB.HIT_IFRAMES_SEC
	
	# 检查死亡
	if hp <= 0:
		hp = 0
		_die()

func heal(amount: float) -> void:
	if is_dead:
		return
	
	var old_hp := hp
	hp = minf(hp + amount, max_hp)
	var healed := hp - old_hp
	
	if healed > 0:
		EventBus.player_healed.emit(healed)


## 造成伤害时触发吸血（由 EnemyManager / WeaponSystem 在结算后调用）
func apply_lifesteal_from_damage(dealt: float) -> void:
	if is_dead or dealt <= 0.0:
		return
	var lifesteal := 0.0
	if skill_system and skill_system.stats.has("lifesteal"):
		lifesteal = float(skill_system.stats["lifesteal"])
	if lifesteal <= 0.0:
		return
	heal(dealt * lifesteal)

func _die() -> void:
	is_dead = true
	_kill_momentum_mul = 1.0
	_has_transformed_this_run = false
	if body_rig:
		body_rig.set_form(PlayerBodyRig.RigForm.BASE)
	EventBus.player_died.emit()
	visible = false
	set_process(false)

func get_hp_ratio() -> float:
	return hp / maxf(max_hp, 1.0)

# 辅助：绘制填充圆
func _draw_circle_filled(img: Image, cx: float, cy: float, radius: float, col: Color, bottom_half := false) -> void:
	var size := img.get_width()
	for y in range(max(0, int(cy - radius)), min(size, int(cy + radius + 1.0))):
		for x in range(max(0, int(cx - radius)), min(size, int(cx + radius + 1.0))):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if bottom_half and dy < 0:
				continue
			if dx * dx + dy * dy <= radius * radius:
				var existing: Color = img.get_pixel(x, y)
				if existing.a < col.a:
					img.set_pixel(x, y, col)

# 辅助：绘制填充椭圆
func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var size := img.get_width()
	for y in range(max(0, int(cy - ry)), min(size, int(cy + ry + 1.0))):
		for x in range(max(0, int(cx - rx)), min(size, int(cx + rx + 1.0))):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.0:
				var existing: Color = img.get_pixel(x, y)
				if existing.a < col.a:
					img.set_pixel(x, y, col)

# 辅助：绘制圆角矩形
func _draw_rounded_rect(img: Image, x: float, y: float, w: float, h: float, r: float, col: Color) -> void:
	var size := img.get_width()
	var r_clamped := minf(r, minf(w, h) / 2.0)
	for py in range(max(0, int(y)), min(size, int(y + h + 1.0))):
		for px in range(max(0, int(x)), min(size, int(x + w + 1.0))):
			var dx := float(px)
			var dy := float(py)
			var inside := true
			# 检查四个角的圆角区域
			var in_corner := false
			var cdx: float = 0.0
			var cdy: float = 0.0
			var corner_data: Array = [[x + r_clamped, y + r_clamped], [x + w - r_clamped, y + r_clamped], [x + r_clamped, y + h - r_clamped], [x + w - r_clamped, y + h - r_clamped]]
			for c in corner_data:
				cdx = dx - float(c[0])
				cdy = dy - float(c[1])
				if (dx < x + r_clamped or dx > x + w - r_clamped) and (dy < y + r_clamped or dy > y + h - r_clamped):
					in_corner = true
					if cdx * cdx + cdy * cdy > r_clamped * r_clamped:
						inside = false
					break
			if inside:
				var existing: Color = img.get_pixel(px, py)
				if existing.a < col.a:
					img.set_pixel(px, py, col)

# HP成长被动应用（含局外 Meta、局内遗物对 hp_growth 的加减）
func _apply_hp_growth() -> void:
	if skill_system == null or not skill_system.stats.has("hp_growth"):
		return
	var growth: float = float(skill_system.stats["hp_growth"])
	var target_max := maxf(100.0 + growth, 40.0)
	if is_equal_approx(max_hp, target_max):
		return
	var old_max := max_hp
	max_hp = target_max
	if max_hp > old_max:
		hp += (max_hp - old_max)
	else:
		hp = minf(hp, max_hp)
