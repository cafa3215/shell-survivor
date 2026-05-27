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
	"armor_break": 0.0         # 破甲效果
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


func _recalc() -> void:
	# 攻击力加成：每级+10%，5级=50%（稍微增强）
	stats["atk_bonus"] = float(passive_levels.get("atk_boost", 0)) * 0.10
	# 移动速度加成：每级+7%，5级=35%
	stats["move_bonus"] = float(passive_levels.get("move_speed", 0)) * 0.07
	# 减伤：每级+7%，上限75%
	stats["dr"] = min(float(passive_levels.get("damage_reduction", 0)) * 0.07, 0.75)
	# 吸血：每级+4%伤害回复
	stats["lifesteal"] = float(passive_levels.get("lifesteal", 0)) * 0.04
	# 经验加成：每级+14%
	stats["xp_bonus"] = float(passive_levels.get("xp_boost", 0)) * 0.14
	# 射速加成：每级+10%
	stats["fire_rate"] = float(passive_levels.get("fire_rate", 0)) * 0.10
	# 暴击率：每级+6%，5级=30%（加上基础5%=35%）
	stats["crit_chance"] = GameDB.BASE_CRIT_CHANCE + float(passive_levels.get("crit_chance", 0)) * 0.06
	# 拾取半径：每级+28像素，5级=+140px
	stats["pickup_range"] = float(passive_levels.get("pickup_range", 0)) * 28.0
	# 生命成长：每级+18最大HP，5级=+90HP
	stats["hp_growth"] = float(passive_levels.get("hp_growth", 0)) * 18.0
	
	# ========== 新增被动效果计算 ==========
	# 护盾：每级+15护盾值，最大45
	stats["shield_amount"] = float(passive_levels.get("shield", 0)) * 15.0
	
	# 冰霜：每级+8%冰冻几率，+0.1秒持续时间
	stats["freeze_chance"] = float(passive_levels.get("freeze", 0)) * 0.08
	stats["freeze_duration"] = float(passive_levels.get("freeze", 0)) * 0.1
	
	# 击杀爆炸：每级+20伤害，+15范围
	var ek_lv: int = int(passive_levels.get("explosion_kill", 0))
	stats["explosion_kill_dmg"] = float(ek_lv) * 20.0
	stats["explosion_kill_radius"] = 60.0 + float(ek_lv) * 15.0
	
	# 破甲：每级+5%破甲效果
	stats["armor_break"] = float(passive_levels.get("armor_break", 0)) * 0.05
	
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


func get_run_archetype_id() -> String:
	return _run_archetype_id

func get_passive_level(id: String) -> int:
	return int(passive_levels.get(id, 0))

# 检查是否有护盾（被动或变异叠的 shield_amount）
func has_shield_passive() -> bool:
	return float(stats.get("shield_amount", 0.0)) > 0.01
