extends RefCounted
class_name PoolManager

var capacity := 0
var alive := PackedByteArray()
var free_list := PackedInt32Array()

func setup(size: int) -> void:
	capacity = size
	alive.resize(size)
	free_list.resize(size)
	for i in size:
		alive[i] = 0
		free_list[i] = size - 1 - i

func alloc() -> int:
	if free_list.is_empty():
		return -1
	var idx := free_list[free_list.size() - 1]
	free_list.resize(free_list.size() - 1)
	alive[idx] = 1
	return idx

func release(idx: int) -> void:
	if idx < 0 or idx >= capacity or alive[idx] == 0:
		return
	alive[idx] = 0
	free_list.append(idx)

func is_alive(idx: int) -> bool:
	return idx >= 0 and idx < capacity and alive[idx] == 1
