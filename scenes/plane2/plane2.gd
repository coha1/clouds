extends RigidBody3D


# Speed -----------------------------------------------------------------------

@export_group("Speed")
@export var speed: float = 20.0
@export var speed_min: float = 5.0
@export var speed_max: float = 50.0
## How fast speed changes when throttle is held
@export var throttle_speed: float = 8.0

# Controls --------------------------------------------------------------------

@export_group("Controls")
@export var roll_speed: float = 1.9
@export var pitch_speed: float = 1.5
@export var yaw_speed: float = 1.25

# Aerodynamics ----------------------------------------------------------------

@export_group("Aerodynamics")
## How fast the travel direction steers toward the nose direction
@export var aero_correction: float = 1.5
## How strongly a banked wing curves the flight path sideways
@export var lift_factor: float = 0.6


## Actual travel direction — normalised. Banking gradually curves this sideways.
var _direction := Vector3.FORWARD


func _ready() -> void:
	_direction = -transform.basis.z
	add_to_group("player_plane")


func _physics_process(delta: float) -> void:
	var roll_input: float  = Input.get_axis("roll_left",     "roll_right")
	var pitch_input: float = Input.get_axis("pitch_forward", "pitch_back")
	var yaw_input: float   = Input.get_axis("yaw_left",      "yaw_right")
	var throttle: float    = Input.get_axis("throttle_down", "throttle_up")

	# Throttle — hold trigger to change speed
	speed = clampf(speed + throttle * throttle_speed * delta, speed_min, speed_max)

	# Rotate the plane's orientation
	transform.basis = transform.basis.rotated(transform.basis.z, -roll_input  * roll_speed  * delta)
	transform.basis = transform.basis.rotated(transform.basis.x,  pitch_input * pitch_speed * delta)
	transform.basis = transform.basis.rotated(transform.basis.y, -yaw_input   * yaw_speed   * delta)
	transform.basis = transform.basis.orthonormalized()

	# Aerodynamic correction: travel direction gradually chases the nose
	var nose := -transform.basis.z
	_direction = _direction.lerp(nose, aero_correction * delta).normalized()

	# Wing lift: when banked, the local up axis tilts sideways.
	# Its horizontal component is a lateral force that curves the flight path —
	# roll right → plane veers right, even before yaw catches up.
	var local_up := transform.basis.y
	var lift_lateral := Vector3(local_up.x, 0.0, local_up.z)
	if lift_lateral.length_squared() > 0.0001:
		_direction = (_direction + lift_lateral * lift_factor * delta).normalized()

	move_and_collide(_direction * speed * delta)
