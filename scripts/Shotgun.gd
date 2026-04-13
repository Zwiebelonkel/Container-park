## Shotgun.gd
## Hänge dieses Script an einen Node3D namens "Shotgun" unter der Camera3D.

extends Node3D

signal fired(hit_nodes: Array)
signal reloaded()
signal ammo_changed(current: int, max_ammo: int)

@export var max_ammo: int = 6
@export var pellet_count: int = 8
@export var spread_degrees: float = 4.5
@export var fire_range: float = 25.0
@export var reload_time: float = 0.9
@export var fire_rate: float = 1.1

@export var recoil_kick_up: float = 4.5
@export var recoil_kick_side: float = 0.6
@export var recoil_recover_speed: float = 6.0

@export var idle_sway_x_amplitude: float = 0.01
@export var idle_sway_y_amplitude: float = 0.007
@export var movement_sway_amount: float = 0.02
@export var movement_sway_frequency: float = 9.5
@export var mouse_sway_strength: float = 0.00018
@export var mouse_sway_return_speed: float = 14.0
@export var sway_rotation_degrees: float = 1.6

@onready var muzzle_flash: OmniLight3D = $MuzzleFlash
@onready var camera: Camera3D = get_parent() as Camera3D
@onready var _player_body: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D

var current_ammo: int = max_ammo
var _can_fire: bool = true
var _is_reloading: bool = false
var _recoil_current: Vector2 = Vector2.ZERO
var _recoil_target: Vector2 = Vector2.ZERO
var _weapon_base_position: Vector3
var _weapon_base_rotation: Vector3

var _sway_time: float = 0.0
var _move_sway_time: float = 0.0
var _mouse_sway_target: Vector2 = Vector2.ZERO
var _mouse_sway_current: Vector2 = Vector2.ZERO
var _fire_kick_offset_z: float = 0.0

func _ready() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not _player_body:
		_player_body = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_weapon_base_position = position
	_weapon_base_rotation = rotation_degrees
	if muzzle_flash:
		muzzle_flash.visible = false
	emit_signal("ammo_changed", current_ammo, max_ammo)

func _process(delta: float) -> void:
	_update_recoil(delta)
	_update_weapon_sway(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_sway_target.x = clamp(-event.relative.x * mouse_sway_strength, -0.08, 0.08)
		_mouse_sway_target.y = clamp(event.relative.y * mouse_sway_strength, -0.06, 0.06)
		return

	if not (event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton):
		return
	if event.is_action_pressed("fire") and _can_fire and not _is_reloading:
		if current_ammo > 0:
			_fire()
		else:
			_play_empty_click()

func _fire() -> void:
	_can_fire = false
	current_ammo -= 1
	emit_signal("ammo_changed", current_ammo, max_ammo)

	var hit_nodes: Array = []
	var space_state := get_viewport().get_camera_3d().get_world_3d().direct_space_state
	for i in pellet_count:
		var hit := _cast_pellet(space_state)
		if hit and hit not in hit_nodes:
			hit_nodes.append(hit)

	emit_signal("fired", hit_nodes)
	_trigger_muzzle_flash()
	_apply_recoil()
	_play_fire_animation()

	await get_tree().create_timer(fire_rate * 0.2).timeout
	_pump_action()
	await get_tree().create_timer(fire_rate * 0.8).timeout
	_can_fire = true

func _cast_pellet(space_state: PhysicsDirectSpaceState3D) -> Node:
	if not camera:
		return null

	var spread_rad := deg_to_rad(spread_degrees)
	var spread_dir := Vector3(
		randf_range(-spread_rad, spread_rad),
		randf_range(-spread_rad, spread_rad),
		0.0
	)

	var cam_basis := camera.global_transform.basis
	var direction := (-cam_basis.z + cam_basis.x * spread_dir.x + cam_basis.y * spread_dir.y).normalized()
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * fire_range)
	query.collide_with_areas = true

	var result := space_state.intersect_ray(query)
	if result and result.has("collider"):
		return result["collider"]
	return null

func _apply_recoil() -> void:
	_recoil_target.y += recoil_kick_up
	_recoil_target.x += randf_range(-recoil_kick_side, recoil_kick_side)

func _update_recoil(delta: float) -> void:
	if not camera:
		return
	_recoil_current = _recoil_current.lerp(_recoil_target, delta * recoil_recover_speed * 0.4)
	_recoil_target = _recoil_target.lerp(Vector2.ZERO, delta * recoil_recover_speed)
	camera.rotation_degrees.x -= _recoil_current.y * delta * 60.0
	camera.rotation_degrees.y += _recoil_current.x * delta * 30.0

func _update_weapon_sway(delta: float) -> void:
	_sway_time += delta
	var idle_sway := Vector3(
		sin(_sway_time * 1.4) * idle_sway_x_amplitude,
		sin(_sway_time * 2.1) * idle_sway_y_amplitude,
		0.0
	)

	_mouse_sway_target = _mouse_sway_target.lerp(Vector2.ZERO, delta * mouse_sway_return_speed)
	_mouse_sway_current = _mouse_sway_current.lerp(_mouse_sway_target, delta * mouse_sway_return_speed)
	var mouse_sway := Vector3(_mouse_sway_current.x, _mouse_sway_current.y, 0.0)

	var move_sway := Vector3.ZERO
	if _player_body and _player_body.is_inside_tree():
		var horizontal_speed := Vector2(_player_body.velocity.x, _player_body.velocity.z).length()
		if _player_body.is_on_floor() and horizontal_speed > 0.05:
			var player_walk_speed := float(_player_body.get("walk_speed"))
			var speed_factor := clamp(horizontal_speed / max(player_walk_speed, 0.001), 0.0, 1.0)
			_move_sway_time += delta * movement_sway_frequency * lerp(0.8, 1.5, speed_factor)
			move_sway.x = sin(_move_sway_time) * movement_sway_amount * speed_factor
			move_sway.y = abs(cos(_move_sway_time * 0.5)) * movement_sway_amount * 0.7 * speed_factor

	position = _weapon_base_position + idle_sway + mouse_sway + move_sway + Vector3(0.0, 0.0, _fire_kick_offset_z)
	rotation_degrees.x = _weapon_base_rotation.x + (mouse_sway.y + move_sway.y) * sway_rotation_degrees * 40.0
	rotation_degrees.y = _weapon_base_rotation.y + (-mouse_sway.x + move_sway.x) * sway_rotation_degrees * 45.0

func _play_fire_animation() -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(self, "_fire_kick_offset_z", 0.05, 0.05)
	tween.tween_property(self, "_fire_kick_offset_z", 0.0, 0.1)

func _pump_action() -> void:
	if current_ammo <= 0:
		return
	var tween := get_tree().create_tween()
	tween.tween_property(self, "_fire_kick_offset_z", 0.08, 0.12)
	tween.tween_property(self, "_fire_kick_offset_z", 0.0, 0.18)

func _trigger_muzzle_flash() -> void:
	if not muzzle_flash:
		return
	muzzle_flash.visible = true
	await get_tree().create_timer(0.06).timeout
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = false

func _play_empty_click() -> void:
	print("[Shotgun] *click* – leer!")

func force_reload() -> void:
	current_ammo = max_ammo
	emit_signal("ammo_changed", current_ammo, max_ammo)
	emit_signal("reloaded")
