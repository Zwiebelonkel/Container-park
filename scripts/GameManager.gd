extends Node

signal round_started(has_anomaly: bool)
signal round_ended(was_correct: bool)
signal score_changed(new_score: int)
signal game_over_triggered(final_score: int)
signal streak_changed(new_streak: int)

@export var rounds_to_win: int = 8

var current_score: int = 0
var current_streak: int = 0
var best_streak: int = 0
var total_rounds: int = 0
var correct_answers: int = 0
var current_round_has_anomaly: bool = false
var round_active: bool = false
var game_running: bool = false

func _ready() -> void:
	print("[GameManager] Bereit.")

func start_game() -> void:
	current_score = 0
	current_streak = 0
	best_streak = 0
	total_rounds = 0
	correct_answers = 0
	game_running = true
	current_round_has_anomaly = false

	emit_signal("score_changed", current_score)
	emit_signal("streak_changed", current_streak)

	start_round()

func start_round() -> void:
	if not game_running:
		return

	total_rounds += 1
	round_active = true

	emit_signal("round_started", current_round_has_anomaly)
	print("[GameManager] Runde %d gestartet | Anomalie im aktiven Segment: %s" % [total_rounds, current_round_has_anomaly])

func set_current_round_has_anomaly(has_anomaly: bool) -> void:
	current_round_has_anomaly = has_anomaly

func complete_segment(was_cleaned: bool) -> void:
	if not round_active:
		return
	round_active = false
	_process_answer(was_cleaned)

func submit_answer(player_says_anomaly: bool) -> void:
	# Legacy-Pfad zur Kompatibilität: true bedeutet "sauber".
	complete_segment(player_says_anomaly)

func get_time_remaining() -> float:
	return 0.0

func get_time_percent() -> float:
	return 1.0

func _process_answer(correct: bool) -> void:
	if correct:
		correct_answers += 1
		current_streak += 1
		best_streak = max(best_streak, current_streak)

		var points := _calculate_points()
		current_score += points

		emit_signal("score_changed", current_score)
		emit_signal("streak_changed", current_streak)
		print("[GameManager] ✅ Segment korrekt abgeschlossen! +%d Punkte (Streak: %d)" % [points, current_streak])
		if rounds_to_win > 0 and current_streak >= rounds_to_win:
			print("[GameManager] 🏆 Sieg erreicht! %d/%d richtige Segmente." % [current_streak, rounds_to_win])
			trigger_game_over()
	else:
		current_streak = 0
		current_score = 0

		emit_signal("score_changed", current_score)
		emit_signal("streak_changed", current_streak)
		print("[GameManager] ❌ Segment mit aktiver Anomalie verlassen! Score zurückgesetzt.")

	emit_signal("round_ended", correct)

func _calculate_points() -> int:
	var base := 100
	var streak_bonus := (current_streak - 1) * 25
	return base + streak_bonus

func trigger_game_over() -> void:
	game_running = false
	round_active = false
	emit_signal("game_over_triggered", current_score)
	print("[GameManager] 💀 Game Over | Score: %d" % current_score)

func get_stats() -> Dictionary:
	return {
		"score": current_score,
		"streak": current_streak,
		"best_streak": best_streak,
		"rounds": total_rounds,
		"correct": correct_answers,
		"accuracy": float(correct_answers) / max(total_rounds, 1) * 100.0
	}
