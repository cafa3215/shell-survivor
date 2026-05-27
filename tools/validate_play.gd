extends SceneTree

## 从主菜单点击开始，跑若干帧以覆盖 Game/战斗逻辑（无头环境）

const FRAMES := 4000

func _init() -> void:
	call_deferred("_boot")

func _boot() -> void:
	var packed: Resource = ResourceLoader.load("res://scenes/Main_new.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("validate_play: Main_new load failed")
		quit(1)
		return
	var main: Node = (packed as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var btn := main.get_node_or_null("MenuLayer/Root/Panel/StartButton") as Button
	if btn == null:
		push_error("validate_play: StartButton missing")
		quit(1)
		return
	btn.pressed.emit()
	for _i in FRAMES:
		await process_frame
	print("validate_play: OK (%d frames)" % FRAMES)
	quit(0)
