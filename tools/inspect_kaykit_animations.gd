extends SceneTree

func _init() -> void:
	var path := "res://assets/game_pack/models/hero/rogue.glb"
	var scene: PackedScene = load(path)
	if scene == null:
		push_error("failed load " + path)
		quit(1)
		return
	var inst := scene.instantiate()
	_print_tree(inst, 0)
	inst.free()
	quit(0)


func _print_tree(n: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	print(pad, n.get_class(), " ", n.name)
	if n is AnimationPlayer:
		for a in (n as AnimationPlayer).get_animation_list():
			print(pad, "  anim: ", a)
	for c in n.get_children():
		_print_tree(c, depth + 1)
