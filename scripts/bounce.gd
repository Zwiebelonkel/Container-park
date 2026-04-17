extends Node3D

# -------------------------
# 🔼 Bounce Einstellungen
# -------------------------
@export var auto_bounce: bool = true
@export var bounce_height: float = 0.5
@export var bounce_speed: float = 2.0

# -------------------------
# 💥 Impuls (Lowrider-Hop)
# -------------------------
@export var enable_impulse: bool = true
@export var jump_force: float = 3.0
@export var gravity: float = 9.8
@export var damping: float = 0.92

# -------------------------
# 🔄 Rotation Einstellungen
# -------------------------
@export var enable_rotation: bool = true

@export var rotate_x: bool = true
@export var rotate_y: bool = false
@export var rotate_z: bool = false

@export var rot_strength_x: float = 6.0
@export var rot_strength_y: float = 2.0
@export var rot_strength_z: float = 4.0

# leichte Verzögerung für realistischen Look
@export var rotation_delay: float = 0.5

# -------------------------
# Intern
# -------------------------
var _time := 0.0
var _start_y := 0.0
var _start_rot := Vector3.ZERO

var _velocity := 0.0
var _offset_impulse := 0.0

# -------------------------
# Ready
# -------------------------
func _ready() -> void:
	_start_y = global_position.y
	_start_rot = rotation_degrees

# -------------------------
# Loop
# -------------------------
func _process(delta: float) -> void:
	_time += delta * bounce_speed

	var wave := sin(_time)
	var wave_delayed := sin(_time + rotation_delay)
	var wave_y := sin(_time * 0.6)

	# -------------------------
	# 💥 Impuls Trigger
	# -------------------------
	if enable_impulse and Input.is_action_just_pressed("ui_accept"):
		_velocity = jump_force

	# Physik für Impuls
	if enable_impulse:
		_velocity -= gravity * delta
		_velocity *= damping
		_offset_impulse += _velocity * delta

		# Bodenlimit
		if _start_y + _offset_impulse < _start_y:
			_offset_impulse = 0.0
			_velocity = 0.0

	# -------------------------
	# 🔼 Position
	# -------------------------
	var pos := global_position

	var auto_offset := 0.0
	if auto_bounce:
		auto_offset = wave * bounce_height

	pos.y = _start_y + auto_offset + _offset_impulse
	global_position = pos

	# -------------------------
	# 🔄 Rotation
	# -------------------------
	if enable_rotation:
		var rot := _start_rot

		if rotate_x:
			rot.x += wave_delayed * rot_strength_x

		if rotate_y:
			rot.y += wave_y * rot_strength_y

		if rotate_z:
			rot.z += wave * rot_strength_z

		rotation_degrees = rot
