extends SceneTree

func _init() -> void:
	call_deferred("_boot")

func _boot() -> void:
	var packed: Resource = load("res://scenes/Main_new.tscn")
	var main: Node = (packed as PackedScene).instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	var title: Label = main.get_node_or_null("MenuLayer/Root/Panel/Title") as Label
	if title == null:
		push_error("validate_ui_font_scene: title missing")
		quit(1)
		return
	var font: Font = title.get_theme_font("font")
	if font == null:
		push_error("validate_ui_font_scene: title font null")
		quit(1)
		return
	var sz: Vector2 = font.get_string_size("弹壳幸存者", HORIZONTAL_ALIGNMENT_LEFT, -1, 48)
	print("validate_ui_font_scene: font=%s size=%s label_settings=%s" % [font.get_class(), str(sz), str(title.label_settings)])
	quit(0)
