extends Node3D

@export var shake_duration: float = 0.8
@export var shake_strength: float = 0.08
@export var scare_audio: AudioStream = preload("res://assets/audio/scare_high.mp3")

var _base_position: Vector3
var _base_rotation: Vector3
var _audio_player: AudioStreamPlayer3D = null
var _running: bool = false

func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	visible = false

func play_scare_once() -> void:
	if _running:
		return
	_running = true
	_base_position = position
	_base_rotation = rotation
	visible = true

	if not is_instance_valid(_audio_player):
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "GhostScareAudio"
		_audio_player.bus = &"SFX"
		add_child(_audio_player)
		_audio_player.owner = owner
	_audio_player.stream = scare_audio
	_audio_player.max_distance = 20.0
	_audio_player.unit_size = 3.0
	_audio_player.play()

	var elapsed := 0.0
	while elapsed < shake_duration:
		var t := shake_duration - elapsed
		var factor := clamp(t / shake_duration, 0.0, 1.0)
		position = _base_position + Vector3(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		) * factor
		rotation = _base_rotation + Vector3(
			randf_range(-0.03, 0.03),
			randf_range(-0.03, 0.03),
			randf_range(-0.03, 0.03)
		) * factor
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	position = _base_position
	rotation = _base_rotation
	visible = false
	_running = false
