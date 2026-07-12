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

func _ready() -> void:
	_card_buttons = [c1, c2, c3]
	for b in _card_buttons:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 148)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.0
	c1.pressed.connect(func(): _pick(0))
	c2.pressed.connect(func(): _pick(1))
	c3.pressed.connect(func(): _pick(2))
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
	# 延迟获取引用（避免时序问题）
	call_deferred("_cache_refs")

func _cache_refs() -> void:
	var game := get_parent().get_parent()
	if game:
		_weapon_system = game.get_node_or_null("WeaponSystem")
		_skill_system = game.get_node_or_null("SkillSystem")

func open_with_options(opts: Array) -> void:
	visible = true
	_is_picking = false
	_ids.clear()
	for i in 3:
		var btn: Button = [c1, c2, c3][i]
		if i < opts.size():
			var id := ""
			var recommended := false
			var synergy := false
			var synergy_label := ""
			var synergy_badge := ""
			var hint := ""
			var card_icon := ""
			if opts[i] is Dictionary:
				var d: Dictionary = opts[i]
				id = String(d.get("id", ""))
				recommended = bool(d.get("recommended", false))
				synergy = bool(d.get("synergy", false))
				synergy_label = String(d.get("synergy_label", ""))
				synergy_badge = String(d.get("synergy_badge", ""))
				hint = String(d.get("hint", ""))
				card_icon = String(d.get("icon", ""))
			else:
				id = String(opts[i])
			if synergy and not synergy_label.is_empty():
				var badge_prefix := (synergy_badge + " ") if not synergy_badge.is_empty() else ""
				hint = badge_prefix + "连携：" + synergy_label + (("｜" + hint) if not hint.is_empty() else "")
			_ids.append(id)
			btn.visible = true
			btn.disabled = false
			btn.scale = Vector2.ONE
			btn.text = _label_of(id, recommended, synergy, hint, card_icon)
			_card_recommended[i] = recommended
		else:
			btn.visible = false
			btn.disabled = true
			_card_recommended[i] = false
	_hovered_card_idx = -1
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
	_is_picking = true
	var chosen := StringName(_ids[i])
	for idx in _card_buttons.size():
		var b := _card_buttons[idx]
		b.disabled = true
	_apply_selected_state(i)
	var picked_btn := _card_buttons[i]
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

func _label_of(id: String, recommended := false, synergy := false, hint := "", card_icon := "") -> String:
	var icon_prefix := ""
	if not card_icon.is_empty():
		icon_prefix = card_icon + " "
	var lead := ""
	if recommended:
		lead += "★推荐 "
	if synergy:
		lead += "◎连携 "
	var prefix := icon_prefix + (lead.strip_edges() + "\n" if not lead.is_empty() else "")
	
	var title := ""
	var detail := ""
	var level_info := ""
	
	if id.begins_with("w:"):
		var wid := id.trim_prefix("w:")
		title = "【武器】"
		detail = String(GameDB.WEAPONS[wid]["name"])
		# 显示当前等级
		if _weapon_system:
			var cur_lv := int(_weapon_system.level_map.get(wid, 0))
			if cur_lv > 0:
				level_info = "  Lv.%d→%d" % [cur_lv, mini(cur_lv + 1, 5)]
				# 融合前置检查
				for fid in GameDB.FUSIONS.keys():
					var f: Dictionary = GameDB.FUSIONS[fid]
					if String(f["weapon"]) == wid and cur_lv + 1 >= 5:
						var req: Dictionary = f["requires"]
						var req_met := true
						var req_text := ""
						if _skill_system:
							for pid in req.keys():
								var plv := int(_skill_system.passive_levels.get(pid, 0))
								if plv < int(req[pid]):
									req_met = false
									req_text += " %s%d→%d" % [String(GameDB.PASSIVES[pid]["name"]), plv, int(req[pid])]
						if req_met:
							hint = "★融合可激活！"
						else:
							hint = "融合前置:%s" % req_text
			else:
				level_info = "  新武器"
		if hint.is_empty():
			hint = "提升武器等级，增强攻击力"
	elif id.begins_with("p:"):
		var pid: String = id.trim_prefix("p:")
		title = "【被动】"
		detail = String(GameDB.PASSIVES[pid]["name"])
		# 显示当前等级和效果
		if _skill_system:
			var cur_lv: int = int(_skill_system.passive_levels.get(pid, 0))
			var max_lv: int = int(GameDB.PASSIVES[pid]["max_lv"])
			level_info = "  Lv.%d→%d" % [cur_lv, mini(cur_lv + 1, max_lv)]
			# 显示具体效果
			var effect_text: String = _passive_effect_text(pid, cur_lv + 1)
			if not effect_text.is_empty():
				hint = effect_text
		if hint.is_empty():
			hint = _passive_hint(pid)
	elif id.begins_with("m:"):
		var mid := id.trim_prefix("m:")
		title = "【变异】"
		if GameDB.MUTATIONS.has(mid):
			var mdef: Dictionary = GameDB.MUTATIONS[mid]
			detail = String(mdef["name"])
			if _skill_system:
				var cur_m := int(_skill_system.get_mutation_level(mid))
				var max_m := int(mdef["max_lv"])
				level_info = "  层数 %d→%d（上限%d）" % [cur_m, mini(cur_m + 1, max_m), max_m]
		if hint.is_empty():
			hint = "与武器/被动分轨的永久构筑强化"
	elif id.begins_with("f:"):
		title = "【融合】"
		var fid := id.trim_prefix("f:")
		detail = fid.replace("_ex", "进化")
		var wid := String(GameDB.FUSIONS.get(fid, {}).get("weapon", ""))
		if not wid.is_empty():
			level_info = "  Lv.5→6(进化)"
		if hint.is_empty():
			hint = "武器质变：伤害×1.5 + 独特强化"
	else:
		title = "【?】"
		detail = id
	
	return "%s%s%s%s\n%s" % [prefix, title, detail, level_info, hint]

func _passive_effect_text(pid: String, next_lv: int) -> String:
	match pid:
		"xp_boost":
			return "经验+%d%%（当前+%d%%）" % [next_lv * 12, (next_lv - 1) * 12]
		"atk_boost":
			return "攻击+%d%%（当前+%d%%）" % [next_lv * 8, (next_lv - 1) * 8]
		"move_speed":
			return "移速+%d%%（当前+%d%%）" % [next_lv * 6, (next_lv - 1) * 6]
		"damage_reduction":
			return "减伤+%d%%（当前+%d%%）" % [next_lv * 6, (next_lv - 1) * 6]
		"lifesteal":
			return "吸血+%d%%（当前+%d%%）" % [next_lv * 3, (next_lv - 1) * 3]
		"fire_rate":
			return "射速+%d%%（当前+%d%%）" % [next_lv * 8, (next_lv - 1) * 8]
		"crit_chance":
			return "暴击+%d%%（当前+%d%%）" % [5 + next_lv * 5, 5 + (next_lv - 1) * 5]
		"pickup_range":
			return "拾取+%dpx（当前+%dpx）" % [next_lv * 25, (next_lv - 1) * 25]
		"hp_growth":
			return "生命+%d（当前+%d）" % [100 + next_lv * 15, 100 + (next_lv - 1) * 15]
		_:
			return ""

func _passive_hint(pid: String) -> String:
	match pid:
		"xp_boost":
			return "经验成长更快，缩短成型时间"
		"atk_boost":
			return "直接提升所有武器伤害"
		"move_speed":
			return "走位容错提升，规避弹幕更稳定"
		"damage_reduction":
			return "硬度提升，防止后期暴毙"
		"lifesteal":
			return "持续作战能力提升"
		"fire_rate":
			return "攻速/冷却收益显著"
		"crit_chance":
			return "暴击时伤害翻倍，爆发提升巨大"
		"pickup_range":
			return "经验球磁吸范围扩大，升级更快"
		"hp_growth":
			return "最大生命值提升，容错率增加"
		_:
			return "强化构筑协同"
