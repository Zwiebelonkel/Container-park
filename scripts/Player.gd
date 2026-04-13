## Player.gd (v3 - Jump Update)
## CharacterBody3D - First-Person Controller
## Movement + Mouse Look + Shooting + Jump

extends CharacterBody3D

@export var walk_speed: float = 3.5
@export var mouse_sensitivity: float = 0.002
@export var jump_velocity: float = 5.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var shotgun: Node = $Head/Camera3D/Shotgun

var _can_move: bool = true
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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

	# ── Gravity ─────────────────────────────
	if not is_on_floor():
		velocity.y -= gravity * delta

	# ── Jump ───────────────────────────────
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity

	# ── Movement ───────────────────────────
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed)
		velocity.z = move_toward(velocity.z, 0, walk_speed)

	move_and_slide()

# ── Utility ──────────────────────────────

func freeze(frozen: bool) -> void:
	_can_move = !frozen

func teleport_to(pos: Vector3) -> void:
	global_position = pos
