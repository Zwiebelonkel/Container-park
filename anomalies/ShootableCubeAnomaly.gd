extends BaseAnomaly

@export var cube_size: Vector3 = Vector3(1.2, 1.2, 1.2)
@export var cube_color: Color = Color(1.0, 0.2, 0.2, 1.0)

func _ready() -> void:
	if get_child_count() == 0:
		_build_cube()
	super._ready()

func _build_cube() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var box_mesh := BoxMesh.new()
	box_mesh.size = cube_size
	mesh_instance.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cube_color
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.1, 1.0)
	mat.emission_energy_multiplier = 0.5
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	var collider := StaticBody3D.new()
	collider.name = "StaticBody3D"
	mesh_instance.add_child(collider)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = cube_size
	shape.shape = box_shape
	collider.add_child(shape)

func _apply() -> void:
	print("[ShootableCubeAnomaly] Würfel-Anomalie aktiv.")

func _on_destroyed() -> void:
	print("[ShootableCubeAnomaly] Würfel-Anomalie beseitigt.")
