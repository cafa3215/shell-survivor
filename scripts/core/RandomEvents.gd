extends Node2D
class_name RandomEvents

# ============================================
# 随机事件系统 - 宝箱/祭坛/治疗
# ============================================

var player: Node2D
var weapon_system: Node
var skill_system: Node
var experience_system: Node

# 事件计时器
var _event_timers: Dictionary = {}
var _active_events: Array[Dictionary] = []
var _spawn_center := Vector2.ZERO

# 事件可视化
var _event_marks: Array[Dictionary] = []

const EVENT_SPAWN_RADIUS_MIN := 350.0
const EVENT_SPAWN_RADIUS_MAX := 600.0
const EVENT_COLLECT_RADIUS := 50.0
## BOSS 战时事件计时倍率（<1 则降频，避免与 BOSS 机制抢注意力）
const BOSS_FIGHT_EVENT_TIME_SCALE := 0.28

func _ready() -> void:
	# 延迟初始化，等待其他系统就绪
	call_deferred("_delayed_init")

func _delayed_init() -> void:
	player = get_parent().get_node("Player")
	weapon_system = get_parent().get_node("WeaponSystem")
	skill_system = get_parent().get_node("SkillSystem")
	experience_system = get_parent().get_node_or_null("ExperienceSystem")
	
	# 首次刷新略提前，避免开局「干刷怪」太久（吸引力 / 目标感）
	for event_type in GameDB.EVENT_TYPES.keys():
		_event_timers[event_type] = randf_range(22.0, 58.0)

func _process(delta: float) -> void:
	if player == null:
		return
	
	var eff_delta: float = delta
	var em: Node = get_parent().get_node_or_null("EnemyManager")
	if em != null and em.has_method("boss_alive") and em.boss_alive():
		eff_delta *= BOSS_FIGHT_EVENT_TIME_SCALE
	
	# 更新事件计时器
	for event_type in _event_timers.keys():
		_event_timers[event_type] -= eff_delta
		if _event_timers[event_type] <= 0.0:
			_event_timers[event_type] = float(GameDB.EVENT_TYPES[event_type]["spawn_interval"])
			_spawn_event(event_type)
	
	# 检查事件收集
	_check_event_collection()
	
	# 更新事件特效
	_update_event_marks(delta)
	
	queue_redraw()

func _spawn_event(event_type: String) -> void:
	# 在玩家附近生成事件
	var angle := randf() * TAU
	var dist := randf_range(EVENT_SPAWN_RADIUS_MIN, EVENT_SPAWN_RADIUS_MAX)
	var spawn_pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist
	
	var event_data := {
		"type": event_type,
		"pos": spawn_pos,
		"spawn_time": Time.get_ticks_msec()
	}
	_active_events.append(event_data)
	
	# 添加可视化标记
	_event_marks.append({
		"pos": spawn_pos,
		"type": event_type,
		"spawn_time": Time.get_ticks_msec(),
		"radius": EVENT_COLLECT_RADIUS
	})
	
	# 显示通知
	match event_type:
		"treasure_box":
			NotificationSystem.notify_message("地图上刷了宝箱 — 往光点跑，踩圈拾取！", 2.4, "item")
		"curse_altar":
			NotificationSystem.notify_message("诅咒祭坛出现 — 高风险；若已带开局遗物，踩下后有小概率从裂隙析出第二件（与诅咒提示绑定）。", 3.0, "warning")
		"healing_shrine":
			NotificationSystem.notify_message("治愈祭坛出现 — 恢复生命；若已带开局遗物，治愈后有小概率析出第二件遗物。", 2.9, "success")

func _check_event_collection() -> void:
	var player_pos := player.global_position
	
	for i in range(_active_events.size() - 1, -1, -1):
		var event: Dictionary = _active_events[i]
		var event_pos: Vector2 = event["pos"]
		
		if player_pos.distance_to(event_pos) < EVENT_COLLECT_RADIUS:
			_collect_event(event)
			_active_events.remove_at(i)

func _collect_event(event: Dictionary) -> void:
	var event_type := String(event["type"])
	var event_pos: Vector2 = event["pos"]
	
	match event_type:
		"treasure_box":
			_collect_treasure(event_pos)
		"curse_altar":
			_apply_curse(event_pos)
		"healing_shrine":
			_collect_healing(event_pos)
	
	# 播放收集特效
	CombatFeedback.shake("hit", 2.0, 0.1)
	EventBus.screen_flash.emit(Color(1.0, 1.0, 0.5, 0.2), 0.15)

func _collect_treasure(pos: Vector2) -> void:
	# 按局进度缩放奖励，并增加“构筑保护”：
	# 越到中后期，给到与当前武器/融合路径更相关的选项。
	var u := _run_progress_u()
	var w_xp := 1.25 - u * 0.35
	var w_weapon := 1.0 + u * 0.3
	var w_passive := 1.0 + u * 0.45
	var w_relic := 0.75 + u * 0.55
	var roll := randf() * (w_xp + w_weapon + w_passive + w_relic)
	var reward_type := 0
	if roll < w_xp:
		reward_type = 0
	elif roll < w_xp + w_weapon:
		reward_type = 1
	elif roll < w_xp + w_weapon + w_passive:
		reward_type = 2
	else:
		reward_type = 3
	
	match reward_type:
		0:  # 经验奖励
			var xp_amount := _scaled_treasure_xp_amount()
			if experience_system and experience_system.has_method("spawn_orb"):
				# 生成多个经验球
				var orb_count := 3 + int(round(_run_progress_u() * 2.0))
				for _i in orb_count:
					var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
					experience_system.spawn_orb(pos + offset, maxi(1, int(round(float(xp_amount) / float(orb_count)))))
			NotificationSystem.notify_message("获得 %d 经验！" % xp_amount, 2.0, "success")
		1:  # 随机武器
			var random_weapon := _pick_synergy_weapon()
			var weapon_name: String = GameDB.WEAPONS[random_weapon]["name"]
			weapon_system.level_up_weapon(random_weapon)
			NotificationSystem.notify_message("宝箱武器：%s！" % weapon_name, 2.6, "item")
		2:  # 随机被动+1
			var random_passive := _pick_synergy_passive()
			var passive_name: String = GameDB.PASSIVES[random_passive]["name"]
			skill_system.level_up_passive(random_passive)
			NotificationSystem.notify_message("%s +1！" % passive_name, 2.2, "success")
		3:  # 第二件遗物（与开局遗物叠乘；无空位或无池时退回经验）
			var g := get_parent()
			if g != null and g.has_method("try_grant_run_relic_from_chest"):
				if bool(g.call("try_grant_run_relic_from_chest", pos, "treasure_box")):
					return
			var xp_fb := _scaled_treasure_xp_amount() + 3
			if experience_system and experience_system.has_method("spawn_orb"):
				for _j in 3:
					var off2 := Vector2(randf_range(-30, 30), randf_range(-30, 30))
					experience_system.spawn_orb(pos + off2, xp_fb / 3)
			NotificationSystem.notify_message("宝箱改为经验：%d（遗物格已满或未解锁池）" % xp_fb, 2.0, "item")

func _apply_curse(pos: Vector2) -> void:
	# 随机选择诅咒效果（与 Game.apply_world_curse 数值绑定）
	var curse: Dictionary = GameDB.CURSE_EFFECTS[randi() % GameDB.CURSE_EFFECTS.size()]
	var curse_name: String = String(curse.get("name", ""))
	var curse_key := String(curse.get("curse", ""))
	var dur := float(curse.get("duration", 20.0))
	var g := get_parent()
	if g != null and g.has_method("apply_world_curse"):
		g.call("apply_world_curse", curse_key, dur)
	NotificationSystem.notify_message("受到诅咒：%s" % curse_name, 3.0, "error")
	EventBus.screen_flash.emit(Color(0.5, 0.0, 0.5, 0.3), 0.2)
	if randf() < 0.16:
		_try_event_relic_drop(pos, "curse_altar")

func _collect_healing(pos: Vector2) -> void:
	# 随机选择治疗量
	var heal_reward: Dictionary = GameDB.HEALING_REWARDS[randi() % GameDB.HEALING_REWARDS.size()]
	var heal_percent: float = float(heal_reward["heal"])
	
	# 应用治疗
	var current_hp := float(player.hp)
	var max_hp := float(player.max_hp)
	var heal_amount := max_hp * (heal_percent / 100.0)
	var new_hp := minf(current_hp + heal_amount, max_hp)
	player.hp = new_hp
	
	NotificationSystem.notify_message("恢复 %d%% 生命！" % int(round(heal_percent)), 2.0, "success")
	EventBus.player_healed.emit(heal_amount)
	EventBus.screen_flash.emit(Color(0.2, 1.0, 0.4, 0.25), 0.2)
	# 叙事绑定：治愈余韵有小概率析出第二件遗物（与诅咒祭坛同源校验）
	if randf() < 0.10:
		_try_event_relic_drop(pos, "healing_shrine")

func _try_event_relic_drop(pos: Vector2, source: String) -> void:
	var g := get_parent()
	if g != null and g.has_method("try_grant_run_relic_from_chest"):
		g.call("try_grant_run_relic_from_chest", pos, source)


func _run_progress_u() -> float:
	var g := get_parent()
	if g == null:
		return 0.0
	var elapsed := float(g.get("elapsed")) if "elapsed" in g else 0.0
	return GameDB.run_progress_normalized(elapsed)


func _scaled_treasure_xp_amount() -> int:
	var u := _run_progress_u()
	var min_xp := int(round(lerpf(15.0, 28.0, u)))
	var max_xp := int(round(lerpf(25.0, 42.0, u)))
	return randi_range(min_xp, maxi(min_xp + 1, max_xp))


func _pick_synergy_weapon() -> String:
	var weapons: Array = GameDB.WEAPONS.keys()
	if weapons.is_empty():
		return "kunai"
	var best := ""
	var best_score := -999
	for wid_any in weapons:
		var wid := String(wid_any)
		var lv := int(weapon_system.level_map.get(wid, 0)) if weapon_system != null else 0
		if lv >= 5:
			continue
		var score := 0
		if lv == 0:
			score += 1
		else:
			score += lv * 2
		if lv >= 3:
			score += 3
		for fid_any in GameDB.FUSIONS.keys():
			var fid := String(fid_any)
			var fdef: Dictionary = GameDB.FUSIONS[fid]
			if String(fdef.get("weapon", "")) != wid:
				continue
			var req: Dictionary = fdef.get("requires", {}) as Dictionary
			for pid_any in req.keys():
				var pid := String(pid_any)
				var need := int(req[pid])
				var cur := int(skill_system.passive_levels.get(pid, 0)) if skill_system != null else 0
				if cur < need:
					score += 2
				else:
					score += 1
		if score > best_score:
			best_score = score
			best = wid
	if best.is_empty():
		best = String(weapons[randi() % weapons.size()])
	return best


func _pick_synergy_passive() -> String:
	var passives: Array = GameDB.PASSIVES.keys()
	if passives.is_empty():
		return "atk_boost"
	var candidates: Array[String] = []
	for fid_any in GameDB.FUSIONS.keys():
		var fdef: Dictionary = GameDB.FUSIONS[String(fid_any)]
		var wid := String(fdef.get("weapon", ""))
		var wlv := int(weapon_system.level_map.get(wid, 0)) if weapon_system != null else 0
		if wlv < 3:
			continue
		var req: Dictionary = fdef.get("requires", {}) as Dictionary
		for pid_any in req.keys():
			var pid := String(pid_any)
			var need := int(req[pid])
			var cur := int(skill_system.passive_levels.get(pid, 0)) if skill_system != null else 0
			if cur < need:
				candidates.append(pid)
	if not candidates.is_empty():
		return candidates[randi() % candidates.size()]
	return String(passives[randi() % passives.size()])

func _update_event_marks(delta: float) -> void:
	for i in range(_event_marks.size() - 1, -1, -1):
		_event_marks.remove_at(i)  # 清理已过期的标记
	# 重新添加活跃事件
	for event in _active_events:
		var event_pos: Vector2 = event["pos"]
		var event_type: String = event["type"]
		_event_marks.append({
			"pos": event_pos,
			"type": event_type,
			"spawn_time": event["spawn_time"]
		})

func _draw() -> void:
	var time_ms := Time.get_ticks_msec()
	
	for mark in _event_marks:
		var pos: Vector2 = mark["pos"]
		var event_type: String = mark["type"]
		var age := (time_ms - float(mark["spawn_time"])) / 1000.0
		var pulse := 0.8 + 0.2 * sin(age * 4.0)
		
		match event_type:
			"treasure_box":
				# 金黄色宝箱
				draw_circle(pos, 35.0 * pulse, Color(1.0, 0.85, 0.2, 0.15))
				draw_circle(pos, 25.0 * pulse, Color(1.0, 0.9, 0.3, 0.25))
				draw_circle(pos, 15.0, Color(1.0, 0.95, 0.5, 0.6))
				# 星星装饰
				for i in 4:
					var angle := age * 2.0 + TAU * 0.25 * float(i)
					var star_pos := pos + Vector2(cos(angle), sin(angle)) * 30.0 * pulse
					draw_circle(star_pos, 3.0, Color(1.0, 1.0, 0.6, 0.5))
			
			"curse_altar":
				# 紫色诅咒
				draw_circle(pos, 40.0 * pulse, Color(0.5, 0.0, 0.5, 0.12))
				draw_circle(pos, 28.0 * pulse, Color(0.7, 0.2, 0.8, 0.2))
				draw_circle(pos, 16.0, Color(0.9, 0.4, 1.0, 0.5))
				# 符文效果
				var rune_rot := age * 1.5
				for i in 3:
					var angle := rune_rot + TAU * 0.33 * float(i)
					var rune_pos := pos + Vector2(cos(angle), sin(angle)) * 25.0
					draw_circle(rune_pos, 4.0, Color(0.8, 0.5, 1.0, 0.6))
			
			"healing_shrine":
				# 翠绿治疗
				draw_circle(pos, 38.0 * pulse, Color(0.2, 1.0, 0.5, 0.1))
				draw_circle(pos, 26.0 * pulse, Color(0.3, 1.0, 0.6, 0.18))
				draw_circle(pos, 16.0, Color(0.5, 1.0, 0.7, 0.5))
				# 治疗波纹
				var wave_r := 30.0 * (1.0 - fmod(age * 0.8, 1.0))
				var wave_alpha := 0.3 * (1.0 - fmod(age * 0.8, 1.0))
				draw_arc(pos, wave_r, 0.0, TAU, 16, Color(0.4, 1.0, 0.6, wave_alpha), 2.0)
