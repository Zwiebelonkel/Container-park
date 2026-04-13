## AnomalyManager.gd  (v2 - Shooting Update)
## Haenge dieses Script an Node "AnomalyManager" in der Room-Szene.

extends Node

signal anomaly_spawned(anomaly_name: String)
signal anomaly_cleared()
signal anomaly_shot_down()

@export var anomaly_scenes: Array[PackedScene] = []
@export var spawn_points: Array[NodePath] = []
@export var room_root: NodePath = ""

var _current_anomaly: Node = null
var _anomaly_was_shot: bool = false
var _spawn_point_nodes: Array[Node3D] = []

func _ready() -> void:
	for path in spawn_points:
		var node := get_node_or_null(path)
		if node is Node3D:
			_spawn_point_nodes.append(node)
	if GameManager:
		GameManager.round_started.connect(_on_round_started)
		GameManager.round_ended.connect(_on_round_ended)

func _on_round_started(has_anomaly: bool) -> void:
	_anomaly_was_shot = false
	clear_anomaly()
	if has_anomaly:
		spawn_random_anomaly()

func _on_round_ended(_was_correct: bool) -> void:
	await get_tree().create_timer(1.2).timeout
	clear_anomaly()

func spawn_random_anomaly() -> void:
	if anomaly_scenes.is_empty():
		push_warning("[AnomalyManager] Keine Anomalie-Szenen definiert!")
		return
	var scene: PackedScene = anomaly_scenes.pick_random()
	var instance = scene.instantiate()
	if not _spawn_point_nodes.is_empty() and instance is Node3D:
		var point: Node3D = _spawn_point_nodes.pick_random()
		add_child(instance)
		(instance as Node3D).global_position = point.global_position
		(instance as Node3D).global_rotation = point.global_rotation
	else:
		add_child(instance)
	var room := get_node_or_null(room_root)
	if instance.has_method("setup"):
		instance.call("setup", room)
	_current_anomaly = instance
	emit_signal("anomaly_spawned", instance.name)
	print("[AnomalyManager] Anomalie gespawnt: %s" % instance.name)

func clear_anomaly() -> void:
	if _current_anomaly and is_instance_valid(_current_anomaly):
		if not _anomaly_was_shot and _current_anomaly.has_method("revert"):
			_current_anomaly.call("revert")
		_current_anomaly = null
		emit_signal("anomaly_cleared")

## Vom ShootingSystem aufgerufen wenn Anomalie abgeschossen wurde
func on_anomaly_shot() -> void:
	_anomaly_was_shot = true
	_current_anomaly = null
	emit_signal("anomaly_shot_down")
	print("[AnomalyManager] Anomalie abgeschossen.")

## Fuer RoomExit - true wenn noch aktive unbeseitigte Anomalie da ist
func has_active_anomaly() -> bool:
	return _current_anomaly != null \
		and is_instance_valid(_current_anomaly) \
		and not _anomaly_was_shot
