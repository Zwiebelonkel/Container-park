## RoomExit.gd
## Hänge dieses Script an einen Area3D am Ausgang des Raumes.
##
## Node-Struktur:
##   RoomExit (Area3D)  ← dieses Script
##     └── CollisionShape3D (BoxShape3D quer vor der Tür)
##
## Logik:
##   Spieler geht raus = "Ich glaube, alles ist normal" (keine Anomalie mehr da)
##   → GameManager.submit_answer(false) wenn keine Anomalie beseitigt wurde
##   → Runde gilt als korrekt wenn vorher gar keine Anomalie spawnte
##   → Runde gilt als falsch wenn noch eine unentdeckte Anomalie aktiv ist

extends Area3D

@export var anomaly_manager_path: NodePath = ""

@onready var _anomaly_manager: Node = get_node_or_null(anomaly_manager_path)

# Cooldown damit der Exit nicht mehrfach triggert
var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return

	_triggered = true

	# Pruefen ob noch eine aktive (unbeseitigte) Anomalie da ist
	var anomaly_still_active := false
	if _anomaly_manager and _anomaly_manager.has_method("has_active_anomaly"):
		anomaly_still_active = _anomaly_manager.call("has_active_anomaly")

	if anomaly_still_active:
		# Spieler geht raus obwohl noch Anomalie da → FALSCH
		print("[RoomExit] Spieler geht raus – Anomalie noch aktiv → FALSCH")
		GameManager.submit_answer(false)
	else:
		# Keine Anomalie (oder bereits beseitigt) → RICHTIG
		print("[RoomExit] Spieler geht raus – Raum sauber → RICHTIG")
		GameManager.submit_answer(true)

## Muss nach jeder Runde zurückgesetzt werden
func reset() -> void:
	_triggered = false
