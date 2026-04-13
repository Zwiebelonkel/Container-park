## BaseAnomaly.gd  (v2 – Shooting Update)
## Basisklasse fuer alle Anomalien.
## Neu: on_shot() – wird aufgerufen wenn der Spieler draufschiesst.
##
## WICHTIG fuer jede Anomalie-Szene:
##   Der sichtbare/betroffene Node braucht einen Collider (Area3D oder StaticBody3D).
##   Dieser Collider MUSS in der Gruppe "anomaly" sein (automatisch via _register_colliders).
##   ShootingSystem liest anomaly_ref-Metadaten um diese Klasse zu finden.

class_name BaseAnomaly
extends Node

signal anomaly_destroyed()

@export var anomaly_id: String = "unnamed_anomaly"
@export var display_name: String = "Unbekannte Anomalie"
@export var difficulty: int = 1
@export var requires_multiple_hits: int = 1

var room_root: Node = null
var _applied: bool = false
var _hits_received: int = 0
var _destroyed: bool = false

func _ready() -> void:
	await get_tree().process_frame
	_apply()
	_applied = true
	_register_colliders()

func setup(room: Node) -> void:
	room_root = room

func revert() -> void:
	if _applied and not _destroyed:
		_revert()
		_applied = false

## Aufgerufen vom ShootingSystem wenn dieser Node getroffen wird.
## Gibt true zurueck wenn die Anomalie behoben wurde.
func on_shot() -> bool:
	if _destroyed:
		return false
	_hits_received += 1
	_on_hit_received(_hits_received)
	if _hits_received >= requires_multiple_hits:
		_destroy()
		return true
	return false

func _on_hit_received(_hit_count: int) -> void:
	pass

func _destroy() -> void:
	_destroyed = true
	_on_destroyed()
	emit_signal("anomaly_destroyed")
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _on_destroyed() -> void:
	pass

func _register_colliders() -> void:
	for child in get_children():
		_register_node_recursive(child)

func _register_node_recursive(node: Node) -> void:
	if node is CollisionObject3D:
		node.add_to_group("anomaly")
		node.set_meta("anomaly_ref", self)
	for child in node.get_children():
		_register_node_recursive(child)

func _apply() -> void:
	pass

func _revert() -> void:
	pass

func find_in_room(node_name: String) -> Node:
	if room_root:
		return room_root.find_child(node_name, true, false)
	return null

func tween_property_smooth(node: Node, property: String, target_value: Variant, duration: float) -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(node, property, target_value, duration).set_ease(Tween.EASE_IN_OUT)
