extends "res://scripts/modules/ModuleDemoBase.gd"

@onready var _title := $CanvasLayer/Panel/VBox/Title as Label
@onready var _desc := $CanvasLayer/Panel/VBox/Desc as Label
@onready var _status := $CanvasLayer/Panel/VBox/Status as Label

func _ready() -> void:
	demo_name = "原画模块"
	super._ready()
	_title.text = "原画模块：风格与可读性"
	_desc.text = "独立开发建议：先定剪影与色板，再细化；导出前统一分辨率与命名；与骨骼切分对齐可减少返工。本演示仅占位，正式资源走资源目录与玩家外部立绘管线。"
	_status.text = "状态：自检就绪（仅文案与节点结构）"

func module_self_test() -> bool:
	if _title == null or _desc == null or _status == null:
		return false
	return not _title.text.is_empty() and not _desc.text.is_empty()
