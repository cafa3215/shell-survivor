extends "res://scripts/modules/ModuleDemoBase.gd"

@onready var _label := $CanvasLayer/Panel/VBox/Label as Label
@onready var _autoloads := $CanvasLayer/Panel/VBox/Autoloads as Label
@onready var _methods := $CanvasLayer/Panel/VBox/Methods as Label
@onready var _status := $CanvasLayer/Panel/VBox/Status as Label

## 与 tools/validate_release.gd 对齐的 autoload 名称（程序模块的“最薄但致命”合约）。
const _AUTOLOAD_NAMES: PackedStringArray = [
	"EventBus",
	"GameDB",
	"Settings",
	"RunStats",
	"CombatFeedback",
	"MetaProgress",
	"AudioManager",
	"InputManager",
	"ActiveSkillManager",
]

## 关键方法名：只挑跨模块最常被调用的几个，避免和 validate_release 100% 重复但又能挡住重构断裂。
const _METHOD_CHECKS: Array[Dictionary] = [
	{"node": "RunStats", "method": "menu_next_run_hint"},
	{"node": "RunStats", "method": "finalize_latest_run"},
	{"node": "Settings", "method": "set_quality"},
	{"node": "Settings", "method": "set_sfx_volume"},
	{"node": "Settings", "method": "set_vfx_profile"},
	{"node": "GameDB", "method": "humanize_damage_source"},
	{"node": "AudioManager", "method": "play_sfx_named"},
	{"node": "InputManager", "method": "get_aim_direction"},
	{"node": "CombatFeedback", "method": "shake"},
	{"node": "MetaProgress", "method": "summary_line"},
	{"node": "MetaProgress", "method": "is_run_relic_unlocked_for_pool"},
	{"node": "ActiveSkillManager", "method": "get_cooldown_ratio"},
]

func _ready() -> void:
	demo_name = "程序模块"
	super._ready()
	_label.text = "程序模块：自动载入项与关键方法的最小合约"
	_update_autoload_status()
	_update_method_status()
	_status.text = "状态：已刷新"

func module_self_test() -> bool:
	for nm in _AUTOLOAD_NAMES:
		if get_node_or_null("/root/" + nm) == null:
			return false
	for chk in _METHOD_CHECKS:
		var n := get_node_or_null("/root/" + str(chk.get("node", ""))) as Object
		var m := str(chk.get("method", ""))
		if n == null or m.is_empty() or not n.has_method(m):
			return false
	# 轻量信号存在性：避免 EventBus 被误改导致全项目断连
	var eb := get_node_or_null("/root/EventBus")
	if eb == null:
		return false
	for sig in ["play_sfx", "notification_shown", "vfx_profile_changed"]:
		if not eb.has_signal(sig):
			return false
	return true

func _update_autoload_status() -> void:
	var lines: Array[String] = []
	for nm in _AUTOLOAD_NAMES:
		var ok := get_node_or_null("/root/" + nm) != null
		lines.append("%s：%s" % [nm, "可用" if ok else "缺失"])
	_autoloads.text = "\n".join(lines)

func _update_method_status() -> void:
	var lines: Array[String] = []
	for chk in _METHOD_CHECKS:
		var nn := str(chk.get("node", ""))
		var m := str(chk.get("method", ""))
		var n := get_node_or_null("/root/" + nn)
		var ok := n != null and n.has_method(m)
		lines.append("%s.%s：%s" % [nn, m, "存在" if ok else "缺失"])
	_methods.text = "\n".join(lines)
	_status.text = "状态：已刷新（自动载入 + 方法）"

