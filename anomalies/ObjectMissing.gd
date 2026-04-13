## ObjectMissing.gd
## Anomalie: Ein Objekt im Raum verschwindet (wird ausgeblendet).
## Funktioniert mit beliebigen MeshInstance3D oder Node3D im Raum.
##
## Szene: Leerer Node, Script: ObjectMissing.gd

extends BaseAnomaly

## Name(n) von Objekten die verschwinden können (zufällig eines wird gewählt)
@export var target_object_names: Array[String] = ["Barrel", "Box", "Chair"]

var _hidden_node: Node3D = null

func _apply() -> void:
	# Verfügbare Objekte im Raum suchen
	var candidates: Array[Node3D] = []
	for obj_name in target_object_names:
		var node := find_in_room(obj_name) as Node3D
		if node and node.visible:
			candidates.append(node)
	
	if candidates.is_empty():
		push_warning("[ObjectMissing] Keine Zielobjekte gefunden.")
		return
	
	_hidden_node = candidates.pick_random()
	_hidden_node.visible = false
	print("[ObjectMissing] Objekt '%s' versteckt." % _hidden_node.name)

func _revert() -> void:
	if _hidden_node and is_instance_valid(_hidden_node):
		_hidden_node.visible = true
