extends Node

@export var demo_name: String = "模块 Demo"
@export var auto_quit_seconds: float = 0.0

var _t := 0.0

func _ready() -> void:
	print("[module_demo] %s ready" % demo_name)

func _process(delta: float) -> void:
	if auto_quit_seconds <= 0.0:
		return
	_t += delta
	if _t >= auto_quit_seconds:
		print("[module_demo] %s auto quit" % demo_name)
		get_tree().quit(0)

