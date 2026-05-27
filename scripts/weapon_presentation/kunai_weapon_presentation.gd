extends WeaponPresentation

## 苦无载体样板：可见占位 + 首次获得与升级两种短演出（时长约 0.35～0.55s）。


func _visual() -> Polygon2D:
	return get_node_or_null("Visual") as Polygon2D


func _ready() -> void:
	var v := _visual()
	if v and theme:
		v.color = theme.primary


func begin(kind: StringName, payload: Dictionary) -> void:
	var v := _visual()
	if v and theme:
		v.color = theme.primary
	match kind:
		&"first_acquire":
			_play_first_acquire()
		&"level_up":
			_play_level_up(payload)
		_:
			_notify_finished(kind)


func _play_first_acquire() -> void:
	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	await tw.finished
	_notify_finished(&"first_acquire")


func _play_level_up(payload: Dictionary) -> void:
	var bump := 1.22
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * bump, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_notify_finished(&"level_up")
