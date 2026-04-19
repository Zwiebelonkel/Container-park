extends Node3D

@export var target_path: NodePath
@export var rotation_speed: float = 6.0

var target: Node3D

func _ready() -> void:
	if target_path:
		target = get_node(target_path)
	else:
		target = get_tree().get_first_node_in_group("player") as Node3D

func _process(delta: float) -> void:
	if not target:
		return

	# Richtung zum Player
	var direction: Vector3 = target.global_transform.origin - global_transform.origin
	
	# Y ignorieren → nur horizontal drehen
	direction.y = 0
	
	if direction.length() == 0:
		return

	direction = direction.normalized()

	# Zielrotation berechnen
	var target_rotation_y = atan2(direction.x, direction.z)

	# Smooth drehen
	rotation.y = lerp_angle(rotation.y, target_rotation_y, delta * rotation_speed)
