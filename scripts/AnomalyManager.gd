extends Node

signal anomaly_spawned(anomaly_name: String)
signal anomaly_cleared()
signal anomaly_shot_down()

@export var anomaly_chance_per_segment: float = 0.45
@export var anomaly_object_group: StringName = &"anomaly_objects"
@export var anomaly_light_group: StringName = &"anomaly_lights"
@export var scale_up_factor: float = 1.25
@export var scale_down_factor: float = 0.75
@export var flicker_interval_min: float = 0.05
@export var flicker_interval_max: float = 0.2
@export var flicker_energy_min_multiplier: float = 0.2
@export var flicker_energy_max_multiplier: float = 1.3
@export var flicker_off_chance: float = 0.15
@export var mannequin_look_dot_threshold: float = 0.92

const MOD_HIDE := "hide"
const MOD_SHOW := "show"
const MOD_SCALE_UP := "scale_up"
const MOD_SCALE_DOWN := "scale_down"
const MOD_LIGHT_FLICKER := "light_flicker"

var _segment_order: Array[Node3D] = []
var _segment_has_planned_anomaly: Dictionary = {}
var _active_segment: Node3D = null

var _active_target: Node3D = null
var _active_target_original_scale: Vector3 = Vector3.ONE
var _active_target_original_visibility: Dictionary = {}

var _active_light: Light3D = null
var _active_light_original_energy: float = 1.0
var _next_flicker_tick: float = 0.0

var _active_modification: String = ""
var _active_mannequin_swap: bool = false
var _active_mannequin2: Node3D = null
var _mannequin_scare_player: AudioStreamPlayer3D = null
var _mannequin_scare_played: bool = false
var _active_musicbox_audio: AudioStreamPlayer3D = null

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
			_segment_has_planned_anomaly[segment] = randf() < anomaly_chance_per_segment

func _update_active_segment() -> void:
	if _segment_order.size() < 2:
		return
	var new_active: Node3D = _segment_order[1]
	if _active_segment == new_active and has_active_anomaly():
		return
	_active_segment = new_active
	_activate_for_segment(_active_segment)

func _activate_for_segment(segment: Node3D) -> void:
	clear_anomaly()
	if not is_instance_valid(segment):
		GameManager.set_current_round_has_anomaly(false)
		return

	var has_planned_anomaly: bool = _segment_has_planned_anomaly.get(segment, false)
	if has_planned_anomaly:
		has_planned_anomaly = _apply_random_anomaly(segment)
		_segment_has_planned_anomaly[segment] = has_planned_anomaly

	GameManager.set_current_round_has_anomaly(has_planned_anomaly)

func _apply_random_anomaly(segment: Node3D) -> bool:
	var object_candidates: Array[Node3D] = _collect_anomaly_objects_in_segment(segment)
	var light_candidates: Array[Light3D] = _collect_anomaly_lights_in_segment(segment)
	var candidates: Array[Dictionary] = []

	for obj in object_candidates:
		candidates.append({"kind": "object", "node": obj})
	for light in light_candidates:
		candidates.append({"kind": "light", "node": light})

	if candidates.is_empty():
		print("[AnomalyManager] Keine Objekte oder Lichter in den Anomalie-Gruppen im aktiven Segment gefunden.")
		return false

	var pick: Dictionary = candidates[randi_range(0, candidates.size() - 1)]
	if pick.get("kind") == "light":
		return _start_light_flicker(pick.get("node") as Light3D)
	return _apply_random_object_modification(pick.get("node") as Node3D)

func _start_light_flicker(light: Light3D) -> bool:
	if not is_instance_valid(light):
		return false
	_active_light = light
	_active_light_original_energy = light.light_energy
	_active_modification = MOD_LIGHT_FLICKER
	_next_flicker_tick = 0.0
	set_process(true)
	emit_signal("anomaly_spawned", _active_modification)
	print("[AnomalyManager] Anomalie '%s' auf Licht '%s' angewendet." % [_active_modification, _active_light.name])
	return true

func _apply_random_object_modification(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false

	_active_target = target
	_active_target_original_scale = _active_target.scale
	_active_target_original_visibility = _capture_visual_visibility(_active_target)

	var is_hidden_by_default := _is_visually_hidden(_active_target)
	var modifications: Array[String] = [MOD_SCALE_UP, MOD_SCALE_DOWN]
	if is_hidden_by_default:
		modifications.append(MOD_SHOW)
	else:
		modifications.append(MOD_HIDE)

	_active_modification = modifications[randi_range(0, modifications.size() - 1)]
	match _active_modification:
		MOD_HIDE:
			_apply_hidden_state(_active_target, false)
			_apply_special_hide_rules(_active_target)
		MOD_SHOW:
			_apply_hidden_state(_active_target, true)
			_apply_special_show_rules(_active_target)
		MOD_SCALE_UP:
			_active_target.scale = _active_target_original_scale * scale_up_factor
		MOD_SCALE_DOWN:
			_active_target.scale = _active_target_original_scale * scale_down_factor

	set_process(is_instance_valid(_active_light) or _active_mannequin_swap)
	emit_signal("anomaly_spawned", _active_modification)
	print("[AnomalyManager] Anomalie '%s' auf Objekt '%s' angewendet." % [_active_modification, _active_target.name])
	return true

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
		if current is VisualInstance3D:
			state[current] = current.visible
		for child in current.get_children():
			stack.append(child)
	return state

func _apply_hidden_state(root: Node3D, visible: bool) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is VisualInstance3D:
			current.visible = visible
		for child in current.get_children():
			stack.append(child)

func _is_visually_hidden(root: Node3D) -> bool:
	for node in _capture_visual_visibility(root).keys():
		if is_instance_valid(node) and node.visible:
			return false
	return true

func _apply_special_hide_rules(target: Node3D) -> void:
	if target.name.to_lower() != "mannequin":
		return

	var mannequin2 := target.get_parent().find_child("mannequin2", false, false)
	if mannequin2 is Node3D:
		_active_mannequin_swap = true
		_active_mannequin2 = mannequin2
		_apply_hidden_state(_active_mannequin2, true)
		_mannequin_scare_player = _active_mannequin2.find_child("Scare_HI", true, false) as AudioStreamPlayer3D
		_mannequin_scare_played = false

func _apply_special_show_rules(target: Node3D) -> void:
	if target.name.to_lower() == "musicbox":
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

	var to_target := (_active_mannequin2.global_position - camera.global_position).normalized()
	var look_dir := -camera.global_basis.z.normalized()
	if look_dir.dot(to_target) < mannequin_look_dot_threshold:
		return

	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, _active_mannequin2.global_position)
	query.collide_with_areas = true
	var hit := space_state.intersect_ray(query)
	if hit and hit.has("collider"):
		var collider := hit["collider"] as Node
		if collider and not (_active_mannequin2 == collider or _active_mannequin2.is_ancestor_of(collider)):
			return

	_mannequin_scare_player.play()
	_mannequin_scare_played = true

func handle_shot_hit_nodes(hit_nodes: Array) -> bool:
	if not has_active_anomaly():
		return false

	for node in hit_nodes:
		if not is_instance_valid(node):
			continue

		if is_instance_valid(_active_target):
			if node == _active_target or _active_target.is_ancestor_of(node):
				on_anomaly_shot()
				return true

		if is_instance_valid(_active_light):
			if node == _active_light or _active_light.is_ancestor_of(node):
				on_anomaly_shot()
				return true

	return false

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

	if is_instance_valid(_active_musicbox_audio):
		_active_musicbox_audio.stop()

	_active_target = null
	_active_target_original_scale = Vector3.ONE
	_active_target_original_visibility.clear()
	_active_light = null
	_active_light_original_energy = 1.0
	_next_flicker_tick = 0.0
	_active_modification = ""
	_active_mannequin_swap = false
	_active_mannequin2 = null
	_mannequin_scare_player = null
	_mannequin_scare_played = false
	_active_musicbox_audio = null
	set_process(false)

	emit_signal("anomaly_cleared")

func on_anomaly_shot() -> void:
	if _active_segment and _segment_has_planned_anomaly.has(_active_segment):
		_segment_has_planned_anomaly[_active_segment] = false
	clear_anomaly()
	GameManager.set_current_round_has_anomaly(false)
	emit_signal("anomaly_shot_down")

func has_active_anomaly() -> bool:
	return _active_modification != "" and (is_instance_valid(_active_target) or is_instance_valid(_active_light))
