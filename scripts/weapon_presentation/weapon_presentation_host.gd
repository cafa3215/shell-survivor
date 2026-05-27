extends Node

## 解析武器 id → 子场景，挂在 Player/WeaponMount 下，并把 EventBus 演出请求转给各 WeaponPresentation。

const _REGISTRY_JSON := "res://assets/config/weapon_presentation_registry.json"

var _paths: Dictionary = {}
var _instances: Dictionary = {} ## weapon_id -> WeaponPresentation


func _ready() -> void:
	_load_registry()
	if EventBus.has_signal("weapon_presentation_requested") and not EventBus.weapon_presentation_requested.is_connected(_on_weapon_presentation_requested):
		EventBus.weapon_presentation_requested.connect(_on_weapon_presentation_requested)


func _load_registry() -> void:
	if not FileAccess.file_exists(_REGISTRY_JSON):
		return
	var f := FileAccess.open(_REGISTRY_JSON, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	var data = JSON.parse_string(txt)
	if data is Dictionary:
		_paths = data


func _on_weapon_presentation_requested(weapon_id: StringName, kind: StringName, payload: Dictionary) -> void:
	var key := String(weapon_id)
	if not _paths.has(key):
		return
	var p := String(_paths[key])
	if p.is_empty() or not ResourceLoader.exists(p):
		return
	var mount := _get_weapon_mount()
	if mount == null:
		return
	var pres: WeaponPresentation = _instances.get(weapon_id) as WeaponPresentation
	if pres == null or not is_instance_valid(pres):
		var scn := load(p) as PackedScene
		if scn == null:
			return
		pres = scn.instantiate() as WeaponPresentation
		if pres == null:
			return
		pres.name = "Presentation_%s" % key
		pres.bound_weapon_id = weapon_id
		mount.add_child(pres)
		_instances[weapon_id] = pres
	pres.attach_to_mount(mount)
	pres.call_deferred("begin", kind, payload)


func _get_weapon_mount() -> Node2D:
	var game := get_parent() as Node2D
	if game == null:
		return null
	var pl := game.get_node_or_null("Player")
	if pl == null:
		return null
	if pl.has_method("get_weapon_mount_node"):
		return pl.get_weapon_mount_node() as Node2D
	return pl.get_node_or_null("WeaponMount") as Node2D
