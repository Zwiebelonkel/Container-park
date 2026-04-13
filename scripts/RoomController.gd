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

func _ready() -> void:
	_setup_transition_overlay()
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
