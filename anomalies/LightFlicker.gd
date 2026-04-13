## LightFlicker.gd
## Anomalie: Ein Licht im Raum fängt an zu flackern.
## Szene: Leerer Node (kein Mesh nötig), Script: LightFlicker.gd
##
## Voraussetzung: Im Raum gibt es einen OmniLight3D oder SpotLight3D
## mit dem Namen "MainLight" (oder im Inspector konfiguriert).

extends BaseAnomaly

@export var target_light_name: String = "MainLight"
@export var flicker_min_interval: float = 0.05
@export var flicker_max_interval: float = 0.3
@export var original_energy: float = 1.0

var _light: Light3D = null
var _flicker_timer: Timer = null
var _original_energy: float = 1.0
var _is_flickering: bool = false

func _apply() -> void:
	_light = find_in_room(target_light_name) as Light3D
	if not _light:
		push_warning("[LightFlicker] Kein Light3D namens '%s' gefunden." % target_light_name)
		return
	
	_original_energy = _light.light_energy
	_is_flickering = true
	
	# Timer für unregelmäßiges Flackern
	_flicker_timer = Timer.new()
	_flicker_timer.one_shot = true
	add_child(_flicker_timer)
	_flicker_timer.timeout.connect(_flicker_step)
	_flicker_step()
	print("[LightFlicker] Licht '%s' flackert jetzt." % target_light_name)

func _revert() -> void:
	_is_flickering = false
	if _flicker_timer:
		_flicker_timer.stop()
	if _light and is_instance_valid(_light):
		_light.light_energy = _original_energy
		_light.visible = true

func _flicker_step() -> void:
	if not _is_flickering or not _light or not is_instance_valid(_light):
		return
	# Zufällig an/aus oder gedimmtes Flackern
	var r := randf()
	if r < 0.3:
		_light.visible = false
	elif r < 0.6:
		_light.light_energy = _original_energy * randf_range(0.1, 0.4)
	else:
		_light.visible = true
		_light.light_energy = _original_energy * randf_range(0.7, 1.0)
	
	_flicker_timer.start(randf_range(flicker_min_interval, flicker_max_interval))
