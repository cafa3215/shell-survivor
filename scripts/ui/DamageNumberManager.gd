extends Node2D
class_name DamageNumberManager

# ============================================
# 伤害跳字管理器 - 对象池优化
# ============================================

const DAMAGE_NUMBER_SCENE := preload("res://scenes/ui/DamageNumber.tscn")

var _pool: Array[DamageNumber] = []
var _active: Array[DamageNumber] = []
var _max_pool_size := 50

func _ready() -> void:
	EventBus.damage_number_spawned.connect(_on_damage_number_spawned)
	z_index = 100

func spawn_damage_number(amount: float, position: Vector2, is_critical := false) -> void:
	var dn: DamageNumber
	
	# 从对象池获取
	if _pool.size() > 0:
		dn = _pool.pop_back()
		dn.visible = true
	else:
		dn = DAMAGE_NUMBER_SCENE.instantiate()
		add_child(dn)
	
	# 设置属性
	dn.setup(amount, position, is_critical)
	_active.append(dn)
	
	# 清理完成的实例
	_cleanup_finished()

func _cleanup_finished() -> void:
	for i in range(_active.size() - 1, -1, -1):
		if not is_instance_valid(_active[i]) or not _active[i].visible:
			var dn := _active[i]
			_active.remove_at(i)
			
			# 回收到对象池
			if _pool.size() < _max_pool_size and is_instance_valid(dn):
				dn.visible = false
				_pool.append(dn)
			elif is_instance_valid(dn):
				dn.queue_free()

func _on_damage_number_spawned(position: Vector2, amount: float, is_critical: bool) -> void:
	spawn_damage_number(amount, position, is_critical)

# ============================================
# 资源清理 - 防止跳字泄漏
# ============================================
func _exit_tree() -> void:
	for dn in _active:
		if is_instance_valid(dn):
			dn.queue_free()
	_active.clear()
	for dn in _pool:
		if is_instance_valid(dn):
			dn.queue_free()
	_pool.clear()
