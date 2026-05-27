extends Node

# ============================================
# 游戏数据配置
# ============================================

## 权威版本号（主菜单/发版信息等统一从此读取）
const GAME_VERSION := "v2.2"

const RUN_TIME_SECONDS := 25 * 60  # 游戏时间从20分钟增加到25分钟
## 撤离前最后 N 秒显示 HUD 警报（与 RUN_TIME_SECONDS 配合）
const EXTRACTION_ALERT_BEFORE_SEC := 60
const ENEMY_MAX := 3200  # 增加最大敌人数
const EXP_ORB_MAX := 2500
const ACTIVE_RADIUS_PX := 2200.0  # 增加活动范围
const BOSS_SPAWN_TIME := 22 * 60  # BOSS在22分钟出现

# 无尽模式配置
const ENDLESS_ENEMY_HP_SCALE_PER_MIN := 0.015    # 每分钟HP+1.5%
const ENDLESS_ENEMY_DMG_SCALE_PER_MIN := 0.012    # 每分钟伤害+1.2%
const ENDLESS_ENEMY_SPEED_SCALE_PER_MIN := 0.005  # 每分钟速度+0.5%
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

const WEAPONS := {
	"kunai": {"name":"苦无","base_cd":0.32,"base_dmg":20,"type":"projectile"},
	"quantum_ball": {"name":"足球","base_cd":0.75,"base_dmg":22,"type":"aoe"},
	"lightning": {"name":"雷电发射器","base_cd":1.0,"base_dmg":38,"type":"chain"},
	"rocket": {"name":"火箭发射器","base_cd":1.2,"base_dmg":52,"type":"explosive"},
	"molotov": {"name":"燃烧瓶","base_cd":1.5,"base_dmg":14,"type":"dot"},
	"guardian": {"name":"守卫者","base_cd":0.18,"base_dmg":10,"type":"orbit"},
	"drone_ab": {"name":"AB无人机","base_cd":0.15,"base_dmg":8,"type":"orbit"},
	"boomerang": {"name":"回旋镖","base_cd":0.8,"base_dmg":20,"type":"return"},
	# ========== 新增功能性武器 ==========
	"frost_aura": {"name":"冰霜领域","base_cd":0.5,"base_dmg":8,"type":"aura","desc":"持续减速周围敌人"},
	"stun_mine": {"name":"眩晕地雷","base_cd":2.0,"base_dmg":15,"type":"trap","desc":"踩到触发范围眩晕"},
	"heal_aura": {"name":"治疗光环","base_cd":0.8,"base_dmg":0,"type":"heal","desc":"持续恢复生命"}
}

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
	"shield":{"name":"护盾","max_lv":3,"desc":"定期获得护盾吸收伤害"},  # 护盾被动
	"freeze":{"name":"冰霜","max_lv":3,"desc":"攻击附带减速效果"},  # 冰冻被动
	"explosion_kill":{"name":"击杀爆炸","max_lv":3,"desc":"击杀敌人时造成范围爆炸"},  # 击杀爆炸
	"armor_break":{"name":"破甲","max_lv":3,"desc":"攻击降低敌人防御"},  # 破甲
}

# ========== 《重生细胞》式：独立「变异」池（与武器/被动分轨；三选一 id 前缀 m:）==========
# roll_weight：进入加权池的份数，越大越容易出现在三卡中（与 w:/p: 分开调）
# stats_per_lv：每层叠加到 SkillSystem.stats（在被动结算之后加法叠乘键）
const MUTATIONS := {
	"violet_madness": {"name": "异变·狂乱", "max_lv": 3, "icon": "💢", "roll_weight": 5, "stats_per_lv": {"atk_bonus": 0.034}},
	"violet_fertility": {"name": "异变·丰壤", "max_lv": 3, "icon": "🌿", "roll_weight": 4, "stats_per_lv": {"hp_growth": 22.0}},
	"violet_sprint": {"name": "异变·奔行", "max_lv": 3, "icon": "⚡", "roll_weight": 4, "stats_per_lv": {"move_bonus": 0.05}},
	"violet_carapace": {"name": "异变·甲壳", "max_lv": 3, "icon": "🛡", "roll_weight": 3, "stats_per_lv": {"dr": 0.024}},
	"violet_gluttony": {"name": "异变·饕餮", "max_lv": 3, "icon": "📈", "roll_weight": 4, "stats_per_lv": {"xp_bonus": 0.055}},
	"violet_siphon": {"name": "异变·血契", "max_lv": 3, "icon": "🩸", "roll_weight": 3, "stats_per_lv": {"lifesteal": 0.026}},
	"violet_overclock": {"name": "异变·过载", "max_lv": 3, "icon": "🔧", "roll_weight": 4, "stats_per_lv": {"fire_rate": 0.052}},
	"violet_malice": {"name": "异变·歹毒", "max_lv": 3, "icon": "🎯", "roll_weight": 3, "stats_per_lv": {"crit_chance": 0.024}},
	"violet_magnet": {"name": "异变·引力", "max_lv": 3, "icon": "🧲", "roll_weight": 3, "stats_per_lv": {"pickup_range": 26.0}},
	"violet_barrier": {"name": "异变·屏障", "max_lv": 3, "icon": "🔷", "roll_weight": 3, "stats_per_lv": {"shield_amount": 14.0}}
}

# 融合定义 - 每种融合有独特效果描述
const FUSIONS := {
	"kunai_ex":{"weapon":"kunai","requires":{"xp_boost":3},"desc":"无限追踪穿透+多重投射"},
	"quantum_ball_ex":{"weapon":"quantum_ball","requires":{"atk_boost":3},"desc":"链式反弹+BOSS神圣一击"},
	"lightning_ex":{"weapon":"lightning","requires":{"fire_rate":3},"desc":"超长眩晕+5次链式跳跃"},
	"rocket_ex":{"weapon":"rocket","requires":{"atk_boost":3},"desc":"二次爆炸+1.5x范围"},
	"molotov_ex":{"weapon":"molotov","requires":{"damage_reduction":3},"desc":"1.5x持续时间+1.3x范围"},
	"guardian_ex":{"weapon":"guardian","requires":{"damage_reduction":3},"desc":"+2守卫者+强力击退"},
	"drone_ex":{"weapon":"drone_ab","requires":{"fire_rate":3},"desc":"+2无人机+轨道扩展"},
	"boomerang_ex":{"weapon":"boomerang","requires":{"move_speed":3},"desc":"双程90%伤害+环绕伤害"},
	# ========== 新功能性武器融合 ==========
	"frost_aura_ex":{"weapon":"frost_aura","requires":{"freeze":3},"desc":"极寒领域：冻结敌人"},
	"stun_mine_ex":{"weapon":"stun_mine","requires":{"atk_boost":3},"desc":"连锁地雷：触发连锁爆炸"},
	"heal_aura_ex":{"weapon":"heal_aura","requires":{"lifesteal":3},"desc":"生命之泉：吸收敌人生命"}
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
		"desc": "火控平滑：射速体感 +6%（叠在 fire_rate 加成上）。",
		"stat_add": {"fire_rate": 0.06},
		"unlock_min_wins": 0,
		"scrap_unlock": 52,
	},
}

const ENEMY_TYPES := [
	{"name":"grunter", "hp":38.0, "speed":42.0, "damage":4.0, "color":Color(0.68, 0.55, 0.92, 1.0)},
	{"name":"runner", "hp":24.0, "speed":72.0, "damage":4.0, "color":Color(0.55, 0.92, 0.38, 1.0)},
	{"name":"tank", "hp":110.0, "speed":28.0, "damage":7.0, "color":Color(0.48, 0.58, 0.72, 1.0)},
	{"name":"spitter", "hp":46.0, "speed":35.0, "damage":5.0, "color":Color(0.32, 0.88, 0.52, 1.0)},
	{"name":"boomer", "hp":30.0, "speed":55.0, "damage":10.0, "color":Color(1.0, 0.78, 0.22, 1.0)},
	{"name":"guard", "hp":64.0, "speed":33.0, "damage":5.0, "color":Color(0.38, 0.62, 1.0, 1.0)},
	{"name":"summoner", "hp":58.0, "speed":30.0, "damage":4.0, "color":Color(0.72, 0.42, 1.0, 1.0)},
	{"name":"charger", "hp":52.0, "speed":60.0, "damage":7.0, "color":Color(1.0, 0.35, 0.58, 1.0)},
	{"name":"shade", "hp":70.0, "speed":48.0, "damage":6.0, "color":Color(0.58, 0.62, 0.82, 1.0)},
	{"name":"elite", "hp":220.0, "speed":40.0, "damage":10.0, "color":Color(0.98, 0.18, 0.2, 1.0)}
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

const MAP_TEMPLATES := [
	{"id":"city_ruins", "title": "第1区·废墟禁区", "spawn_radius_min":620.0, "spawn_radius_max":980.0, "ranged_weight":0.18, "xp_pickup_mul": 1.0, "hint": "废墟：刷怪圈略远，适合拉扯与磁吸走位。"},
	{"id":"lab_corridor", "title": "第2区·实验廊道", "spawn_radius_min":600.0, "spawn_radius_max":900.0, "ranged_weight":0.32, "xp_pickup_mul": 1.0, "hint": "廊道：远程比重略高，优先找掩体与冲刺穿缝。"},
	{"id":"desert_border", "title": "第3区·荒漠边境", "spawn_radius_min":700.0, "spawn_radius_max":1060.0, "ranged_weight":0.24, "xp_pickup_mul": 1.0, "hint": "边境：开阔图，冲刺与走位空间更大。"},
	{"id":"rain_quarters", "title": "第4区·雨巷补给", "spawn_radius_min":580.0, "spawn_radius_max":940.0, "ranged_weight":0.26, "xp_pickup_mul": 1.08, "hint": "雨巷区：经验球+8%，更利快速成型。"}
]

## 一句话主题（R12 语气：赛博简报 / 冷硬短句）
const THEME_TAGLINE := "弹壳、尸潮、撤离——简报体幸存者"

const HOWTO_TITLE := "三分钟上手"
const HOWTO_STEPS: PackedStringArray = [
	"走位 + 自动开火；冲刺用来穿怪与躲红圈。",
	"吸绿球升级 → 三选一：先铺一条武器链，再补减伤/移速等生存。",
	"右上角计时归零且存活即撤离胜利；紫精英与终局 BOSS 是硬检查点。",
	"地图光点 = 宝箱/祭坛；节律补给会撒额外经验球，别站桩。",
	"作战区域顺序解锁：在已开放中最靠后的那张图「撤离胜利」后，才会开放下一张。",
	"撤离胜利可获得战备碎片（高阶地图更多）；失利也有少量参与奖，余额见主菜单。",
	"主菜单「战备强化」消耗碎片永久提升体质/火力/机动；新局立即生效。",
]

## 性能与自检（R8 / R9）：给开发者/未来的自己看
const PERF_TARGET_MIN_FPS := 50
const PERF_STRESS_HINT := "Profiler：BOSS 存活 + 场上高敌人数 60s，关注 Physics_2D / CanvasItem / Particles。"

const SMOKE_EXPECT_AUTOLOADS: PackedStringArray = [
	"EventBus", "GameDB", "Settings", "RunStats", "CombatFeedback", "MetaProgress", "AudioManager", "ActiveSkillManager", "InputManager"
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
const MINI_BOSS_TIMES := [300, 600, 900]  # 5分钟, 10分钟, 15分钟
const MINI_BOSS_HP_SCALE := 3.5
const MINI_BOSS_DMG_SCALE := 2.0

# ========== BOSS类型定义 ==========
# 0: 暗影巨兽 (默认) - 均衡型
# 1: 雷霆领主 - 快速攻击型
# 2: 熔岩巨魔 - 高血量型
const BOSS_TYPES := {
	0: {"name":"暗影巨兽", "hp_scale":1.0, "dmg_scale":1.0, "speed_scale":1.0, "special":"无", "color":Color(0.85, 0.12, 0.12, 1.0)},
	1: {"name":"雷霆领主", "hp_scale":0.7, "dmg_scale":1.3, "speed_scale":1.4, "special":"闪电链", "color":Color(0.3, 0.5, 1.0, 1.0)},
	2: {"name":"熔岩巨魔", "hp_scale":1.8, "dmg_scale":0.8, "speed_scale":0.6, "special":"岩浆弹幕", "color":Color(1.0, 0.4, 0.1, 1.0)}
}

# BOSS技能配置
const BOSS_SKILLS := {
	"lightning_chain": {"name":"闪电链", "damage":25.0, "range":200.0, "chain_count":5, "cooldown":3.0},
	"magma_barrage": {"name":"岩浆弹幕", "damage":35.0, "projectile_count":8, "cooldown":4.0},
	"enrage": {"name":"狂暴", "dmg_increase":0.5, "hp_threshold":0.3}
}

# ========== 随机事件系统 ==========
# 事件类型
const EVENT_TYPES := {
	"treasure_box": {"name":"宝箱", "spawn_interval":92.0, "reward":"random"},
	"curse_altar": {"name":"诅咒祭坛", "spawn_interval":138.0, "reward":"curse"},
	"healing_shrine": {"name":"治疗祭坛", "spawn_interval":115.0, "reward":"heal"}
}

# 宝箱奖励
const TREASURE_REWARDS := [
	{"type":"xp", "min":15, "max":25, "name":"大量经验"},
	{"type":"weapon", "weight":1, "name":"随机武器"},
	{"type":"passive", "weight":1, "name":"随机被动+1"}
]

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


func run_progress_normalized(elapsed_sec: float) -> float:
	return clampf(elapsed_sec / float(RUN_TIME_SECONDS), 0.0, 1.0)


## 导演目标乘子里「纯时间」贡献，约 0～0.34；前期缓、中后期抬、撤离前再挤一档
func director_time_pressure_add(u: float) -> float:
	var uu := clampf(u, 0.0, 1.0)
	var a := smoothstep_f(0.0, 0.32, uu) * 0.09
	var b := smoothstep_f(0.18, 0.70, uu) * 0.11
	var c := smoothstep_f(0.52, 0.98, uu) * 0.13
	return minf(a + b + c, 0.34)


## 期望等级曲线：在旧版 `1 + elapsed/25` 附近，前段略宽容、后段略收紧
func director_expected_level(elapsed_sec: float) -> float:
	var linear := elapsed_sec / 25.0
	var u := run_progress_normalized(elapsed_sec)
	var wrap := lerpf(0.9, 1.06, smoothstep_f(0.0, 0.92, u))
	return maxf(1.0, 1.0 + linear * wrap)


## 每波生成数量里的「分钟项」：前期略少、中后期追平并略超线性，避免台阶感
func director_wave_time_bonus(elapsed_sec: float) -> int:
	var m := elapsed_sec / 60.0
	var u := run_progress_normalized(elapsed_sec)
	var curve := lerpf(0.72, 1.08, smoothstep_f(0.08, 0.9, u))
	return maxi(0, int(round(m * curve)))


## 动态存活池阈值里的时间分量（乘原每分钟 150 的系数）
func director_alive_pressure_minutes(elapsed_sec: float) -> float:
	var m := elapsed_sec / 60.0
	var u := run_progress_normalized(elapsed_sec)
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
	# 优先磁盘 PNG：与导入压缩纹理解耦，避免 Texture2D.get_image() 为 null 时整图失效（玩家/敌人成纯色块或全透明）
	if FileAccess.file_exists(res_path):
		var abs_path := ProjectSettings.globalize_path(res_path)
		var disk_img := Image.new()
		if disk_img.load(abs_path) == OK:
			return disk_img
	if ResourceLoader.exists(res_path):
		var res: Resource = ResourceLoader.load(res_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is Texture2D:
			var ti: Texture2D = res as Texture2D
			var from_tex: Image = ti.get_image()
			if from_tex != null:
				return from_tex
	return null
