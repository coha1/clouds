## Backup of plane2.gd before aerodynamics pass — restore if needed.
extends RigidBody3D


@export var speed: float = 10.0
@export var accel: float = 0.6
@export var roll_speed = 1.9
@export var pitch_speed = 1.5
@export var yaw_speed = 1.25

var velocity := Vector3.ZERO
var stick_vector := Vector2.ZERO
var deadzone: float = -1.0
var throttle: float
var roll_input: float
var pitch_input: float
var yaw_input: float


func _ready() -> void:
	add_to_group("player_plane")


func _physics_process(delta: float) -> void:
	roll_input = Input.get_axis("roll_left", "roll_right")
	pitch_input = Input.get_axis("pitch_forward", "pitch_back")
	yaw_input = Input.get_axis("yaw_left", "yaw_right")

	speed += Input.get_axis("throttle_down", "throttle_up") * 1.0 * delta

	transform.basis = transform.basis.rotated(transform.basis.z, -roll_input * roll_speed * delta)
	transform.basis = transform.basis.rotated(transform.basis.x, pitch_input * pitch_speed * delta)
	transform.basis = transform.basis.rotated(transform.basis.y, -yaw_input * yaw_speed * delta)
	transform.basis = transform.basis.orthonormalized()

	velocity = -transform.basis.z * speed

	move_and_collide(velocity * delta)
