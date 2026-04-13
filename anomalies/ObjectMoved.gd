## ObjectMoved.gd
## Anomalie: Ein Objekt ist leicht verschoben (subtil aber merkbar).
## PSX-Horror-klassiker: Kleinigkeit die nicht stimmt.

extends BaseAnomaly

@export var target_object_names: Array[String] = ["Chair", "Barrel", "Crate"]
@export var move_distance: float = 1.2  # Meter die es verschoben wird

var _moved_node: Node3D = null
var _original_position: Vector3 = Vector3.ZERO
var _original_rotation: Vector3 = Vector3.ZERO

func _apply() -> void:
	var candidates: Array[Node3D] = []
	for obj_name in target_object_names:
		var node := find_in_room(obj_name) as Node3D
		if node:
			candidates.append(node)
	
	if candidates.is_empty():
		push_warning("[ObjectMoved] Keine Zielobjekte gefunden.")
		return
	
	_moved_node = candidates.pick_random()
	_original_position = _moved_node.position
	_original_rotation = _moved_node.rotation_degrees
	
	# Zufällig verschieben (auf X/Z Ebene)
	var offset := Vector3(
		randf_range(-move_distance, move_distance),
		0.0,
		randf_range(-move_distance, move_distance)
	)
	# Sicherstellen dass Offset nicht zu klein ist
	if offset.length() < move_distance * 0.5:
		offset.x += move_distance * sign(randf() - 0.5)
	
	# Optional: leichte Rotation
	var rot_offset := randf_range(-25.0, 25.0)
	
	_moved_node.position = _original_position + offset
	_moved_node.rotation_degrees.y = _original_rotation.y + rot_offset
	print("[ObjectMoved] '%s' verschoben um %s" % [_moved_node.name, offset])

func _revert() -> void:
	if _moved_node and is_instance_valid(_moved_node):
		_moved_node.position = _original_position
		_moved_node.rotation_degrees = _original_rotation
