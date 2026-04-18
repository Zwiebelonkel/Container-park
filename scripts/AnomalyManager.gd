extends Node

signal anomaly_spawned(anomaly_name: String)
signal anomaly_cleared()
signal anomaly_shot_down()

@export var anomaly_chance_per_segment: float = 0.45
@export var anomaly_object_group: StringName = &"anomaly_objects"
@export var anomaly_light_group: StringName = &"anomaly_lights"
@export var scale_up_factor: float = 1.25
@export var scale_down_factor: float = 0.75
@export var hit_proxy_min_radius: float = 0.3
@export var hit_proxy_max_radius: float = 1.25
@export var hit_proxy_radius_padding: float = 0.08
@export var flicker_interval_min: float = 0.05
@export var flicker_interval_max: float = 0.2
@export var flicker_energy_min_multiplier: float = 0.2
@export var flicker_energy_max_multiplier: float = 1.3
@export var flicker_off_chance: float = 0.15
@export var mannequin_look_dot_threshold: float = 0.92
@export var ghost_look_dot_threshold: float = 0.9
@export var ghost_scene: PackedScene = preload("res://assets/3d/ghost/ghost.tscn")
@export var ghost_scare_audio: AudioStream = preload("res://assets/audio/scare_mid.mp3")
@export var warning2_ghost_feedback_delay: float = 2.1
@export var correction_fog_enabled: bool = true
@export var correction_fog_amount: int = 48
@export var correction_fog_lifetime: float = 1.25
@export var correction_fog_initial_velocity: float = 1.2
@export var correction_fog_scale_min: float = 0.35
@export var correction_fog_scale_max: float = 0.8
@export var correction_fog_gravity: Vector3 = Vector3(0.0, 0.25, 0.0)
@export var correction_fog_color: Color = Color(0.86, 0.9, 0.95, 0.55)

const MOD_HIDE := "hide"
const MOD_SHOW := "show"
const MOD_SCALE_UP := "scale_up"
const MOD_SCALE_DOWN := "scale_down"
const MOD_LIGHT_FLICKER := "light_flicker"
const MOD_GHOST_SCARE := "ghostscare"

var _segment_order: Array[Node3D] = []
var _segment_has_planned_anomaly: Dictionary = {}
var _active_segment: Node3D = null

var _active_target: Node3D = null
var _active_target_original_scale: Vector3 = Vector3.ONE
var _active_target_original_visibility: Dictionary = {}
var _active_target_hit_root: Node = null
var _active_target_created_proxy: Node = null

var _active_light: Light3D = null
var _active_light_original_energy: float = 1.0
var _next_flicker_tick: float = 0.0
var _active_light_hit_root: Node = null
var _active_light_created_proxy: Node = null

var _active_modification: String = ""
var _active_mannequin_swap: bool = false
var _active_mannequin_primary: Node3D = null
var _active_mannequin2: Node3D = null
var _mannequin_scare_player: AudioStreamPlayer3D = null
var _mannequin_scare_played: bool = false
var _active_ghost_area: Area3D = null
var _active_ghost_spawn: Marker3D = null
var _active_ghost_instance: Node3D = null
var _ghost_scare_player: AudioStreamPlayer3D = null
var _ghost_scare_played: bool = false
var _active_musicbox_audio: AudioStreamPlayer3D = null
var _scene_lights_before_musicbox: Dictionary = {}

func _ready() -> void:
	set_process(false)
	if GameManager:
		GameManager.round_started.connect(_on_round_started)
		GameManager.round_ended.connect(_on_round_ended)

func _process(delta: float) -> void:
	if is_instance_valid(_active_light):
		_next_flicker_tick -= delta
		if _next_flicker_tick <= 0.0:
			if randf() <= flicker_off_chance:
				_active_light.light_energy = 0.0
			else:
				var random_multiplier := randf_range(flicker_energy_min_multiplier, flicker_energy_max_multiplier)
				_active_light.light_energy = _active_light_original_energy * random_multiplier

			_next_flicker_tick = randf_range(flicker_interval_min, max(flicker_interval_min, flicker_interval_max))

	if _active_mannequin_swap and is_instance_valid(_active_mannequin2) and is_instance_valid(_mannequin_scare_player):
		_try_trigger_mannequin_scare()

	if is_instance_valid(_active_ghost_instance):
		_try_trigger_ghost_scare()

func set_segment_order(segments: Array[Node3D]) -> void:
	_segment_order = segments.duplicate()
	_ensure_plans_for_segments()
	_update_active_segment()

func _on_round_started(_unused: bool) -> void:
	_update_active_segment()

func _on_round_ended(_was_correct: bool) -> void:
	await get_tree().create_timer(0.1).timeout
	clear_anomaly()

func _ensure_plans_for_segments() -> void:
	for segment in _segment_order:
		if not is_instance_valid(segment):
			continue
		if not _segment_has_planned_anomaly.has(segment):
			_segment_has_planned_anomaly[segment] = _roll_anomaly_plan()

func _update_active_segment() -> void:
	if _segment_order.size() < 2:
		return
	var new_active: Node3D = _segment_order[1]
	if _active_segment == new_active and has_active_anomaly():
		return
	_active_segment = new_active

	# Segmentwechsel kann auch zwischen zwei Runden passieren (z.B. direkt am Exit).
	# In dem Fall erst bei round_started aktivieren, sonst erscheinen im Log scheinbar
	# zwei Anomalien nacheinander für dieselbe Runde.
	if GameManager and not GameManager.round_active:
		return

	_activate_for_segment(_active_segment)

func _activate_for_segment(segment: Node3D) -> void:
	clear_anomaly()
	if not is_instance_valid(segment):
		GameManager.set_current_round_has_anomaly(false)
		return

	var has_planned_anomaly: bool = _roll_anomaly_plan()
	_segment_has_planned_anomaly[segment] = has_planned_anomaly
	if has_planned_anomaly:
		has_planned_anomaly = _apply_random_anomaly(segment)
		_segment_has_planned_anomaly[segment] = has_planned_anomaly

	GameManager.set_current_round_has_anomaly(has_planned_anomaly)

func _roll_anomaly_plan() -> bool:
	return randf() < clampf(anomaly_chance_per_segment, 0.0, 1.0)

func _apply_random_anomaly(segment: Node3D) -> bool:
	var object_candidates: Array[Node3D] = _collect_anomaly_objects_in_segment(segment)
	var light_candidates: Array[Light3D] = _collect_anomaly_lights_in_segment(segment)
	var candidates: Array[Dictionary] = []

	# 🔥 Objekte sammeln (inkl. hidden-Status)
	for obj in object_candidates:
		candidates.append({
			"kind": "object",
			"node": obj,
			"hidden": not obj.visible,
			"show_only": obj.is_in_group("show_only")
		})

	# Lichter bleiben unverändert
	for light in light_candidates:
		candidates.append({
			"kind": "light",
			"node": light
		})

	var ghost_area := segment.find_child("ghostArea", true, false)
	var ghost_spawn := segment.find_child("ghostSpawn", true, false)
	if ghost_area is Area3D and ghost_spawn is Marker3D and ghost_scene != null:
		candidates.append({
			"kind": "ghost_scare",
			"area": ghost_area,
			"spawn": ghost_spawn
		})

	if candidates.is_empty():
		return false

	var pick: Dictionary = candidates[randi_range(0, candidates.size() - 1)]

	if pick.get("kind") == "ghost_scare":
		return _start_ghost_scare(pick.get("area") as Area3D, pick.get("spawn") as Marker3D)

	# 👉 Licht-Anomalie
	if pick.get("kind") == "light":
		return _start_light_flicker(pick.get("node") as Light3D)

	# 👉 Objekt-Anomalie
	var target: Node3D = pick.get("node")
	var is_hidden: bool = pick.get("hidden", false)
	var is_show_only: bool = target.is_in_group("show_only")
	
	print("ACTIVE SEGMENT:", segment.name)
	print("TARGET OBJECT:", target.name)
	print("TARGET PARENT:", target.get_parent().name)

	return _apply_random_object_modification(target, is_hidden, is_show_only)
	
	
func _start_light_flicker(light: Light3D) -> bool:
	if not is_instance_valid(light):
		return false
	_active_light = light
	_active_light_original_energy = light.light_energy
	_active_light_hit_root = _find_or_create_hit_root(_active_light, "ShotProxyLight", 0.35)
	_active_modification = MOD_LIGHT_FLICKER
	_next_flicker_tick = 0.0
	set_process(true)
	emit_signal("anomaly_spawned", _active_modification)
	print("[AnomalyManager] Anomalie '%s' auf Licht '%s' angewendet." % [_active_modification, _active_light.name])
	return true

func _apply_random_object_modification(
	target: Node3D,
	is_hidden_by_default: bool,
	is_show_only: bool
) -> bool:
	if not is_instance_valid(target):
		return false

	# ─── Setup ─────────────────────────────────────────────
	_active_target = target
	_active_target_original_scale = _active_target.scale
	_active_target_original_visibility = _capture_visual_visibility(_active_target)

	var modifications: Array[String] = []

	# ─── Auswahl der möglichen Mods ────────────────────────
	if is_show_only:
		# 🔥 Spezial-Objekte (z.B. mannequin2)
		modifications = [MOD_SHOW]

	elif is_hidden_by_default:
		# 🔥 normale hidden Objekte (z.B. musicBox)
		modifications = [MOD_SHOW]

	else:
		# 🔥 normale sichtbare Objekte
		modifications = [MOD_SCALE_UP, MOD_SCALE_DOWN, MOD_HIDE]

	# ─── Zufällige Auswahl ─────────────────────────────────
	if modifications.is_empty():
		return false

	_active_modification = modifications[randi_range(0, modifications.size() - 1)]

	# ─── Hitbox / Proxy ────────────────────────────────────
	if _active_modification == MOD_HIDE:
		# versteckte Objekte brauchen großen Proxy zum Treffen
		_active_target_hit_root = _create_hit_proxy(_active_target, "ShotProxyHiddenObject", 0.8)
	else:
		_active_target_hit_root = _find_or_create_hit_root(_active_target, "ShotProxyObject", 0.45)

	# ─── Anwendung der Anomalie ────────────────────────────
	match _active_modification:

		MOD_HIDE:
			_apply_hidden_state(_active_target, false)
			_apply_special_hide_rules(_active_target)

		MOD_SHOW:
			_apply_hidden_state(_active_target, true)
			if _active_target.has_method("reset_bounce"):
				_active_target.call_deferred("reset_bounce")
			_apply_special_show_rules(_active_target)

		MOD_SCALE_UP:
			_active_target.scale = _active_target_original_scale * scale_up_factor

		MOD_SCALE_DOWN:
			_active_target.scale = _active_target_original_scale * scale_down_factor

	# ─── Laufzeit / Signals ────────────────────────────────
	set_process(is_instance_valid(_active_light) or _active_mannequin_swap)

	emit_signal("anomaly_spawned", _active_modification)

	print("[AnomalyManager] Anomalie '%s' auf Objekt '%s' angewendet." % [
		_active_modification,
		_active_target.name
	])

	return true

func _start_ghost_scare(ghost_area: Area3D, ghost_spawn: Marker3D) -> bool:
	if not is_instance_valid(ghost_area) or not is_instance_valid(ghost_spawn) or ghost_scene == null:
		return false

	_active_ghost_area = ghost_area
	_active_ghost_spawn = ghost_spawn
	if not _active_ghost_area.body_entered.is_connected(_on_ghost_area_body_entered):
		_active_ghost_area.body_entered.connect(_on_ghost_area_body_entered)

	_active_modification = MOD_GHOST_SCARE
	set_process(true)
	emit_signal("anomaly_spawned", _active_modification)
	print("[AnomalyManager] Anomalie '%s' vorbereitet an '%s'." % [_active_modification, _active_ghost_area.name])
	return true

func _on_ghost_area_body_entered(body: Node) -> void:
	if _active_modification != MOD_GHOST_SCARE:
		return
	if not is_instance_valid(body) or not body.is_in_group("player"):
		return
	if is_instance_valid(_active_ghost_instance):
		return
	if not is_instance_valid(_active_ghost_spawn) or ghost_scene == null:
		return

	var instance := ghost_scene.instantiate()
	if not (instance is Node3D):
		instance.queue_free()
		return

	_active_ghost_instance = instance as Node3D
	_active_ghost_instance.transform = _active_ghost_spawn.transform
	_active_ghost_spawn.get_parent().add_child(_active_ghost_instance)
	_active_ghost_instance.owner = _active_ghost_spawn.owner
	_active_target = _active_ghost_instance
	_active_target_original_scale = _active_ghost_instance.scale
	_active_target_original_visibility = _capture_visual_visibility(_active_ghost_instance)
	_active_target_hit_root = _find_or_create_hit_root(_active_ghost_instance, "ShotProxyGhost", 0.6)
	_ghost_scare_played = false
	var bus_index := AudioServer.get_bus_index("Music")
	if bus_index != -1:
		AudioServer.set_bus_mute(bus_index, true)

	_ghost_scare_player = AudioStreamPlayer3D.new()
	_ghost_scare_player.name = "Scare_HI"
	_ghost_scare_player.stream = ghost_scare_audio
	_ghost_scare_player.bus = &"SFX"
	_ghost_scare_player.max_distance = 40.0
	_ghost_scare_player.unit_size = 8.0
	_active_ghost_instance.add_child(_ghost_scare_player)
	_ghost_scare_player.owner = _active_ghost_instance.owner

func _collect_anomaly_objects_in_segment(segment: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(anomaly_object_group):
		if node is Node3D and segment.is_ancestor_of(node):
			result.append(node)
	return result

func _collect_anomaly_lights_in_segment(segment: Node3D) -> Array[Light3D]:
	var result: Array[Light3D] = []
	for node in get_tree().get_nodes_in_group(anomaly_light_group):
		if node is Light3D and segment.is_ancestor_of(node):
			result.append(node)
	return result

func _capture_visual_visibility(root: Node3D) -> Dictionary:
	var state: Dictionary = {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Node3D:
			state[current] = current.visible
		if current is VisualInstance3D:
			state[current] = current.visible
		for child in current.get_children():
			stack.append(child)
	return state

func _apply_hidden_state(root: Node3D, visible: bool) -> void:
	root.visible = visible  # ← das fehlte
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is VisualInstance3D:
			current.visible = visible
		for child in current.get_children():
			stack.append(child)

func _is_visually_hidden(root: Node3D) -> bool:
	# Prüfe erst den Root selbst
	if not root.visible:
		return true
	# Dann alle VisualInstance3D-Children
	for node in _capture_visual_visibility(root).keys():
		if is_instance_valid(node) and node.visible:
			return false
	return true

func _apply_special_hide_rules(target: Node3D) -> void:
	if target.name.to_lower() == "mannequin":
		var mannequin2 := target.get_parent().find_child("mannequin2", false, false)
		if mannequin2 is Node3D:
			_active_mannequin_swap = true
			_active_mannequin_primary = target
			_active_mannequin2 = mannequin2
			_apply_hidden_state(_active_mannequin2, true)
			_mannequin_scare_player = _active_mannequin2.find_child("Scare_HI", true, false) as AudioStreamPlayer3D
			_mannequin_scare_played = false
		return

	if target.name.to_lower() == "mannequin2":
		_active_mannequin_swap = true
		_active_mannequin2 = target
		_active_mannequin_primary = target.get_parent().find_child("mannequin", false, false) as Node3D
		if is_instance_valid(_active_mannequin_primary):
			_apply_hidden_state(_active_mannequin_primary, true)
		_mannequin_scare_player = _active_mannequin2.find_child("Scare_HI", true, false) as AudioStreamPlayer3D
		_mannequin_scare_played = false
		
func _apply_special_show_rules(target: Node3D) -> void:
	if target.name.to_lower() == "mannequin2":
		_active_mannequin_swap = true
		_active_mannequin2 = target
		_active_mannequin_primary = target.get_parent().find_child("mannequin", false, false) as Node3D
		if is_instance_valid(_active_mannequin_primary):
			_apply_hidden_state(_active_mannequin_primary, false)
		_mannequin_scare_player = _active_mannequin2.find_child("Scare_HI", true, false) as AudioStreamPlayer3D
		_mannequin_scare_played = false

	if target.name.to_lower() == "musicbox":
	
	# 🔥 Music Bus muten
		var bus_index := AudioServer.get_bus_index("Music")
		if bus_index != -1:
			AudioServer.set_bus_mute(bus_index, true)

		_disable_all_scene_lights_for_musicbox()

		_active_musicbox_audio = target.find_child("music", true, false) as AudioStreamPlayer3D
		if is_instance_valid(_active_musicbox_audio):
			if _active_musicbox_audio.stream is AudioStreamMP3:
				(_active_musicbox_audio.stream as AudioStreamMP3).loop = true
			_active_musicbox_audio.play()

func _try_trigger_mannequin_scare() -> void:
	if _mannequin_scare_played:
		return

	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return

	var target_focus: Vector3 = _get_node_focus_position(_active_mannequin2)
	if not camera.is_position_in_frustum(target_focus):
		return

	var to_target := (target_focus - camera.global_position).normalized()
	var look_dir := -camera.global_basis.z.normalized()
	if look_dir.dot(to_target) < mannequin_look_dot_threshold:
		return

	_mannequin_scare_player.play()
	_mannequin_scare_played = true

func _try_trigger_ghost_scare() -> void:
	if _ghost_scare_played:
		return
	if not is_instance_valid(_active_ghost_instance) or not is_instance_valid(_ghost_scare_player):
		return

	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return

	var target_focus: Vector3 = _get_node_focus_position(_active_ghost_instance)
	if not camera.is_position_in_frustum(target_focus):
		return

	var to_target := (target_focus - camera.global_position).normalized()
	var look_dir := -camera.global_basis.z.normalized()
	if look_dir.dot(to_target) < ghost_look_dot_threshold:
		return

	_ghost_scare_player.play()
	_ghost_scare_played = true

func _get_node_focus_position(node: Node3D) -> Vector3:
	if not is_instance_valid(node):
		return Vector3.ZERO

	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current : Node = stack.pop_back()
		if current is VisualInstance3D:
			var visual := current as VisualInstance3D
			var aabb := visual.get_aabb()
			return visual.global_transform * aabb.get_center()
		for child in current.get_children():
			stack.append(child)

	return node.global_position
	
func _is_flashlight(light: Node) -> bool:
	var n: String = light.name.to_lower()
	return n.contains("flashlight")

func _disable_all_scene_lights_for_musicbox() -> void:
	if not _scene_lights_before_musicbox.is_empty():
		return

	# ─── Gruppe: anomaly_lights ─────────────────────────────
	for light in get_tree().get_nodes_in_group(&"anomaly_lights"):
		if not (light is Light3D):
			continue
		if not is_instance_valid(light):
			continue

		# 🔥 Flashlight überspringen
		if _is_flashlight(light):
			continue

		_scene_lights_before_musicbox[light] = {
			"visible": light.visible,
			"light_energy": light.light_energy
		}

		light.visible = false
		light.light_energy = 0.0

	# ─── Alle anderen Lichter ───────────────────────────────
	for light in get_tree().current_scene.find_children("*", "Light3D", true, false):
		if not (light is Light3D):
			continue
		if not is_instance_valid(light):
			continue

		# 🔥 Flashlight überspringen
		if _is_flashlight(light):
			continue

		if _scene_lights_before_musicbox.has(light):
			continue

		_scene_lights_before_musicbox[light] = {
			"visible": light.visible,
			"light_energy": light.light_energy
		}

		light.visible = false
		light.light_energy = 0.0
		
func _restore_scene_lights_after_musicbox() -> void:
	for light in _scene_lights_before_musicbox.keys():
		if not is_instance_valid(light):
			continue
		var state: Dictionary = _scene_lights_before_musicbox[light]
		light.visible = state.get("visible", true)
		light.light_energy = state.get("light_energy", 1.0)
	_scene_lights_before_musicbox.clear()
	_restore_music_bus()
	
func _restore_music_bus():
	# Nur aktivieren wenn KEINE MusicBox läuft
	if has_node("/root/AnomalyManager"):
		var manager = get_node("/root/AnomalyManager")
		if manager.has_method("has_active_anomaly"):
			# wenn MusicBox aktiv → NICHT unmuten
			if manager._active_musicbox_audio:
				return
	
	var music_bus_index := AudioServer.get_bus_index("Music")
	if music_bus_index != -1:
		AudioServer.set_bus_mute(music_bus_index, false)

func handle_shot_hit_nodes(hit_nodes: Array) -> bool:
	if not has_active_anomaly():
		return false

	for node in hit_nodes:
		if not is_instance_valid(node):
			continue

		if is_instance_valid(_active_target):
			if _nodes_related(node, _active_target) or _nodes_related(node, _active_target_hit_root):
				on_anomaly_shot()
				return true

		if is_instance_valid(_active_light):
			if _nodes_related(node, _active_light) or _nodes_related(node, _active_light_hit_root):
				on_anomaly_shot()
				return true

	return false

func _nodes_related(a: Node, b: Node) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false
	if a == b:
		return true
	return _is_in_parent_chain(a, b) or _is_in_parent_chain(b, a)

func _is_in_parent_chain(node: Node, possible_ancestor: Node) -> bool:
	var check: Node = node
	while is_instance_valid(check):
		if check == possible_ancestor:
			return true
		check = check.get_parent()
	return false


func _get_player_feedback_node(feedback_name: String = "ghost") -> Node:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return null
	return player.find_child(feedback_name, true, false)

func _play_player_ghost_feedback(feedback_name: String = "ghost") -> void:
	var feedback_node := _get_player_feedback_node(feedback_name)
	if not is_instance_valid(feedback_node):
		return

	if feedback_node.has_method("play_scare_once"):
		feedback_node.call("play_scare_once")
		return

	if feedback_node is Node3D:
		(feedback_node as Node3D).visible = true
		await get_tree().create_timer(0.8).timeout
		if is_instance_valid(feedback_node):
			(feedback_node as Node3D).visible = false

func _play_player_ghost_feedback_delayed(delay_seconds: float, feedback_name: String = "ghost") -> void:
	await get_tree().create_timer(max(0.0, delay_seconds)).timeout
	_play_player_ghost_feedback(feedback_name)

func _get_visual_bounds_center_and_radius(root: Node3D) -> Dictionary:
	var has_visual := false
	var min_corner := Vector3.ZERO
	var max_corner := Vector3.ZERO

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is VisualInstance3D:
			var visual := current as VisualInstance3D
			var aabb := visual.get_aabb()
			var world_center := visual.global_transform * aabb.get_center()
			var extents := aabb.size * 0.5
			var world_min := world_center - extents
			var world_max := world_center + extents
			if not has_visual:
				min_corner = world_min
				max_corner = world_max
				has_visual = true
			else:
				min_corner = min_corner.min(world_min)
				max_corner = max_corner.max(world_max)

		for child in current.get_children():
			stack.append(child)

	if not has_visual:
		return {
			"center": Vector3.ZERO,
			"radius": 1.0
		}

	var world_center_merged := (min_corner + max_corner) * 0.5
	var local_center := root.to_local(world_center_merged)
	var size := max_corner - min_corner
	var radius: float = max(size.x, max(size.y, size.z)) * 0.5 + hit_proxy_radius_padding
	radius = clampf(radius, hit_proxy_min_radius, hit_proxy_max_radius)
	return {
		"center": local_center,
		"radius": radius
	}

func _find_or_create_hit_root(root: Node3D, proxy_name: String, radius: float) -> Node:
	var existing := _find_hit_root(root)
	if is_instance_valid(existing):
		return existing

	return _create_hit_proxy(root, proxy_name, radius)

func _create_hit_proxy(root: Node3D, proxy_name: String, radius: float) -> StaticBody3D:
	if not is_instance_valid(root):
		return null

	var bounds := _get_visual_bounds_center_and_radius(root)
	var proxy_center: Vector3 = bounds.get("center", Vector3.ZERO)
	var proxy_radius: float = max(radius, float(bounds.get("radius", radius)))
	proxy_radius = clampf(proxy_radius, hit_proxy_min_radius, hit_proxy_max_radius)

	var proxy := StaticBody3D.new()
	proxy.name = proxy_name
	proxy.position = proxy_center

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = proxy_radius
	shape.shape = sphere
	proxy.add_child(shape)

	# 🔥 DEBUG VISUAL (NEU)
	var mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = proxy_radius
	mesh.mesh = sphere_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0) # rot, transparent
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mesh.material_override = mat
	proxy.add_child(mesh)

	root.add_child(proxy)
	proxy.owner = root.owner
	shape.owner = root.owner
	mesh.owner = root.owner

	if root == _active_target:
		_active_target_created_proxy = proxy
	elif root == _active_light:
		_active_light_created_proxy = proxy

	return proxy
	
func _find_hit_root(root: Node) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is StaticBody3D or current is Area3D:
			for child in current.get_children():
				if child is CollisionShape3D:
					return current
		for child in current.get_children():
			stack.append(child)
	return null

func _get_active_anomaly_world_position() -> Vector3:
	if is_instance_valid(_active_target):
		return _active_target.global_position
	if is_instance_valid(_active_light):
		return _active_light.global_position
	if is_instance_valid(_active_ghost_area):
		return _active_ghost_area.global_position
	
	return Vector3.ZERO  # 🔥 FIX
	
func _spawn_correction_fog_effect(world_position: Vector3) -> void:
	if not correction_fog_enabled:
		return

	var particles := GPUParticles3D.new()
	particles.name = "CorrectionFogBurst"
	particles.one_shot = true
	particles.amount = max(1, correction_fog_amount)
	particles.lifetime = max(0.1, correction_fog_lifetime)
	particles.explosiveness = 0.95
	particles.local_coords = false
	particles.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME

	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 0.25, 0.0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = max(0.1, correction_fog_initial_velocity * 0.6)
	process_material.initial_velocity_max = max(0.2, correction_fog_initial_velocity)
	process_material.gravity = correction_fog_gravity
	process_material.scale_min = correction_fog_scale_min
	process_material.scale_max = max(correction_fog_scale_min, correction_fog_scale_max)
	process_material.color = correction_fog_color
	process_material.damping_min = 1.4
	process_material.damping_max = 2.1
	particles.process_material = process_material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	particles.draw_pass_1 = quad

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = correction_fog_color
	material.disable_receive_shadows = true
	particles.material_override = material

	get_tree().current_scene.add_child(particles)
	particles.global_position = world_position
	particles.emitting = true
	_queue_node_free_later(particles, particles.lifetime + 1.0)

func _queue_node_free_later(node: Node, delay: float) -> void:
	await get_tree().create_timer(max(0.1, delay)).timeout
	if is_instance_valid(node):
		node.queue_free()

func clear_anomaly() -> void:
	if is_instance_valid(_active_target):
		_active_target.scale = _active_target_original_scale
		for node in _active_target_original_visibility.keys():
			if is_instance_valid(node):
				node.visible = _active_target_original_visibility[node]

	if is_instance_valid(_active_light):
		_active_light.light_energy = _active_light_original_energy

	if is_instance_valid(_active_mannequin2):
		_apply_hidden_state(_active_mannequin2, false)
	if is_instance_valid(_active_mannequin_primary):
		_apply_hidden_state(_active_mannequin_primary, true)

	if is_instance_valid(_active_musicbox_audio):
		_active_musicbox_audio.stop()
	var music_bus_index := AudioServer.get_bus_index("Music")
	if music_bus_index != -1:
		AudioServer.set_bus_mute(music_bus_index, false)
	_restore_scene_lights_after_musicbox()

	if is_instance_valid(_active_target_created_proxy):
		_active_target_created_proxy.queue_free()
	if is_instance_valid(_active_light_created_proxy):
		_active_light_created_proxy.queue_free()
	if is_instance_valid(_active_ghost_area) and _active_ghost_area.body_entered.is_connected(_on_ghost_area_body_entered):
		_active_ghost_area.body_entered.disconnect(_on_ghost_area_body_entered)
	if is_instance_valid(_active_ghost_instance):
		_active_ghost_instance.queue_free()

	_active_target = null
	_active_target_original_scale = Vector3.ONE
	_active_target_original_visibility.clear()
	_active_target_hit_root = null
	_active_target_created_proxy = null
	_active_light = null
	_active_light_original_energy = 1.0
	_next_flicker_tick = 0.0
	_active_light_hit_root = null
	_active_light_created_proxy = null
	_active_modification = ""
	_active_mannequin_swap = false
	_active_mannequin_primary = null
	_active_mannequin2 = null
	_mannequin_scare_player = null
	_mannequin_scare_played = false
	_active_ghost_area = null
	_active_ghost_spawn = null
	_active_ghost_instance = null
	_ghost_scare_player = null
	_ghost_scare_played = false
	_active_musicbox_audio = null
	set_process(false)

	emit_signal("anomaly_cleared")

func on_anomaly_shot() -> void:
	var anomaly_position := _get_active_anomaly_world_position()
	var was_ghost_scare := _active_modification == MOD_GHOST_SCARE
	var was_warning2_fix := is_instance_valid(_active_target) and _active_target.name.to_lower() == "warning2"
	clear_anomaly()
	_spawn_correction_fog_effect(anomaly_position)
	if was_ghost_scare:
		_play_player_ghost_feedback("ghost")
	elif was_warning2_fix:
		_play_player_ghost_feedback_delayed(warning2_ghost_feedback_delay, "killer")

	GameManager.set_current_round_has_anomaly(false)
	emit_signal("anomaly_shot_down")

func has_active_anomaly() -> bool:
	return _active_modification != "" and (
		is_instance_valid(_active_target)
		or is_instance_valid(_active_light)
		or (_active_modification == MOD_GHOST_SCARE and is_instance_valid(_active_ghost_area))
	)
