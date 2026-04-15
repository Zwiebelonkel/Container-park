## ShootingSystem.gd
## Verbindet die Schrotflinte mit dem Anomalie-System und dem GameManager.
## Hänge dieses Script an einen Node in der Room-Szene (z.B. als Child von RoomController).
##
## Logik:
##   - Spieler schiesst → ShootingSystem prueft ob getroffener Node eine Anomalie ist
##   - Anomalie getroffen → on_shot() aufrufen → AnomalyManager benachrichtigen
##   - Normales Objekt getroffen → nichts passiert (stiller Treffer)
##   - Ausgang betreten → "keine Anomalie mehr" → Runde beenden

extends Node

# ─── Signale ───────────────────────────────────────────────────────────────────
signal anomaly_shot(anomaly: BaseAnomaly)
signal normal_object_shot(collider: Node)

# ─── Node-Refs ─────────────────────────────────────────────────────────────────
## Referenz auf die Schrotflinte
@export var shotgun_path: NodePath = ""
## Referenz auf den AnomalyManager
@export var anomaly_manager_path: NodePath = ""

var _shotgun: Node = null
var _anomaly_manager: Node = null

# ─── Treffereffekte auf normalen Objekten ──────────────────────────────────────
## Aufprall-Partikel oder Decal-Szene (optional)
@export var impact_effect_scene: PackedScene = null

func _ready() -> void:
	_shotgun = get_node_or_null(shotgun_path)
	_anomaly_manager = get_node_or_null(anomaly_manager_path)

	if _shotgun and _shotgun.has_signal("fired"):
		_shotgun.fired.connect(_on_shotgun_fired)
	else:
		push_warning("[ShootingSystem] Keine Schrotflinte gefunden oder kein 'fired'-Signal!")
		
	if not _anomaly_manager:
		push_error("[ShootingSystem] AnomalyManager nicht gefunden: %s" % anomaly_manager_path)
		return

	if _shotgun and _shotgun.has_signal("fired"):
		_shotgun.fired.connect(_on_shotgun_fired)
	else:
		push_warning("[ShootingSystem] Kein Shotgun oder kein 'fired'-Signal!")

# ─── Schuss-Handler ────────────────────────────────────────────────────────────
func _on_shotgun_fired(hit_nodes: Array) -> void:
	if not _anomaly_manager:
		return

	var corrected: bool = _anomaly_manager.handle_shot_hit_nodes(hit_nodes)
	if corrected:
		print("[ShootingSystem] ✅ Anomalie durch Schuss korrigiert!")
		
		
# ─── Anomalie-Auflosung ────────────────────────────────────────────────────────
func _on_anomaly_eliminated() -> void:
	print("[ShootingSystem] ✅ Anomalie beseitigt!")
	# AnomalyManager informieren damit _current_anomaly gecleant wird
	if _anomaly_manager and _anomaly_manager.has_method("on_anomaly_shot"):
		_anomaly_manager.call("on_anomaly_shot")

# ─── Hilfsfunktionen ───────────────────────────────────────────────────────────
func _find_anomaly_from_collider(collider: Node) -> BaseAnomaly:
	# Option 1: Collider hat Metadaten (via BaseAnomaly._register_colliders)
	if collider.has_meta("anomaly_ref"):
		var ref = collider.get_meta("anomaly_ref")
		if ref is BaseAnomaly:
			return ref

	# Option 2: Collider ist in "anomaly"-Gruppe
	if collider.is_in_group("anomaly"):
		# Direkt oder Parent durchsuchen
		var node: Node = collider
		while node:
			if node is BaseAnomaly:
				return node as BaseAnomaly
			node = node.get_parent()

	return null

func _spawn_impact_effect(at_node: Node) -> void:
	if not impact_effect_scene:
		return
	if not at_node is Node3D:
		return
	var effect := impact_effect_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	(effect as Node3D).global_position = (at_node as Node3D).global_position
	##
	
func _draw_shot_ray(from: Vector3, to: Vector3) -> void:
	var mesh := ImmediateMesh.new()
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()

	var instance := MeshInstance3D.new()
	instance.mesh = mesh

	# Material (rot leuchtend)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0)
	mat.emission_enabled = true
	mat.emission = Color(1, 0, 0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	instance.material_override = mat

	get_tree().current_scene.add_child(instance)

	# automatisch löschen nach kurzer Zeit
	await get_tree().create_timer(0.1).timeout
	instance.queue_free()
