extends Control
class_name RunRelicPickPanel

signal relic_chosen(rid: String)
signal option_chosen(id: String)

@onready var _title: Label = $Title
@onready var _hint: Label = $HintLabel
@onready var _bottom: Label = $BottomHint
@onready var _c1: Button = $CardRow/Card1
@onready var _c2: Button = $CardRow/Card2
@onready var _c3: Button = $CardRow/Card3
@onready var _dim_bg: Panel = $DimBg
@onready var _background: Panel = $Background
@onready var _card_row: HBoxContainer = $CardRow

var _ids: PackedStringArray = []
var _picked := false
var _closing := false
var _buttons: Array[Button] = []
var _generic_mode := false
var _generic_options: Array[Dictionary] = []
@export var esc_close_hint_enabled: bool = false
@export var esc_close_hint_text: String = "本次未选择"
var _title_text := "战备遗物 · 三选一"
var _hint_text := "本局仅生效一次；与升级三选一构筑分轨。"
var _bottom_text := "点击选择，或按数字键 1 / 2 / 3"

func _ready() -> void:
	set_process_unhandled_input(true)
	visible = true
	_closing = false
	_buttons = [_c1, _c2, _c3]
	_c1.pressed.connect(func() -> void: _emit_pick(0))
	_c2.pressed.connect(func() -> void: _emit_pick(1))
	_c3.pressed.connect(func() -> void: _emit_pick(2))
	for b in _buttons:
		b.pivot_offset = b.size * 0.5
		b.mouse_entered.connect(func() -> void: _set_card_hover(b, true))
		b.mouse_exited.connect(func() -> void: _set_card_hover(b, false))
	_apply_responsive_layout()
	_apply_copy()
	_apply_cards()
	call_deferred("_play_intro_anim")


func configure(ids: PackedStringArray) -> void:
	visible = true
	set_process_unhandled_input(true)
	_closing = false
	_generic_mode = false
	_generic_options.clear()
	_ids = ids
	_picked = false
	_title_text = "战备遗物 · 三选一"
	_hint_text = "本局仅生效一次；与升级三选一构筑分轨。"
	_bottom_text = "点击选择，或按数字键 1 / 2 / 3"
	_apply_copy()
	_apply_cards()
	call_deferred("_play_intro_anim")


func configure_generic(title: String, hint: String, bottom_hint: String, options: Array[Dictionary]) -> void:
	visible = true
	set_process_unhandled_input(true)
	_closing = false
	_generic_mode = true
	_generic_options = options.duplicate(true)
	_ids = PackedStringArray()
	for d in _generic_options:
		_ids.append(String(d.get("id", "")))
	_picked = false
	_title_text = title
	_hint_text = hint
	_bottom_text = bottom_hint
	_apply_copy()
	_apply_cards()
	call_deferred("_play_intro_anim")


func _apply_cards() -> void:
	if _buttons.is_empty():
		return
	for i in _buttons.size():
		var b: Button = _buttons[i]
		if i < _ids.size():
			var pick_id := String(_ids[i])
			b.visible = true
			b.disabled = false
			if _generic_mode:
				var gdef: Dictionary = _generic_options[i] if i < _generic_options.size() else {}
				var tag := String(gdef.get("tag", "专精"))
				var nm := String(gdef.get("name", pick_id))
				var ds := String(gdef.get("desc", ""))
				b.text = _build_card_text(tag, nm, ds)
			else:
				var def: Dictionary = GameDB.RUN_RELICS.get(pick_id, {}) as Dictionary
				var nm := String(def.get("name", pick_id))
				var ds := String(def.get("desc", ""))
				b.text = _build_card_text("遗物", nm, ds)
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			b.modulate = Color(1.0, 1.0, 1.0, 1.0)
			b.scale = Vector2.ONE
			b.theme_type_variation = &"CardNormal"
		else:
			b.visible = false
			b.disabled = true


func _emit_pick(idx: int) -> void:
	if _picked or _closing or idx < 0 or idx >= _ids.size():
		return
	_picked = true
	for b in _buttons:
		b.disabled = true
		b.modulate = Color(0.78, 0.82, 0.9, 0.82)
	var chosen := _buttons[idx]
	chosen.modulate = Color(1.15, 1.08, 0.92, 1.0)
	chosen.scale = Vector2(1.03, 1.03)
	var id := String(_ids[idx])
	_play_confirm_then_emit(id, chosen)


func _unhandled_input(event: InputEvent) -> void:
	if _picked or _closing or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var e := event as InputEventKey
		match e.keycode:
			KEY_1:
				_emit_pick(0)
			KEY_2:
				_emit_pick(1)
			KEY_3:
				_emit_pick(2)
			KEY_ESCAPE:
				_emit_esc_close_hint()
				_play_close_anim()


func _apply_copy() -> void:
	if _title:
		_title.text = _title_text
	if _hint:
		_hint.text = _hint_text
	if _bottom:
		_bottom.text = _bottom_text


func _build_card_text(tag: String, name_text: String, desc_text: String) -> String:
	var d := desc_text.replace("，", "，\n")
	d = d.replace("。", "。\n")
	d = d.strip_edges()
	return "【%s】%s\n%s" % [tag, name_text, d]


func _apply_responsive_layout() -> void:
	var vr := get_viewport_rect().size
	if vr.x <= 1.0 or vr.y <= 1.0:
		return
	var panel_w := clampf(vr.x * 0.86, 780.0, 1120.0)
	var panel_h := clampf(vr.y * 0.60, 330.0, 500.0)
	_background.offset_left = -panel_w * 0.5
	_background.offset_top = -panel_h * 0.5
	_background.offset_right = panel_w * 0.5
	_background.offset_bottom = panel_h * 0.5
	_title.offset_left = -panel_w * 0.40
	_title.offset_right = panel_w * 0.40
	_title.offset_top = -panel_h * 0.44
	_title.offset_bottom = -panel_h * 0.30
	_hint.offset_left = -panel_w * 0.42
	_hint.offset_right = panel_w * 0.42
	_hint.offset_top = -panel_h * 0.30
	_hint.offset_bottom = -panel_h * 0.20
	_card_row.offset_left = -panel_w * 0.46
	_card_row.offset_right = panel_w * 0.46
	_card_row.offset_top = -panel_h * 0.16
	_card_row.offset_bottom = panel_h * 0.28
	_bottom.offset_left = -panel_w * 0.30
	_bottom.offset_right = panel_w * 0.30
	_bottom.offset_top = panel_h * 0.34
	_bottom.offset_bottom = panel_h * 0.43
	if _dim_bg:
		_dim_bg.modulate = Color(0.0, 0.0, 0.0, 0.72)
	if _card_row:
		_card_row.add_theme_constant_override("separation", 14)
	var card_w := maxf(220.0, floor((_card_row.size.x - 28.0) / 3.0))
	for b in _buttons:
		b.pivot_offset = Vector2(card_w * 0.5, 84.0)
		b.custom_minimum_size = Vector2(card_w, 168.0)


func _set_card_hover(btn: Button, hover: bool) -> void:
	if btn == null or _picked or _closing or btn.disabled:
		return
	var tw := create_tween()
	if hover:
		btn.modulate = Color(1.08, 1.08, 1.08, 1.0)
		tw.tween_property(btn, "scale", Vector2(1.015, 1.015), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_intro_anim() -> void:
	# 弹窗整体先淡入，再让三张卡片按顺序轻微弹出。
	if _dim_bg:
		_dim_bg.modulate.a = 0.0
	if _background:
		_background.modulate.a = 0.0
	if _title:
		_title.modulate.a = 0.0
	if _hint:
		_hint.modulate.a = 0.0
	if _bottom:
		_bottom.modulate.a = 0.0
	for i in _buttons.size():
		var b: Button = _buttons[i]
		if not b.visible:
			continue
		b.scale = Vector2(0.92, 0.92)
		b.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tw := create_tween()
	if _dim_bg:
		tw.parallel().tween_property(_dim_bg, "modulate:a", 0.72, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _background:
		tw.parallel().tween_property(_background, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _title:
		tw.parallel().tween_property(_title, "modulate:a", 1.0, 0.15).set_delay(0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _hint:
		tw.parallel().tween_property(_hint, "modulate:a", 1.0, 0.15).set_delay(0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _bottom:
		tw.parallel().tween_property(_bottom, "modulate:a", 1.0, 0.15).set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in _buttons.size():
		var card: Button = _buttons[i]
		if not card.visible:
			continue
		var d := 0.10 + float(i) * 0.06
		tw.parallel().tween_property(card, "modulate:a", 1.0, 0.14).set_delay(d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.18).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_confirm_then_emit(id: String, chosen: Button) -> void:
	if _closing:
		return
	_closing = true
	set_process_unhandled_input(false)
	var tw := create_tween()
	tw.tween_interval(0.12)
	if chosen:
		tw.parallel().tween_property(chosen, "scale", Vector2(1.06, 1.06), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(chosen, "modulate", Color(1.2, 1.12, 0.95, 1.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if _generic_mode:
			option_chosen.emit(id)
		else:
			relic_chosen.emit(id)
		_play_close_anim(true)
	)


func _play_close_anim(force: bool = false) -> void:
	if _closing and not force:
		return
	_closing = true
	set_process_unhandled_input(false)
	for b in _buttons:
		b.disabled = true
	var tw := create_tween()
	if _dim_bg:
		tw.parallel().tween_property(_dim_bg, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _background:
		tw.parallel().tween_property(_background, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_background, "scale", Vector2(0.985, 0.985), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _title:
		tw.parallel().tween_property(_title, "modulate:a", 0.0, 0.1)
	if _hint:
		tw.parallel().tween_property(_hint, "modulate:a", 0.0, 0.1)
	if _bottom:
		tw.parallel().tween_property(_bottom, "modulate:a", 0.0, 0.1)
	for b in _buttons:
		if b.visible:
			tw.parallel().tween_property(b, "modulate:a", 0.0, 0.08)
	tw.tween_callback(func() -> void:
		visible = false
	)


func _emit_esc_close_hint() -> void:
	if not esc_close_hint_enabled:
		return
	var msg := esc_close_hint_text.strip_edges()
	if msg.is_empty():
		msg = "本次未选择"
	var eb := get_tree().root.get_node_or_null("EventBus")
	if eb != null and eb.has_signal("notification_shown"):
		NotificationSystem.notify_message(msg, 0.9, "info")
