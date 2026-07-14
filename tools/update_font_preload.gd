extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var chars: Dictionary = {}
	_scan_dir("res://scenes", chars)
	_scan_dir("res://scripts", chars)
	var arr: Array[String] = []
	for k in chars.keys():
		arr.append(String(k))
	arr.sort()
	var text := "".join(arr)
	var out := FileAccess.open("res://assets/fonts/ui_preload_chars.txt", FileAccess.WRITE)
	if out == null:
		push_error("update_font_preload: cannot write chars file")
		quit(1)
		return
	out.store_string(text)
	out.close()
	print("update_font_preload: %d chars" % text.length())
	quit(0)

func _scan_dir(path: String, chars: Dictionary) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	da.list_dir_begin()
	while true:
		var name := da.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var full := path.path_join(name)
		if da.current_is_dir():
			_scan_dir(full, chars)
			continue
		if not (full.ends_with(".tscn") or full.ends_with(".gd")):
			continue
		var txt := FileAccess.get_file_as_string(full)
		for i in txt.length():
			var code := txt.unicode_at(i)
			if code < 128:
				continue
			if code >= 0xD800 and code <= 0xDFFF:
				continue
			chars[txt[i]] = true
