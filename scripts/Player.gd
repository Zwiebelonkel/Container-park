## Player.gd (v5 - Visible Headbob)
## CharacterBody3D - First-Person Controller
## Movement + Mouse Look + Shooting + Jump + Headbob

extends CharacterBody3D

@export var walk_speed: float = 3.5
@export var mouse_sensitivity: float = 0.002
@export var jump_velocity: float = 5.5

@export var headbob_frequency: float = 10.5
@export var headbob_amplitude: float = 0.09
@export var headbob_smoothing: float = 12.0
@export var headbob_roll_degrees: float = 1.4

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var shotgun: Node = $Head/Camera3D/Shotgun

var _can_move: bool = true
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")*2.5

var _headbob_time: float = 0.0
var _camera_base_local_position: Vector3

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_camera_base_local_position = camera.position

	if GameManager:
		GameManager.round_started.connect(_on_round_started)
		GameManager.round_ended.connect(_on_round_ended)

	if shotgun and shotgun.has_signal("ammo_changed"):
		shotgun.ammo_changed.connect(_on_ammo_changed)

func _on_round_started(_h: bool) -> void:
	_can_move = true
	if shotgun and shotgun.has_method("force_reload"):
		shotgun.call("force_reload")

func _on_round_ended(_c: bool) -> void:
	pass

func _on_ammo_changed(current: int, max_ammo: int) -> void:
	var ui := get_tree().current_scene.find_child("UI", true, false)
	if ui and ui.has_method("update_ammo"):
		ui.call("update_ammo", current, max_ammo)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			head.rotate_y(-event.relative.x * mouse_sensitivity)
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		return

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not _can_move:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed)
		velocity.z = move_toward(velocity.z, 0, walk_speed)

	move_and_slide()
	_update_headbob(delta)

func _update_headbob(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var speed_norm: float = clamp(horizontal_speed / max(walk_speed, 0.001), 0.0, 1.0)
	var active: bool = is_on_floor() and speed_norm > 0.05

	if active:
		_headbob_time += delta * headbob_frequency * lerp(0.8, 1.5, speed_norm)

	var bob_factor: float = speed_norm if active else 0.0

	var bob_x: float = sin(_headbob_time * 0.5) * headbob_amplitude * 0.55 * bob_factor
	var bob_y: float = absf(sin(_headbob_time)) * headbob_amplitude * bob_factor

	var target_position: Vector3 = _camera_base_local_position + Vector3(bob_x, bob_y, 0.0)
	camera.position = camera.position.lerp(target_position, delta * headbob_smoothing)

	var target_roll: float = -sin(_headbob_time * 0.5) * headbob_roll_degrees * bob_factor
	camera.rotation_degrees.z = lerp(camera.rotation_degrees.z, target_roll, delta * headbob_smoothing)
	camera.rotation_degrees.z = lerp(camera.rotation_degrees.z, target_roll, delta * headbob_smoothing)

func freeze(frozen: bool) -> void:
	_can_move = !frozen

func teleport_to(pos: Vector3) -> void:
	global_position = pos
