## RoomController.gd  (v3 - Segment Trigger Update)
## Root-Node der Room-Szene.
## Segment-Loop verschiebt jetzt gezielt beim Exit des mittleren Segments.

extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var player_start: Marker3D = $PlayerStart
@onready var anomaly_manager: Node = $AnomalyManager

var _transition_overlay: ColorRect
var _is_transitioning: bool = false
var _segment_shifted_this_round: bool = false

@export var transition_duration: float = 0.8
@export var segment_repeat_offset: Vector3 = Vector3(-115.61612, 11.2995, 0.0)

var _loop_segments: Array[Node3D] = []
var _room_exits: Array[Area3D] = []
var _active_shift_exit: Area3D

func _ready() -> void:
	_setup_transition_overlay()
	_collect_loop_segments()
	_collect_room_exits()
	_refresh_shift_exit_connection()
	if GameManager:
		GameManager.round_ended.connect(_on_round_ended)
	await get_tree().process_frame
	GameManager.start_game()

func _setup_transition_overlay() -> void:
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color.BLACK
	_transition_overlay.modulate.a = 0.0
	_transition_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)
	cl.add_child(_transition_overlay)

func _fade_out() -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(_transition_overlay, "modulate:a", 1.0, transition_duration * 0.5)
	await tween.finished

func _fade_in() -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(_transition_overlay, "modulate:a", 0.0, transition_duration * 0.5)
	await tween.finished

func _on_round_ended(_was_correct: bool) -> void:
	if _is_transitioning:
		return
	await get_tree().create_timer(0.8).timeout
	_start_next_round()

func _start_next_round() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _fade_out()
	for exit_area in _room_exits:
		if exit_area and exit_area.has_method("reset"):
			exit_area.call("reset")
	_segment_shifted_this_round = false
	await _fade_in()
	_is_transitioning = false
	GameManager.start_round()

func _on_room_exit_body_entered(body: Node) -> void:
	if _segment_shifted_this_round:
		return
	if not body.is_in_group("player"):
		return
	_shift_segments_once()
	_segment_shifted_this_round = true

func _collect_room_exits() -> void:
	_room_exits.clear()
	for segment in _loop_segments:
		var exit_node := _find_room_exit(segment)
		if exit_node:
			_room_exits.append(exit_node)

func _collect_loop_segments() -> void:
	_loop_segments.clear()
	var back_segment := get_node_or_null("back_segment")
	var mid_segment := get_node_or_null("mid_segment")
	var front_segment := get_node_or_null("front_segment")
	if back_segment is Node3D:
		_loop_segments.append(back_segment)
	if mid_segment is Node3D:
		_loop_segments.append(mid_segment)
	if front_segment is Node3D:
		_loop_segments.append(front_segment)

func _refresh_shift_exit_connection() -> void:
	if _active_shift_exit and _active_shift_exit.body_entered.is_connected(_on_room_exit_body_entered):
		_active_shift_exit.body_entered.disconnect(_on_room_exit_body_entered)

	_active_shift_exit = null
	if _loop_segments.size() < 3:
		return

	var middle_segment := _loop_segments[1]
	var middle_exit := _find_room_exit(middle_segment)
	if middle_exit:
		_active_shift_exit = middle_exit
		if not _active_shift_exit.body_entered.is_connected(_on_room_exit_body_entered):
			_active_shift_exit.body_entered.connect(_on_room_exit_body_entered)

func _find_room_exit(segment: Node3D) -> Area3D:
	if not segment:
		return null
	var exit_node := segment.find_child("RoomExit", true, false)
	if exit_node is Area3D:
		return exit_node
	return null

func _shift_segments_once() -> void:
	if _loop_segments.size() < 3:
		return

	var first := _loop_segments[0]
	var last := _loop_segments[_loop_segments.size() - 1]

	var last_exit := last.find_child("RoomExit", true, false)
	var first_entry := first.find_child("RoomEntry", true, false)

	if last_exit is Node3D and first_entry is Node3D:
		# Back-Segment an das Front-Segment anhängen (inkl. korrekter Rotation).
		# Formel: First_new * Entry_local = LastExit_global  =>  First_new = LastExit_global * Entry_local^-1
		var entry_local_transform := first.global_transform.affine_inverse() * first_entry.global_transform
		var aligned_transform := last_exit.global_transform * entry_local_transform.affine_inverse()
		aligned_transform.basis = aligned_transform.basis.orthonormalized()
		first.global_transform = aligned_transform
	else:
		var last_transform := last.global_transform
		var new_origin := last_transform.origin - last_transform.basis * segment_repeat_offset
		var fallback_transform := first.global_transform
		fallback_transform.origin = new_origin
		first.global_transform = fallback_transform

	# Reihenfolge rotieren: [back, mid, front] -> [mid, front, back]
	_loop_segments.pop_front()
	_loop_segments.append(first)

	# Nach dem Shift ist ein neues Segment in der Mitte -> neuen Trigger verbinden
	_refresh_shift_exit_connection()
