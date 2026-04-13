extends Area3D

@export var anomaly_manager_path: NodePath = ""

@onready var _anomaly_manager: Node = _resolve_anomaly_manager()

var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return

	_triggered = true

	var anomaly_still_active := false
	if _anomaly_manager and _anomaly_manager.has_method("has_active_anomaly"):
		anomaly_still_active = _anomaly_manager.call("has_active_anomaly")

	if anomaly_still_active:
		print("[RoomExit] Spieler geht weiter trotz aktiver Anomalie -> Score reset")
		GameManager.complete_segment(false)
	else:
		print("[RoomExit] Segment bereinigt -> Runde bestanden")
		GameManager.complete_segment(true)

func reset() -> void:
	_triggered = false

func _resolve_anomaly_manager() -> Node:
	if anomaly_manager_path != NodePath(""):
		var by_path := get_node_or_null(anomaly_manager_path)
		if by_path:
			return by_path
	var scene := get_tree().current_scene
	if scene:
		return scene.find_child("AnomalyManager", true, false)
	return null
