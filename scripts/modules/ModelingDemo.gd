extends "res://scripts/modules/ModuleDemoBase.gd"

@onready var _title := $CanvasLayer/Panel/VBox/Title as Label
@onready var _desc := $CanvasLayer/Panel/VBox/Desc as Label
@onready var _status := $CanvasLayer/Panel/VBox/Status as Label

func _ready() -> void:
	demo_name = "建模模块"
	super._ready()
	_title.text = "建模模块：2D 碰撞与切片"
	_desc.text = "独立开发建议：本工程主流程为二维；建模侧重「切片网格、碰撞简形、与精灵对齐」。占位演示用于门禁与文档挂钩，复杂模型在局内玩家与敌人场景验证。"
	_status.text = "状态：自检就绪（仅文案与节点结构）"

func module_self_test() -> bool:
	if _title == null or _desc == null or _status == null:
		return false
	return not _title.text.is_empty() and not _desc.text.is_empty()
