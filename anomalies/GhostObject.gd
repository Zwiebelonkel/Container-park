## GhostObject.gd
## Anomalie: Ein Objekt erscheint das nicht da sein sollte.
## Spawnt ein Mesh an einem Spawn-Punkt und lässt es leicht "pulsieren".
##
## Szene: Node3D mit MeshInstance3D als Child (z.B. eine rote Tonne),
##         Script: GhostObject.gd

extends BaseAnomaly

@export var pulse_speed: float = 2.0
@export var pulse_amount: float = 0.08

var _mesh: MeshInstance3D = null
var _base_scale: Vector3 = Vector3.ONE
var _time: float = 0.0

func _apply() -> void:
	_mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if _mesh:
		_base_scale = _mesh.scale
		# Material leicht transparent/unheimlich
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.85, 0.8, 0.92)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.1, 0.0)
		mat.emission_energy_multiplier = 0.4
		_mesh.material_override = mat
	set_process(true)
	print("[GhostObject] Ghost-Objekt erschienen.")

func _process(delta: float) -> void:
	if not _mesh:
		return
	_time += delta
	var pulse := 1.0 + sin(_time * pulse_speed) * pulse_amount
	_mesh.scale = _base_scale * pulse

func _revert() -> void:
	set_process(false)
