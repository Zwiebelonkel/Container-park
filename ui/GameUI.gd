extends CanvasLayer

const HUD_SCENE := preload("res://ui/gameHud.tscn")

@export var counter_prefix: String = "Fortschritt"

var _counter_label: Label
var _status_label: Label
var _ammo_value: Label
var _ammo_bar: ProgressBar

func _ready() -> void:
	_setup_hud()
	_connect_game_signals()
	_connect_ammo_signal()

func _setup_hud() -> void:
	var hud_root := HUD_SCENE.instantiate()
	add_child(hud_root)

	_counter_label = hud_root.get_node("ScreenMargin/TopRow/ProgressCard/ProgressMargin/ProgressVBox/CounterLabel") as Label
	_status_label = hud_root.get_node("ScreenMargin/TopRow/ProgressCard/ProgressMargin/ProgressVBox/StatusLabel") as Label
	_ammo_value = hud_root.get_node("ScreenMargin/TopRow/RightColumn/AmmoCard/AmmoMargin/AmmoVBox/AmmoValue") as Label
	_ammo_bar = hud_root.get_node("ScreenMargin/TopRow/RightColumn/AmmoCard/AmmoMargin/AmmoVBox/AmmoBar") as ProgressBar

	_apply_card_styles(hud_root)

func _apply_card_styles(hud_root: Control) -> void:
	var progress_card := hud_root.get_node("ScreenMargin/TopRow/ProgressCard") as PanelContainer
	var ammo_card := hud_root.get_node("ScreenMargin/TopRow/RightColumn/AmmoCard") as PanelContainer
	var scanner_chip := hud_root.get_node("ScreenMargin/TopRow/RightColumn/ScannerChip") as PanelContainer

	progress_card.add_theme_stylebox_override("panel", _create_card_style(Color(0.95, 0.73, 0.25, 0.72)))
	ammo_card.add_theme_stylebox_override("panel", _create_card_style(Color(0.4, 0.67, 1.0, 0.75)))
	scanner_chip.add_theme_stylebox_override("panel", _create_card_style(Color(0.45, 0.95, 0.85, 0.64)))

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

	var target := max(GameManager.rounds_to_win, 0)
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
	if not _ammo_value or not _ammo_bar:
		return

	var safe_max := max(max_ammo, 1)
	var safe_current := clamp(current, 0, safe_max)
	_ammo_value.text = "%d / %d" % [safe_current, safe_max]
	_ammo_bar.max_value = safe_max
	_ammo_bar.value = safe_current

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
