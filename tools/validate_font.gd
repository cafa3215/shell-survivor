extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var font: Font = load("res://assets/fonts/simhei.ttf")
	if font == null:
		push_error("validate_font: load failed")
		quit(1)
		return
	var sz: Vector2 = font.get_string_size("弹壳幸存者", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	print("validate_font: size=%s font_class=%s" % [str(sz), font.get_class()])
	var theme: Theme = load("res://assets/themes/cyber_theme.tres")
	if theme == null or theme.default_font == null:
		push_error("validate_font: theme font missing")
		quit(1)
		return
	print("validate_font: theme default ok")
	quit(0)
