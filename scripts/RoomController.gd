## RoomController.gd  (v2 - Shooting Update)
## Root-Node der Room-Szene.
## Neu: RoomExit wird nach jeder Runde zurueckgesetzt.

extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var player_start: Marker3D = $PlayerStart
@onready var anomaly_manager: Node = $AnomalyManager
@onready var room_exit: Area3D = $RoomExit

var _transition_overlay: ColorRect
var _is_transitioning: bool = false

@export var transition_duration: float = 0.8

@export var loop_axis: Vector3 = Vector3.LEFT
@export var segment_length: float = 115.0
@export var recycle_threshold: float = 35.0

var _loop_segments: Array[Node3D] = []

func _ready() -> void:
	_setup_transition_overlay()
	_collect_loop_segments()
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
	if player and player_start:
		player.teleport_to(player_start.global_position)
		player.velocity = Vector3.ZERO
		var h := player.get_node_or_null("Head")
		if h: h.rotation.y = 0.0
	if room_exit and room_exit.has_method("reset"):
		room_exit.call("reset")
	await _fade_in()
	_is_transitioning = false
	GameManager.start_round()

func _process(_delta: float) -> void:
	_update_loop_segments()

func _collect_loop_segments() -> void:
	_loop_segments.clear()
	for child in get_children():
		if child is Node3D and String(child.name).ends_with("_segment"):
			_loop_segments.append(child)
	if _loop_segments.size() < 2:
		return
	_sort_segments_by_progress()

func _sort_segments_by_progress() -> void:
	if _loop_segments.is_empty():
		return
	var axis := loop_axis.normalized()
	_loop_segments.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.dot(axis) < b.global_position.dot(axis)
	)

func _update_loop_segments() -> void:
	if not player or _loop_segments.size() < 2:
		return
	var axis := loop_axis.normalized()
	if axis == Vector3.ZERO:
		return

	var player_progress := player.global_position.dot(axis)
	var moved := false
	while _loop_segments.size() >= 2:
		var first := _loop_segments[0]
		var last := _loop_segments[_loop_segments.size() - 1]
		var first_progress := first.global_position.dot(axis)
		if player_progress - first_progress <= recycle_threshold:
			break
		first.global_position = last.global_position + axis * segment_length
		_loop_segments.pop_front()
		_loop_segments.append(first)
		moved = true
	if moved:
		_sort_segments_by_progress()
