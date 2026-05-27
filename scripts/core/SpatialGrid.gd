extends RefCounted
class_name SpatialGrid

var cell_size := 96.0
var _cells: Dictionary = {}

func clear() -> void:
	_cells.clear()

func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size)))

func insert(id: int, pos: Vector2) -> void:
	var c := _cell(pos)
	if not _cells.has(c):
		_cells[c] = PackedInt32Array()
	var arr: PackedInt32Array = _cells[c]
	arr.append(id)
	_cells[c] = arr

func query_indices(center: Vector2, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var min_c := _cell(center - Vector2(radius, radius))
	var max_c := _cell(center + Vector2(radius, radius))
	for y in range(min_c.y, max_c.y + 1):
		for x in range(min_c.x, max_c.x + 1):
			var key := Vector2i(x, y)
			if not _cells.has(key):
				continue
			var arr: PackedInt32Array = _cells[key]
			for id in arr:
				out.append(id)
	return out
