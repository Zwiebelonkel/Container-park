## Shotgun.gd
## Hänge dieses Script an einen Node3D namens "Shotgun" unter der Camera3D.
##
## Node-Struktur:
##   Camera3D
##     └── Shotgun (Node3D)  ← dieses Script
##          ├── MeshInstance3D        (Waffenmodell)
##          ├── MuzzleFlash (OmniLight3D, default invisible)
##          ├── ShellEject (GPUParticles3D, optional)
##          └── RayCast3D             (für Hitscan, falls kein Pellet-Raycast)

extends Node3D

# ─── Signale ───────────────────────────────────────────────────────────────────
signal fired(hit_nodes: Array)
signal reloaded()
signal ammo_changed(current: int, max_ammo: int)

# ─── Konfiguration ─────────────────────────────────────────────────────────────
@export var max_ammo: int = 6
@export var pellet_count: int = 8           # Schrotkugeln pro Schuss
@export var spread_degrees: float = 4.5     # Streuung in Grad
@export var fire_range: float = 25.0        # Maximale Reichweite (Meter)
@export var reload_time: float = 0.9        # Sekunden zum Nachladen (Pump-Action)
@export var fire_rate: float = 1.1          # Sekunden zwischen Schüssen (mind.)

# Recoil
@export var recoil_kick_up: float = 4.5     # Grad nach oben
@export var recoil_kick_side: float = 0.6   # Grad seitlich (zufällig)
@export var recoil_recover_speed: float = 6.0

# ─── Node-Refs ─────────────────────────────────────────────────────────────────
@onready var muzzle_flash: OmniLight3D = $MuzzleFlash
@onready var camera: Camera3D = get_parent() as Camera3D

# ─── State ─────────────────────────────────────────────────────────────────────
var current_ammo: int = max_ammo
var _can_fire: bool = true
var _is_reloading: bool = false
var _recoil_current: Vector2 = Vector2.ZERO
var _recoil_target: Vector2 = Vector2.ZERO
var _weapon_base_position: Vector3
var _weapon_base_rotation: Vector3

func _ready() -> void:
	# Falls get_parent() keine Camera3D ist, im Baum suchen
	if not camera:
		camera = get_viewport().get_camera_3d()
	_weapon_base_position = position
	_weapon_base_rotation = rotation_degrees
	if muzzle_flash:
		muzzle_flash.visible = false
	emit_signal("ammo_changed", current_ammo, max_ammo)

func _process(delta: float) -> void:
	_update_recoil(delta)
	_update_weapon_sway(delta)

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton):
		return
	if event.is_action_pressed("fire") and _can_fire and not _is_reloading:
		if current_ammo > 0:
			_fire()
		else:
			_play_empty_click()

# ─── Schießen ──────────────────────────────────────────────────────────────────
func _fire() -> void:
	_can_fire = false
	current_ammo -= 1
	emit_signal("ammo_changed", current_ammo, max_ammo)

	# Pellets abfeuern (Raycast pro Schrotkugel)
	var hit_nodes: Array = []
	var space_state := get_viewport().get_camera_3d().get_world_3d().direct_space_state

	for i in pellet_count:
		var hit := _cast_pellet(space_state)
		if hit and hit not in hit_nodes:
			hit_nodes.append(hit)

	emit_signal("fired", hit_nodes)

	# Effekte
	_trigger_muzzle_flash()
	_apply_recoil()
	_play_fire_animation()

	# Fire-Rate Cooldown → dann Pump-Action
	await get_tree().create_timer(fire_rate * 0.2).timeout
	_pump_action()
	await get_tree().create_timer(fire_rate * 0.8).timeout
	_can_fire = true

func _cast_pellet(space_state: PhysicsDirectSpaceState3D) -> Node:
	if not camera:
		return null

	# Streuung berechnen
	var spread_rad := deg_to_rad(spread_degrees)
	var spread_dir := Vector3(
		randf_range(-spread_rad, spread_rad),
		randf_range(-spread_rad, spread_rad),
		0.0
	)

	var cam_basis := camera.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	var up := cam_basis.y

	var direction := (forward + right * spread_dir.x + up * spread_dir.y).normalized()

	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * fire_range)
	query.collide_with_areas = true

	var result := space_state.intersect_ray(query)
	if result and result.has("collider"):
		return result["collider"]
	return null

# ─── Recoil ────────────────────────────────────────────────────────────────────
func _apply_recoil() -> void:
	_recoil_target.y += recoil_kick_up
	_recoil_target.x += randf_range(-recoil_kick_side, recoil_kick_side)

func _update_recoil(delta: float) -> void:
	if not camera:
		return
	# Smooth zum Target
	_recoil_current = _recoil_current.lerp(_recoil_target, delta * recoil_recover_speed * 0.4)
	# Target zurück zu 0
	_recoil_target = _recoil_target.lerp(Vector2.ZERO, delta * recoil_recover_speed)

	# Kamera-Rotation anwenden
	camera.rotation_degrees.x -= _recoil_current.y * delta * 60.0
	camera.rotation_degrees.y += _recoil_current.x * delta * 30.0

# ─── Weapon Sway (Bewegungs-Schaukeln) ────────────────────────────────────────
var _sway_time: float = 0.0
func _update_weapon_sway(delta: float) -> void:
	_sway_time += delta
	var sway_x := sin(_sway_time * 1.4) * 0.003
	var sway_y := sin(_sway_time * 2.1) * 0.002
	position = _weapon_base_position + Vector3(sway_x, sway_y, 0.0)

# ─── Fire Animation (Kick nach vorne/hinten) ──────────────────────────────────
func _play_fire_animation() -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(self, "position:z", _weapon_base_position.z + 0.05, 0.05)
	tween.tween_property(self, "position:z", _weapon_base_position.z, 0.1)

# ─── Pump-Action Animation ─────────────────────────────────────────────────────
func _pump_action() -> void:
	if current_ammo <= 0:
		return
	var tween := get_tree().create_tween()
	# Waffe kurz nach hinten → dann zurück
	tween.tween_property(self, "position:z", _weapon_base_position.z + 0.08, 0.12)
	tween.tween_property(self, "position:z", _weapon_base_position.z, 0.18)

# ─── Muzzle Flash ─────────────────────────────────────────────────────────────
func _trigger_muzzle_flash() -> void:
	if not muzzle_flash:
		return
	muzzle_flash.visible = true
	await get_tree().create_timer(0.06).timeout
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = false

# ─── Leer-Click ───────────────────────────────────────────────────────────────
func _play_empty_click() -> void:
	# Hier AudioStreamPlayer3D.play() mit "empty_click.wav"
	print("[Shotgun] *click* – leer!")

# ─── Öffentliche API ──────────────────────────────────────────────────────────
func force_reload() -> void:
	current_ammo = max_ammo
	emit_signal("ammo_changed", current_ammo, max_ammo)
	emit_signal("reloaded")
