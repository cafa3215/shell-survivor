class_name WeaponPresentation
extends Node2D

## 单武器子场景的根类型：人物层只负责走位与通用姿态；本节点为武器可见部件 + 获得/升级短演出。
## kind：&"first_acquire" | &"level_up"（可扩展）；payload 含 prev_lv、new_lv、weapon_name、world_pos 等。

signal interaction_finished(kind: StringName)

@export var bound_weapon_id: StringName = &""
@export var theme: WeaponTheme


func begin(kind: StringName, payload: Dictionary) -> void:
	push_warning("WeaponPresentation.begin 未实现: %s" % String(bound_weapon_id))
	_notify_finished(kind)


func _notify_finished(kind: StringName) -> void:
	interaction_finished.emit(kind)


func attach_to_mount(mount: Node2D) -> void:
	if mount == null:
		return
	if is_instance_valid(get_parent()):
		reparent(mount)
	else:
		mount.add_child(self)
