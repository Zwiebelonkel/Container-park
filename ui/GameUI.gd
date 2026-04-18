extends CanvasLayer

const AMMO_DISPLAY_SCENE := preload("res://ui/ammoDisplay.tscn")

@export var counter_prefix: String = "Fortschritt"

var _counter_label: Label
var _sub_label: Label
var _status_label: Label
var _ammo_display: Control

func _ready() -> void:
	_layer_setup()
	_connect_game_signals()
	_connect_ammo_signal()

func _layer_setup() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var progress_card := PanelContainer.new()
	progress_card.name = "ProgressCard"
	progress_card.position = Vector2(18, 18)
	progress_card.custom_minimum_size = Vector2(280, 108)
	progress_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_card.add_theme_stylebox_override("panel", _create_card_style(Color(0.95, 0.73, 0.25, 0.72)))
	root.add_child(progress_card)

	var progress_margin := MarginContainer.new()
	progress_margin.add_theme_constant_override("margin_left", 14)
	progress_margin.add_theme_constant_override("margin_top", 12)
	progress_margin.add_theme_constant_override("margin_right", 14)
	progress_margin.add_theme_constant_override("margin_bottom", 12)
	progress_card.add_child(progress_margin)

	var progress_vbox := VBoxContainer.new()
	progress_vbox.add_theme_constant_override("separation", 4)
	progress_margin.add_child(progress_vbox)

	_sub_label = Label.new()
	_sub_label.text = "Anomalie-Jagd läuft"
	_sub_label.modulate = Color(0.95, 0.91, 0.8)
	progress_vbox.add_child(_sub_label)

	_counter_label = Label.new()
	_counter_label.add_theme_font_size_override("font_size", 30)
	_counter_label.text = "%s: 0/0" % counter_prefix
	progress_vbox.add_child(_counter_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.modulate = Color(0.25, 1.0, 0.52)
	_status_label.visible = false
	progress_vbox.add_child(_status_label)

	_ammo_display = AMMO_DISPLAY_SCENE.instantiate()
	_ammo_display.name = "AmmoDisplay"
	_ammo_display.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_ammo_display.position = Vector2(-18, 18)
	root.add_child(_ammo_display)

	var scanner_chip := PanelContainer.new()
	scanner_chip.name = "ScannerChip"
	scanner_chip.custom_minimum_size = Vector2(220, 50)
	scanner_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	scanner_chip.position = Vector2(-18, 112)
	scanner_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanner_chip.add_theme_stylebox_override("panel", _create_card_style(Color(0.45, 0.95, 0.85, 0.64)))
	root.add_child(scanner_chip)

	var chip_margin := MarginContainer.new()
	chip_margin.add_theme_constant_override("margin_left", 12)
	chip_margin.add_theme_constant_override("margin_top", 8)
	chip_margin.add_theme_constant_override("margin_right", 12)
	chip_margin.add_theme_constant_override("margin_bottom", 8)
	scanner_chip.add_child(chip_margin)

	var chip_label := Label.new()
	chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_label.text = "SCANNER: ONLINE"
	chip_margin.add_child(chip_label)

func _connect_game_signals() -> void:
	if not GameManager:
		return
	if not GameManager.streak_changed.is_connected(_on_streak_changed):
		GameManager.streak_changed.connect(_on_streak_changed)
	if not GameManager.game_over_triggered.is_connected(_on_game_over):
		GameManager.game_over_triggered.connect(_on_game_over)
	_on_streak_changed(GameManager.current_streak)

func _connect_ammo_signal() -> void:
	var shotgun := get_tree().current_scene.get_node_or_null("Player/Head/Camera3D/Shotgun")
	if shotgun and shotgun.has_signal("ammo_changed"):
		if not shotgun.ammo_changed.is_connected(_on_ammo_changed):
			shotgun.ammo_changed.connect(_on_ammo_changed)
		_on_ammo_changed(shotgun.get("current_ammo"), shotgun.get("max_ammo"))

func _on_streak_changed(streak: int) -> void:
	if not _counter_label:
		return
	var target : int= max(GameManager.rounds_to_win, 0)
	if target > 0:
		_counter_label.text = "%s: %d/%d" % [counter_prefix, streak, target]
	else:
		_counter_label.text = "%s: %d" % [counter_prefix, streak]

	if streak == 0 and _status_label:
		_status_label.visible = false

func _on_game_over(_final_score: int) -> void:
	if not _status_label:
		return
	if GameManager.rounds_to_win > 0 and GameManager.current_streak >= GameManager.rounds_to_win:
		_status_label.text = "🏆 Ziel erreicht!"
		_status_label.visible = true

func _on_ammo_changed(current: int, max_ammo: int) -> void:
	if _ammo_display and _ammo_display.has_method("set_ammo"):
		_ammo_display.call("set_ammo", current, max_ammo)

func _create_card_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.11, 0.86)
	style.set_border_width_all(2)
	style.border_color = accent
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 6
	return style
