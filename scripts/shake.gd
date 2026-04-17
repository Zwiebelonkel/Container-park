extends Node3D

@export var shake_duration: float = 0.8
@export var shake_strength: float = 0.08
@export var scare_audio: AudioStream = preload("res://assets/audio/scare_intense.mp3")

var _base_position: Vector3
var _base_rotation: Vector3
var _audio_player: AudioStreamPlayer3D = null
var _running: bool = false

# 🔦 Player Flashlight
var _player_flashlight: Light3D = null
var _flashlight_prev_state: bool = true

# 👻 Ghost Light
var _ghost_light: Light3D = null
var _ghost_light_base_energy: float = 1.0

func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	visible = false
	
	# 👻 Ghost Light suchen
	for node in find_children("*", "Light3D", true, false):
		_ghost_light = node
		break
	
	if is_instance_valid(_ghost_light):
		_ghost_light_base_energy = _ghost_light.light_energy


# 🔍 Flashlight finden
func _find_flashlight() -> Light3D:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return null
	
	for light in player.find_children("*", "Light3D", true, false):
		if light.name.to_lower().contains("flashlight"):
			return light
	
	return null


# 🔦 Flashlight AUS
func _disable_flashlight():
	if not is_instance_valid(_player_flashlight):
		_player_flashlight = _find_flashlight()
	
	if not is_instance_valid(_player_flashlight):
		return
	
	_flashlight_prev_state = _player_flashlight.visible
	_player_flashlight.visible = false


# 🔦 Flashlight AN
func _restore_flashlight():
	if not is_instance_valid(_player_flashlight):
		return
	
	_player_flashlight.visible = _flashlight_prev_state


# 🎵 Music Bus wieder aktivieren (safe)
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


# 💀 MAIN SCARE
func play_scare_once() -> void:
	if _running:
		return
	_running = true
	
	# 🔦 Player Licht aus
	_disable_flashlight()

	_base_position = position
	_base_rotation = rotation
	visible = true

	# 🔊 Sound
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
		var factor : float = clamp(t / shake_duration, 0.0, 1.0)

		# 💥 SHAKE
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

		# 👻 LIGHT FLICKER
		if is_instance_valid(_ghost_light):
			if randf() < 0.25:
				_ghost_light.light_energy = 0.0
			else:
				_ghost_light.light_energy = _ghost_light_base_energy * randf_range(0.3, 2.0)

		await get_tree().process_frame
		elapsed += get_process_delta_time()

	# 🔄 RESET
	position = _base_position
	rotation = _base_rotation
	visible = false

	# 👻 Licht zurücksetzen
	if is_instance_valid(_ghost_light):
		_ghost_light.light_energy = _ghost_light_base_energy

	# 🔦 Player Licht wieder an
	_restore_flashlight()

	# 🎵 Music Bus wieder aktivieren
	_restore_music_bus()

	_running = false
