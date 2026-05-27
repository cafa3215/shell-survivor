extends Node

# ============================================
# RunStats - 局统计系统（完整版）
# ============================================

var kills := 0
var damage_total := 0.0
var damage_to_boss := 0.0
var damage_taken_total := 0.0
var hits_taken := 0
var fusions := 0
var runtime_sec := 0
var boss_spawn_sec := -1
var boss_defeat_sec := -1
var fusion_damage_total := 0.0
var non_fusion_damage_total := 0.0

# 详细统计
var _kill_by_type: Dictionary = {}       # kind -> count
var _damage_by_source: Dictionary = {}   # source -> total damage
var _boss_damage_by_source: Dictionary = {} # source -> total boss damage
var _upgrade_picks: Array[String] = []   # ordered list of picks
var _director_samples: Array[float] = []
var _xp_samples: Array[float] = []
var _skill_cast_stats: Dictionary = {}   # skill_id -> cast/hit/duration aggregates
var _active_skill_casts: Dictionary = {} # "caster:seq" -> runtime tracker
var _skill_cast_recent: Array[Dictionary] = [] # recent cast summaries with timestamp

# 历史记录
var _run_history: Array[Dictionary] = []
var _current_run_tags: Array[String] = []
const SAVE_PATH := "user://run_stats.cfg"
const SAVE_VERSION := 1

# 战术预设
const TACTIC_PRESETS := {
	"glass_cannon": {"label": "玻璃大炮", "tags": ["offense_single_core", "survival_gap"]},
	"tank": {"label": "铁壁堡垒", "tags": ["survival_stable", "boss_distribution_good"]},
	"balanced": {"label": "均衡战士", "tags": ["healthy", "fusion_value_high"]},
	"speedrunner": {"label": "速通猎手", "tags": ["boss_distribution_good", "fusion_value_high"]},
}
var _tactic_preset := "balanced"
## 当前局随机到的战备遗物（GameDB.RUN_RELICS 的键；仅当局有效）
var current_run_relic_id: String = ""
## 宝箱/事件掉落的第二件遗物（与开局遗物分轨记录；仅当局有效）
var current_run_relic_second_id: String = ""


func _ready() -> void:
	_load_history()
	EventBus.skill_cast_start.connect(_on_skill_cast_start)
	EventBus.skill_hit.connect(_on_skill_hit)
	EventBus.skill_end.connect(_on_skill_end)

func reset() -> void:
	kills = 0
	damage_total = 0.0
	damage_to_boss = 0.0
	damage_taken_total = 0.0
	hits_taken = 0
	fusions = 0
	runtime_sec = 0
	boss_spawn_sec = -1
	boss_defeat_sec = -1
	fusion_damage_total = 0.0
	non_fusion_damage_total = 0.0
	_kill_by_type.clear()
	_damage_by_source.clear()
	_boss_damage_by_source.clear()
	_upgrade_picks.clear()
	_director_samples.clear()
	_xp_samples.clear()
	_skill_cast_stats.clear()
	_active_skill_casts.clear()
	_skill_cast_recent.clear()
	_current_run_tags.clear()
	_tactic_preset = "balanced"
	current_run_relic_id = ""
	current_run_relic_second_id = ""


func set_current_run_relic(id: String) -> void:
	current_run_relic_id = id


func set_current_run_relic_second(id: String) -> void:
	current_run_relic_second_id = id

func add_damage_taken(amount: float) -> void:
	damage_taken_total += max(amount, 0.0)
	hits_taken += 1

func add_kill(kind: StringName) -> void:
	kills += 1
	var k := String(kind)
	_kill_by_type[k] = int(_kill_by_type.get(k, 0)) + 1

func add_upgrade_pick(id: String) -> void:
	_upgrade_picks.append(id)

func add_damage_source(source: String, amount: float, to_boss: bool, from_fusion: bool) -> void:
	if source.is_empty():
		return
	var safe_amount: float = max(amount, 0.0)
	damage_total += safe_amount
	if to_boss:
		damage_to_boss += safe_amount
	if from_fusion:
		fusion_damage_total += safe_amount
	else:
		non_fusion_damage_total += safe_amount
	_damage_by_source[source] = float(_damage_by_source.get(source, 0.0)) + safe_amount
	if to_boss:
		_boss_damage_by_source[source] = float(_boss_damage_by_source.get(source, 0.0)) + safe_amount

func add_director_sample(director_mul: float, xp_mul: float) -> void:
	_director_samples.append(director_mul)
	_xp_samples.append(xp_mul)

func kpm() -> float:
	if runtime_sec <= 0:
		return 0.0
	return float(kills) / (float(runtime_sec) / 60.0)

func dpm_taken() -> float:
	if runtime_sec <= 0:
		return 0.0
	return damage_taken_total / (float(runtime_sec) / 60.0)

func boss_ttk() -> int:
	if boss_spawn_sec < 0 or boss_defeat_sec < 0:
		return -1
	return maxi(0, boss_defeat_sec - boss_spawn_sec)

func boss_dps() -> float:
	var ttk: int = boss_ttk()
	if ttk <= 0:
		return 0.0
	return damage_to_boss / float(ttk)

func fusion_damage_ratio() -> float:
	if damage_total <= 0.0:
		return 0.0
	return clampf(fusion_damage_total / damage_total, 0.0, 1.0)

func boss_damage_focus_ratio() -> float:
	if damage_total <= 0.0:
		return 0.0
	return clampf(damage_to_boss / damage_total, 0.0, 1.0)

func avg_director_mul() -> float:
	if _director_samples.is_empty():
		return 1.0
	var total := 0.0
	for s in _director_samples:
		total += s
	return total / float(_director_samples.size())

func avg_xp_mul() -> float:
	if _xp_samples.is_empty():
		return 1.0
	var total := 0.0
	for s in _xp_samples:
		total += s
	return total / float(_xp_samples.size())

# ============================================
# Top-K 查询
# ============================================

func top_kill_types(n: int) -> Array[String]:
	var entries: Array = []
	for k in _kill_by_type:
		entries.append({"kind": k, "count": int(_kill_by_type[k])})
	entries.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))
	var out: Array[String] = []
	for i in range(mini(n, entries.size())):
		out.append(String(entries[i]["kind"]))
	return out

func top_upgrade_picks(n: int) -> Array[String]:
	var freq: Dictionary = {}
	for p in _upgrade_picks:
		freq[p] = int(freq.get(p, 0)) + 1
	var entries: Array = []
	for k in freq:
		entries.append({"id": k, "count": int(freq[k])})
	entries.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))
	var out: Array[String] = []
	for i in range(mini(n, entries.size())):
		out.append(String(entries[i]["id"]))
	return out

func top_damage_sources(n: int) -> Array[String]:
	var entries: Array = []
	for k in _damage_by_source:
		entries.append({"source": k, "damage": float(_damage_by_source[k])})
	entries.sort_custom(func(a, b): return float(a["damage"]) > float(b["damage"]))
	var out: Array[String] = []
	for i in range(mini(n, entries.size())):
		out.append(String(entries[i]["source"]))
	return out


func damage_of_source(source: String) -> float:
	return float(_damage_by_source.get(source, 0.0))


func top_damage_entries(n: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for k in _damage_by_source:
		var dmg := float(_damage_by_source[k])
		var ratio := 0.0
		if damage_total > 0.001:
			ratio = clampf(dmg / damage_total, 0.0, 1.0)
		entries.append({
			"source": String(k),
			"damage": dmg,
			"ratio": ratio
		})
	entries.sort_custom(func(a, b): return float(a["damage"]) > float(b["damage"]))
	if n <= 0:
		return []
	var out: Array[Dictionary] = []
	for i in range(mini(n, entries.size())):
		out.append(entries[i])
	return out

func top_boss_damage_sources(n: int) -> Array[String]:
	var entries: Array = []
	for k in _boss_damage_by_source:
		entries.append({"source": k, "damage": float(_boss_damage_by_source[k])})
	entries.sort_custom(func(a, b): return float(a["damage"]) > float(b["damage"]))
	var out: Array[String] = []
	for i in range(mini(n, entries.size())):
		out.append(String(entries[i]["source"]))
	return out


func top_boss_damage_entries(n: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for k in _boss_damage_by_source:
		var dmg := float(_boss_damage_by_source[k])
		var ratio := 0.0
		if damage_to_boss > 0.001:
			ratio = clampf(dmg / damage_to_boss, 0.0, 1.0)
		entries.append({
			"source": String(k),
			"damage": dmg,
			"ratio": ratio
		})
	entries.sort_custom(func(a, b): return float(a["damage"]) > float(b["damage"]))
	if n <= 0:
		return []
	var out: Array[Dictionary] = []
	for i in range(mini(n, entries.size())):
		out.append(entries[i])
	return out


func top_skill_cast_entries(n: int, sort_by: String = "casts", min_casts: int = 1) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for k in _skill_cast_stats:
		var st: Dictionary = _skill_cast_stats[k]
		var casts := int(st.get("casts", 0))
		var hits := int(st.get("hits", 0))
		var dur_total := int(st.get("duration_total_ms", 0))
		var avg_hits := float(hits) / float(maxi(casts, 1))
		var avg_dur := float(dur_total) / float(maxi(casts, 1))
		var efficiency := avg_hits / maxf(avg_dur / 1000.0, 0.001)
		if casts < maxi(1, min_casts):
			continue
		entries.append({
			"skill_id": String(k),
			"casts": casts,
			"hits": hits,
			"avg_hits": avg_hits,
			"avg_duration_ms": avg_dur,
			"efficiency": efficiency,
		})
	_sort_skill_entries(entries, sort_by)
	if n <= 0:
		return []
	var out: Array[Dictionary] = []
	for i in range(mini(n, entries.size())):
		out.append(entries[i])
	return out


func top_skill_cast_entries_recent(n: int, window_sec: float = 60.0, sort_by: String = "casts", min_casts: int = 1) -> Array[Dictionary]:
	var now_ms := Time.get_ticks_msec()
	var window_ms := int(maxf(1.0, window_sec) * 1000.0)
	var agg: Dictionary = {}
	for r in _skill_cast_recent:
		var ts := int(r.get("timestamp_ms", 0))
		if now_ms - ts > window_ms:
			continue
		var sid := String(r.get("skill_id", ""))
		if sid.is_empty():
			continue
		if not agg.has(sid):
			agg[sid] = {"casts": 0, "hits": 0, "duration_total_ms": 0}
		var row: Dictionary = agg[sid]
		row["casts"] = int(row.get("casts", 0)) + 1
		row["hits"] = int(row.get("hits", 0)) + int(r.get("hits", 0))
		row["duration_total_ms"] = int(row.get("duration_total_ms", 0)) + int(r.get("duration_ms", 0))
		agg[sid] = row
	var entries: Array[Dictionary] = []
	for k in agg:
		var st: Dictionary = agg[k]
		var casts := int(st.get("casts", 0))
		var hits := int(st.get("hits", 0))
		var dur_total := int(st.get("duration_total_ms", 0))
		if casts < maxi(1, min_casts):
			continue
		entries.append({
			"skill_id": String(k),
			"casts": casts,
			"hits": hits,
			"avg_hits": float(hits) / float(maxi(casts, 1)),
			"avg_duration_ms": float(dur_total) / float(maxi(casts, 1)),
			"efficiency": float(hits) / float(maxi(casts, 1)) / maxf((float(dur_total) / float(maxi(casts, 1))) / 1000.0, 0.001),
		})
	_sort_skill_entries(entries, sort_by)
	if n <= 0:
		return []
	var out: Array[Dictionary] = []
	for i in range(mini(n, entries.size())):
		out.append(entries[i])
	return out


func top_skill_cast_entries_since_ms(n: int, since_ms: int, sort_by: String = "casts", min_casts: int = 1) -> Array[Dictionary]:
	var agg: Dictionary = {}
	for r in _skill_cast_recent:
		var ts := int(r.get("timestamp_ms", 0))
		if ts < since_ms:
			continue
		var sid := String(r.get("skill_id", ""))
		if sid.is_empty():
			continue
		if not agg.has(sid):
			agg[sid] = {"casts": 0, "hits": 0, "duration_total_ms": 0}
		var row: Dictionary = agg[sid]
		row["casts"] = int(row.get("casts", 0)) + 1
		row["hits"] = int(row.get("hits", 0)) + int(r.get("hits", 0))
		row["duration_total_ms"] = int(row.get("duration_total_ms", 0)) + int(r.get("duration_ms", 0))
		agg[sid] = row
	var entries: Array[Dictionary] = []
	for k in agg:
		var st: Dictionary = agg[k]
		var casts := int(st.get("casts", 0))
		var hits := int(st.get("hits", 0))
		var dur_total := int(st.get("duration_total_ms", 0))
		if casts < maxi(1, min_casts):
			continue
		entries.append({
			"skill_id": String(k),
			"casts": casts,
			"hits": hits,
			"avg_hits": float(hits) / float(maxi(casts, 1)),
			"avg_duration_ms": float(dur_total) / float(maxi(casts, 1)),
			"efficiency": float(hits) / float(maxi(casts, 1)) / maxf((float(dur_total) / float(maxi(casts, 1))) / 1000.0, 0.001),
		})
	_sort_skill_entries(entries, sort_by)
	if n <= 0:
		return []
	var out: Array[Dictionary] = []
	for i in range(mini(n, entries.size())):
		out.append(entries[i])
	return out


func _sort_skill_entries(entries: Array[Dictionary], sort_by: String) -> void:
	match sort_by:
		"efficiency":
			entries.sort_custom(func(a, b):
				var ae := float(a.get("efficiency", 0.0))
				var be := float(b.get("efficiency", 0.0))
				if absf(ae - be) < 0.0001:
					return int(a.get("casts", 0)) > int(b.get("casts", 0))
				return ae > be
			)
		"avg_hits":
			entries.sort_custom(func(a, b):
				var ah := float(a.get("avg_hits", 0.0))
				var bh := float(b.get("avg_hits", 0.0))
				if absf(ah - bh) < 0.0001:
					return int(a.get("casts", 0)) > int(b.get("casts", 0))
				return ah > bh
			)
		_:
			entries.sort_custom(func(a, b): return int(a["casts"]) > int(b["casts"]))

# ============================================
# 诊断系统
# ============================================

func set_diagnosis_tags(tags: Array[String]) -> void:
	_current_run_tags.clear()
	for t in tags:
		_current_run_tags.append(t)
	# 自动匹配战术预设
	_tactic_preset = "balanced"
	var best_score := 0
	for preset_id in TACTIC_PRESETS:
		var preset: Dictionary = TACTIC_PRESETS[preset_id]
		var preset_tags: Array = preset["tags"]
		var score := 0
		for t in _current_run_tags:
			if preset_tags.has(t):
				score += 1
		if score > best_score:
			best_score = score
			_tactic_preset = String(preset_id)

func current_tactic_preset_label() -> String:
	if TACTIC_PRESETS.has(_tactic_preset):
		return String(TACTIC_PRESETS[_tactic_preset]["label"])
	return "均衡战士"

func recent_hot_tag_labels(n: int) -> Array[String]:
	# 从最近几局中收集最频繁标签
	var tag_freq: Dictionary = {}
	for run in _run_history:
		var tags_variant: Variant = run.get("tags", [])
		var tags: Array
		if tags_variant is Array:
			tags = tags_variant
		for t in tags:
			tag_freq[t] = int(tag_freq.get(t, 0)) + 1
	# 也包含当前局
	for t in _current_run_tags:
		tag_freq[t] = int(tag_freq.get(t, 0)) + 1
	var entries: Array = []
	for k in tag_freq:
		entries.append({"tag": k, "count": int(tag_freq[k])})
	entries.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))
	var out: Array[String] = []
	for i in range(mini(n, entries.size())):
		out.append(_tag_label(String(entries[i]["tag"])))
	return out

func recent_preset_usage(n: int) -> Array[String]:
	var freq: Dictionary = {}
	for run in _run_history:
		var preset: String = str(run.get("preset", "balanced"))
		freq[preset] = int(freq.get(preset, 0)) + 1
	freq[_tactic_preset] = int(freq.get(_tactic_preset, 0)) + 1
	var entries: Array = []
	for k in freq:
		entries.append({"preset": k, "count": int(freq[k])})
	entries.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))
	var out: Array[String] = []
	for i in range(mini(n, entries.size())):
		var pid: String = String(entries[i]["preset"])
		if TACTIC_PRESETS.has(pid):
			out.append(String(TACTIC_PRESETS[pid]["label"]))
		else:
			out.append(pid)
	return out

func recent_preset_winrates(n: int) -> Array[String]:
	var stats: Dictionary = {} # preset -> {wins, total}
	for run in _run_history:
		var preset: String = str(run.get("preset", "balanced"))
		if not stats.has(preset):
			stats[preset] = {"wins": 0, "total": 0}
		var s: Dictionary = stats[preset]
		s["total"] = int(s["total"]) + 1
		if run.get("win", false):
			s["wins"] = int(s["wins"]) + 1
	var entries: Array = []
	for k in stats:
		var s: Dictionary = stats[k]
		var wr := float(s["wins"]) / maxf(float(s["total"]), 1.0) * 100.0
		entries.append({"preset": k, "wr": wr})
	entries.sort_custom(func(a, b): return float(a["wr"]) > float(b["wr"]))
	var out: Array[String] = []
	for i in range(mini(n, entries.size())):
		var pid: String = String(entries[i]["preset"])
		var label := pid
		if TACTIC_PRESETS.has(pid):
			label = String(TACTIC_PRESETS[pid]["label"])
		out.append("%s: %.0f%%" % [label, float(entries[i]["wr"])])
	return out

func recent_preset_stability(n: int) -> Array[String]:
	# 稳定性 = 低受伤害方差
	var stats: Dictionary = {}
	for run in _run_history:
		var preset: String = str(run.get("preset", "balanced"))
		if not stats.has(preset):
			stats[preset] = []
		stats[preset].append(float(run.get("dpm_taken", 0.0)))
	var entries: Array = []
	for k in stats:
		var values: Array = stats[k]
		if values.is_empty():
			continue
		var mean := 0.0
		for v in values:
			mean += v
		mean /= float(values.size())
		var variance := 0.0
		for v in values:
			variance += (v - mean) * (v - mean)
		variance /= float(values.size())
		var stability := maxf(0.0, 100.0 - sqrt(variance) * 0.5)
		entries.append({"preset": k, "stability": stability})
	entries.sort_custom(func(a, b): return float(a["stability"]) > float(b["stability"]))
	var out: Array[String] = []
	for i in range(mini(n, entries.size())):
		var pid: String = String(entries[i]["preset"])
		var label := pid
		if TACTIC_PRESETS.has(pid):
			label = String(TACTIC_PRESETS[pid]["label"])
		out.append("%s: %.0f%%" % [label, float(entries[i]["stability"])])
	return out

func recommended_preset_summary() -> String:
	if TACTIC_PRESETS.has(_tactic_preset):
		return "推荐预设: %s" % String(TACTIC_PRESETS[_tactic_preset]["label"])
	return "推荐预设: 均衡战士"


func menu_next_run_hint() -> String:
	if _run_history.is_empty():
		return "下一局建议：先稳住前 3 分钟，再追融合路线。"
	var last: Dictionary = _run_history[_run_history.size() - 1]
	var tags_variant: Variant = last.get("tags", [])
	var tags: Array = []
	if tags_variant is Array:
		tags = tags_variant
	var win := bool(last.get("win", false))
	if tags.has("survival_gap"):
		return "下一局建议：先补减伤/移速，保证 6 分钟前不暴毙。"
	if tags.has("offense_single_core"):
		return "下一局建议：补副C或持续伤害，避免单核输出断档。"
	if tags.has("fusion_value_low"):
		return "下一局建议：优先拿融合前置被动，把质变点提前。"
	if tags.has("survival_stable") and win:
		return "下一局建议：生存已稳，可更激进堆进攻与清场。"
	if tags.has("fusion_value_high"):
		return "下一局建议：延续当前成型路线，保持中盘滚雪球。"
	return "下一局建议：维持均衡构筑，关键威胁优先清除。"

func recent_primary_suggestion() -> String:
	if _current_run_tags.has("survival_gap"):
		return "建议：优先减伤/移速，生存不稳"
	if _current_run_tags.has("offense_single_core"):
		return "建议：补副C/持续伤害，输出过于单核"
	if _current_run_tags.has("fusion_value_low"):
		return "建议：优先融合关联被动，提升融合收益"
	if _current_run_tags.has("survival_stable"):
		return "建议：可将资源转向进攻"
	if _current_run_tags.has("fusion_value_high"):
		return "建议：维持当前成型路线"
	return "建议：构筑均衡，保持节奏"

func recent_action_plan_personalized() -> Array[String]:
	var plan: Array[String] = []
	if _current_run_tags.has("survival_gap"):
		plan.append("提升减伤至3级+")
		plan.append("移速加成优先")
	if _current_run_tags.has("offense_single_core"):
		plan.append("补充AOE武器覆盖")
		plan.append("确保2个以上武器满级")
	if _current_run_tags.has("fusion_value_low"):
		plan.append("补齐融合被动前置")
	if plan.is_empty():
		plan.append("保持当前构筑节奏")
	return plan

func finalize_latest_run(win: bool) -> void:
	_run_history.append({
		"win": win,
		"kills": kills,
		"damage": damage_total,
		"damage_taken": damage_taken_total,
		"runtime": runtime_sec,
		"fusions": fusions,
		"tags": _current_run_tags.duplicate(),
		"preset": _tactic_preset,
		"dpm_taken": dpm_taken(),
		"relic": current_run_relic_id,
		"relic2": current_run_relic_second_id,
	})
	# 保留最近20局
	if _run_history.size() > 20:
		var sliced: Array = _run_history.slice(_run_history.size() - 20)
		_run_history.clear()
		for item in sliced:
			_run_history.append(item)
	_save_history()

func build_loss_recap_line() -> String:
	var parts: Array[String] = []
	var top := top_damage_sources(1)
	if not top.is_empty():
		parts.append("主力输出 " + GameDB.humanize_damage_source(top[0]))
	parts.append("平均压力 %.2f×" % avg_director_mul())
	if hits_taken > 0:
		parts.append("承伤命中 %d 次" % hits_taken)
	if damage_taken_total > 0.5:
		parts.append("总承伤 %.0f" % damage_taken_total)
	var sb := ""
	for i in parts.size():
		if i > 0:
			sb += " · "
		sb += parts[i]
	return sb


func _tag_label(tag: String) -> String:
	match tag:
		"offense_single_core":
			return "单核输出"
		"boss_distribution_good":
			return "BOSS分布好"
		"fusion_value_low":
			return "融合收益低"
		"fusion_value_high":
			return "融合收益高"
		"survival_gap":
			return "生存不稳"
		"survival_stable":
			return "生存稳定"
		"healthy":
			return "健康"
		_:
			return tag


func _save_history() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run_stats", "version", SAVE_VERSION)
	cfg.set_value("run_stats", "history", _run_history)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("RunStats: 历史写入失败 (%d)" % err)


func _load_history() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		if err != ERR_FILE_NOT_FOUND:
			push_warning("RunStats: 历史读取失败，已回退为空历史 (%d)" % err)
		return
	var ver := int(cfg.get_value("run_stats", "version", 0))
	var raw: Variant = cfg.get_value("run_stats", "history", [])
	if raw is Array:
		_run_history.clear()
		for item in raw:
			if item is Dictionary:
				var rec := _sanitize_run_record(item as Dictionary, ver)
				if not rec.is_empty():
					_run_history.append(rec)
		# 保险：历史上限与 finalize 保持一致
		if _run_history.size() > 20:
			var sliced: Array = _run_history.slice(_run_history.size() - 20)
			_run_history.clear()
			for v in sliced:
				if v is Dictionary:
					_run_history.append(v)
	# 读取坏档后自动回写清洗结果，避免每次启动重复解析异常记录。
	if ver != SAVE_VERSION:
		_save_history()


func _sanitize_run_record(src: Dictionary, ver: int = 0) -> Dictionary:
	var out: Dictionary = {}
	# 为后续存档演进保留版本分支：目前 v0/v1 字段一致
	if ver < 1:
		pass
	# 必要字段做类型兜底，坏档时自动回退默认值
	out["win"] = bool(src.get("win", false))
	out["kills"] = int(src.get("kills", 0))
	out["damage"] = float(src.get("damage", 0.0))
	out["damage_taken"] = float(src.get("damage_taken", 0.0))
	out["runtime"] = int(src.get("runtime", 0))
	out["fusions"] = int(src.get("fusions", 0))
	out["preset"] = str(src.get("preset", "balanced"))
	out["dpm_taken"] = float(src.get("dpm_taken", 0.0))
	out["relic"] = str(src.get("relic", ""))
	out["relic2"] = str(src.get("relic2", ""))
	var tags_in: Variant = src.get("tags", [])
	var tags_out: Array[String] = []
	if tags_in is Array:
		for t in tags_in:
			tags_out.append(str(t))
	out["tags"] = tags_out
	return out


func _cast_key(caster_id: int, cast_seq: int) -> String:
	return "%d:%d" % [caster_id, cast_seq]


func _ensure_skill_stat(skill_id: String) -> Dictionary:
	if not _skill_cast_stats.has(skill_id):
		_skill_cast_stats[skill_id] = {
			"casts": 0,
			"hits": 0,
			"duration_total_ms": 0,
			"last_duration_ms": 0,
			"last_hits": 0,
		}
	return _skill_cast_stats[skill_id]


func _on_skill_cast_start(skill_id: StringName, caster_id: int, cast_seq: int, timestamp_ms: int) -> void:
	var sid := String(skill_id)
	var key := _cast_key(caster_id, cast_seq)
	_active_skill_casts[key] = {
		"skill_id": sid,
		"start_ms": timestamp_ms,
		"hits": 0,
	}
	var st := _ensure_skill_stat(sid)
	st["casts"] = int(st.get("casts", 0)) + 1
	_skill_cast_stats[sid] = st


func _on_skill_hit(skill_id: StringName, caster_id: int, _target_id: int, cast_seq: int, _damage_type: StringName, _final_damage: float, _is_critical: bool, _timestamp_ms: int) -> void:
	var sid := String(skill_id)
	var key := _cast_key(caster_id, cast_seq)
	var st := _ensure_skill_stat(sid)
	st["hits"] = int(st.get("hits", 0)) + 1
	_skill_cast_stats[sid] = st
	if _active_skill_casts.has(key):
		var run: Dictionary = _active_skill_casts[key]
		run["hits"] = int(run.get("hits", 0)) + 1
		_active_skill_casts[key] = run


func _on_skill_end(skill_id: StringName, caster_id: int, cast_seq: int, _reason: StringName, timestamp_ms: int) -> void:
	var sid := String(skill_id)
	var key := _cast_key(caster_id, cast_seq)
	var st := _ensure_skill_stat(sid)
	if _active_skill_casts.has(key):
		var run: Dictionary = _active_skill_casts[key]
		var start_ms := int(run.get("start_ms", timestamp_ms))
		var dur_ms := maxi(0, timestamp_ms - start_ms)
		var run_hits := int(run.get("hits", 0))
		st["duration_total_ms"] = int(st.get("duration_total_ms", 0)) + dur_ms
		st["last_duration_ms"] = dur_ms
		st["last_hits"] = run_hits
		_skill_cast_recent.append({
			"timestamp_ms": timestamp_ms,
			"skill_id": sid,
			"hits": run_hits,
			"duration_ms": dur_ms,
		})
		if _skill_cast_recent.size() > 256:
			var trimmed: Array[Dictionary] = []
			for i in range(maxi(0, _skill_cast_recent.size() - 256), _skill_cast_recent.size()):
				var item: Variant = _skill_cast_recent[i]
				if item is Dictionary:
					trimmed.append(item)
			_skill_cast_recent = trimmed
		_active_skill_casts.erase(key)
	_skill_cast_stats[sid] = st
