extends Node

# ============================================
# 游戏数据配置
# ============================================

## 权威版本号（主菜单/发版信息等统一从此读取）
const GAME_VERSION := "v2.3"
## Web 导出构建戳（export_web.ps1 每次导出自动更新，用于确认本地包版本）
const WEB_BUILD_STAMP := "20260714-221714"
## 强制 Demo（本地调试）；正式 Demo 导出请用 custom_feature=demo
const FORCE_DEMO_BUILD := false
## 持久模式撤离成功后进入无尽突围
const ENDLESS_AFTER_EXTRACTION := true
## 无尽前 N 秒压力更软（跳字不再放大，避免假伤害观感）
const ENDLESS_SOFT_INTRO_SEC := 300.0
const ENDLESS_DAMAGE_NUMBER_MUL := 1.0


func version_line() -> String:
	var demo_bit := " · Demo" if is_demo_build() else ""
	return "版本 %s · build %s%s" % [GAME_VERSION, WEB_BUILD_STAMP, demo_bit]


func is_demo_build() -> bool:
	if FORCE_DEMO_BUILD:
		return true
	return OS.has_feature("demo")

const RUN_TIME_SECONDS := 18 * 60  # 持久模式默认；运行时请用 run_time_for_mode()
## 撤离前最后 N 秒显示 HUD 警报（与 RUN_TIME_SECONDS 配合）
const EXTRACTION_ALERT_BEFORE_SEC := 60
const ENEMY_MAX := 3200  # 池容量上限（非同时目标存活数）
const EXP_ORB_MAX := 2500
const ACTIVE_RADIUS_PX := 4800.0  # 无限大地图：远距离仍激活 AI
## 第 7 周性能软顶：Boss 战目标存活压到 ~400，避免 Boss+尸潮双倍负载
const BOSS_FIGHT_ALIVE_SOFT_CAP := 400
const COMBAT_ALIVE_PERF_SOFT_CAP := 720
const UNLIMITED_WORLD_MOVEMENT := true
## 仅用于 UI/旧逻辑兼容；UNLIMITED_WORLD_MOVEMENT 时不限制玩家坐标
const ARENA_HALF_W := 1200.0
const ARENA_HALF_H := 800.0
const PLAYER_BOUND_MARGIN := 48.0
const ENEMY_SPEED_GLOBAL_MUL := 1.30
const BOSS_SPAWN_TIME := 15 * 60  # 持久模式默认；运行时请用 boss_spawn_time_for_mode()

## 单局模式（试炼 / 标准 / 持久）
const RUN_MODES := {
	"trial": {
		"label": "试炼 · 5分钟",
		"seconds": 300,
		"boss_at": 240,
		"mini_bosses": [120, 180],
		"hint": "快速上手：4 分钟终局首领，击破即胜。",
	},
	"standard": {
		"label": "标准 · 10分钟",
		"seconds": 600,
		"boss_at": 480,
		"mini_bosses": [120, 300, 420],
		"hint": "主流单局：8 分钟终局首领，击破后 30 秒内撤离。",
	},
	"endurance": {
		"label": "持久 · 18分钟",
		"seconds": 1080,
		"boss_at": 900,
		"mini_bosses": [300, 480, 720],
		"hint": "完整体验：15 分钟终局首领，击破后须撤离。",
	},
}
const DEFAULT_RUN_MODE := "standard"
const FUSION_WEAPON_LEVEL := 4
const FUSION_PASSIVE_LEVEL := 2

## 难度阶梯（无新怪物；仅缩放 HP / 伤害 / 碎片倍率）
const DIFFICULTY_TIERS := {
	"normal": {
		"label": "普通",
		"enemy_hp_mul": 1.0,
		"enemy_dmg_mul": 1.0,
		"scrap_mul": 1.0,
		"hint": "标准压力，适合熟悉构筑。",
	},
	"hard": {
		"label": "困难",
		"enemy_hp_mul": 1.28,
		"enemy_dmg_mul": 1.18,
		"scrap_mul": 1.45,
		"hint": "敌人更硬更痛，胜利碎片 +45%。",
	},
	"nightmare": {
		"label": "噩梦",
		"enemy_hp_mul": 1.55,
		"enemy_dmg_mul": 1.32,
		"scrap_mul": 1.85,
		"hint": "高压挑战：胜利碎片 +85%。",
	},
}
const DEFAULT_DIFFICULTY := "normal"

## 挑战契约（局前自选 debuff；无纯数值永久强化）
const CHALLENGE_CONTRACTS := {
	"none": {
		"label": "无契约",
		"desc": "不附加挑战。",
		"scrap_mul": 1.0,
		"player_move_mul": 1.0,
		"enemy_hp_mul": 1.0,
		"enemy_dmg_mul": 1.0,
		"badge": "",
	},
	"brittle": {
		"label": "脆骨契约",
		"desc": "移速体感 −10%，胜利碎片 ×1.35。",
		"scrap_mul": 1.35,
		"player_move_mul": 0.9,
		"enemy_hp_mul": 1.0,
		"enemy_dmg_mul": 1.0,
		"badge": "脆骨",
	},
	"swarm": {
		"label": "尸潮契约",
		"desc": "敌人生命 ×1.2，胜利碎片 ×1.5。",
		"scrap_mul": 1.5,
		"player_move_mul": 1.0,
		"enemy_hp_mul": 1.2,
		"enemy_dmg_mul": 1.0,
		"badge": "尸潮",
	},
	"glass": {
		"label": "玻璃契约",
		"desc": "敌人伤害 ×1.25，胜利碎片 ×1.6。",
		"scrap_mul": 1.6,
		"player_move_mul": 1.0,
		"enemy_hp_mul": 1.0,
		"enemy_dmg_mul": 1.25,
		"badge": "玻璃",
	},
	"iron": {
		"label": "铁骨契约",
		"desc": "敌人生命 ×1.3，胜利碎片 ×1.55。",
		"scrap_mul": 1.55,
		"player_move_mul": 1.0,
		"enemy_hp_mul": 1.3,
		"enemy_dmg_mul": 1.0,
		"badge": "铁骨",
	},
	"shadow": {
		"label": "暗潮契约",
		"desc": "敌人伤害 ×1.35，胜利碎片 ×1.65。",
		"scrap_mul": 1.65,
		"player_move_mul": 1.0,
		"enemy_hp_mul": 1.0,
		"enemy_dmg_mul": 1.35,
		"badge": "暗潮",
	},
}
const DEFAULT_CHALLENGE := "none"

## 五流派专精被动 id（收藏图鉴用）
const SCHOOL_MASTERY_IDS: PackedStringArray = [
	"frost_mastery", "burn_mastery", "lightning_mastery", "pierce_mastery", "orbit_mastery"
]

## 地图精通星奖励：称号进度用，不叠永久数值膨胀
const MAP_MASTERY_PER_STAR: Array[Dictionary] = [{}, {}, {}]
## ★3 条件：击破首领用时上限（秒）
const MAP_MASTERY_SPEED_BOSS_SEC := 480

## 局内碎片情报：升级重抽 / 排除
const RUN_SCRAP_REROLL_COST := 12
const RUN_SCRAP_BAN_COST := 10

# 无尽模式配置
const ENDLESS_ENEMY_HP_SCALE_PER_MIN := 0.028
const ENDLESS_ENEMY_DMG_SCALE_PER_MIN := 0.022
const ENDLESS_ENEMY_SPEED_SCALE_PER_MIN := 0.008
const ENDLESS_SUPPLY_INTERVAL_SEC := 90.0        # BOSS 击破后无尽阶段：周期性补给间隔

# ========== 《弓箭手传说》式：站定输出略快于移动扫射 ==========
const ARCHERO_STATIONARY_VEL_THRESH := 22.0
const ARCHERO_STATIONARY_WEAPON_CD_MUL := 0.88
# ========== 《弹壳特工队》式：升级后短暂磁吸爆发 ==========
const SURVIVOR_LEVELUP_MAGNET_SEC := 2.8
const SURVIVOR_LEVELUP_MAGNET_MULT := 1.75

# ========== 《重生细胞》式节奏：短时连杀 → 轻微移速动量（不叠攻速避免失衡）==========
const DC_KILL_STREAK_WINDOW_SEC := 2.75
const DC_KILL_STREAK_SPEED_PER_KILL := 0.011
const DC_KILL_STREAK_SPEED_CAP := 0.11

# 武器表：战斗伤害在 WeaponSystem 硬编码；此处仅 name/cd/type（已删除未接线的 base_dmg）
const WEAPONS := {
	"kunai": {"name":"苦无","base_cd":0.36,"type":"projectile"},
	"quantum_ball": {"name":"足球","base_cd":0.72,"type":"aoe"},
	"lightning": {"name":"雷电发射器","base_cd":0.95,"type":"chain"},
	"rocket": {"name":"火箭发射器","base_cd":1.15,"type":"explosive"},
	"molotov": {"name":"燃烧瓶","base_cd":1.35,"type":"dot"},
	"guardian": {"name":"守卫者","base_cd":0.20,"type":"orbit"},
	"drone_ab": {"name":"AB无人机","base_cd":0.14,"type":"orbit"},
	"boomerang": {"name":"回旋镖","base_cd":0.72,"type":"return"},
	"frost_aura": {"name":"冰霜领域","base_cd":0.48,"type":"aura","desc":"持续减速；叠专精/进化可脉冲冻结"},
	"stun_mine": {"name":"眩晕地雷","base_cd":1.9,"type":"trap","desc":"踩到触发范围眩晕"},
	"heal_aura": {"name":"治疗光环","base_cd":0.8,"type":"heal","desc":"持续恢复生命"}
}

## 8 路主流构筑平衡目标（标准 10 分钟模式，通关率口径 48–62%）
## power_score：静态相对强度（用于周 7 QA，不进运行时战斗公式）
const BUILD_BALANCE_ROUTES := {
	"kunai": {"label": "苦无穿透", "fusion": "kunai_ex", "target_clear_pct": 58, "power_score": 58},
	"guardian": {"label": "守卫坦克", "fusion": "guardian_ex", "target_clear_pct": 55, "power_score": 55},
	"lightning": {"label": "雷电控场", "fusion": "lightning_ex", "target_clear_pct": 56, "power_score": 56},
	"quantum_ball": {"label": "足球 AoE", "fusion": "quantum_ball_ex", "target_clear_pct": 57, "power_score": 57},
	"drone_ab": {"label": "无人机协同", "fusion": "drone_ex", "target_clear_pct": 56, "power_score": 56},
	"molotov": {"label": "燃爆地带", "fusion": "molotov_ex", "target_clear_pct": 53, "power_score": 53},
	"boomerang": {"label": "回旋双程", "fusion": "boomerang_ex", "target_clear_pct": 52, "power_score": 52},
	"frost_aura": {"label": "冰霜控制", "fusion": "frost_aura_ex", "target_clear_pct": 50, "power_score": 50},
}
const BUILD_CLEAR_PCT_MIN := 48
const BUILD_CLEAR_PCT_MAX := 62
const BUILD_CLEAR_PCT_SPREAD_MAX := 15

const PASSIVES := {
	"xp_boost":{"name":"经验增幅","max_lv":5},
	"atk_boost":{"name":"攻击提升","max_lv":5},
	"move_speed":{"name":"移动速度","max_lv":5},
	"damage_reduction":{"name":"减伤","max_lv":5},
	"lifesteal":{"name":"吸血","max_lv":5},
	"fire_rate":{"name":"额外射速","max_lv":5},
	"crit_chance":{"name":"暴击率","max_lv":5},
	"pickup_range":{"name":"拾取半径","max_lv":5},
	"hp_growth":{"name":"生命成长","max_lv":5},
	# ========== 新增被动技能 ==========
	"shield":{"name":"护盾","max_lv":3,"desc":"定期获得护盾吸收伤害"},
	"freeze":{"name":"冰霜","max_lv":3,"desc":"攻击附带冻结几率"},
	"explosion_kill":{"name":"击杀爆炸","max_lv":3,"desc":"击杀敌人时造成范围爆炸"},
	"armor_break":{"name":"锋刃增伤","max_lv":3,"desc":"攻击额外增伤（不是降低敌人防御）"},
	# ========== 五流派专精（机制成长，非纯 atk%）==========
	"frost_mastery":{"name":"冰域专精","max_lv":3,"desc":"延长冻结并扩散冰冻范围"},
	"burn_mastery":{"name":"燃爆专精","max_lv":3,"desc":"提升灼烧伤害并有几率蔓延"},
	"lightning_mastery":{"name":"雷链专精","max_lv":3,"desc":"增加连锁次数与跳跃距离"},
	"pierce_mastery":{"name":"穿透专精","max_lv":3,"desc":"增加穿透层数与扇形角度"},
	"orbit_mastery":{"name":"环绕专精","max_lv":3,"desc":"增加环绕单位数量与轨道半径"},
}

# ========== 《重生细胞》式：独立「变异」池（与武器/被动分轨；三选一 id 前缀 m:）==========
# roll_weight：进入加权池的份数，越大越容易出现在三卡中（与 w:/p: 分开调）
# stats_per_lv：每层叠加到 SkillSystem.stats（在被动结算之后加法叠乘键）
const MUTATIONS := {
	"violet_madness": {"name": "异变·狂乱", "max_lv": 3, "icon": "狂", "roll_weight": 5, "stats_per_lv": {"atk_bonus": 0.034}},
	"violet_fertility": {"name": "异变·丰壤", "max_lv": 3, "icon": "壤", "roll_weight": 1, "stats_per_lv": {"hp_growth": 22.0}},
	"violet_sprint": {"name": "异变·奔行", "max_lv": 3, "icon": "行", "roll_weight": 4, "stats_per_lv": {"move_bonus": 0.05}},
	"violet_carapace": {"name": "异变·甲壳", "max_lv": 3, "icon": "甲", "roll_weight": 4, "stats_per_lv": {"dr": 0.024}},
	"violet_gluttony": {"name": "异变·饕餮", "max_lv": 3, "icon": "饕", "roll_weight": 4, "stats_per_lv": {"xp_bonus": 0.055}},
	"violet_siphon": {"name": "异变·血契", "max_lv": 3, "icon": "契", "roll_weight": 1, "stats_per_lv": {"lifesteal": 0.026}},
	"violet_overclock": {"name": "异变·过载", "max_lv": 3, "icon": "载", "roll_weight": 4, "stats_per_lv": {"fire_rate": 0.052}},
	"violet_malice": {"name": "异变·歹毒", "max_lv": 3, "icon": "毒", "roll_weight": 3, "stats_per_lv": {"crit_chance": 0.024}},
	"violet_magnet": {"name": "异变·引力", "max_lv": 3, "icon": "引", "roll_weight": 1, "stats_per_lv": {"pickup_range": 26.0}},
	"violet_barrier": {"name": "异变·屏障", "max_lv": 3, "icon": "障", "roll_weight": 1, "stats_per_lv": {"shield_amount": 14.0}}
}

# 融合定义（被动门槛显示值 = FUSION_PASSIVE_LEVEL；运行时仍走 fusion_required_passive_level）
const FUSIONS := {
	"kunai_ex":{"weapon":"kunai","requires":{"xp_boost":2},"desc":"无限追踪穿透+多重投射"},
	"quantum_ball_ex":{"weapon":"quantum_ball","requires":{"atk_boost":2},"desc":"链式反弹+BOSS神圣一击"},
	"lightning_ex":{"weapon":"lightning","requires":{"fire_rate":2},"desc":"超长眩晕+5次链式跳跃"},
	"rocket_ex":{"weapon":"rocket","requires":{"atk_boost":2},"desc":"二次爆炸+1.5x范围"},
	"molotov_ex":{"weapon":"molotov","requires":{"damage_reduction":2},"desc":"1.5x持续时间+1.3x范围"},
	"guardian_ex":{"weapon":"guardian","requires":{"damage_reduction":2},"desc":"+2守卫者+强力击退"},
	"drone_ex":{"weapon":"drone_ab","requires":{"fire_rate":2},"desc":"+2无人机+轨道扩展"},
	"boomerang_ex":{"weapon":"boomerang","requires":{"move_speed":2},"desc":"双程90%伤害+环绕伤害"},
	# ========== 新功能性武器融合 ==========
	"frost_aura_ex":{"weapon":"frost_aura","requires":{"freeze":2},"desc":"极寒领域：冻结敌人"},
	"stun_mine_ex":{"weapon":"stun_mine","requires":{"atk_boost":2},"desc":"连锁地雷：触发连锁爆炸"},
	"heal_aura_ex":{"weapon":"heal_aura","requires":{"lifesteal":2},"desc":"生命之泉：吸收敌人生命"}
}

## 局内「战备遗物」：开局随机 1 件，数值叠在 SkillSystem.stats（与升级三选一池分轨；对标 Magic Survival 式神器条目的轻量版）
## stat_add 的键须与 SkillSystem.stats 一致；hp_growth 为「+最大生命」的增量（与被动生命成长同口径：100 + hp_growth）
## unlock_min_wins：累计胜场达到后才进入随机池（与碎片入库独立判断）
## scrap_unlock：>0 时需局外支付一次战备碎片「入库」后才进池（入库后永久有效）
const RUN_RELICS := {
	"optic_refraction": {
		"name": "折射校正镜",
		"desc": "火力校准：局内伤害加成 +7%。",
		"stat_add": {"atk_bonus": 0.07},
		"unlock_min_wins": 0,
		"scrap_unlock": 0,
	},
	"magnet_frame": {
		"name": "磁力背架",
		"desc": "拾取强化：经验球吸附范围 +40 像素。",
		"stat_add": {"pickup_range": 40.0},
		"unlock_min_wins": 0,
		"scrap_unlock": 0,
	},
	"data_siphon": {
		"name": "数据虹吸芯",
		"desc": "经验效率：吸球经验 +10%。",
		"stat_add": {"xp_bonus": 0.10},
		"unlock_min_wins": 1,
		"scrap_unlock": 0,
	},
	"buffer_liner": {
		"name": "复合衬层",
		"desc": "防护涂层：减伤 +3.5%。",
		"stat_add": {"dr": 0.035},
		"unlock_min_wins": 3,
		"scrap_unlock": 0,
	},
	"lightweight_coat": {
		"name": "轻装涂层",
		"desc": "机动优先：移速 +4%，最大生命 −8。",
		"stat_add": {"move_bonus": 0.04, "hp_growth": -8.0},
		"unlock_min_wins": 5,
		"scrap_unlock": 0,
	},
	"carrier_stabilizer": {
		"name": "载波稳压单元",
		"desc": "火控平滑：射速 +6%。",
		"stat_add": {"fire_rate": 0.06},
		"unlock_min_wins": 0,
		"scrap_unlock": 52,
	},
}

const ENEMY_TYPES := [
	{"name":"grunter", "hp":38.0, "speed":58.0, "damage":4.0, "color":Color(0.72, 0.58, 0.98, 1.0)},
	{"name":"runner", "hp":24.0, "speed":98.0, "damage":4.0, "color":Color(0.42, 1.0, 0.48, 1.0)},
	{"name":"tank", "hp":110.0, "speed":38.0, "damage":7.0, "color":Color(0.52, 0.62, 0.88, 1.0)},
	{"name":"spitter", "hp":46.0, "speed":48.0, "damage":5.0, "color":Color(0.28, 0.95, 0.62, 1.0)},
	{"name":"boomer", "hp":30.0, "speed":74.0, "damage":10.0, "color":Color(1.0, 0.72, 0.18, 1.0)},
	{"name":"guard", "hp":64.0, "speed":46.0, "damage":5.0, "color":Color(0.35, 0.68, 1.0, 1.0)},
	{"name":"summoner", "hp":58.0, "speed":42.0, "damage":4.0, "color":Color(0.82, 0.38, 1.0, 1.0)},
	{"name":"charger", "hp":52.0, "speed":84.0, "damage":7.0, "color":Color(1.0, 0.32, 0.52, 1.0)},
	{"name":"shade", "hp":70.0, "speed":66.0, "damage":6.0, "color":Color(0.62, 0.66, 0.95, 1.0)},
	{"name":"elite", "hp":220.0, "speed":56.0, "damage":10.0, "color":Color(1.0, 0.22, 0.28, 1.0)}
]

## 局外「战备碎片」：胜利按地图阶递增；失败少量参与奖（原创数值，非内购）
const META_SCRAP_WIN_BASE := 28
const META_SCRAP_WIN_PER_MAP := 14
const META_SCRAP_LOSS := 8

func meta_scrap_win_amount(map_index: int) -> int:
	var mi := clampi(map_index, 0, maxi(0, MAP_TEMPLATES.size() - 1))
	return META_SCRAP_WIN_BASE + mi * META_SCRAP_WIN_PER_MAP

## 局外永久强化（原创数值；消耗战备碎片，与局内三选一分轨）
const META_PERK_HP_PER_LV := 12.0
const META_PERK_ATK_PER_LV := 0.02
const META_PERK_MOVE_PER_LV := 0.015

const META_PERMANENT_UPGRADES := {
	"vitality": {
		"name": "体质强化",
		"desc": "每级：最大生命 +12（局内与被动成长叠加）",
		"max_lv": 5,
		"base_cost": 40,
		"cost_per_lv": 22,
	},
	"firepower": {
		"name": "火力校准",
		"desc": "每级：局内伤害 +2%（叠乘 atk_bonus）",
		"max_lv": 5,
		"base_cost": 45,
		"cost_per_lv": 24,
	},
	"mobility": {
		"name": "机动强化",
		"desc": "每级：移动速度 +1.5%",
		"max_lv": 5,
		"base_cost": 42,
		"cost_per_lv": 22,
	},
}

## map_rule.id：poison_ring / moving_safe_zone / elite_hunt / event_bias（每图一条可感知规则）
const MAP_TEMPLATES := [
	{
		"id": "city_ruins", "title": "第1区·废墟禁区",
		"spawn_radius_min": 380.0, "spawn_radius_max": 620.0, "ranged_weight": 0.18, "xp_pickup_mul": 1.0,
		"hint": "废墟：中期毒圈收缩；圈外减速并被吸入，须主动走位。",
		"zone_objective": {"kind": 3, "kind_name": "远程", "count": 8, "label": "歼灭远程单位"},
		"map_rule": {
			"id": "poison_ring", "start_sec": 120.0, "radius_start": 560.0, "radius_end": 240.0,
			"duration_sec": 360.0, "dps_out": 7.0,
			"announce": "废墟毒圈启动：圈外持续掉血，安全区会收缩。",
		},
	},
	{
		"id": "lab_corridor", "title": "第2区·实验廊道",
		"spawn_radius_min": 360.0, "spawn_radius_max": 580.0, "ranged_weight": 0.32, "xp_pickup_mul": 1.0,
		"hint": "廊道：移动安全区巡场；圈外减速强吸，圈内加速，必须跟圈移动。",
		"zone_objective": {"kind": 6, "kind_name": "召唤者", "count": 5, "label": "清除召唤者"},
		"map_rule": {
			"id": "moving_safe_zone", "start_sec": 90.0, "radius": 210.0, "move_speed": 58.0,
			"retarget_sec": 16.0, "dps_out": 6.0,
			"announce": "实验廊充能场：跟随移动安全区，圈外会受伤。",
		},
	},
	{
		"id": "desert_border", "title": "第3区·荒漠边境",
		"spawn_radius_min": 420.0, "spawn_radius_max": 660.0, "ranged_weight": 0.24, "xp_pickup_mul": 1.0,
		"hint": "边境：精英猎杀奖励强化，主动抢击破更划算。",
		"zone_objective": {"kind": 7, "kind_name": "冲锋者", "count": 6, "label": "击退冲锋者"},
		"map_rule": {
			"id": "elite_hunt", "orb_mul": 1.75, "heal_mul": 1.4, "extra_orbs": 4,
			"announce": "荒漠法则：击破精英猎杀目标可获得强化补给。",
		},
	},
	{
		"id": "rain_quarters", "title": "第4区·雨巷补给",
		"spawn_radius_min": 340.0, "spawn_radius_max": 600.0, "ranged_weight": 0.26, "xp_pickup_mul": 1.08,
		"hint": "雨巷：经验球+8%，宝箱/治疗事件更频繁。",
		"zone_objective": {"kind": 1, "kind_name": "快速单位", "count": 10, "label": "清扫快速威胁"},
		"map_rule": {
			"id": "event_bias",
			"interval_mul": {"treasure_box": 0.70, "healing_shrine": 0.80, "curse_altar": 1.20},
			"announce": "雨巷补给站：宝箱与治疗更频繁，诅咒略少。",
		},
	},
]

## 首武器选定后，前 2 次升级优先出现的构筑前置（被动 / 同武器）
const WEAPON_BUILD_PRIMERS := {
	"kunai": ["p:pierce_mastery", "p:xp_boost", "w:kunai"],
	"quantum_ball": ["p:atk_boost", "w:quantum_ball"],
	"lightning": ["p:lightning_mastery", "p:fire_rate", "w:lightning"],
	"rocket": ["p:atk_boost", "w:rocket"],
	"molotov": ["p:burn_mastery", "p:damage_reduction", "w:molotov"],
	"guardian": ["p:orbit_mastery", "p:damage_reduction", "w:guardian"],
	"drone_ab": ["p:orbit_mastery", "p:fire_rate", "w:drone_ab"],
	"boomerang": ["p:move_speed", "p:crit_chance", "w:boomerang"],
	"frost_aura": ["p:frost_mastery", "p:freeze", "w:frost_aura"],
	"stun_mine": ["p:atk_boost", "w:stun_mine"],
	"heal_aura": ["p:lifesteal", "w:heal_aura"],
}

## 一句话主题（R12 语气：赛博简报 / 冷硬短句）
const THEME_TAGLINE := "弹壳、尸潮、撤离——简报体幸存者"

const HOWTO_TITLE := "上手指南（试炼 5 分 · 标准 10 分）"
const HOWTO_STEPS: PackedStringArray = [
	"推荐先打「试炼 · 5 分钟」：快速上手；主流默认「标准 · 10 分钟」。",
	"走位 + 自动开火；冲刺穿怪、躲红圈预告。",
	"吸绿球升级 → 三选一：先铺一条武器链，再点对应流派专精（冰/火/雷/穿透/环绕）。",
	"终局必须击破首领。试炼：击破即胜；标准/持久：击破后进入撤离光圈并停留。",
	"持久模式撤离成功后可进入「无尽突围」：前 5 分钟刷怪压力较软。",
	"地图光点 = 宝箱/祭坛；完成区域歼灭任务有补给。",
	"难度 / 挑战契约提高压力与碎片收益；升级可用碎片重抽/排除。",
	"战备强化消耗碎片永久提升属性；成就随通关与挑战自动解锁。",
]

## Steam / 商店页短文案（复制到店页即可）
const STORE_PAGE_BLURB := """Shell Survivor — 弹壳、尸潮、撤离。

• 试炼 5 分钟：退款窗口内也能跑完一局，击破首领即胜。
• 标准 10 分钟：主流单局；击破首领后 30 秒撤离。
• 持久 18 分钟：完整体验 + 撤离后无尽突围。
• 专精 / 遗物 / 融合 / 挑战契约：构筑可复玩，不靠数值膨胀堆 Meta。
• 地图精通与融合/流派图鉴：收藏勾选目标（无永久属性加成）。
• 契约 × 难度徽章：满战备后仍有挑战钩。
Demo 锁定试炼模式；完整版解锁标准、持久与全套挑战。"""

## Steam 成就定义（API 名 = 键；本地 AchievementService 持久化）
const STEAM_ACHIEVEMENTS := {
	"first_win": {"name": "首次通关", "desc": "任意模式完成一次胜利。"},
	"mode_trial_win": {"name": "试炼合格", "desc": "试炼模式胜利。"},
	"mode_standard_win": {"name": "标准撤离", "desc": "标准模式胜利。"},
	"mode_endurance_win": {"name": "持久突围", "desc": "持久模式胜利。"},
	"diff_nightmare_win": {"name": "噩梦幸存者", "desc": "噩梦难度胜利。"},
	"chal_brittle_win": {"name": "脆骨契约", "desc": "携带脆骨契约胜利。"},
	"chal_swarm_win": {"name": "尸潮契约", "desc": "携带尸潮契约胜利。"},
	"chal_glass_win": {"name": "玻璃契约", "desc": "携带玻璃契约胜利。"},
	"chal_iron_win": {"name": "铁骨契约", "desc": "携带铁骨契约胜利。"},
	"chal_shadow_win": {"name": "暗潮契约", "desc": "携带暗潮契约胜利。"},
	"chal_glass_nightmare": {"name": "碎镜噩梦", "desc": "玻璃契约 × 噩梦难度胜利。"},
	"chal_any_nightmare": {"name": "契约噩梦", "desc": "任意挑战契约 × 噩梦难度胜利。"},
	"build_kunai": {"name": "苦无成型", "desc": "以苦无为主输出胜利。"},
	"build_guardian": {"name": "守卫成型", "desc": "以守卫者为主输出胜利。"},
	"build_lightning": {"name": "雷电成型", "desc": "以雷电为主输出胜利。"},
	"build_quantum_ball": {"name": "足球成型", "desc": "以足球为主输出胜利。"},
	"build_drone_ab": {"name": "无人机成型", "desc": "以无人机为主输出胜利。"},
	"build_molotov": {"name": "燃爆成型", "desc": "以燃烧/爆炸为主输出胜利。"},
	"build_boomerang": {"name": "回旋成型", "desc": "以回旋镖为主输出胜利。"},
	"build_frost_aura": {"name": "冰霜成型", "desc": "以冰霜领域为主输出胜利。"},
	"build_all_eight": {"name": "八方火力", "desc": "八条主流构筑均至少通关一次。"},
	"map_three_stars": {"name": "区域精通", "desc": "单张地图达成三星。"},
	"endless_survive": {"name": "无尽余烬", "desc": "持久撤离后进入无尽并坚持到倒下。"},
	"codex_fusions_half": {"name": "融合见闻", "desc": "至少见过半数武器融合。"},
	"codex_schools_all": {"name": "五流皆通", "desc": "五流派专精均至少点过一级。"},
}

## 性能与自检（R8 / R9）：给开发者/未来的自己看
const PERF_TARGET_MIN_FPS := 50
const PERF_STRESS_HINT := "Profiler：BOSS 存活 + 场上高敌人数 60s，关注 Physics_2D / CanvasItem / Particles。"

const SMOKE_EXPECT_AUTOLOADS: PackedStringArray = [
	"EventBus", "GameDB", "Settings", "RunStats", "CombatFeedback", "MetaProgress", "AchievementService", "AudioManager", "ActiveSkillManager", "InputManager"
]

## 结算用：武器伤害来源 key → 中文（R3）
const DAMAGE_SOURCE_LABELS := {
	"kunai_hit": "苦无", "kunai_pierce": "苦无穿透",
	"quantum_burst": "量子球", "quantum_bounce": "量子弹跳", "quantum_holy": "量子神圣",
	"lightning_strike": "雷电", "lightning_jump": "雷电跳跃",
	"rocket_explode": "火箭爆炸", "rocket_secondary": "火箭二次",
	"molotov_burn": "燃烧瓶", "molotov_impact": "燃烧瓶落地",
	"guardian_spin": "守卫环绕", "drone_attack": "无人机", "drone_pulse": "无人机脉冲",
	"boomerang_hit": "回旋镖", "mine_explosion": "地雷",
	"frost_tick": "冰霜领域", "stun_mine": "眩晕地雷", "heal_aura": "治疗光环",
	"generic_light": "混合伤害"
}

## 技能事件统计用：skill_id -> 中文名（缺失时会走自动回退）
const SKILL_ID_LABELS := {
	"SK_Player_ActiveLaser_01": "主动激光",
}


func humanize_damage_source(src: String) -> String:
	if DAMAGE_SOURCE_LABELS.has(src):
		return String(DAMAGE_SOURCE_LABELS[src])
	if src.ends_with("_hit"):
		return src.trim_suffix("_hit")
	return src


func humanize_skill_id(skill_id: String) -> String:
	if skill_id.is_empty():
		return "-"
	if SKILL_ID_LABELS.has(skill_id):
		return String(SKILL_ID_LABELS[skill_id])
	for wid in WEAPONS.keys():
		var w := String(wid)
		if skill_id.findn(w) >= 0:
			return String(WEAPONS[w].get("name", w))
	var hm := humanize_damage_source(skill_id)
	return hm if hm != skill_id else skill_id

# 武器栏位上限
const WEAPON_SLOTS := 6

# 冲刺配置 - 优化版
const DASH_SPEED := 900.0  # 稍微提升冲刺速度
const DASH_DURATION := 0.18  # 略微增加冲刺持续时间
const DASH_COOLDOWN := 0.8  # 从1.2秒缩短到0.8秒，提升手感
## 翻滚/冲刺触发的无敌（与受击无敌分轨，互不覆盖）
const DASH_IFRAMES := 0.25
## 受伤后的无敌（细胞式：与翻滚无敌分开计时）
const HIT_IFRAMES_SEC := 0.4

# 暴击配置
const CRIT_MULTIPLIER := 2.0
const BASE_CRIT_CHANCE := 0.05  # 5%基础暴击率

# 中BOSS配置
const MINI_BOSS_TIMES := [300, 480, 720]  # 5 / 8 / 12 分钟（首领 15 分前）
const MINI_BOSS_HP_SCALE := 3.5
const MINI_BOSS_DMG_SCALE := 2.0
const MINI_BOSS_FIRST_HP_SCALE := 4.2
const MINI_BOSS_FIRST_DMG_SCALE := 2.15

# ========== BOSS类型定义 ==========
# 0: 暗影巨兽 (默认) - 均衡型
# 1: 雷霆领主 - 快速攻击型
# 2: 熔岩巨魔 - 高血量型
const BOSS_TYPES := {
	0: {"name":"暗影巨兽", "hp_scale":1.0, "dmg_scale":1.0, "speed_scale":1.0, "special":"无", "color":Color(0.85, 0.12, 0.12, 1.0)},
	1: {"name":"雷霆领主", "hp_scale":0.7, "dmg_scale":1.3, "speed_scale":1.4, "special":"闪电链", "color":Color(0.3, 0.5, 1.0, 1.0)},
	2: {"name":"熔岩巨魔", "hp_scale":1.8, "dmg_scale":0.8, "speed_scale":0.6, "special":"岩浆弹幕", "color":Color(1.0, 0.4, 0.1, 1.0)}
}

# BOSS技能配置（enrage 由 EnemyManager 实读取）
const BOSS_SKILLS := {
	"lightning_chain": {"name":"闪电链", "damage":25.0, "range":200.0, "chain_count":5, "cooldown":3.0},
	"magma_barrage": {"name":"岩浆弹幕", "damage":35.0, "projectile_count":8, "cooldown":4.0},
	"enrage": {
		"name": "狂暴",
		"hp_threshold": 0.3,
		"hp_threshold_lightning": 0.4,
		"speed_mul": 1.3,
		"dmg_mul": 1.35,
		"dmg_mul_magma": 1.25,
	},
}

# ========== 随机事件系统 ==========
# 事件类型（奖励逻辑在 RandomEvents 内联）
const EVENT_TYPES := {
	"treasure_box": {"name":"宝箱", "spawn_interval":92.0},
	"curse_altar": {"name":"诅咒祭坛", "spawn_interval":138.0},
	"healing_shrine": {"name":"治疗祭坛", "spawn_interval":115.0}
}

# 诅咒祭坛效果
const CURSE_EFFECTS := [
	{"curse":"slow", "name":"移速降低20%", "duration":30.0},
	{"curse":"damage", "name":"伤害降低15%", "duration":30.0},
	{"curse":"nocollect", "name":"无法拾取", "duration":20.0}
]

# 治疗祭坛效果
const HEALING_REWARDS := [
	{"heal":30.0, "name":"恢复30%生命"},
	{"heal":50.0, "name":"恢复50%生命"}
]

# ========== 可整体替换的资源包（把 PNG 放进 game_pack/textures/ 同名覆盖即可）==========
const ASSET_PACK_ROOT := "res://assets/game_pack/"
const ASSET_PACK_TEXTURES := ASSET_PACK_ROOT + "textures/"
const ASSET_PACK_PROJECTILES := ASSET_PACK_ROOT + "vfx/projectiles/"
const ASSET_PACK_KENNEY := "res://assets/vendor/kenney_particle_pack/"
const ASSET_PACK_PARTICLES := ASSET_PACK_ROOT + "vfx/particles/"
const ASSET_PACK_SFX := ASSET_PACK_ROOT + "sfx/"
const ASSET_PACK_SFX_VARIANTS := ASSET_PACK_SFX + "variants/"
const ASSET_PACK_MUSIC := ASSET_PACK_ROOT + "music/"

# ========== 高清生成贴图：优先 game_pack，缺失时回退旧路径 / 程序生成 ==========
const TEX_GEN_PLAYER := ASSET_PACK_TEXTURES + "player_chibi.png"
## 横向三帧跑步条带（宽 = 3×单帧宽，高与 player_chibi 单帧相同）；缺失则仅显示待机
const TEX_GEN_PLAYER_RUN := ASSET_PACK_TEXTURES + "player_run_strip.png"
## 横向三帧朝向条带（左/中/右），用于移动时轻切换增强立体感。
const TEX_GEN_PLAYER_TURN := ASSET_PACK_TEXTURES + "player_turn_strip.png"
## 与 player_chibi 同尺寸的战斗单帧（缺失则仅用待机/跑步）
const TEX_GEN_PLAYER_ATTACK := ASSET_PACK_TEXTURES + "player_attack.png"
const TEX_GEN_PLAYER_HIT := ASSET_PACK_TEXTURES + "player_hit.png"
const TEX_GEN_ENEMY_BASE := ASSET_PACK_TEXTURES + "enemy_base.png"
const TEX_GEN_ENEMY_ATLAS := ASSET_PACK_TEXTURES + "enemy_atlas.png"
const TEX_GEN_GROUND := ASSET_PACK_TEXTURES + "ground_tile.png"
## 旧版路径（仅作 load_png_if_exists 的磁盘回退参考；常量已指向 game_pack）
const TEX_LEGACY_GENERATED_DIR := "res://assets/textures/generated/"

## 升级时低概率出现的冷幽默短句（细胞式旁白感）
const DC_LEVEL_FLAVOR_LINES: PackedStringArray = [
	"……还能再快点。",
	"继续。别停。",
	"尸体从不多嘴。",
	"节奏对了。",
	"这点场面，不够看。",
	"火力在成型，别省技能。",
	"再升一级，场面就不一样了。",
	"爽感区间快到了。",
	"清屏的节奏，别断。",
	"构筑对了，越打越顺。",
	"下一选可能质变。",
	"别站着发呆，动起来。",
]

# ========== 导演 / 升级节奏曲线（按 RUN_TIME_SECONDS 归一化，单点调手感）==========

func smoothstep_f(edge0: float, edge1: float, x: float) -> float:
	var denom := edge1 - edge0
	var t := 0.0 if abs(denom) < 1e-5 else clampf((x - edge0) / denom, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func normalize_run_mode_id(mode_id: String) -> String:
	var mid := mode_id.strip_edges().to_lower()
	if RUN_MODES.has(mid):
		return mid
	return DEFAULT_RUN_MODE


func get_run_mode(mode_id: String = "") -> Dictionary:
	var mid := normalize_run_mode_id(mode_id if not mode_id.is_empty() else Settings.selected_run_mode)
	return RUN_MODES[mid] as Dictionary


func run_time_for_mode(mode_id: String = "") -> int:
	return int(get_run_mode(mode_id).get("seconds", RUN_TIME_SECONDS))


func boss_spawn_time_for_mode(mode_id: String = "") -> float:
	return float(get_run_mode(mode_id).get("boss_at", BOSS_SPAWN_TIME))


func mini_boss_times_for_mode(mode_id: String = "") -> Array[int]:
	var raw: Array = get_run_mode(mode_id).get("mini_bosses", MINI_BOSS_TIMES)
	var out: Array[int] = []
	for v in raw:
		out.append(int(v))
	return out


func fusion_required_passive_level(original_req: int) -> int:
	return mini(maxi(1, original_req), maxi(FUSION_PASSIVE_LEVEL, int(original_req) - 1))


func normalize_difficulty_id(diff_id: String) -> String:
	var d := diff_id.strip_edges().to_lower()
	if DIFFICULTY_TIERS.has(d):
		return d
	return DEFAULT_DIFFICULTY


func get_difficulty_tier(diff_id: String = "") -> Dictionary:
	var d := normalize_difficulty_id(diff_id if not diff_id.is_empty() else Settings.selected_difficulty)
	return DIFFICULTY_TIERS[d] as Dictionary


func normalize_challenge_id(challenge_id: String) -> String:
	var c := challenge_id.strip_edges().to_lower()
	if CHALLENGE_CONTRACTS.has(c):
		return c
	return DEFAULT_CHALLENGE


func get_challenge_contract(challenge_id: String = "") -> Dictionary:
	var c := normalize_challenge_id(challenge_id if not challenge_id.is_empty() else Settings.selected_challenge)
	return CHALLENGE_CONTRACTS[c] as Dictionary


func map_mastery_key(map_index: int) -> String:
	var i := clampi(map_index, 0, maxi(0, MAP_TEMPLATES.size() - 1))
	return String(MAP_TEMPLATES[i].get("id", "map_%d" % i))


func map_mastery_stars_text(stars: int) -> String:
	var s := clampi(stars, 0, 3)
	var filled := "★".repeat(s)
	var empty := "☆".repeat(3 - s)
	return filled + empty


## 导演目标乘子里「纯时间」贡献，约 0～0.34；前期缓、中后期抬、撤离前再挤一档
func run_progress_normalized(elapsed_sec: float, run_time_sec: float = -1.0) -> float:
	var rt := run_time_sec if run_time_sec > 0.0 else float(run_time_for_mode())
	return clampf(elapsed_sec / rt, 0.0, 1.0)


func director_time_pressure_add(u: float) -> float:
	var uu := clampf(u, 0.0, 1.0)
	var a := smoothstep_f(0.0, 0.32, uu) * 0.09
	var b := smoothstep_f(0.18, 0.70, uu) * 0.11
	var c := smoothstep_f(0.52, 0.98, uu) * 0.13
	return minf(a + b + c, 0.34)


## 期望等级曲线：在旧版 `1 + elapsed/25` 附近，前段略宽容、后段略收紧
func director_expected_level(elapsed_sec: float, run_time_sec: float = -1.0) -> float:
	var linear := elapsed_sec / 25.0
	var u := run_progress_normalized(elapsed_sec, run_time_sec)
	var wrap := lerpf(0.9, 1.06, smoothstep_f(0.0, 0.92, u))
	return maxf(1.0, 1.0 + linear * wrap)


## 每波生成数量里的「分钟项」：前期略少、中后期追平并略超线性，避免台阶感
func director_wave_time_bonus(elapsed_sec: float, run_time_sec: float = -1.0) -> int:
	var m := elapsed_sec / 60.0
	var u := run_progress_normalized(elapsed_sec, run_time_sec)
	var curve := lerpf(0.72, 1.08, smoothstep_f(0.08, 0.9, u))
	return maxi(0, int(round(m * curve)))


## 动态存活池阈值里的时间分量（乘原每分钟 150 的系数）
func director_alive_pressure_minutes(elapsed_sec: float, run_time_sec: float = -1.0) -> float:
	var m := elapsed_sec / 60.0
	var u := run_progress_normalized(elapsed_sec, run_time_sec)
	var curve := lerpf(0.78, 1.12, smoothstep_f(0.1, 0.92, u))
	return m * curve


## 下一级所需经验倍率：平滑替代分段常数，避免升级节奏在阈值处「跳一下」
func xp_need_multiplier_for_level(new_level: int) -> float:
	# 让升级更“有质感”：前期不再连跳，中后期更明显收紧
	var L := float(clampi(new_level, 1, 999))
	var t := smoothstep_f(1.0, 48.0, L)
	var base := lerpf(1.18, 1.28, t)
	var late := 0.06 * smoothstep_f(24.0, 52.0, L)
	return clampf(base + late, 1.16, 1.34)


func run_relic_display_name(id: String) -> String:
	if id.is_empty() or not RUN_RELICS.has(id):
		return ""
	return String(RUN_RELICS[id].get("name", id))


func run_relic_pool_progress_text() -> String:
	var tot := 0
	var ok := 0
	for rid in RUN_RELICS.keys():
		tot += 1
		if MetaProgress.is_run_relic_unlocked_for_pool(String(rid)):
			ok += 1
	return "遗物池 %d/%d" % [ok, tot]


func load_png_if_exists(res_path: String) -> Image:
	if res_path.is_empty():
		return null
	var img := _load_png_at(res_path)
	if img != null:
		return img
	if res_path.begins_with(ASSET_PACK_TEXTURES):
		var legacy_path := TEX_LEGACY_GENERATED_DIR + res_path.get_file()
		return _load_png_at(legacy_path)
	return null


func _load_png_at(res_path: String) -> Image:
	if res_path.is_empty():
		return null
	var img := Image.new()
	# res:// 字节读取：Web 导出无 OS 绝对路径，必须与编辑器共用此路径。
	if FileAccess.file_exists(res_path):
		var file := FileAccess.open(res_path, FileAccess.READ)
		if file != null:
			var data: PackedByteArray = file.get_buffer(file.get_length())
			file.close()
			if _load_image_from_bytes(img, data, res_path):
				return img
		if not OS.has_feature("web"):
			var abs_path := ProjectSettings.globalize_path(res_path)
			if not abs_path.is_empty() and img.load(abs_path) == OK:
				return img
	if ResourceLoader.exists(res_path):
		var res: Resource = ResourceLoader.load(res_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is Texture2D:
			var ti: Texture2D = res as Texture2D
			var from_tex: Image = ti.get_image()
			if from_tex != null and not from_tex.is_empty():
				return from_tex
	return null


func _load_image_from_bytes(img: Image, data: PackedByteArray, hint_path: String) -> bool:
	if data.is_empty():
		return false
	var ext := hint_path.get_extension().to_lower()
	match ext:
		"png":
			return img.load_png_from_buffer(data) == OK
		"jpg", "jpeg":
			return img.load_jpg_from_buffer(data) == OK
		"webp":
			return img.load_webp_from_buffer(data) == OK
		_:
			if img.load_png_from_buffer(data) == OK:
				return true
			if img.load_jpg_from_buffer(data) == OK:
				return true
			return img.load_webp_from_buffer(data) == OK
