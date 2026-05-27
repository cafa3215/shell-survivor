extends SceneTree

## 主动技能链路守卫：
## - ActiveSkillManager autoload 存在
## - Game 场景关键节点存在（Player / EnemyManager / WeaponTelegraph）
## - EnemyManager 具备激光命中所需方法
## - ActiveSkillManager 关键调用 token 未被重构破坏

const REQUIRED_GAME_NODES: PackedStringArray = [
	"Player",
	"EnemyManager",
	"WeaponTelegraph",
]

const REQUIRED_ENEMY_METHODS: PackedStringArray = [
	"apply_piercing_line_damage_with_hit_positions",
]

const REQUIRED_ACTIVE_SKILL_TOKENS: PackedStringArray = [
	"Input.is_action_pressed(\"active_skill\")",
	"apply_piercing_line_damage_with_hit_positions(",
	"get_node_or_null(\"WeaponTelegraph\")",
	"wt.add_hit_feedback(",
]


func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var asm := root.get_node_or_null("/root/ActiveSkillManager")
	if asm == null:
		push_error("validate_active_skill_chain: ActiveSkillManager autoload missing")
		quit(1)
		return

	var packed: Resource = ResourceLoader.load("res://scenes/Game.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("validate_active_skill_chain: failed to load scenes/Game.tscn")
		quit(1)
		return
	var game := (packed as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	for path in REQUIRED_GAME_NODES:
		if game.get_node_or_null(path) == null:
			push_error("validate_active_skill_chain: missing Game node " + path)
			quit(1)
			return

	var enemy_mgr := game.get_node_or_null("EnemyManager")
	if enemy_mgr == null:
		push_error("validate_active_skill_chain: EnemyManager missing")
		quit(1)
		return
	for method_name in REQUIRED_ENEMY_METHODS:
		if not enemy_mgr.has_method(method_name):
			push_error("validate_active_skill_chain: EnemyManager method missing " + method_name)
			quit(1)
			return

	var script_text := FileAccess.get_file_as_string("res://scripts/autoload/ActiveSkillManager.gd")
	if script_text.is_empty():
		push_error("validate_active_skill_chain: cannot read ActiveSkillManager.gd")
		quit(1)
		return
	for token in REQUIRED_ACTIVE_SKILL_TOKENS:
		if script_text.find(token) == -1:
			push_error("validate_active_skill_chain: missing token " + token)
			quit(1)
			return

	print("validate_active_skill_chain: OK")
	quit(0)
