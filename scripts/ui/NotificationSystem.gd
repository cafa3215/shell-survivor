extends CanvasLayer

# 通知系统 - 美化版提示信息
# 使用方式: NotificationSystem.push("消息内容", 类型)
# 类型可选: "info", "success", "warning", "error", "item", "achievement"

const DEFAULT_DURATION := 2.5
const NOTIFY_Z_INDEX := 200

# 通知配置
const CONFIGS := {
	"info": {"icon": "ℹ️", "variation": &"Notification"},
	"success": {"icon": "✅", "variation": &"NotificationSuccess"},
	"warning": {"icon": "⚠️", "variation": &"NotificationWarning"},
	"error": {"icon": "❌", "variation": &"NotificationWarning"},
	"item": {"icon": "⭐", "variation": &"NotificationSuccess"},
	"achievement": {"icon": "🏆", "variation": &"NotificationSuccess"}
}

var _queue: Array[Dictionary] = []
var _current: Control = null
var _showing := false

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _ready() -> void:
	EventBus.notification_shown.connect(_on_notification_requested)
	visible = false

func _on_notification_requested(msg: String, duration := DEFAULT_DURATION, type := "info") -> void:
	_queue.append({"msg": msg, "duration": duration, "type": type})
	if not _showing:
		_show_next()

func _exit_tree() -> void:
	_showing = false
	_queue.clear()
	if _current:
		_current.queue_free()
		_current = null

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	
	_showing = true
	visible = true
	var data := _queue.pop_front() as Dictionary
	var cfg := CONFIGS.get(data.type, CONFIGS["info"]) as Dictionary
	
	# 清理旧的
	if _current:
		_current.queue_free()
	
	# 创建通知
	var notify := _create_notification(data.msg, cfg, String(data.type))
	_current = notify
	add_child(notify)
	
	# 动画序列
	var tween := create_tween().set_trans(UIMotion.TRANS_ENTRANCE).set_ease(UIMotion.EASE_OUT).set_parallel(true)
	
	# 滑入
	var target_x := _viewport_size().x - notify.size.x - 20.0
	notify.position.x = _viewport_size().x
	tween.tween_property(notify, "position:x", target_x, UIMotion.MOTION_PANEL)

	# 等待后滑出
	if not is_inside_tree():
		return
	await get_tree().create_timer(maxf(data.duration, 1.0)).timeout
	if not is_inside_tree():
		return
	
	tween = create_tween().set_trans(UIMotion.TRANS_ENTRANCE).set_ease(UIMotion.EASE_IN_OUT).set_parallel(true)
	tween.tween_property(notify, "position:x", _viewport_size().x + 50.0, UIMotion.MOTION_PANEL)
	
	await tween.finished
	if not is_inside_tree():
		return
	notify.queue_free()
	_show_next()

func _create_notification(msg: String, cfg: Dictionary, ntype: String) -> Control:
	var root := PanelContainer.new()
	root.z_index = NOTIFY_Z_INDEX
	root.theme_type_variation = cfg.get("variation", &"Notification")
	root.custom_minimum_size = Vector2(400, 70)
	root.clip_contents = true

	var vp_size := _viewport_size()
	root.size = root.custom_minimum_size
	root.position = Vector2(vp_size.x - root.size.x - 20.0, vp_size.y * 0.12)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	root.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var icon := Label.new()
	icon.text = cfg.icon
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(36, 0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.theme_type_variation = &"Meta"
	hbox.add_child(icon)

	var label := Label.new()
	label.text = msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(300, 0)
	label.theme_type_variation = _notification_label_variation(ntype)
	hbox.add_child(label)

	return root

func _notification_label_variation(ntype: String) -> StringName:
	match ntype:
		"warning", "error":
			return &"NotificationWarning"
		"success", "item", "achievement":
			return &"NotificationSuccess"
		_:
			return &"Notification"

# 静态便捷方法（避免与 Node.show 冲突，使用 push）
static func notify_message(msg: String, duration := DEFAULT_DURATION, type := "info") -> void:
	EventBus.notification_shown.emit(msg, duration, type)

# 特殊通知类型
static func show_weapon_acquired(name: String) -> void:
	notify_message("获得新武器: " + name, 3.0, "item")

static func show_weapon_upgraded(name: String, level: int) -> void:
	notify_message(name + " 升级至 等级." + str(level), 2.5, "success")

static func show_passive_acquired(name: String) -> void:
	notify_message("获得被动: " + name, 3.0, "item")

static func show_fusion_ready(fusion_name: String) -> void:
	notify_message("融合可激活: " + fusion_name, 4.0, "achievement")

static func show_boss_warning() -> void:
	notify_message("⚠️ 首领即将来袭!", 3.0, "warning")
