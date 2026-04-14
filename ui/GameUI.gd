extends CanvasLayer

@export var counter_prefix: String = "Richtig"

var _counter_label: Label
var _status_label: Label

func _ready() -> void:
	_layer_setup()
	if GameManager:
		GameManager.streak_changed.connect(_on_streak_changed)
		GameManager.game_over_triggered.connect(_on_game_over)
		_on_streak_changed(GameManager.current_streak)

func _layer_setup() -> void:
	_counter_label = Label.new()
	_counter_label.name = "CounterLabel"
	_counter_label.position = Vector2(20, 20)
	_counter_label.add_theme_font_size_override("font_size", 28)
	_counter_label.text = "%s: 0/0" % counter_prefix
	add_child(_counter_label)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.position = Vector2(20, 60)
	_status_label.add_theme_font_size_override("font_size", 32)
	_status_label.modulate = Color(0.2, 1.0, 0.3)
	_status_label.visible = false
	add_child(_status_label)

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
		_status_label.text = "🏆 Gewonnen!"
		_status_label.visible = true
