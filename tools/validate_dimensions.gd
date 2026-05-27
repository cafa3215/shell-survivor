extends SceneTree

## 十维主链路对齐门禁：
## - 不只检查 Demo，可直接验证 Main/Game 链路关键节点与接口
## - 每个维度至少一个“可运行合约”断言，防止模块与主玩法漂移

const MAIN_SCENE := "res://scenes/Main_new.tscn"
const GAME_SCENE := "res://scenes/Game.tscn"
const UI_THEME_PATH := "res://assets/themes/cyber_theme.tres"


func _init() -> void:
	call_deferred("_run")


func _require(ok: bool, msg: String) -> bool:
	if not ok:
		push_error("validate_dimensions: " + msg)
		return false
	return true


func _autoload(nm: String) -> Node:
	return root.get_node_or_null("/root/" + nm)


func _run() -> void:
	if not _check_autoloads():
		quit(1)
		return
	if not await _check_main_scene():
		quit(1)
		return
	if not await _check_game_scene_dims():
		quit(1)
		return
	print("validate_dimensions: OK")
	quit(0)


func _check_autoloads() -> bool:
	for nm in ["EventBus", "GameDB", "Settings", "AudioManager", "ActiveSkillManager", "MetaProgress"]:
		if not _require(_autoload(nm) != null, "缺少 autoload " + nm):
			return false
	var eb := _autoload("EventBus")
	if not _require(eb != null and eb.has_signal("play_sfx"), "EventBus.play_sfx 信号缺失"):
		return false
	var audio := _autoload("AudioManager")
	if not _require(audio != null and audio.has_method("play_sfx_named"), "AudioManager.play_sfx_named 缺失"):
		return false
	return true


func _check_main_scene() -> bool:
	var packed: Resource = ResourceLoader.load(MAIN_SCENE)
	if not _require(packed != null and packed is PackedScene, "Main_new 场景加载失败"):
		return false
	var main := (packed as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var btn := main.get_node_or_null("MenuLayer/Root/Panel/StartButton")
	if not _require(btn != null, "UI 维度：StartButton 缺失"):
		return false
	main.queue_free()
	await process_frame
	return true


func _check_game_scene_dims() -> bool:
	var packed: Resource = ResourceLoader.load(GAME_SCENE)
	if not _require(packed != null and packed is PackedScene, "Game 场景加载失败"):
		return false
	var game := (packed as PackedScene).instantiate()
	root.add_child(game)
	for _i in 12:
		await process_frame

	# 程序 / 技能 / 地编主链路
	if not _require(game.get_node_or_null("WeaponSystem") != null, "程序维度：WeaponSystem 缺失"):
		return false
	if not _require(game.get_node_or_null("SkillSystem") != null, "技能维度：SkillSystem 缺失"):
		return false
	if not _require(game.get_node_or_null("EnemyManager") != null, "地编维度：EnemyManager 缺失"):
		return false

	# 动作 / 骨骼
	if not _require(game.get_node_or_null("Player") != null, "动作维度：Player 缺失"):
		return false
	if not _require(game.get_node_or_null("Player/PlayerVisuals") != null, "骨骼维度：PlayerVisuals 缺失"):
		return false

	# UI / 特效
	var hud := game.get_node_or_null("HUD")
	if not _require(hud != null and hud.has_method("set_hp"), "UI 维度：HUD.set_hp 缺失"):
		return false
	var pm := game.get_node_or_null("ParticleManager")
	if not _require(pm != null and pm.has_method("shockwave_ring"), "特效维度：ParticleManager.shockwave_ring 缺失"):
		return false

	# 原画 / 建模：关键素材入口 + 主题资源可加载
	var gdb := _autoload("GameDB")
	if not _require(gdb != null and String(gdb.get("TEX_GEN_PLAYER")) != "", "原画维度：TEX_GEN_PLAYER 缺失"):
		return false
	if not _require(gdb != null and String(gdb.get("TEX_GEN_ENEMY_BASE")) != "", "建模维度：TEX_GEN_ENEMY_BASE 缺失"):
		return false
	if not _require(ResourceLoader.load(UI_THEME_PATH) != null, "UI/原画维度：cyber_theme 资源加载失败"):
		return false

	# 程序：诅咒祭坛闭环接口
	if not _require(game.has_method("apply_world_curse"), "程序维度：apply_world_curse 缺失"):
		return false
	if not _require(game.has_method("get_curse_outgoing_damage_mul"), "程序维度：get_curse_outgoing_damage_mul 缺失"):
		return false
	if not _require(game.has_method("is_curse_blocking_xp_pickup"), "程序维度：is_curse_blocking_xp_pickup 缺失"):
		return false

	game.queue_free()
	await process_frame
	return true
