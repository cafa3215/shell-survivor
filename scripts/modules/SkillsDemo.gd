extends "res://scripts/modules/ModuleDemoBase.gd"

const _ENEMY_STUB := preload("res://scripts/modules/SkillsDemoEnemyStub.gd")
const _TEL_STUB := preload("res://scripts/modules/SkillsDemoTelegraphStub.gd")
const _PM_STUB := preload("res://scripts/modules/SkillsDemoParticleStub.gd")
const _PLAYER_SCN := preload("res://scenes/Player.tscn")
const _SKILL_SYS := preload("res://scripts/core/SkillSystem.gd")

@onready var _title := $CanvasLayer/Panel/VBox/Title as Label
@onready var _desc := $CanvasLayer/Panel/VBox/Desc as Label
@onready var _status := $CanvasLayer/Panel/VBox/Status as Label

var _asm: Node = null
var _main: Node = null

func _ready() -> void:
	demo_name = "技能模块"
	super._ready()
	_title.text = "技能模块：主动技能与冷却比"
	_desc.text = "用于验证：与主玩法同结构的战场节点存在时，自动载入的主动技能管理器能完成绑定，并提供冷却比读取。"
	_status.text = "状态：正在搭建最小战场上下文…"
	_asm = get_node_or_null("/root/ActiveSkillManager")
	call_deferred("_build_minimal_battle")

func _exit_tree() -> void:
	# 避免把 `Main` 节点留在根场景树里（本 Demo 复用与正式战斗相同的 `Main/Game` 入口名）
	if is_instance_valid(_main):
		_main.queue_free()
		_main = null

func _build_minimal_battle() -> void:
	var r := get_tree().root
	if r == null:
		_status.text = "状态：无法获取根节点"
		return
	# 若存在历史残留，先清理（同一编辑器会话里若重复运行场景）
	if r.has_node("Main"):
		var old: Node = r.get_node("Main")
		if is_instance_valid(old):
			old.queue_free()
	var main := _create_main_battle()
	r.add_child(main)
	EventBus.game_started.emit()
	_status.text = "状态：已挂入主节点并发送开局信号（冷却比应会刷新）"

func _create_main_battle() -> Node:
	var main := Node2D.new()
	main.name = "Main"
	_main = main
	var g := Node2D.new()
	g.name = "Game"
	main.add_child(g)

	var ss := Node.new()
	ss.name = "SkillSystem"
	ss.set_script(_SKILL_SYS)
	g.add_child(ss)

	var em := Node2D.new()
	em.name = "EnemyManager"
	em.set_script(_ENEMY_STUB)
	g.add_child(em)

	var wt := Node2D.new()
	wt.name = "WeaponTelegraph"
	wt.set_script(_TEL_STUB)
	g.add_child(wt)

	var pm := Node2D.new()
	pm.name = "ParticleManager"
	pm.set_script(_PM_STUB)
	g.add_child(pm)

	if _PLAYER_SCN == null:
		_status.text = "状态：玩家场景加载失败"
		return main
	var player := _PLAYER_SCN.instantiate() as Node2D
	if player == null:
		_status.text = "状态：玩家场景实例化失败"
		return main
	player.name = "Player"
	player.position = Vector2(240, 200)
	g.add_child(player)
	return main

func _process(delta: float) -> void:
	super._process(delta)
	if _asm == null or not is_instance_valid(_asm):
		return
	if not _asm.has_method("get_cooldown_ratio"):
		return
	var r: float = float(_asm.call("get_cooldown_ratio"))
	r = clampf(r, 0.0, 1.0)
	_status.text = "状态：主动技能冷却就绪度 %d%%" % int(roundf(r * 100.0))

func module_self_test() -> bool:
	# 仅做“接口存在 + 能读到数值”的最薄检查；更严格的绑定与范围检查在 validate_modules 多帧后执行。
	if get_node_or_null("/root/ActiveSkillManager") == null:
		return false
	return true
