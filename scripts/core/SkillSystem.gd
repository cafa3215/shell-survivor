extends Node
class_name SkillSystem

# ============================================
# 技能/被动系统 - 支持新增被动技能
# ============================================

var passive_levels := {}
## 变异等级（与被动分轨；数据来自 GameDB.MUTATIONS）
var mutation_levels := {}
## 局内遗物对 stats 的加法（每局由 Game 写入；_recalc 末尾叠加，与被动/变异/局外强化分轨）
var _run_relic_stat_add: Dictionary = {}
var _run_archetype_id := ""
var _run_archetype_stat_add: Dictionary = {}
var _contract_move_delta := 0.0
var _map_mastery_stat_add: Dictionary = {}

var stats := {
	"atk_bonus": 0.0,
	"move_bonus": 0.0,
	"dr": 0.0,
	"lifesteal": 0.0,
	"xp_bonus": 0.0,
	"fire_rate": 0.0,
	"crit_chance": 0.0,
	"pickup_range": 0.0,
	"hp_growth": 0.0,
	# ========== 新增被动属性 ==========
	"shield_amount": 0.0,     # 护盾值
	"freeze_chance": 0.0,      # 冰冻几率
	"freeze_duration": 0.0,   # 冰冻持续时间
	"explosion_kill_dmg": 0.0, # 击杀爆炸伤害
	"explosion_kill_radius": 0.0, # 爆炸范围
	"armor_break": 0.0,         # 破甲效果
	# 五流派专精
	"frost_duration_add": 0.0,
	"frost_spread_radius": 0.0,
	"burn_dps_mul": 0.0,
	"burn_spread_chance": 0.0,
	"lightning_jumps": 0.0,
	"lightning_jump_range": 0.0,
	"kunai_pierce": 0.0,
	"kunai_fan_angle": 0.0,
	"orbit_count": 0.0,
	"orbit_radius": 0.0,
}

# 护盾相关
var _shield := 0.0
var _shield_max := 0.0
var _shield_regen_timer := 0.0

func _ready() -> void:
	for pid in GameDB.PASSIVES.keys():
		passive_levels[pid] = 0
	for mid in GameDB.MUTATIONS.keys():
		mutation_levels[mid] = 0
	_recalc()

func _process(delta: float) -> void:
	# 护盾再生：每8秒回复一次
	if _shield_max > 0:
		_shield_regen_timer += delta
		if _shield_regen_timer >= 8.0:
			_shield_regen_timer = 0.0
			_shield = minf(_shield + _shield_max * 0.25, _shield_max)

func add_shield(amount: float) -> void:
	_shield = minf(_shield + amount, _shield_max)

func get_shield() -> float:
	return _shield

func consume_shield(amount: float) -> bool:
	if _shield >= amount:
		_shield -= amount
		return true
	return false

func level_up_passive(id: String) -> void:
	var cap: int = int(GameDB.PASSIVES[id]["max_lv"])
	passive_levels[id] = min(int(passive_levels.get(id, 0)) + 1, cap)
	_recalc()
	if int(passive_levels.get(id, 0)) >= 1 and id in GameDB.SCHOOL_MASTERY_IDS:
		if MetaProgress != null and MetaProgress.has_method("mark_school_mastery_seen"):
			MetaProgress.mark_school_mastery_seen(id)
	if int(passive_levels.get(id, 0)) >= cap:
		EventBus.skill_vertex_reached.emit(&"passive", StringName(id))


func level_up_mutation(id: String) -> void:
	if not GameDB.MUTATIONS.has(id):
		return
	var cap: int = int(GameDB.MUTATIONS[id]["max_lv"])
	mutation_levels[id] = min(int(mutation_levels.get(id, 0)) + 1, cap)
	_recalc()
	if int(mutation_levels.get(id, 0)) >= cap:
		EventBus.skill_vertex_reached.emit(&"mutation", StringName(id))


func get_mutation_level(id: String) -> int:
	return int(mutation_levels.get(id, 0))


## 被动每级增量（唯一数值源；卡面与 _recalc 必须同表）
const PASSIVE_PER_LV := {
	"atk_boost": {"stat": "atk_bonus", "per": 0.10, "kind": "pct", "label": "攻击"},
	"move_speed": {"stat": "move_bonus", "per": 0.07, "kind": "pct", "label": "移速"},
	"damage_reduction": {"stat": "dr", "per": 0.07, "kind": "pct", "label": "减伤"},
	"lifesteal": {"stat": "lifesteal", "per": 0.04, "kind": "pct", "label": "吸血"},
	"xp_boost": {"stat": "xp_bonus", "per": 0.14, "kind": "pct", "label": "经验"},
	"fire_rate": {"stat": "fire_rate", "per": 0.10, "kind": "pct", "label": "射速"},
	"crit_chance": {"stat": "crit_chance", "per": 0.06, "kind": "pct", "label": "暴击"},
	"pickup_range": {"stat": "pickup_range", "per": 28.0, "kind": "flat", "label": "拾取"},
	"hp_growth": {"stat": "hp_growth", "per": 18.0, "kind": "flat", "label": "生命"},
	"shield": {"stat": "shield_amount", "per": 15.0, "kind": "flat", "label": "护盾"},
	"freeze": {"stat": "freeze_chance", "per": 0.08, "kind": "pct", "label": "冻结几率", "extra": "时长 +0.1秒"},
	"explosion_kill": {"stat": "explosion_kill_dmg", "per": 20.0, "kind": "flat", "label": "爆炸伤害", "extra": "范围 +15"},
	"armor_break": {"stat": "armor_break", "per": 0.05, "kind": "pct", "label": "增伤"},
	"frost_mastery": {"stat": "frost_duration_add", "per": 0.12, "kind": "sec", "label": "冻结时长", "extra": "扩散 +28"},
	"burn_mastery": {"stat": "burn_dps_mul", "per": 0.18, "kind": "pct", "label": "灼烧伤害", "extra": "蔓延 +12%"},
	"lightning_mastery": {"stat": "lightning_jumps", "per": 1.0, "kind": "flat", "label": "连锁次数", "extra": "跳跃 +40"},
	"pierce_mastery": {"stat": "kunai_pierce", "per": 1.0, "kind": "flat", "label": "穿透层数", "extra": "扇形 +0.05"},
	"orbit_mastery": {"stat": "orbit_count", "per": 1.0, "kind": "flat", "label": "环绕数量", "extra": "轨道 +22"},
}


## 升级卡文案：本级增量，数值与 PASSIVE_PER_LV / _recalc 一致（禁止近似）
static func passive_upgrade_effect_text(pid: String) -> String:
	if not PASSIVE_PER_LV.has(pid):
		return ""
	var row: Dictionary = PASSIVE_PER_LV[pid]
	var per := float(row["per"])
	var label := String(row["label"])
	var kind := String(row["kind"])
	var main := ""
	if kind == "pct":
		main = "%s +%d%%" % [label, int(round(per * 100.0))]
	elif kind == "sec":
		main = "%s +%.2f秒" % [label, per]
	else:
		main = "%s +%d" % [label, int(round(per))]
	var extra := String(row.get("extra", ""))
	if not extra.is_empty():
		return "%s · %s" % [main, extra]
	return main


func _recalc() -> void:
	# 攻击力加成：每级+10%，5级=50%（稍微增强）
	stats["atk_bonus"] = float(passive_levels.get("atk_boost", 0)) * float(PASSIVE_PER_LV["atk_boost"]["per"])
	# 移动速度加成：每级+7%，5级=35%
	stats["move_bonus"] = float(passive_levels.get("move_speed", 0)) * float(PASSIVE_PER_LV["move_speed"]["per"])
	# 减伤：每级+7%，上限75%
	stats["dr"] = min(float(passive_levels.get("damage_reduction", 0)) * float(PASSIVE_PER_LV["damage_reduction"]["per"]), 0.75)
	# 吸血：每级+4%伤害回复
	stats["lifesteal"] = float(passive_levels.get("lifesteal", 0)) * float(PASSIVE_PER_LV["lifesteal"]["per"])
	# 经验加成：每级+14%
	stats["xp_bonus"] = float(passive_levels.get("xp_boost", 0)) * float(PASSIVE_PER_LV["xp_boost"]["per"])
	# 射速加成：每级+10%
	stats["fire_rate"] = float(passive_levels.get("fire_rate", 0)) * float(PASSIVE_PER_LV["fire_rate"]["per"])
	# 暴击率：每级+6%，5级=30%（加上基础5%=35%）
	stats["crit_chance"] = GameDB.BASE_CRIT_CHANCE + float(passive_levels.get("crit_chance", 0)) * float(PASSIVE_PER_LV["crit_chance"]["per"])
	# 拾取半径：每级+28像素，5级=+140px
	stats["pickup_range"] = float(passive_levels.get("pickup_range", 0)) * float(PASSIVE_PER_LV["pickup_range"]["per"])
	# 生命成长：每级+18最大HP，5级=+90HP
	stats["hp_growth"] = float(passive_levels.get("hp_growth", 0)) * float(PASSIVE_PER_LV["hp_growth"]["per"])
	
	# ========== 新增被动效果计算 ==========
	# 护盾：每级+15护盾值，最大45
	stats["shield_amount"] = float(passive_levels.get("shield", 0)) * float(PASSIVE_PER_LV["shield"]["per"])
	
	# 冰霜：每级+8%冰冻几率，+0.1秒持续时间
	stats["freeze_chance"] = float(passive_levels.get("freeze", 0)) * float(PASSIVE_PER_LV["freeze"]["per"])
	stats["freeze_duration"] = float(passive_levels.get("freeze", 0)) * 0.1
	
	# 击杀爆炸：每级+20伤害，+15范围
	var ek_lv: int = int(passive_levels.get("explosion_kill", 0))
	stats["explosion_kill_dmg"] = float(ek_lv) * float(PASSIVE_PER_LV["explosion_kill"]["per"])
	stats["explosion_kill_radius"] = 60.0 + float(ek_lv) * 15.0
	
	# 锋刃增伤：每级+5%出伤（id 仍为 armor_break，兼容旧存档）
	stats["armor_break"] = float(passive_levels.get("armor_break", 0)) * float(PASSIVE_PER_LV["armor_break"]["per"])

	# 五流派专精：机制成长（与通用 atk% 分轨）
	var frost_m := float(passive_levels.get("frost_mastery", 0))
	stats["frost_duration_add"] = frost_m * float(PASSIVE_PER_LV["frost_mastery"]["per"])
	stats["frost_spread_radius"] = frost_m * 28.0
	stats["freeze_duration"] = float(stats["freeze_duration"]) + float(stats["frost_duration_add"])
	var burn_m := float(passive_levels.get("burn_mastery", 0))
	stats["burn_dps_mul"] = burn_m * float(PASSIVE_PER_LV["burn_mastery"]["per"])
	stats["burn_spread_chance"] = burn_m * 0.12
	var light_m := float(passive_levels.get("lightning_mastery", 0))
	stats["lightning_jumps"] = light_m * float(PASSIVE_PER_LV["lightning_mastery"]["per"])
	stats["lightning_jump_range"] = light_m * 40.0
	var pierce_m := float(passive_levels.get("pierce_mastery", 0))
	stats["kunai_pierce"] = pierce_m * float(PASSIVE_PER_LV["pierce_mastery"]["per"])
	stats["kunai_fan_angle"] = pierce_m * 0.05
	var orbit_m := float(passive_levels.get("orbit_mastery", 0))
	stats["orbit_count"] = orbit_m * float(PASSIVE_PER_LV["orbit_mastery"]["per"])
	stats["orbit_radius"] = orbit_m * 22.0
	
	# ========== 变异：在被动结算后逐项叠加 ==========
	for mid in GameDB.MUTATIONS.keys():
		var ml: int = int(mutation_levels.get(mid, 0))
		if ml <= 0:
			continue
		var mdef: Dictionary = GameDB.MUTATIONS[mid]
		var per_lv: Dictionary = mdef.get("stats_per_lv", {}) as Dictionary
		for sk in per_lv.keys():
			var add: float = float(per_lv[sk]) * float(ml)
			if stats.has(sk):
				stats[sk] = float(stats[sk]) + add
			else:
				stats[sk] = add
	
	stats["dr"] = minf(float(stats["dr"]), 0.78)
	stats["crit_chance"] = clampf(float(stats["crit_chance"]), 0.0, 0.72)
	# 局外永久强化（MetaProgress）：在被动/变异之后叠加
	stats["atk_bonus"] = float(stats["atk_bonus"]) + MetaProgress.get_meta_atk_bonus_add()
	stats["move_bonus"] = float(stats["move_bonus"]) + MetaProgress.get_meta_move_bonus_add()
	stats["hp_growth"] = float(stats["hp_growth"]) + MetaProgress.get_meta_hp_flat_bonus()
	for mk in _map_mastery_stat_add.keys():
		var addv := float(_map_mastery_stat_add[mk])
		if stats.has(mk):
			stats[mk] = float(stats[mk]) + addv
		else:
			stats[mk] = addv
	stats["move_bonus"] = float(stats["move_bonus"]) + _contract_move_delta
	for rk in _run_relic_stat_add.keys():
		var addv: float = float(_run_relic_stat_add[rk])
		if stats.has(rk):
			stats[rk] = float(stats[rk]) + addv
		else:
			stats[rk] = addv
	for ak in _run_archetype_stat_add.keys():
		var a_add: float = float(_run_archetype_stat_add[ak])
		if stats.has(ak):
			stats[ak] = float(stats[ak]) + a_add
		else:
			stats[ak] = a_add
	stats["dr"] = minf(float(stats["dr"]), 0.78)
	_shield_max = float(stats["shield_amount"])


func set_run_relic_stat_add(adds: Dictionary) -> void:
	_run_relic_stat_add.clear()
	for k in adds.keys():
		_run_relic_stat_add[String(k)] = float(adds[k])
	_recalc()


func merge_run_relic_stat_add(adds: Dictionary) -> void:
	for k in adds.keys():
		var kk := String(k)
		_run_relic_stat_add[kk] = float(_run_relic_stat_add.get(kk, 0.0)) + float(adds[kk])
	_recalc()


func set_run_archetype(id: String, stat_add: Dictionary) -> void:
	_run_archetype_id = id
	_run_archetype_stat_add.clear()
	for k in stat_add.keys():
		_run_archetype_stat_add[String(k)] = float(stat_add[k])
	_recalc()


func apply_challenge_contract(contract_cfg: Dictionary) -> void:
	var move_mul := float(contract_cfg.get("player_move_mul", 1.0))
	_contract_move_delta = 0.0
	if move_mul < 0.999:
		_contract_move_delta = -(1.0 - move_mul) * 0.12
	_recalc()


func apply_map_mastery_bonus(adds: Dictionary) -> void:
	_map_mastery_stat_add.clear()
	for k in adds.keys():
		_map_mastery_stat_add[String(k)] = float(adds[k])
	_recalc()


func get_run_archetype_id() -> String:
	return _run_archetype_id

func get_passive_level(id: String) -> int:
	return int(passive_levels.get(id, 0))

# 检查是否有护盾（被动或变异叠的 shield_amount）
func has_shield_passive() -> bool:
	return float(stats.get("shield_amount", 0.0)) > 0.01
