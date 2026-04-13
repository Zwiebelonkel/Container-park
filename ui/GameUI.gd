## GameUI.gd  (v2 - Shooting Update)
## Kein Anomalie/Normal-Button mehr.
## Stattdessen: Fadenkreuz, Munitionsanzeige, Hinweis-Text.
## Rausgehen = Runde beenden.

extends CanvasLayer

@onready var score_label: Label = $HUD/TopBar/ScoreLabel
@onready var streak_label: Label = $HUD/TopBar/StreakLabel
@onready var ammo_label: Label = $HUD/AmmoBar/AmmoLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var feedback_label: Label = $HUD/FeedbackLabel
@onready var game_over_panel: Panel = $HUD/GameOverPanel
@onready var final_score_label: Label = $HUD/GameOverPanel/FinalScoreLabel
@onready var restart_button: Button = $HUD/GameOverPanel/RestartButton

func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.streak_changed.connect(_on_streak_changed)
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.game_over_triggered.connect(_on_game_over)
	game_over_panel.visible = false
	feedback_label.visible = false
	_update_ammo(6, 6)
	hint_label.text = "Anomalie abschiessen  |  Tuer rausgehen = Runde beenden"

## Wird vom Shotgun-Node aufgerufen: get_node("../UI").update_ammo(current, max)
func update_ammo(current: int, max_a: int) -> void:
	_update_ammo(current, max_a)

func _update_ammo(current: int, max_a: int) -> void:
	if not ammo_label:
		return
	var filled := "| ".repeat(current).strip_edges()
	var empty_s := ". ".repeat(max_a - current).strip_edges()
	ammo_label.text = "%s  %s" % [filled, empty_s]
	if current <= 1:
		ammo_label.modulate = Color(1.0, 0.2, 0.2)
	elif current <= 2:
		ammo_label.modulate = Color(1.0, 0.7, 0.1)
	else:
		ammo_label.modulate = Color(1.0, 1.0, 1.0)

func _on_score_changed(s: int) -> void:
	if score_label: score_label.text = "Score: %d" % s

func _on_streak_changed(s: int) -> void:
	if streak_label: streak_label.text = "x%d" % s if s > 1 else ""

func _on_round_started(_h: bool) -> void:
	feedback_label.visible = false
	hint_label.visible = true

func _on_round_ended(correct: bool) -> void:
	hint_label.visible = false
	_show_feedback(correct)

func _on_game_over(final_score: int) -> void:
	game_over_panel.visible = true
	var stats := GameManager.get_stats()
	final_score_label.text = "Score: %d\nGenauigkeit: %.0f%%\nBester Streak: %d" % [
		final_score, stats["accuracy"], stats["best_streak"]
	]

func _on_restart_pressed() -> void:
	game_over_panel.visible = false
	GameManager.start_game()

func _show_feedback(correct: bool) -> void:
	if not feedback_label: return
	feedback_label.visible = true
	feedback_label.text = "RICHTIG" if correct else "FALSCH"
	feedback_label.modulate = Color(0.2, 1.0, 0.3) if correct else Color(1.0, 0.2, 0.2)
	var tween := get_tree().create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.5)
	await tween.finished
	feedback_label.modulate.a = 1.0
	feedback_label.visible = false
