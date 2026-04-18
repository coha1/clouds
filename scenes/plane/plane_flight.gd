## Arcade flight model adapted from kidscancode.org/godot_recipes (Godot 4.6).
## The plane always flies forward at current_speed.
## Pitch rotates around the plane's own X axis (nose up/down).
## Turning rotates around world Y (yaw), while PlaneMesh banks visually.
extends CharacterBody3D
class_name PlaneFlight


# Speed -----------------------------------------------------------------------

@export_group("Speed")
## Hard lower bound — throttle cannot go below this
@export var speed_min: float = 10.0
## Hard upper bound
@export var speed_max: float = 50.0
## Starting speed in m/s
@export var speed_initial: float = 22.0
## How quickly throttle input changes target speed (m/s per second)
@export var throttle_delta: float = 28.0
## How fast actual speed closes on target speed (lerp coefficient)
@export var acceleration: float = 3.5

# Control Feel ----------------------------------------------------------------

@export_group("Control Feel")
## Yaw rotation rate in rad/s
@export var turn_speed: float = 0.90
## Pitch rotation rate in rad/s
@export var pitch_speed: float = 0.65
## Peak visual bank angle in radians (~40°) — PlaneMesh only, not the physics body
@export var bank_angle_max: float = 0.70
## How quickly the visual bank reaches target and levels out
@export var bank_speed: float = 3.5


# Public state — read by HUD and camera ---------------------------------------

## Current airspeed in m/s
var current_speed: float = 0.0
## Current visual bank angle in radians — read by PlaneCamera for subtle tilt
var current_bank: float = 0.0


# Private ---------------------------------------------------------------------

var _target_speed: float = 0.0
var _turn_input: float = 0.0
var _pitch_input: float = 0.0
var _plane_mesh: Node3D  # visual pivot — banks without affecting physics body


func _ready() -> void:
	current_speed = speed_initial
	_target_speed = speed_initial
	_plane_mesh = $PlaneMesh
	add_to_group("player_plane")


func _physics_process(delta: float) -> void:
	_get_input(delta)
	_rotate_plane(delta)
	_bank_mesh(delta)

	# Speed lerps toward throttle target
	current_speed = lerpf(current_speed, _target_speed, acceleration * delta)

	# Velocity is always along the nose — forward is -Z in Godot's convention
	velocity = -transform.basis.z * current_speed
	move_and_slide()


func _get_input(delta: float) -> void:
	# Throttle — hold to accelerate / decelerate
	if Input.is_action_pressed("throttle_up"):
		_target_speed = minf(_target_speed + throttle_delta * delta, speed_max)
	if Input.is_action_pressed("throttle_down"):
		_target_speed = maxf(_target_speed - throttle_delta * delta, speed_min)

	# get_axis(negative, positive) → -1 … +1
	# roll_right (D) is the negative action so D → turn right ← correct
	_turn_input  = Input.get_axis("roll_right", "roll_left")
	# pitch_forward (W) is negative so W → negative pitch → nose down ← correct
	_pitch_input = Input.get_axis("pitch_forward", "pitch_back")


func _rotate_plane(delta: float) -> void:
	# Pitch around the plane's own X axis (local space)
	transform.basis = transform.basis.rotated(
		transform.basis.x, _pitch_input * pitch_speed * delta)

	# Yaw around world UP — keeps turns flat and readable
	transform.basis = transform.basis.rotated(
		Vector3.UP, _turn_input * turn_speed * delta)

	transform.basis = transform.basis.orthonormalized()


func _bank_mesh(delta: float) -> void:
	# Lerp the visual mesh into a banked lean; auto-levels when input released.
	# Negative turn_input means right turn → positive Z rotation → right wing dips.
	var target_bank: float = -_turn_input * bank_angle_max
	current_bank = lerpf(current_bank, target_bank, bank_speed * delta)
	_plane_mesh.rotation.z = current_bank
