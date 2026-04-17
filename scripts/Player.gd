## Player.gd (v7 - Step-Up + Floor Fix)
## CharacterBody3D - First-Person Controller
## Movement + Mouse Look + Shooting + Jump + Headbob + Step-Up
extends CharacterBody3D

# ── Movement ────────────────────────────────────────────────
@export var walk_speed: float = 3.5
@export var mouse_sensitivity: float = 0.002
@export var jump_velocity: float = 5.5

# ── Headbob ──────────────────────────────────────────────────
@export var headbob_frequency: float = 10.5
@export var headbob_amplitude: float = 0.09
@export var headbob_smoothing: float = 12.0
@export var headbob_roll_degrees: float = 1.4
@export var wave_sway_enabled: bool = true
@export var wave_sway_interval_min: float = 2.2
@export var wave_sway_interval_max: float = 4.8
@export var wave_sway_hold_time: float = 1.1
@export var wave_sway_tilt_min_degrees: float = 0.6
@export var wave_sway_tilt_max_degrees: float = 2.0
@export var wave_sway_smoothing: float = 4.5

# ── Step-Up ───────────────────────────────────────────────────
@export var step_height: float = 0.35
@export var step_smooth_speed: float = 14.0

# ── Node refs ────────────────────────────────────────────────
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var shotgun: Node = $Head/Camera3D/Shotgun
@onready var col_shape: CollisionShape3D = $CollisionShape3D
@onready var _dbg: Label3D = null

# ── State ────────────────────────────────────────────────────
var _can_move: bool = true
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * 4
var _headbob_time: float = 0.0
var _camera_base_local_position: Vector3
var _head_base_y: float = 0.0
var _visual_y_offset: float = 0.0
var _in_step_area: bool = false
var _wave_sway_timer: float = 0.0
var _wave_sway_is_neutral: bool = true
var _wave_sway_target_roll: float = 0.0
var _wave_sway_current_roll: float = 0.0

# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	randomize()
	var areas := get_tree().get_nodes_in_group("stepArea")
	for a in areas:
		if a is Area3D:
			a.body_entered.connect(_on_step_area_entered)
			a.body_exited.connect(_on_step_area_exited)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_camera_base_local_position = camera.position
	_head_base_y = head.position.y
	_wave_sway_timer = _random_wave_sway_interval()

	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(46)

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

# ── Input ────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			head.rotate_y(-event.relative.x * mouse_sensitivity)
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		return

# ── Physics ───────────────────────────────────────────────────
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

	_move_with_step_up(delta)
	_update_headbob(delta)

# ── Step-Up ───────────────────────────────────────────────────
var _dbg_timer: float = 0.0

func _move_with_step_up(delta: float) -> void:
	move_and_slide()

	if not _in_step_area:
		return

	# ── Debug Timer ─────────────────────────────
	_dbg_timer += delta
	var should_print := _dbg_timer >= 0.2
	if should_print:
		_dbg_timer = 0.0

	# ── Nur am Boden
	if not is_on_floor():
		if should_print:
			print_rich("[color=gray]● nicht am Boden[/color]")
		return

	# ── Nur wenn Bewegung
	var horiz_vel := Vector2(velocity.x, velocity.z)
	if horiz_vel.length() < 0.05:
		if should_print:
			print_rich("[color=gray]● steht still[/color]")
		return

	# ── WICHTIG: richtige Richtung (kein doppelt transformieren!)
	var dir := Vector3(velocity.x, 0, velocity.z).normalized()

	var space := get_world_3d().direct_space_state

	# ── 1. Forward Ray (FIXED)
	var forward_offset := 3
	var ray_height := 0.5

	var forward_from := global_position + Vector3(0, ray_height, 0)
	var forward_to := forward_from + dir * forward_offset

	var ray_params := PhysicsRayQueryParameters3D.create(forward_from, forward_to)
	ray_params.exclude = [self]
	ray_params.collision_mask = collision_mask

	var forward_hit: Dictionary = space.intersect_ray(ray_params)

	# ── Debug Ray zeichnen
	_draw_debug_ray(forward_from, forward_to, Color.RED)

	if should_print:
		if forward_hit.is_empty():
			print_rich("[color=gray]● forward ray: MISS[/color]")
		else:
			var n: Vector3 = forward_hit.normal
			print_rich("[color=yellow]● HIT normal=(%.2f, %.2f, %.2f)[/color]"
				% [n.x, n.y, n.z])

	if forward_hit.is_empty():
		return

	# ── 2. Platz über der Stufe prüfen
	var step_test_pos := global_position + Vector3(0, step_height, 0)

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape_rid = col_shape.shape.get_rid()
	params.transform = Transform3D(Basis(), step_test_pos)
	params.exclude = [self]
	params.collision_mask = collision_mask

	var shape_result := space.intersect_shape(params)

	if should_print:
		if shape_result.is_empty():
			print_rich("[color=lime]● oben frei → STEP möglich[/color]")
		else:
			print_rich("[color=red]● oben blockiert[/color]")

	if not shape_result.is_empty():
		return

	# ── 3. STEP AUSFÜHREN
	if should_print:
		print_rich("[color=lime][b]★ STEP UP![/b][/color]")

	global_position += Vector3(0, step_height, 0) + dir * 0.1
	velocity.y = 0.0

	move_and_slide()
	
# ── Headbob ───────────────────────────────────────────────────
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
	_update_wave_sway(delta)
	camera.rotation_degrees.z = lerp(
		camera.rotation_degrees.z,
		target_roll + _wave_sway_current_roll,
		delta * headbob_smoothing
	)

func _update_wave_sway(delta: float) -> void:
	if not wave_sway_enabled:
		_wave_sway_target_roll = 0.0
		_wave_sway_current_roll = lerp(_wave_sway_current_roll, 0.0, delta * wave_sway_smoothing)
		return

	_wave_sway_timer -= delta
	if _wave_sway_timer <= 0.0:
		if _wave_sway_is_neutral:
			_wave_sway_target_roll = _random_wave_sway_tilt()
			_wave_sway_timer = max(wave_sway_hold_time, 0.05)
		else:
			_wave_sway_target_roll = 0.0
			_wave_sway_timer = _random_wave_sway_interval()
		_wave_sway_is_neutral = !_wave_sway_is_neutral

	_wave_sway_current_roll = lerp(
		_wave_sway_current_roll,
		_wave_sway_target_roll,
		delta * wave_sway_smoothing
	)

func _random_wave_sway_interval() -> float:
	var min_interval: float = min(wave_sway_interval_min, wave_sway_interval_max)
	var max_interval: float = max(wave_sway_interval_min, wave_sway_interval_max)
	return randf_range(min_interval, max_interval)

func _random_wave_sway_tilt() -> float:
	var min_tilt: float = min(wave_sway_tilt_min_degrees, wave_sway_tilt_max_degrees)
	var max_tilt: float = max(wave_sway_tilt_min_degrees, wave_sway_tilt_max_degrees)
	var tilt: float = randf_range(min_tilt, max_tilt)
	return tilt if randf() > 0.5 else -tilt

# ── Public API ────────────────────────────────────────────────
func freeze(frozen: bool) -> void:
	_can_move = !frozen

func teleport_to(pos: Vector3) -> void:
	global_position = pos
	
func _draw_debug_ray(from: Vector3, to: Vector3, color: Color = Color.RED) -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	get_tree().current_scene.add_child(instance)

	# Nach kurzer Zeit löschen
	await get_tree().create_timer(0.1).timeout
	instance.queue_free()
	
func _on_step_area_entered(body: Node) -> void:
	if body == self:
		_in_step_area = true
		print("ENTER STEP AREA")

func _on_step_area_exited(body: Node) -> void:
	if body == self:
		_in_step_area = false
		print("EXIT STEP AREA")
