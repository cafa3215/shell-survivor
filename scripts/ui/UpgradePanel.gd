extends Control
class_name UpgradePanel

@onready var c1: Button = $Background/Margin/VBox/CardRow/Card1
@onready var c2: Button = $Background/Margin/VBox/CardRow/Card2
@onready var c3: Button = $Background/Margin/VBox/CardRow/Card3
var _ids: Array[String] = []
var _weapon_system: Node = null
var _skill_system: Node = null
var _is_picking := false
var _card_buttons: Array[Button] = []
var _card_recommended: Array[bool] = [false, false, false]
var _hovered_card_idx := -1
var _upgrade_system: Node = null
var _service_row: HBoxContainer = null
var _reroll_btn: Button = null
var _ban_btn: Button = null
var _scrap_label: Label = null
var _ban_mode := false

func _ready() -> void:
	_card_buttons = [c1, c2, c3]
	for b in _card_buttons:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 118)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.0
	InputManager.bind_instant_tap(c1, func(): _pick(0))
	InputManager.bind_instant_tap(c2, func(): _pick(1))
	InputManager.bind_instant_tap(c3, func(): _pick(2))
	for i in _card_buttons.size():
		var b := _card_buttons[i]
		b.mouse_entered.connect(func() -> void:
			_on_card_hover(i)
		)
		b.focus_entered.connect(func() -> void:
			_on_card_hover(i)
		)
		b.mouse_exited.connect(func() -> void:
			_hovered_card_idx = -1
			_refresh_card_variations()
			_reset_card_scales()
		)
	call_deferred("_cache_refs")
	call_deferred("_ensure_service_row")


func _ensure_service_row() -> void:
	if _service_row != null and is_instance_valid(_service_row):
		return
	var vbox := get_node_or_null("Background/Margin/VBox") as VBoxContainer
	if vbox == null:
		return
	_service_row = HBoxContainer.new()
	_service_row.name = "ServiceRow"
	_service_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_service_row.add_theme_constant_override("separation", 10)
	_scrap_label = Label.new()
	_scrap_label.theme_type_variation = &"Label.Meta"
	_scrap_label.text = "碎片 0"
	_service_row.add_child(_scrap_label)
	_reroll_btn = Button.new()
	_reroll_btn.text = "重抽"
	_reroll_btn.theme_type_variation = &"Button.Secondary"
	InputManager.bind_instant_tap(_reroll_btn, func() -> void:
		if _upgrade_system and _upgrade_system.has_method("try_scrap_reroll"):
			_upgrade_system.call("try_scrap_reroll")
	)
	_service_row.add_child(_reroll_btn)
	_ban_btn = Button.new()
	_ban_btn.text = "排除"
	_ban_btn.theme_type_variation = &"Button.Secondary"
	InputManager.bind_instant_tap(_ban_btn, func() -> void:
		_ban_mode = true
		if _scrap_label:
			_scrap_label.text = "点选要排除的卡片"
	)
	_service_row.add_child(_ban_btn)
	var card_row := vbox.get_node_or_null("CardRow")
	if card_row:
		vbox.add_child(_service_row)
		vbox.move_child(_service_row, card_row.get_index())


func _cache_refs() -> void:
	var game := get_parent().get_parent()
	if game:
		_weapon_system = game.get_node_or_null("WeaponSystem")
		_skill_system = game.get_node_or_null("SkillSystem")
	var up_sys := get_parent()
	if up_sys:
		_upgrade_system = up_sys


func _refresh_service_buttons(service_state: Dictionary) -> void:
	if _scrap_label == null:
		call_deferred("_ensure_service_row")
		return
	var scrap := int(service_state.get("scrap", MetaProgress.scrap))
	var reroll_cost := int(service_state.get("reroll_cost", GameDB.RUN_SCRAP_REROLL_COST))
	var ban_cost := int(service_state.get("ban_cost", GameDB.RUN_SCRAP_BAN_COST))
	var reroll_used := bool(service_state.get("reroll_used", false))
	var ban_used := bool(service_state.get("ban_used", false))
	_scrap_label.text = "战备碎片 %d" % scrap
	if _reroll_btn:
		_reroll_btn.text = "重抽 (-%d)" % reroll_cost
		_reroll_btn.disabled = reroll_used or scrap < reroll_cost
	if _ban_btn:
		_ban_btn.text = "排除 (-%d)" % ban_cost
		_ban_btn.disabled = ban_used or scrap < ban_cost


func open_with_options(opts: Array, service_state: Dictionary = {}) -> void:
	visible = true
	_is_picking = false
	_ids.clear()
	for i in 3:
		var btn: Button = [c1, c2, c3][i]
		if i < opts.size():
			var id := ""
			var recommended := false
			var synergy := false
			var hint := ""
			if opts[i] is Dictionary:
				var d: Dictionary = opts[i]
				id = String(d.get("id", ""))
				recommended = bool(d.get("recommended", false))
				synergy = bool(d.get("synergy", false))
				hint = String(d.get("hint", ""))
			else:
				id = String(opts[i])
			_ids.append(id)
			btn.visible = true
			btn.disabled = false
			btn.scale = Vector2.ONE
			btn.text = _label_of(id, recommended, synergy, hint)
			_card_recommended[i] = recommended
		else:
			btn.visible = false
			btn.disabled = true
			_card_recommended[i] = false
	_hovered_card_idx = -1
	_ban_mode = false
	_refresh_service_buttons(service_state)
	_refresh_card_variations()
	_reset_card_scales()
	call_deferred("_apply_responsive_layout")

func _apply_responsive_layout() -> void:
	var bg := get_node_or_null("Background") as PanelContainer
	if bg == null:
		return
	var vr := get_viewport_rect().size
	if vr.x <= 1.0 or vr.y <= 1.0:
		return
	var panel_w := clampf(vr.x * 0.86, 820.0, 1120.0)
	var panel_h := clampf(vr.y * 0.58, 340.0, 480.0)
	bg.offset_left = -panel_w * 0.5
	bg.offset_top = -panel_h * 0.5
	bg.offset_right = panel_w * 0.5
	bg.offset_bottom = panel_h * 0.5

func _pick(i: int) -> void:
	if i >= _ids.size() or _is_picking:
		return
	if _ban_mode:
		if _upgrade_system and _upgrade_system.has_method("try_scrap_ban_option"):
			if _upgrade_system.call("try_scrap_ban_option", i):
				_ban_mode = false
		return
	_is_picking = true
	var chosen := StringName(_ids[i])
	for idx in _card_buttons.size():
		var b := _card_buttons[idx]
		b.disabled = true
	_apply_selected_state(i)
	var picked_btn := _card_buttons[i]
	picked_btn.modulate = Color(0.38, 1.0, 1.15, 1.0)
	picked_btn.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_trans(UIMotion.TRANS_SNAP).set_ease(UIMotion.EASE_SNAP)
	tw.tween_property(picked_btn, "scale", Vector2.ONE * 1.08, UIMotion.MOTION_UI_FEEDBACK)
	tw.set_trans(UIMotion.TRANS_ENTRANCE).set_ease(UIMotion.EASE_OUT)
	tw.tween_property(picked_btn, "scale", Vector2.ONE, UIMotion.MOTION_UI_FEEDBACK)
	EventBus.play_sfx.emit(&"upgrade_pick", Vector2.ZERO)
	CombatFeedback.shake("ui", 2.3, 0.08)
	visible = false
	EventBus.upgrade_selected.emit(chosen)

func _refresh_card_variations() -> void:
	for idx in _card_buttons.size():
		var b := _card_buttons[idx]
		if not b.visible:
			continue
		b.theme_type_variation = _variation_for_state(idx)

func _variation_for_state(idx: int) -> StringName:
	if _hovered_card_idx == idx:
		return &"Card.Hover"
	if idx >= 0 and idx < _card_recommended.size() and _card_recommended[idx]:
		return &"Card.Recommended"
	return &"Card.Normal"

func _apply_selected_state(selected_idx: int) -> void:
	for idx in _card_buttons.size():
		var b := _card_buttons[idx]
		if not b.visible:
			continue
		if idx == selected_idx:
			b.theme_type_variation = &"Card.Hover"
		elif idx >= 0 and idx < _card_recommended.size() and _card_recommended[idx]:
			b.theme_type_variation = &"Card.Recommended"
		else:
			b.theme_type_variation = &"Card.Normal"

func _reset_card_scales() -> void:
	for b in _card_buttons:
		if b.visible:
			b.scale = Vector2.ONE

func _on_card_hover(i: int) -> void:
	if _is_picking:
		return
	_hovered_card_idx = i
	_refresh_card_variations()
	for idx in _card_buttons.size():
		var b := _card_buttons[idx]
		if not b.visible:
			continue
		var target := Vector2.ONE * (1.03 if idx == i else 1.0)
		b.scale = b.scale.lerp(target, 0.42)

func _label_of(id: String, recommended := false, synergy := false, hint := "") -> String:
	var lines: PackedStringArray = []
	var name := _display_name(id)
	if recommended:
		lines.append("★ " + name)
	elif synergy:
		lines.append("◆ " + name)
	else:
		lines.append(name)
	var lv_line := _level_line(id)
	if not lv_line.is_empty():
		lines.append(lv_line)
	var effect := _compact_effect(id, hint)
	if not effect.is_empty():
		lines.append(effect)
	return "\n".join(lines)

func _display_name(id: String) -> String:
	if id.begins_with("w:"):
		var wid := id.trim_prefix("w:")
		return String(GameDB.WEAPONS.get(wid, {}).get("name", wid))
	if id.begins_with("p:"):
		var pid := id.trim_prefix("p:")
		return String(GameDB.PASSIVES.get(pid, {}).get("name", pid))
	if id.begins_with("m:"):
		var mid := id.trim_prefix("m:")
		var raw := String(GameDB.MUTATIONS.get(mid, {}).get("name", mid))
		return raw.replace("异变·", "")
	if id.begins_with("f:"):
		var fid := id.trim_prefix("f:")
		var wid := String(GameDB.FUSIONS.get(fid, {}).get("weapon", ""))
		if not wid.is_empty():
			return String(GameDB.WEAPONS.get(wid, {}).get("name", wid)) + "·超武"
		return fid.replace("_ex", "")
	return id

func _level_line(id: String) -> String:
	if id.begins_with("w:"):
		var wid := id.trim_prefix("w:")
		if _weapon_system:
			var cur_lv := int(_weapon_system.level_map.get(wid, 0))
			if cur_lv > 0:
				return "Lv.%d → %d" % [cur_lv, mini(cur_lv + 1, 5)]
			return "新武器"
	elif id.begins_with("p:"):
		var pid := id.trim_prefix("p:")
		if _skill_system and GameDB.PASSIVES.has(pid):
			var cur_lv := int(_skill_system.passive_levels.get(pid, 0))
			var max_lv := int(GameDB.PASSIVES[pid]["max_lv"])
			return "Lv.%d → %d" % [cur_lv, mini(cur_lv + 1, max_lv)]
	elif id.begins_with("m:"):
		var mid := id.trim_prefix("m:")
		if _skill_system and GameDB.MUTATIONS.has(mid):
			var cur_m := int(_skill_system.get_mutation_level(mid))
			var max_m := int(GameDB.MUTATIONS[mid]["max_lv"])
			return "层 %d → %d" % [cur_m, mini(cur_m + 1, max_m)]
	elif id.begins_with("f:"):
		return "Lv.5 → 6"
	return ""

func _compact_effect(id: String, hint: String) -> String:
	if id.begins_with("p:"):
		var pid := id.trim_prefix("p:")
		var fx := SkillSystem.passive_upgrade_effect_text(pid)
		if not fx.is_empty():
			return fx
	elif id.begins_with("m:"):
		var mid := id.trim_prefix("m:")
		if GameDB.MUTATIONS.has(mid):
			var sp: Dictionary = GameDB.MUTATIONS[mid].get("stats_per_lv", {}) as Dictionary
			for sk in sp.keys():
				return _mutation_stat_short(String(sk), float(sp[sk]))
	elif id.begins_with("f:"):
		var fid := id.trim_prefix("f:")
		if GameDB.FUSIONS.has(fid):
			return String(GameDB.FUSIONS[fid].get("desc", "武器质变"))
	elif id.begins_with("w:"):
		var wid := id.trim_prefix("w:")
		var cur_lv := 0
		if _weapon_system:
			cur_lv = int(_weapon_system.level_map.get(wid, 0))
			if cur_lv > 0:
				for fid in GameDB.FUSIONS.keys():
					var f: Dictionary = GameDB.FUSIONS[fid]
					if String(f["weapon"]) == wid and cur_lv + 1 >= 5:
						return "可融合"
		if not hint.is_empty() and hint.length() <= 14:
			return hint
		if cur_lv > 0:
			return "火力提升"
		return ""
	if not hint.is_empty() and hint.length() <= 16:
		return hint
	return ""

func _mutation_stat_short(stat_key: String, per_lv: float) -> String:
	match stat_key:
		"atk_bonus":
			return "攻击 +%d%%" % int(round(per_lv * 100.0))
		"move_bonus":
			return "移速 +%d%%" % int(round(per_lv * 100.0))
		"dr":
			return "减伤 +%d%%" % int(round(per_lv * 100.0))
		"lifesteal":
			return "吸血 +%d%%" % int(round(per_lv * 100.0))
		"xp_bonus":
			return "经验 +%d%%" % int(round(per_lv * 100.0))
		"fire_rate":
			return "射速 +%d%%" % int(round(per_lv * 100.0))
		"crit_chance":
			return "暴击 +%d%%" % int(round(per_lv * 100.0))
		"pickup_range":
			return "拾取 +%d" % int(round(per_lv))
		"hp_growth":
			return "生命 +%d" % int(round(per_lv))
		"shield_amount":
			return "护盾 +%d" % int(round(per_lv))
		_:
			return ""
