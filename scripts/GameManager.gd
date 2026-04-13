## GameManager.gd
## Autoload-Singleton – in den Projekteinstellungen hinzufügen:
## Projekt > Projekteinstellungen > Autoload > Pfad: res://scripts/GameManager.gd > Name: GameManager

extends Node

# ─── Signale ───────────────────────────────────────────────────────────────────
signal round_started(has_anomaly: bool)
signal round_ended(was_correct: bool)
signal score_changed(new_score: int)
signal game_over_triggered(final_score: int)
signal streak_changed(new_streak: int)

# ─── Konfiguration ─────────────────────────────────────────────────────────────
@export var anomaly_chance: float = 0.5
@export var rounds_to_win: int = 10

# ─── State ─────────────────────────────────────────────────────────────────────
var current_score: int = 0
var current_streak: int = 0
var best_streak: int = 0
var total_rounds: int = 0
var correct_answers: int = 0
var current_round_has_anomaly: bool = false
var round_active: bool = false
var game_running: bool = false

# ─── Internes ──────────────────────────────────────────────────────────────────
var _active_anomaly: Node = null

func _ready() -> void:
	print("[GameManager] Bereit.")

# ─── Öffentliche API ───────────────────────────────────────────────────────────

func start_game() -> void:
	current_score = 0
	current_streak = 0
	best_streak = 0
	total_rounds = 0
	correct_answers = 0
	game_running = true

	emit_signal("score_changed", current_score)
	emit_signal("streak_changed", current_streak)

	start_round()

func start_round() -> void:
	if not game_running:
		return

	total_rounds += 1
	current_round_has_anomaly = randf() < anomaly_chance
	round_active = true

	emit_signal("round_started", current_round_has_anomaly)
	print("[GameManager] Runde %d gestartet | Anomalie: %s" % [total_rounds, current_round_has_anomaly])

func submit_answer(player_says_anomaly: bool) -> void:
	if not round_active:
		return

	round_active = false
	var correct: bool = player_says_anomaly == current_round_has_anomaly
	_process_answer(correct)

func get_time_remaining() -> float:
	return 0.0

func get_time_percent() -> float:
	return 1.0

# ─── Interne Logik ─────────────────────────────────────────────────────────────

func _process_answer(correct: bool) -> void:
	if correct:
		correct_answers += 1
		current_streak += 1
		best_streak = max(best_streak, current_streak)

		var points := _calculate_points()
		current_score += points

		emit_signal("score_changed", current_score)
		emit_signal("streak_changed", current_streak)
		print("[GameManager] ✅ Richtig! +%d Punkte (Streak: %d)" % [points, current_streak])
	else:
		current_streak = 0
		current_score = 0

		emit_signal("score_changed", current_score)
		emit_signal("streak_changed", current_streak)
		print("[GameManager] ❌ Falsch! Score zurückgesetzt.")

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
