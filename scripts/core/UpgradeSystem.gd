extends CanvasLayer
class_name UpgradeSystem

# 使用美化版升级面板
var panel_scene := preload("res://scenes/ui/UpgradePanel_new.tscn")
var panel: Control
var weapon_system: Node
var skill_system: Node
var _last_offered: Array[String] = []
var _upgrades_since_fusion := 0
var _upgrade_open := false
var _pending_upgrades := 0
var _pre_upgrade_hint_cd := 0.0
var _build_tag_score: Dictionary = {}
var _tag_cache: Dictionary = {}
var _anchor_weapon_id := ""
var _directed_picks_left := 0
var _scrap_reroll_used := false
var _scrap_ban_used := false
var _current_option_ids: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = panel_scene.instantiate()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(panel)
	weapon_system = get_parent().get_node_or_null("WeaponSystem")
	skill_system = get_parent().get_node_or_null("SkillSystem")
	EventBus.request_upgrade.connect(_on_request_upgrade)
	EventBus.upgrade_selected.connect(_on_upgrade_selected)


func _process(_delta: float) -> void:
	if _pending_upgrades > 0 and not _upgrade_open:
		_try_open_upgrade_queue()

func _on_request_upgrade() -> void:
	_pending_upgrades += 1
	_pre_upgrade_hint_cd = maxf(_pre_upgrade_hint_cd - 0.12, 0.0)
	if _upgrade_open:
		return
	_try_open_upgrade_queue()


func _try_open_upgrade_queue() -> void:
	var g := get_parent()
	if g != null and g.has_method("upgrade_panel_allowed") and not g.upgrade_panel_allowed():
		return
	_open_next_upgrade()

func _open_next_upgrade() -> void:
	_ensure_runtime_refs()
	if weapon_system == null or skill_system == null or panel == null:
		# 依赖节点缺失时不冻结游戏，避免升级流程卡死。
		_pending_upgrades = 0
		_upgrade_open = false
		get_tree().paused = false
		EventBus.upgrade_ui_state_changed.emit(false)
		EventBus.game_resumed.emit()
		return
	if _pending_upgrades <= 0:
		_upgrade_open = false
		return
	_pending_upgrades -= 1
	_upgrade_open = true
	_emit_pre_upgrade_context_hint()
	EventBus.upgrade_ui_state_changed.emit(true)
	# 升级开启瞬间给一段轻冲击，强化“决策时刻”的仪式感。
	EventBus.screen_flash.emit(Color(0.78, 0.9, 1.0, 0.16), 0.09)
	CombatFeedback.shake("ui", 1.6, 0.06)
	# 与暂停菜单一致：压低 BGM，突出「构筑决策」时刻（AudioManager 监听 game_paused）
	EventBus.game_paused.emit()
	# 延迟一帧打开面板，确保暂停生效后UI可接收输入
	get_tree().paused = true
	call_deferred("_deferred_open_panel")

func _deferred_open_panel() -> void:
	_ensure_runtime_refs()
	if panel == null or weapon_system == null or skill_system == null:
		get_tree().paused = false
		_upgrade_open = false
		EventBus.upgrade_ui_state_changed.emit(false)
		EventBus.game_resumed.emit()
		return
	var opts := _build_option_infos(_roll_three())
	_current_option_ids.clear()
	for o in opts:
		_current_option_ids.append(String(o.get("id", "")))
	panel.open_with_options(opts, _service_state())


func _service_state() -> Dictionary:
	return {
		"scrap": MetaProgress.scrap,
		"reroll_cost": GameDB.RUN_SCRAP_REROLL_COST,
		"ban_cost": GameDB.RUN_SCRAP_BAN_COST,
		"reroll_used": _scrap_reroll_used,
		"ban_used": _scrap_ban_used,
	}


func try_scrap_reroll() -> bool:
	if not _upgrade_open or _scrap_reroll_used:
		return false
	if not MetaProgress.try_spend_scrap(GameDB.RUN_SCRAP_REROLL_COST):
		NotificationSystem.notify_message("碎片不足，无法重抽。", 1.4, "warning")
		return false
	_scrap_reroll_used = true
	_ensure_runtime_refs()
	var opts := _build_option_infos(_roll_three())
	_current_option_ids.clear()
	for o in opts:
		_current_option_ids.append(String(o.get("id", "")))
	if panel:
		panel.open_with_options(opts, _service_state())
	NotificationSystem.notify_message("情报重抽成功。", 1.2, "item")
	return true


func try_scrap_ban_option(card_index: int) -> bool:
	if not _upgrade_open or _scrap_ban_used:
		return false
	if card_index < 0 or card_index >= _current_option_ids.size():
		return false
	if not MetaProgress.try_spend_scrap(GameDB.RUN_SCRAP_BAN_COST):
		NotificationSystem.notify_message("碎片不足，无法排除。", 1.4, "warning")
		return false
	_scrap_ban_used = true
	var banned := _current_option_ids[card_index]
	_ensure_runtime_refs()
	var fresh := _roll_three()
	# 尽量避开刚排除的选项
	for i in fresh.size():
		if String(fresh[i]) == banned:
			var alt := _pick_replacement_option(banned, fresh)
			if not alt.is_empty():
				fresh[i] = alt
			break
	var opts := _build_option_infos(fresh)
	_current_option_ids.clear()
	for o in opts:
		_current_option_ids.append(String(o.get("id", "")))
	if panel:
		panel.open_with_options(opts, _service_state())
	NotificationSystem.notify_message("已排除陷阱选项并补进新情报。", 1.4, "success")
	return true


func _pick_replacement_option(banned: String, occupied: Array[String]) -> String:
	var pool := _roll_three()
	for cand in pool:
		var c := String(cand)
		if c == banned:
			continue
		if occupied.has(c):
			continue
		return c
	for cand in pool:
		var c2 := String(cand)
		if c2 != banned:
			return c2
	return ""


func _emit_pre_upgrade_context_hint() -> void:
	if _pre_upgrade_hint_cd > 0.0:
		return
	var g := get_parent()
	if g == null:
		return
	var dir_mul := float(g.get("_director_mul")) if "_director_mul" in g else 1.0
	var relief := float(g.pressure_relief_ratio()) if g.has_method("pressure_relief_ratio") else 0.0
	var elapsed := float(g.get("elapsed")) if "elapsed" in g else 0.0
	var hint := ""
	var tp := "info"
	if elapsed <= 180.0:
		hint = "首局建议：优先清场/移速，其次补生存；先把节奏跑起来。"
		tp = "success"
	elif relief > 0.5:
		hint = "战局回稳：这次可偏成长（武器层级 / 融合前置）。"
		tp = "success"
	elif dir_mul > 1.3 and elapsed > 300.0:
		hint = "当前高压：优先保命与控场（减伤 / 移速 / 控制）。"
		tp = "warning"
	elif elapsed > 540.0:
		hint = "中后盘决策：优先能立刻提升清场效率的选项。"
		tp = "item"
	if hint.is_empty():
		return
	_pre_upgrade_hint_cd = 4.2
	NotificationSystem.notify_message(hint, 1.45, tp)


func _run_phase_u() -> float:
	var g := get_parent()
	if g == null or not ("elapsed" in g):
		return 0.0
	var run_t := float(g.run_time_seconds) if "run_time_seconds" in g else float(GameDB.run_time_for_mode())
	return GameDB.run_progress_normalized(float(g.get("elapsed")), run_t)


func _roll_three() -> Array[String]:
	_ensure_runtime_refs()
	if weapon_system == null or skill_system == null:
		return []
	var weighted: Array[String] = []
	var phase_u := _run_phase_u()
	var weapon_early_bias := int(round(lerpf(2.0, 0.0, GameDB.smoothstep_f(0.06, 0.42, phase_u))))
	var passive_mid_bias := int(round(lerpf(0.0, 2.0, GameDB.smoothstep_f(0.22, 0.82, phase_u))))
	var mut_early_bias := int(round(lerpf(2.0, 0.0, GameDB.smoothstep_f(0.0, 0.32, phase_u))))
	var fusion_phase := lerpf(0.72, 1.15, GameDB.smoothstep_f(0.30, 0.88, phase_u))
	
	# ========== 武器选择 - 增加弱势武器权重 ==========
	var total_weapon_level := 0
	var min_weapon_level := 10
	var min_weapon_id := ""
	for wid in GameDB.WEAPONS.keys():
		var lvl := int(weapon_system.level_map.get(wid, 0))
		total_weapon_level += lvl
		if lvl < min_weapon_level:
			min_weapon_level = lvl
			min_weapon_id = wid
	
	for wid in GameDB.WEAPONS.keys():
		if int(weapon_system.level_map[wid]) < 5:
			var w: String = "w:" + String(wid)
			var weight := 2
			# 未获得过的武器优先
			if not _last_offered.has(w):
				weight += 3
			# 弱势武器扶持：如果某武器等级明显低于平均，提升权重
			var weapon_lvl := int(weapon_system.level_map.get(wid, 0))
			if weapon_lvl < min_weapon_level and weapon_lvl < total_weapon_level / GameDB.WEAPONS.size() - 1:
				weight += 2  # 弱势武器额外权重
			# 已4级的武器略微优先（更快融合）
			if weapon_lvl == 4:
				weight += 1
			weight += _build_synergy_bonus(w)
			weight += weapon_early_bias
			_add_weighted(weighted, w, weight)
	
	for pid in GameDB.PASSIVES.keys():
		if int(skill_system.passive_levels[pid]) < int(GameDB.PASSIVES[pid]["max_lv"]):
			var p: String = "p:" + String(pid)
			var weight: int = 1
			if not _last_offered.has(p):
				weight += 1
			# 核心被动（攻击、减伤、吸血）略微优先
			match pid:
				"atk_boost", "damage_reduction", "lifesteal":
					weight += 1
			weight += _build_synergy_bonus(p)
			weight += passive_mid_bias
			_add_weighted(weighted, p, weight)
	
	# ========== 变异池：独立 roll_weight，与 w/p 分轨加权 ==========
	var mut_stack_total := 0
	for mid in GameDB.MUTATIONS.keys():
		mut_stack_total += int(skill_system.get_mutation_level(mid))
	for mid in GameDB.MUTATIONS.keys():
		if int(skill_system.get_mutation_level(mid)) >= int(GameDB.MUTATIONS[mid]["max_lv"]):
			continue
		var m: String = "m:" + String(mid)
		var mw: int = int(GameDB.MUTATIONS[mid].get("roll_weight", 4))
		if not _last_offered.has(m):
			mw += 2
		# 前几次升级略抬高变异出率，避免整局见不到紫卡
		if mut_stack_total <= 2:
			mw += 1
		mw += _build_synergy_bonus(m)
		mw += mut_early_bias
		_add_weighted(weighted, m, mw)
	
	var fusion_candidates: Array[String] = []
	for fid in GameDB.FUSIONS.keys():
		if _can_fuse(fid):
			fusion_candidates.append("f:" + fid)
	if not fusion_candidates.is_empty():
		var boost := 2 + mini(3, _upgrades_since_fusion / 2)
		var fusion_slot_weight := int(round(float(3 + boost) * fusion_phase))
		fusion_slot_weight = maxi(2, fusion_slot_weight)
		for f in fusion_candidates:
			_add_weighted(weighted, f, fusion_slot_weight)
	# Soft pity: if many levels without fusion, guarantee one slot.
	var out: Array[String] = []
	if _upgrades_since_fusion >= 5 and not fusion_candidates.is_empty():
		out.append(fusion_candidates[randi() % fusion_candidates.size()])
	if _directed_picks_left > 0 and not _anchor_weapon_id.is_empty():
		_inject_directed_pick(out, weighted)
		_directed_picks_left -= 1
	while out.size() < 3 and not weighted.is_empty():
		weighted.shuffle()
		var pick: String = weighted[0]
		if not out.has(pick):
			out.append(pick)
		_remove_all(weighted, pick)
	_last_offered.clear()
	for item in out:
		_last_offered.append(item)
	return out

func _build_option_infos(ids: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fusion_ready := false
	for v in ids:
		var sid := String(v)
		if sid.begins_with("f:"):
			fusion_ready = true
			break
	for v in ids:
		var sid := String(v)
		var info := {
			"id": sid,
			"recommended": false,
			"synergy": false,
			"synergy_label": "",
			"synergy_badge": "",
			"hint": "",
			"icon": ""
		}
		info["synergy"] = _is_build_synergy_option(sid)
		info["synergy_label"] = _best_synergy_label(sid)
		info["synergy_badge"] = _synergy_badge(String(info["synergy_label"]))
		if sid.begins_with("f:"):
			info["recommended"] = true
			info["hint"] = ""
			info["icon"] = "融"
		elif sid.begins_with("w:"):
			info["icon"] = "武"
			var wid := sid.trim_prefix("w:")
			if int(weapon_system.level_map.get(wid, 0)) >= GameDB.FUSION_WEAPON_LEVEL - 1:
				info["hint"] = "可融合"
			elif not fusion_ready:
				info["recommended"] = true
		elif sid.begins_with("p:"):
			info["icon"] = "被"
		elif sid.begins_with("m:"):
			var mid: String = sid.trim_prefix("m:")
			if GameDB.MUTATIONS.has(mid):
				info["icon"] = String(GameDB.MUTATIONS[mid].get("icon", "变"))
				if int(GameDB.MUTATIONS[mid].get("roll_weight", 3)) >= 4:
					info["recommended"] = true
		out.append(info)
	return out


func _can_fuse(fid: String) -> bool:
	var f: Dictionary = GameDB.FUSIONS[fid]
	var wid := String(f["weapon"])
	if int(weapon_system.level_map.get(wid, 0)) < GameDB.FUSION_WEAPON_LEVEL:
		return false
	var req: Dictionary = f["requires"]
	for pid in req.keys():
		var need := GameDB.fusion_required_passive_level(int(req[pid]))
		if int(skill_system.passive_levels.get(pid, 0)) < need:
			return false
	return true


func _inject_directed_pick(out: Array[String], weighted: Array[String]) -> void:
	var primers: Array = GameDB.WEAPON_BUILD_PRIMERS.get(_anchor_weapon_id, [])
	if primers.is_empty():
		return
	var pick := ""
	for candidate in primers:
		var cid := String(candidate)
		if _is_upgrade_option_available(cid) and not out.has(cid):
			pick = cid
			break
	if pick.is_empty():
		for candidate in primers:
			var cid := String(candidate)
			if _is_upgrade_option_available(cid):
				pick = cid
				break
	if pick.is_empty():
		return
	if out.has(pick):
		return
	if out.size() >= 3:
		out[2] = pick
	else:
		out.append(pick)


func _is_upgrade_option_available(option_id: String) -> bool:
	_ensure_runtime_refs()
	if weapon_system == null or skill_system == null:
		return false
	if option_id.begins_with("w:"):
		var wid := option_id.trim_prefix("w:")
		return GameDB.WEAPONS.has(wid) and int(weapon_system.level_map.get(wid, 0)) < 5
	if option_id.begins_with("p:"):
		var pid := option_id.trim_prefix("p:")
		if not GameDB.PASSIVES.has(pid):
			return false
		return int(skill_system.passive_levels.get(pid, 0)) < int(GameDB.PASSIVES[pid]["max_lv"])
	return false

func _on_upgrade_selected(id: StringName) -> void:
	_ensure_runtime_refs()
	if weapon_system == null or skill_system == null:
		get_tree().paused = false
		_upgrade_open = false
		_pending_upgrades = 0
		EventBus.upgrade_ui_state_changed.emit(false)
		EventBus.game_resumed.emit()
		return
	var s := String(id)
	RunStats.add_upgrade_pick(s)
	if s.begins_with("w:"):
		var wid := s.trim_prefix("w:")
		weapon_system.level_up_weapon(wid)
		if _anchor_weapon_id.is_empty():
			_anchor_weapon_id = wid
			_directed_picks_left = 2
		_upgrades_since_fusion += 1
	elif s.begins_with("p:"):
		skill_system.level_up_passive(s.trim_prefix("p:"))
		_upgrades_since_fusion += 1
	elif s.begins_with("m:"):
		skill_system.level_up_mutation(s.trim_prefix("m:"))
		_upgrades_since_fusion += 1
	elif s.begins_with("f:"):
		weapon_system.apply_fusion(s.trim_prefix("f:"))
		_upgrades_since_fusion = 0
	_record_build_choice_tags(s)
	get_tree().paused = false
	_upgrade_open = false
	EventBus.upgrade_ui_state_changed.emit(false)
	if _pending_upgrades > 0:
		call_deferred("_open_next_upgrade")
	else:
		# 连续升级链结束后再恢复音乐，避免三选一之间音量来回跳
		EventBus.game_resumed.emit()

func _exit_tree() -> void:
	_pending_upgrades = 0
	if _upgrade_open or get_tree().paused:
		get_tree().paused = false
		EventBus.game_resumed.emit()
	_upgrade_open = false
	EventBus.upgrade_ui_state_changed.emit(false)

func _add_weighted(target: Array[String], value: String, count: int) -> void:
	for _i in maxi(1, count):
		target.append(value)

func _remove_all(target: Array[String], value: String) -> void:
	for i in range(target.size() - 1, -1, -1):
		if target[i] == value:
			target.remove_at(i)


func _build_synergy_bonus(option_id: String) -> int:
	var tags := _tags_for_upgrade_option(option_id)
	if tags.is_empty():
		return 0
	var score := 0.0
	for t in tags:
		score += float(_build_tag_score.get(t, 0.0))
	if score <= 0.2:
		return 0
	return mini(3, int(floor(score)))


func _is_build_synergy_option(option_id: String) -> bool:
	var tags := _tags_for_upgrade_option(option_id)
	for t in tags:
		if float(_build_tag_score.get(t, 0.0)) >= 0.95:
			return true
	return false


func _best_synergy_label(option_id: String) -> String:
	var tags := _tags_for_upgrade_option(option_id)
	var best_tag := ""
	var best_score := -999.0
	for t in tags:
		var s := float(_build_tag_score.get(t, 0.0))
		if s > best_score:
			best_score = s
			best_tag = t
	if best_score < 0.95:
		return ""
	return _tag_to_cn(best_tag)


func _tag_to_cn(tag: String) -> String:
	match tag:
		"crit":
			return "暴击流"
		"tempo":
			return "节奏流"
		"aoe":
			return "清场流"
		"control":
			return "控制流"
		"survival":
			return "生存流"
		"mobility":
			return "机动流"
		"offense":
			return "输出流"
		"power_spike":
			return "质变流"
		_:
			return "综合流"


func _synergy_badge(label: String) -> String:
	match label:
		"控制流":
			return "控"
		"暴击流":
			return "暴"
		"清场流":
			return "清"
		"生存流":
			return "生"
		"机动流":
			return "机"
		"节奏流":
			return "节"
		"输出流":
			return "攻"
		"质变流":
			return "变"
		_:
			return "综"


func _record_build_choice_tags(option_id: String) -> void:
	# 选择后缓慢衰减旧倾向，再强化新倾向，形成“流派连续性”而非硬锁定。
	var keys := _build_tag_score.keys()
	for k in keys:
		_build_tag_score[k] = float(_build_tag_score[k]) * 0.86
	var tags := _tags_for_upgrade_option(option_id)
	for t in tags:
		_build_tag_score[t] = float(_build_tag_score.get(t, 0.0)) + 0.95


func _tags_for_upgrade_option(option_id: String) -> Array[String]:
	if _tag_cache.has(option_id):
		return _tag_cache[option_id] as Array[String]
	var tags: Array[String] = []
	if option_id.begins_with("w:"):
		var wid := option_id.trim_prefix("w:")
		if GameDB.WEAPONS.has(wid):
			var wdef: Dictionary = GameDB.WEAPONS[wid]
			tags = _infer_tags_from_text("%s %s" % [String(wdef.get("name", "")), String(wdef.get("desc", ""))])
	elif option_id.begins_with("p:"):
		var pid := option_id.trim_prefix("p:")
		if GameDB.PASSIVES.has(pid):
			var pdef: Dictionary = GameDB.PASSIVES[pid]
			tags = _infer_tags_from_text("%s %s" % [String(pdef.get("name", "")), String(pdef.get("desc", ""))])
	elif option_id.begins_with("m:"):
		var mid := option_id.trim_prefix("m:")
		if GameDB.MUTATIONS.has(mid):
			var mdef: Dictionary = GameDB.MUTATIONS[mid]
			tags = _infer_tags_from_text("%s %s" % [String(mdef.get("name", "")), String(mdef.get("desc", ""))])
	elif option_id.begins_with("f:"):
		tags = ["power_spike"]
	if tags.is_empty():
		tags = ["generic"]
	_tag_cache[option_id] = tags
	return tags


func _infer_tags_from_text(src: String) -> Array[String]:
	var s := src.to_lower()
	var tags: Array[String] = []
	if _has_any(s, ["crit", "暴击", "爆击"]):
		tags.append("crit")
	if _has_any(s, ["fire rate", "attack speed", "射速", "攻速", "cooldown", "冷却"]):
		tags.append("tempo")
	if _has_any(s, ["explode", "explosion", "aoe", "范围", "爆炸", "清场", "燃爆", "蔓延", "灼烧"]):
		tags.append("aoe")
	if _has_any(s, ["freeze", "slow", "stun", "冰", "减速", "控制", "眩晕", "冰域", "冻结"]):
		tags.append("control")
	if _has_any(s, ["lifesteal", "heal", "shield", "hp", "dr", "吸血", "护盾", "生命", "减伤"]):
		tags.append("survival")
	if _has_any(s, ["move", "dash", "speed", "移速", "冲刺", "机动"]):
		tags.append("mobility")
	if _has_any(s, ["atk", "attack", "damage", "armor break", "伤害", "攻击", "增伤", "锋刃", "输出", "穿透", "雷链", "环绕", "专精", "连锁"]):
		tags.append("offense")
	if tags.is_empty():
		tags.append("generic")
	return tags


func _has_any(s: String, terms: Array[String]) -> bool:
	for t in terms:
		if s.find(t) >= 0:
			return true
	return false


func _ensure_runtime_refs() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if weapon_system == null or not is_instance_valid(weapon_system):
		weapon_system = parent.get_node_or_null("WeaponSystem")
	if skill_system == null or not is_instance_valid(skill_system):
		skill_system = parent.get_node_or_null("SkillSystem")
