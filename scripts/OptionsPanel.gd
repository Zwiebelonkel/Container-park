extends Panel

signal back_requested

@onready var fullscreen_check: CheckBox = $MarginContainer/VBoxContainer/FullscreenCheck
@onready var volume_slider: HSlider = $MarginContainer/VBoxContainer/VolumeRow/VolumeSlider
@onready var volume_value: Label = $MarginContainer/VBoxContainer/VolumeRow/VolumeValue
@onready var sensitivity_slider: HSlider = $MarginContainer/VBoxContainer/SensitivityRow/SensitivitySlider
@onready var sensitivity_value: Label = $MarginContainer/VBoxContainer/SensitivityRow/SensitivityValue
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	_apply_current_settings_to_controls()

func _apply_current_settings_to_controls() -> void:
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	var bus_idx := AudioServer.get_bus_index("Master")
	var db := AudioServer.get_bus_volume_db(bus_idx)
	volume_slider.value = db_to_linear(db) * 100.0
	_update_volume_label(volume_slider.value)

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].get("mouse_sensitivity") != null:
		var sens: float = players[0].get("mouse_sensitivity")
		sensitivity_slider.value = sens * 10000.0
	else:
		sensitivity_slider.value = 20.0
	_update_sensitivity_label(sensitivity_slider.value)

func _on_back_pressed() -> void:
	visible = false
	back_requested.emit()

func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)

func _on_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clamp(value / 100.0, 0.001, 1.0)))
	_update_volume_label(value)

func _on_sensitivity_changed(value: float) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p.get("mouse_sensitivity") != null:
			p.set("mouse_sensitivity", value / 10000.0)
	_update_sensitivity_label(value)

func _update_volume_label(value: float) -> void:
	volume_value.text = "%d%%" % int(round(value))

func _update_sensitivity_label(value: float) -> void:
	sensitivity_value.text = "%.3f" % (value / 10000.0)
