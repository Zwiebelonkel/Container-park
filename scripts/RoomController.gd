## RoomController.gd  (v2 - Shooting Update)
## Root-Node der Room-Szene.
## Neu: RoomExit wird nach jeder Runde zurueckgesetzt.

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

func _ready() -> void:
	_setup_transition_overlay()
	_collect_loop_segments()
	_collect_room_exits()
	for exit_area in _room_exits:
		exit_area.body_entered.connect(_on_room_exit_body_entered)
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

func _on_round_ended(was_correct: bool) -> void:
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
		if not segment:
			continue
		var exit_node := segment.find_child("RoomExit", true, false)
		if exit_node is Area3D:
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

func _shift_segments_once() -> void:
	if _loop_segments.size() < 3:
		return

	var first := _loop_segments[0]
	var last := _loop_segments[_loop_segments.size() - 1]

	var last_transform := last.global_transform

	# Offset relativ zur Rotation anwenden
	var new_origin := last_transform.origin - last_transform.basis * segment_repeat_offset

	# Eigene Rotation des recycelten Segments beibehalten
	var new_transform := first.global_transform
	new_transform.origin = new_origin

	first.global_transform = new_transform

	# Reihenfolge rotieren
	_loop_segments.pop_front()
	_loop_segments.append(first)
