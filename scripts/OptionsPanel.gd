extends Panel

signal back_requested

@onready var fullscreen_check: CheckBox = $MarginContainer/VBoxContainer/FullscreenCheck
@onready var volume_slider: HSlider = $MarginContainer/VBoxContainer/VolumeRow/VolumeSlider
@onready var volume_value: Label = $MarginContainer/VBoxContainer/VolumeRow/VolumeValue
@onready var sensitivity_slider: HSlider = $MarginContainer/VBoxContainer/SensitivityRow/SensitivitySlider
@onready var sensitivity_value: Label = $MarginContainer/VBoxContainer/SensitivityRow/SensitivityValue
@onready var debug_divider: Panel = $MarginContainer/VBoxContainer/DebugDivider
@onready var debug_title: Label = $MarginContainer/VBoxContainer/DebugTitle
@onready var debug_row: HBoxContainer = $MarginContainer/VBoxContainer/DebugRow
@onready var debug_picker: OptionButton = $MarginContainer/VBoxContainer/DebugRow/DebugAnomalyPicker
@onready var run_debug_button: Button = $MarginContainer/VBoxContainer/DebugRow/RunDebugAnomalyButton
@onready var debug_status: Label = $MarginContainer/VBoxContainer/DebugStatus
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton

var _debug_anomaly_ids: PackedStringArray = PackedStringArray()

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	run_debug_button.pressed.connect(_on_run_debug_anomaly_pressed)
	_apply_current_settings_to_controls()
	_refresh_debug_controls()

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_debug_controls()

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

func _resolve_anomaly_manager() -> Node:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return null
	return scene.find_child("AnomalyManager", true, false)

func _refresh_debug_controls() -> void:
	var anomaly_manager := _resolve_anomaly_manager()
	var can_debug := is_instance_valid(anomaly_manager) \
		and anomaly_manager.has_method("get_debug_anomaly_ids") \
		and anomaly_manager.has_method("apply_debug_anomaly")

	debug_divider.visible = can_debug
	debug_title.visible = can_debug
	debug_row.visible = can_debug
	debug_status.visible = true

	if not can_debug:
		debug_status.text = "Debug-Menü nur im aktiven Spiel verfügbar."
		return

	debug_picker.clear()
	_debug_anomaly_ids.clear()
	var ids_variant = anomaly_manager.call("get_debug_anomaly_ids")
	if ids_variant is PackedStringArray:
		_debug_anomaly_ids = ids_variant
	elif ids_variant is Array:
		for value in ids_variant:
			_debug_anomaly_ids.append(str(value))

	for anomaly_id in _debug_anomaly_ids:
		debug_picker.add_item(_anomaly_label_from_id(anomaly_id))

	if debug_picker.item_count > 0:
		debug_picker.select(0)
	debug_status.text = "Wendet die ausgewählte Anomalie im aktuellen Raum an."

func _on_run_debug_anomaly_pressed() -> void:
	var anomaly_manager := _resolve_anomaly_manager()
	if not is_instance_valid(anomaly_manager):
		debug_status.text = "Kein AnomalyManager gefunden."
		return
	if debug_picker.item_count == 0:
		debug_status.text = "Keine Debug-Anomalien verfügbar."
		return

	var selected_index := debug_picker.get_selected_id()
	if selected_index < 0 or selected_index >= _debug_anomaly_ids.size():
		selected_index = debug_picker.selected
	if selected_index < 0 or selected_index >= _debug_anomaly_ids.size():
		debug_status.text = "Bitte zuerst eine Anomalie auswählen."
		return

	var anomaly_id := _debug_anomaly_ids[selected_index]
	var applied := bool(anomaly_manager.call("apply_debug_anomaly", anomaly_id))
	if applied:
		debug_status.text = "Debug-Anomalie gestartet: %s" % _anomaly_label_from_id(anomaly_id)
	else:
		debug_status.text = "Konnte nicht gestartet werden (im aktuellen Raum nicht möglich)."

func _anomaly_label_from_id(anomaly_id: String) -> String:
	match anomaly_id:
		"hide":
			return "Objekt verstecken"
		"show":
			return "Objekt anzeigen"
		"scale_up":
			return "Objekt vergrößern"
		"scale_down":
			return "Objekt verkleinern"
		"light_flicker":
			return "Licht flackern"
		"ghostscare":
			return "Ghost Scare"
		_:
			return anomaly_id
