extends Node

## 轻量局外统计（R11）：局数、胜场、最佳胜利用时；个人项目不做内购
const SAVE_PATH := "user://meta_progress.cfg"

var runs_total: int = 0
var wins_total: int = 0
## 胜利局最短生存时间（秒），越大越好 → 存「越少秒数越好」用 RUN_TIME - elapsed 或直接用 elapsed 取 min
var best_win_runtime_sec: int = 999999
## 已开放作战区域：可玩地图索引为 0..unlocked_map_upto（含）。新档仅开放第 1 张；在「当前最前沿」地图获胜后 +1。
var unlocked_map_upto: int = 0
## 局外战备碎片（战备强化消费）
var scrap: int = 0
## 永久强化等级 uid → lv（与 GameDB.META_PERMANENT_UPGRADES 对齐）
var meta_upgrade_levels: Dictionary = {}
## 战备遗物：碎片一次性「入库」后永久可进开局随机池（仅对 GameDB.RUN_RELICS 中带 scrap_unlock 的条目）
var run_relic_scrap_unlocked: Dictionary = {}
## 地图精通：map_id → 0~3 星
var map_mastery: Dictionary = {}
## 收藏：融合见过 / 流派专精见过（无数值膨胀，只做勾选）
var fusions_seen: Dictionary = {}
var school_mastery_seen: Dictionary = {}


func _ready() -> void:
	_load()
	_ensure_meta_upgrade_keys()


func _load() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		if err != ERR_FILE_NOT_FOUND:
			push_warning("MetaProgress: 存档读取失败，已回退默认进度 (%d)" % err)
		return
	runs_total = maxi(0, int(cfg.get_value("meta", "runs_total", runs_total)))
	wins_total = clampi(int(cfg.get_value("meta", "wins_total", wins_total)), 0, runs_total)
	best_win_runtime_sec = maxi(0, int(cfg.get_value("meta", "best_win_runtime_sec", best_win_runtime_sec)))
	var map_count := maxi(1, GameDB.MAP_TEMPLATES.size())
	var last_i := map_count - 1
	if cfg.has_section_key("meta", "unlocked_map_upto"):
		unlocked_map_upto = clampi(int(cfg.get_value("meta", "unlocked_map_upto", 0)), 0, last_i)
	else:
		# 旧存档：已有游玩记录则视为全开，避免突然锁关
		if runs_total > 0:
			unlocked_map_upto = last_i
		else:
			unlocked_map_upto = 0
	# 必须先读永久强化，再执行可能触发 _save() 的碎片折算，否则会误把未加载的强化等级写成 0
	_load_meta_upgrades_from_cfg(cfg)
	if cfg.has_section_key("meta", "scrap"):
		scrap = maxi(0, int(cfg.get_value("meta", "scrap", 0)))
	elif runs_total > 0:
		# 旧存档一次性折算，避免长期玩家余额从零开始
		scrap = mini(runs_total * 5 + wins_total * 10, 500)
		_save()
	_load_run_relic_unlocks_from_cfg(cfg)
	_load_map_mastery_from_cfg(cfg)
	_load_bool_section_from_cfg(cfg, "fusions_seen", fusions_seen)
	_load_bool_section_from_cfg(cfg, "school_mastery_seen", school_mastery_seen)


func _load_map_mastery_from_cfg(cfg: ConfigFile) -> void:
	map_mastery.clear()
	if not cfg.has_section("map_mastery"):
		return
	for k in cfg.get_section_keys("map_mastery"):
		map_mastery[String(k)] = clampi(int(cfg.get_value("map_mastery", k, 0)), 0, 3)


func _load_run_relic_unlocks_from_cfg(cfg: ConfigFile) -> void:
	run_relic_scrap_unlocked.clear()
	if not cfg.has_section("run_relic_unlocks"):
		return
	for k in cfg.get_section_keys("run_relic_unlocks"):
		if bool(cfg.get_value("run_relic_unlocks", k, false)):
			run_relic_scrap_unlocked[String(k)] = true


func _load_bool_section_from_cfg(cfg: ConfigFile, section: String, into: Dictionary) -> void:
	into.clear()
	if not cfg.has_section(section):
		return
	for k in cfg.get_section_keys(section):
		if bool(cfg.get_value(section, k, false)):
			into[String(k)] = true


func _ensure_meta_upgrade_keys() -> void:
	for uid in GameDB.META_PERMANENT_UPGRADES.keys():
		if not meta_upgrade_levels.has(uid):
			meta_upgrade_levels[uid] = 0


func _load_meta_upgrades_from_cfg(cfg: ConfigFile) -> void:
	for uid in GameDB.META_PERMANENT_UPGRADES.keys():
		meta_upgrade_levels[uid] = 0
	if not cfg.has_section("meta_upgrades"):
		return
	for uid in GameDB.META_PERMANENT_UPGRADES.keys():
		var def: Dictionary = GameDB.META_PERMANENT_UPGRADES[uid]
		var cap: int = int(def["max_lv"])
		meta_upgrade_levels[uid] = clampi(int(cfg.get_value("meta_upgrades", uid, 0)), 0, cap)


func _save() -> void:
	var cfg := ConfigFile.new()
	runs_total = maxi(0, runs_total)
	wins_total = clampi(wins_total, 0, runs_total)
	best_win_runtime_sec = maxi(0, best_win_runtime_sec)
	scrap = maxi(0, scrap)
	cfg.set_value("meta", "runs_total", runs_total)
	cfg.set_value("meta", "wins_total", wins_total)
	cfg.set_value("meta", "best_win_runtime_sec", best_win_runtime_sec)
	cfg.set_value("meta", "unlocked_map_upto", unlocked_map_upto)
	cfg.set_value("meta", "scrap", scrap)
	for uid in GameDB.META_PERMANENT_UPGRADES.keys():
		cfg.set_value("meta_upgrades", uid, int(meta_upgrade_levels.get(uid, 0)))
	for rk in run_relic_scrap_unlocked.keys():
		if bool(run_relic_scrap_unlocked.get(rk, false)):
			cfg.set_value("run_relic_unlocks", str(rk), true)
	for mk in map_mastery.keys():
		cfg.set_value("map_mastery", str(mk), clampi(int(map_mastery.get(mk, 0)), 0, 3))
	for fk in fusions_seen.keys():
		if bool(fusions_seen.get(fk, false)):
			cfg.set_value("fusions_seen", str(fk), true)
	for sk in school_mastery_seen.keys():
		if bool(school_mastery_seen.get(sk, false)):
			cfg.set_value("school_mastery_seen", str(sk), true)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("MetaProgress: 存档写入失败 (%d)" % err)


func mark_fusion_seen(fusion_id: String) -> bool:
	var fid := String(fusion_id)
	if fid.is_empty() or not GameDB.FUSIONS.has(fid):
		return false
	if bool(fusions_seen.get(fid, false)):
		return false
	fusions_seen[fid] = true
	_save()
	_try_unlock_codex_achievements()
	return true


func mark_school_mastery_seen(passive_id: String) -> bool:
	var pid := String(passive_id)
	if pid.is_empty() or not (pid in GameDB.SCHOOL_MASTERY_IDS):
		return false
	if bool(school_mastery_seen.get(pid, false)):
		return false
	school_mastery_seen[pid] = true
	_save()
	_try_unlock_codex_achievements()
	return true


func _try_unlock_codex_achievements() -> void:
	if AchievementService == null:
		return
	var fuse_cap := maxi(1, fusion_total_count())
	if fusion_seen_count() * 2 >= fuse_cap:
		AchievementService.try_unlock("codex_fusions_half")
	if school_mastery_seen_count() >= GameDB.SCHOOL_MASTERY_IDS.size():
		AchievementService.try_unlock("codex_schools_all")


func fusion_seen_count() -> int:
	var n := 0
	for fid in GameDB.FUSIONS.keys():
		if bool(fusions_seen.get(String(fid), false)):
			n += 1
	return n


func fusion_total_count() -> int:
	return GameDB.FUSIONS.size()


func school_mastery_seen_count() -> int:
	var n := 0
	for pid in GameDB.SCHOOL_MASTERY_IDS:
		if bool(school_mastery_seen.get(String(pid), false)):
			n += 1
	return n


func is_meta_upgrades_maxed() -> bool:
	for uid in GameDB.META_PERMANENT_UPGRADES.keys():
		var def: Dictionary = GameDB.META_PERMANENT_UPGRADES[uid]
		if int(meta_upgrade_levels.get(uid, 0)) < int(def.get("max_lv", 0)):
			return false
	return true


## 满 Meta 后仍给收藏/挑战目标（禁止用数值膨胀填空）
func next_goal_line() -> String:
	var map_n := maxi(1, GameDB.MAP_TEMPLATES.size())
	var star_cap := map_n * 3
	var stars := total_map_mastery_stars()
	if stars < star_cap:
		return "下一目标：地图精通 %d / %d★（称号进度，无永久属性）" % [stars, star_cap]
	var fuse_n := fusion_seen_count()
	var fuse_cap := fusion_total_count()
	if fuse_n < fuse_cap:
		return "下一目标：融合图鉴 %d / %d（局内激活过即勾选）" % [fuse_n, fuse_cap]
	var school_n := school_mastery_seen_count()
	var school_cap := GameDB.SCHOOL_MASTERY_IDS.size()
	if school_n < school_cap:
		return "下一目标：五流派专精 %d / %d（点过一级即勾选）" % [school_n, school_cap]
	if AchievementService != null:
		if not AchievementService.is_unlocked("chal_any_nightmare"):
			return "下一目标：任意契约 × 噩梦难度胜利（契约噩梦徽章）"
		if not AchievementService.is_unlocked("chal_glass_nightmare"):
			return "下一目标：玻璃契约 × 噩梦难度胜利（碎镜噩梦）"
		if not AchievementService.is_unlocked("build_all_eight"):
			return "下一目标：八条主流构筑各通关一次"
		if not AchievementService.is_unlocked("endless_survive"):
			return "下一目标：持久撤离后进入无尽并坚持到倒下"
	return "下一目标：换专精 / 契约 / 地图再开一局，追逐不同构筑手感"


func record_run_ended(win: bool, runtime_sec: int, cleared_map_index: int = -1, run_context: Dictionary = {}) -> Dictionary:
	var unlock_line := ""
	var mastery_lines: Array[String] = []
	var scrap_delta := 0
	var scrap_mul := 1.0
	runs_total += 1
	var mi := 0
	if cleared_map_index >= 0:
		mi = clampi(cleared_map_index, 0, maxi(0, GameDB.MAP_TEMPLATES.size() - 1))
	if win:
		wins_total += 1
		best_win_runtime_sec = mini(best_win_runtime_sec, maxi(0, runtime_sec))
		var last_i := maxi(0, GameDB.MAP_TEMPLATES.size() - 1)
		if cleared_map_index >= 0 and mi == unlocked_map_upto and unlocked_map_upto < last_i:
			unlocked_map_upto += 1
			unlock_line = "新作战区域已开放：%s" % _map_title_at(unlocked_map_upto)
		scrap_mul = _scrap_reward_multiplier(run_context)
		scrap_delta = int(round(float(GameDB.meta_scrap_win_amount(mi)) * scrap_mul))
		mastery_lines = _evaluate_map_mastery(mi, run_context)
	else:
		scrap_delta = GameDB.META_SCRAP_LOSS
	scrap = maxi(0, scrap + scrap_delta)
	_save()
	return {
		"unlock_line": unlock_line,
		"mastery_lines": mastery_lines,
		"scrap_delta": scrap_delta,
		"scrap_total": scrap,
		"scrap_mul": scrap_mul,
	}


func meta_upgrade_cost_next(uid: String) -> int:
	if not GameDB.META_PERMANENT_UPGRADES.has(uid):
		return -1
	var def: Dictionary = GameDB.META_PERMANENT_UPGRADES[uid]
	var lv := int(meta_upgrade_levels.get(uid, 0))
	var cap: int = int(def["max_lv"])
	if lv >= cap:
		return -1
	return int(def["base_cost"]) + int(def["cost_per_lv"]) * lv


func is_run_relic_unlocked_for_pool(rid: String) -> bool:
	if not GameDB.RUN_RELICS.has(rid):
		return false
	var def: Dictionary = GameDB.RUN_RELICS[rid]
	if wins_total < int(def.get("unlock_min_wins", 0)):
		return false
	var sc := int(def.get("scrap_unlock", 0))
	if sc > 0:
		return bool(run_relic_scrap_unlocked.get(rid, false))
	return true


func try_purchase_run_relic_unlock(rid: String) -> bool:
	if not GameDB.RUN_RELICS.has(rid):
		return false
	if bool(run_relic_scrap_unlocked.get(rid, false)):
		return false
	var def: Dictionary = GameDB.RUN_RELICS[rid]
	var sc := int(def.get("scrap_unlock", 0))
	if sc <= 0:
		return false
	if scrap < sc:
		return false
	scrap -= sc
	run_relic_scrap_unlocked[rid] = true
	_save()
	return true


func try_spend_scrap(amount: int) -> bool:
	if amount <= 0:
		return false
	if scrap < amount:
		return false
	scrap -= amount
	_save()
	return true


func get_map_stars(map_index: int) -> int:
	var key := GameDB.map_mastery_key(map_index)
	return clampi(int(map_mastery.get(key, 0)), 0, 3)


func get_map_mastery_stat_bonus(map_index: int) -> Dictionary:
	var stars := get_map_stars(map_index)
	var out: Dictionary = {}
	for i in mini(stars, GameDB.MAP_MASTERY_PER_STAR.size()):
		var perk: Dictionary = GameDB.MAP_MASTERY_PER_STAR[i]
		for k in perk.keys():
			var sk := String(k)
			out[sk] = float(out.get(sk, 0.0)) + float(perk[k])
	return out


func total_map_mastery_stars() -> int:
	var total := 0
	for i in GameDB.MAP_TEMPLATES.size():
		total += get_map_stars(i)
	return total


func _scrap_reward_multiplier(run_context: Dictionary) -> float:
	var diff_id := GameDB.normalize_difficulty_id(String(run_context.get("difficulty_id", GameDB.DEFAULT_DIFFICULTY)))
	var challenge_id := GameDB.normalize_challenge_id(String(run_context.get("challenge_id", "none")))
	var diff: Dictionary = GameDB.get_difficulty_tier(diff_id)
	var challenge: Dictionary = GameDB.get_challenge_contract(challenge_id)
	return float(diff.get("scrap_mul", 1.0)) * float(challenge.get("scrap_mul", 1.0))


func _evaluate_map_mastery(map_index: int, run_context: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var key := GameDB.map_mastery_key(map_index)
	var before := clampi(int(map_mastery.get(key, 0)), 0, 3)
	var stars := before
	if stars < 1:
		stars = 1
		lines.append("%s 精通 +1：首次通关胜利" % _map_title_at(map_index))
	if stars < 2 and (bool(run_context.get("no_curse", false)) or bool(run_context.get("zone_objective_done", false))):
		stars = 2
		if bool(run_context.get("no_curse", false)):
			lines.append("%s 精通 +1：无诅咒通关" % _map_title_at(map_index))
		else:
			lines.append("%s 精通 +1：完成区域任务" % _map_title_at(map_index))
	var boss_sec := int(run_context.get("boss_defeat_sec", -1))
	if stars < 3 and boss_sec >= 0 and boss_sec <= GameDB.MAP_MASTERY_SPEED_BOSS_SEC:
		stars = 3
		lines.append("%s 精通 +1：8 分钟内击破首领" % _map_title_at(map_index))
	if stars > before:
		map_mastery[key] = stars
	return lines


func try_purchase_meta_upgrade(uid: String) -> bool:
	if not GameDB.META_PERMANENT_UPGRADES.has(uid):
		return false
	var def: Dictionary = GameDB.META_PERMANENT_UPGRADES[uid]
	var lv := int(meta_upgrade_levels.get(uid, 0))
	var cap: int = int(def["max_lv"])
	if lv >= cap:
		return false
	var cost := meta_upgrade_cost_next(uid)
	if cost < 0 or scrap < cost:
		return false
	scrap -= cost
	meta_upgrade_levels[uid] = lv + 1
	_save()
	return true


func get_meta_hp_flat_bonus() -> float:
	return float(int(meta_upgrade_levels.get("vitality", 0))) * GameDB.META_PERK_HP_PER_LV


func get_meta_atk_bonus_add() -> float:
	return float(int(meta_upgrade_levels.get("firepower", 0))) * GameDB.META_PERK_ATK_PER_LV


func get_meta_move_bonus_add() -> float:
	return float(int(meta_upgrade_levels.get("mobility", 0))) * GameDB.META_PERK_MOVE_PER_LV


func total_meta_upgrade_levels() -> int:
	var t := 0
	for uid in GameDB.META_PERMANENT_UPGRADES.keys():
		t += int(meta_upgrade_levels.get(uid, 0))
	return t


func summary_line() -> String:
	var map_count := maxi(1, GameDB.MAP_TEMPLATES.size())
	var prog := "作战区域已开放至：%s" % _map_title_at(unlocked_map_upto)
	if unlocked_map_upto >= map_count - 1:
		prog = "作战区域：已全部开放"
	var meta_sum := total_meta_upgrade_levels()
	var meta_bit := ""
	if meta_sum > 0:
		meta_bit = " · 永久强化合计 %d 级" % meta_sum
	var relic_prog := GameDB.run_relic_pool_progress_text()
	var mastery_sum := total_map_mastery_stars()
	var mastery_bit := ""
	if mastery_sum > 0:
		mastery_bit = " · 地图精通 %d★" % mastery_sum
	var ach_bit := ""
	if AchievementService != null:
		ach_bit = " · " + AchievementService.summary_line()
	if runs_total <= 0:
		return "局外：尚无记录 · 战备碎片 %d%s%s%s · %s · %s" % [scrap, meta_bit, mastery_bit, ach_bit, relic_prog, prog]
	var wr := float(wins_total) / float(runs_total) * 100.0
	var best := "—"
	if best_win_runtime_sec < 999000:
		var m := best_win_runtime_sec / 60
		var s := best_win_runtime_sec % 60
		best = "%02d:%02d" % [m, s]
	return "累计 %d 局 · 胜 %d（%.0f%%）· 最快胜利 %s · 战备碎片 %d%s%s%s · %s · %s" % [
		runs_total, wins_total, wr, best, scrap, meta_bit, mastery_bit, ach_bit, relic_prog, prog
	]


func _map_title_at(idx: int) -> String:
	var i := clampi(idx, 0, maxi(0, GameDB.MAP_TEMPLATES.size() - 1))
	var tpl: Dictionary = GameDB.MAP_TEMPLATES[i]
	return String(tpl.get("title", tpl.get("id", "区域 %d" % i)))
