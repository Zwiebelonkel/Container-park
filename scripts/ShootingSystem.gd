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

# ─── Schuss-Handler ────────────────────────────────────────────────────────────
func _on_shotgun_fired(hit_nodes: Array) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var from := camera.global_position
	var to := from + (-camera.global_basis.z * 50.0)

	_draw_shot_ray(from, to)
	var anomaly_hit: BaseAnomaly = null

	for node in hit_nodes:
		if not is_instance_valid(node):
			continue

		# Pruefen ob der getroffene Node (oder sein Parent) eine Anomalie ist
		var anomaly := _find_anomaly_from_collider(node)

		if anomaly:
			if not anomaly_hit:  # Nur erste Anomalie pro Schuss zaehlen
				anomaly_hit = anomaly
		else:
			# Normales Objekt → visueller Einschlag-Effekt
			_spawn_impact_effect(node)
			emit_signal("normal_object_shot", node)

	# Anomalie verarbeiten
	if anomaly_hit:
		var destroyed := anomaly_hit.on_shot()
		if destroyed:
			emit_signal("anomaly_shot", anomaly_hit)
			_on_anomaly_eliminated()
		else:
			# Treffer aber noch nicht behoben (requires_multiple_hits > 1)
			print("[ShootingSystem] Anomalie getroffen – braucht noch %d Treffer" % \
				(anomaly_hit.requires_multiple_hits - anomaly_hit._hits_received))
	elif _anomaly_manager and _anomaly_manager.has_method("handle_shot_hit_nodes"):
		var corrected := _anomaly_manager.call("handle_shot_hit_nodes", hit_nodes)
		if corrected:
			print("[ShootingSystem] ✅ Segment-Anomalie durch Schuss korrigiert!")

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
