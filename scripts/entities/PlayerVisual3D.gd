extends Node2D
class_name PlayerVisual3D

## KayKit 主角：SubViewport 3D 渲染到 Sprite2D（避免 SubViewportContainer 挡输入）。

const _VIEWPORT_PX := 192
const _DISPLAY_PX := 132.0

var _sprite: Sprite2D
var _viewport: SubViewport
var _pivot: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _hand_r: Node3D
var _current_anim: StringName = &""
var _facing_sign: float = 1.0


func setup(hero_path: String = KayKitAssets.HERO_ROGUE) -> bool:
	_clear()
	_build_viewport()
	if not _load_hero(hero_path):
		push_warning("PlayerVisual3D: failed to load hero %s" % hero_path)
		_clear()
		return false
	_play_idle(true)
	return true


func is_ready_visual() -> bool:
	return _model != null and _anim != null


func set_weapon_accessory(weapon_id: String) -> void:
	if _hand_r == null:
		return
	for c in _hand_r.get_children():
		if c.name.begins_with("KayKitAcc_"):
			c.queue_free()
	var path := KayKitAssets.accessory_path(weapon_id)
	if not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		return
	var res: Resource = load(path)
	if res == null:
		return
	var node: Node
	if res is PackedScene:
		node = (res as PackedScene).instantiate()
	else:
		return
	node.name = "KayKitAcc_" + weapon_id
	_hand_r.add_child(node)
	if node is Node3D:
		(node as Node3D).scale = Vector3(0.85, 0.85, 0.85)


func get_hand_socket() -> Node3D:
	return _hand_r if _hand_r != null else _pivot


func apply_motion(_delta: float, vel: Vector2, dead: bool, dashing: bool) -> void:
	if _model == null or _anim == null:
		return
	if dead:
		_play_first_match(["Death_A", "Death_B", "Lie_Down"], true)
		return
	var spd := vel.length()
	if dashing or spd > 165.0:
		_play_run()
	elif spd > 18.0:
		_play_run()
	else:
		_play_idle(false)
	if absf(vel.x) > 8.0:
		_facing_sign = signf(vel.x)
	elif absf(_facing_sign) < 0.01:
		_facing_sign = 1.0
	if _pivot:
		_pivot.scale.x = absf(_pivot.scale.x) * _facing_sign


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "KayKitViewport"
	_viewport.size = Vector2i(_VIEWPORT_PX, _VIEWPORT_PX)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.own_world_3d = true
	add_child(_viewport)
	var world := Node3D.new()
	world.name = "World"
	_viewport.add_child(world)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.65
	cam.position = Vector3(0.0, 1.35, 1.35)
	cam.rotation_degrees = Vector3(-42.0, 0.0, 0.0)
	cam.current = true
	world.add_child(cam)
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	key.light_energy = 1.15
	key.shadow_enabled = false
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-20.0, -120.0, 0.0)
	fill.light_color = Color(0.72, 0.82, 1.0)
	fill.light_energy = 0.42
	world.add_child(fill)
	_pivot = Node3D.new()
	_pivot.name = "FacingPivot"
	_pivot.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	world.add_child(_pivot)
	_sprite = Sprite2D.new()
	_sprite.name = "KayKitSprite"
	_sprite.texture = _viewport.get_texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var scale_factor := _DISPLAY_PX / float(_VIEWPORT_PX)
	_sprite.scale = Vector2(scale_factor, scale_factor)
	_sprite.centered = true
	_sprite.z_index = 2
	add_child(_sprite)


func _load_hero(path: String) -> bool:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return false
	_model = scene.instantiate() as Node3D
	if _model == null:
		return false
	_model.name = "HeroModel"
	_pivot.add_child(_model)
	_model.scale = Vector3(0.82, 0.82, 0.82)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_hand_r = _find_hand_slot(_model, "handslot_r")
	_hide_default_hand_meshes()
	return _anim != null


func _hide_default_hand_meshes() -> void:
	if _hand_r == null:
		return
	for c in _hand_r.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false


func _find_hand_slot(root: Node, slot_name: String) -> Node3D:
	for n in root.find_children("*", "BoneAttachment3D", true, false):
		if n.name == slot_name:
			return n as Node3D
	return null


func _play_idle(force: bool) -> void:
	_play_anim(KayKitAssets.resolve_anim(_anim, KayKitAssets.IDLE_ANIM_CANDIDATES), force)


func _play_run() -> void:
	_play_anim(KayKitAssets.resolve_anim(_anim, KayKitAssets.RUN_ANIM_CANDIDATES), false)


func _play_first_match(names: Array, force: bool) -> void:
	for n in names:
		var sn := StringName(n)
		if _anim.has_animation(sn):
			_play_anim(sn, force)
			return


func _play_anim(name: StringName, force: bool) -> void:
	if name == &"" or _anim == null:
		return
	if not force and name == _current_anim:
		return
	_current_anim = name
	_anim.play(name)


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_sprite = null
	_viewport = null
	_pivot = null
	_model = null
	_anim = null
	_hand_r = null
	_current_anim = &""
