extends SceneTree

## BOSS 链路守卫（高风险路径）：
## - Game 场景关键节点存在
## - EnemyManager 的 BOSS 合约方法存在
## - EventBus 的 BOSS 信号存在
## - Game.gd 持有关键链路调用（spawn/telegraph/hud）

const REQUIRED_GAME_NODES: PackedStringArray = [
	"Player",
	"EnemyManager",
	"BossTelegraph",
	"WeaponTelegraph",
	"HUD",
]

const REQUIRED_BOSS_METHODS: PackedStringArray = [
	"spawn_boss",
	"boss_alive",
	"boss_hp_ratio",
	"boss_phase",
	"boss_pos",
]

const REQUIRED_EVENTBUS_SIGNALS: PackedStringArray = [
	"boss_warning",
	"boss_telegraph",
	"boss_defeated",
	"boss_spawned",
]

const REQUIRED_GAME_SCRIPT_TOKENS: PackedStringArray = [
	"EventBus.boss_defeated.connect",
	"$EnemyManager.spawn_boss",
	"$EnemyManager.boss_alive()",
	"$HUD.set_boss_info(",
]


func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var packed: Resource = ResourceLoader.load("res://scenes/Game.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("validate_boss_chain: failed to load scenes/Game.tscn")
		quit(1)
		return

	var game := (packed as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	for path in REQUIRED_GAME_NODES:
		if game.get_node_or_null(path) == null:
			push_error("validate_boss_chain: missing Game node " + path)
			quit(1)
			return

	var enemy_mgr := game.get_node_or_null("EnemyManager")
	if enemy_mgr == null:
		push_error("validate_boss_chain: EnemyManager missing")
		quit(1)
		return
	for method_name in REQUIRED_BOSS_METHODS:
		if not enemy_mgr.has_method(method_name):
			push_error("validate_boss_chain: EnemyManager method missing " + method_name)
			quit(1)
			return

	var eb := root.get_node_or_null("/root/EventBus")
	if eb == null:
		push_error("validate_boss_chain: EventBus autoload missing")
		quit(1)
		return
	for sig in REQUIRED_EVENTBUS_SIGNALS:
		if not eb.has_signal(sig):
			push_error("validate_boss_chain: EventBus signal missing " + sig)
			quit(1)
			return

	var game_script_text := FileAccess.get_file_as_string("res://scripts/core/Game.gd")
	if game_script_text.is_empty():
		push_error("validate_boss_chain: cannot read scripts/core/Game.gd")
		quit(1)
		return
	for token in REQUIRED_GAME_SCRIPT_TOKENS:
		if game_script_text.find(token) == -1:
			push_error("validate_boss_chain: missing Game.gd boss token " + token)
			quit(1)
			return

	print("validate_boss_chain: OK")
	quit(0)
