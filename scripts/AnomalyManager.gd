extends Node

signal anomaly_spawned(anomaly_name: String)
signal anomaly_cleared()
signal anomaly_shot_down()

@export var anomaly_chance_per_segment: float = 0.45
@export var test_cube_count: int = 3
@export var cube_spawn_local_positions: Array[Vector3] = [
	Vector3(10.0, 3.0, 2.0),
	Vector3(22.0, 3.0, -4.0),
	Vector3(35.0, 3.0, 6.0),
	Vector3(48.0, 3.0, -2.0)
]

const CUBE_ANOMALY_SCRIPT := preload("res://anomalies/ShootableCubeAnomaly.gd")

var _segment_order: Array[Node3D] = []
var _segment_has_planned_anomaly: Dictionary = {}
var _active_segment: Node3D = null
var _active_anomaly_nodes: Array[Node] = []
var _anomaly_was_shot: bool = false

func _ready() -> void:
	if GameManager:
		GameManager.round_started.connect(_on_round_started)
		GameManager.round_ended.connect(_on_round_ended)

func set_segment_order(segments: Array[Node3D]) -> void:
	_segment_order = segments.duplicate()
	_ensure_plans_for_segments()
	_update_active_segment()

func _on_round_started(_unused: bool) -> void:
	_anomaly_was_shot = false
	_update_active_segment()

func _on_round_ended(_was_correct: bool) -> void:
	await get_tree().create_timer(0.1).timeout
	clear_anomaly()

func _ensure_plans_for_segments() -> void:
	for segment in _segment_order:
		if not is_instance_valid(segment):
			continue
		if not _segment_has_planned_anomaly.has(segment):
			_segment_has_planned_anomaly[segment] = randf() < anomaly_chance_per_segment

func _update_active_segment() -> void:
	if _segment_order.size() < 2:
		return
	var new_active: Node3D = _segment_order[1]
	if _active_segment == new_active and not _active_anomaly_nodes.is_empty():
		return
	_active_segment = new_active
	_activate_for_segment(_active_segment)

func _activate_for_segment(segment: Node3D) -> void:
	clear_anomaly()
	_anomaly_was_shot = false
	if not is_instance_valid(segment):
		GameManager.set_current_round_has_anomaly(false)
		return
	var has_planned_anomaly: bool = _segment_has_planned_anomaly.get(segment, false)
	GameManager.set_current_round_has_anomaly(has_planned_anomaly)
	if not has_planned_anomaly:
		return
	_spawn_test_cubes(segment)

func _spawn_test_cubes(segment: Node3D) -> void:
	var count := mini(test_cube_count, cube_spawn_local_positions.size())
	if count <= 0:
		return
	for i in count:
		var cube: Node = CUBE_ANOMALY_SCRIPT.new()
		cube.name = "AnomalyCube_%d" % i
		if cube.has_method("set_spawn_offset"):
			cube.call("set_spawn_offset", cube_spawn_local_positions[i])
		segment.add_child(cube)
		_active_anomaly_nodes.append(cube)
	emit_signal("anomaly_spawned", "ShootableCubeAnomaly")
	print("[AnomalyManager] %d Würfel-Anomalien in aktivem Segment gespawnt." % count)

func clear_anomaly() -> void:
	for anomaly in _active_anomaly_nodes:
		if is_instance_valid(anomaly):
			anomaly.queue_free()
	_active_anomaly_nodes.clear()
	emit_signal("anomaly_cleared")

func on_anomaly_shot() -> void:
	_anomaly_was_shot = true
	_active_anomaly_nodes = _active_anomaly_nodes.filter(func(node: Node) -> bool:
		return is_instance_valid(node)
	)
	if _active_anomaly_nodes.is_empty():
		if _active_segment and _segment_has_planned_anomaly.has(_active_segment):
			_segment_has_planned_anomaly[_active_segment] = false
		GameManager.set_current_round_has_anomaly(false)
		emit_signal("anomaly_shot_down")
		print("[AnomalyManager] Alle Anomalien im aktiven Segment beseitigt.")

func has_active_anomaly() -> bool:
	_active_anomaly_nodes = _active_anomaly_nodes.filter(func(node: Node) -> bool:
		return is_instance_valid(node)
	)
	return not _active_anomaly_nodes.is_empty()
