extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var font := FontFile.new()
	var err := font.load_dynamic_font("res://assets/fonts/simhei.ttf")
	if err != OK:
		push_error("bake_ui_font: load_dynamic_font failed %s" % str(err))
		quit(1)
		return
	err = ResourceSaver.save(font, "res://assets/fonts/game_ui_font.tres")
	if err != OK:
		push_error("bake_ui_font: save failed %s" % str(err))
		quit(1)
		return
	print("bake_ui_font: OK")
	quit(0)
