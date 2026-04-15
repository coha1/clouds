class_name PlayerPlane
extends CharacterBody3D


# ── Speed ──────────────────────────────────────────────────────────────────

## Hard upper speed limit in m/s
@export var speed_max: float = 55.0

## Speed below which stall recovery torque kicks in
@export var speed_min: float = 8.0

## Starting airspeed in m/s
@export var speed_initial: float = 25.0

## Forward acceleration from full throttle in m/s²
@export var throttle_acceleration: float = 22.0

## Passive speed bleed with no throttle input in m/s²
@export var idle_drag: float = 0.5

## Speed change per second per unit of nose-up/down (m/s²)
## — climbing bleeds speed; diving gains it
@export var pitch_speed_influence: float = 8.0


# ── Angular control ────────────────────────────────────────────────────────

## Maximum pitch rotation rate in rad/s
@export var pitch_rate_max: float = 1.1

## Maximum roll rotation rate in rad/s
@export var roll_rate_max: float = 2.0

## How fast angular velocity reaches the input target (rad/s per second)
@export var angular_response: float = 5.0

## How fast angular velocity bleeds off after input is released
@export var angular_damping: float = 4.0

## Roll-to-yaw coupling fraction — gives banked turns their coordinated feel
@export var yaw_coupling: float = 0.35


# ── Lift and gravity ───────────────────────────────────────────────────────

## Gravitational acceleration in m/s²
@export var gravity_force: float = 14.0

## Airspeed at which wing lift exactly cancels gravity (level cruise speed)
@export var lift_reference_speed: float = 22.0

## How strongly forward airspeed suppresses accumulated drift.
## Higher values make the plane fly more "on-rails" along the nose direction.
@export var aerodynamic_correction: float = 3.0

## Nose-down torque applied automatically while below speed_min in rad/s²
@export var stall_recovery_torque: float = 2.0


signal pickup_area_entered(character: Node3D)

signal pickup_area_exited(character: Node3D)


var current_speed: float = 0.0

## Exposed for camera tilt — mirrors the current roll angular velocity
var current_roll: float = 0.0

var _is_stalling: bool = false

## Angular velocity in a mixed space: pitch/roll in local axes, yaw in world Y
var _angular_velocity: Vector3 = Vector3.ZERO

## Accumulated vertical velocity from gravity vs. lift (world Y only).
## Horizontal turns come entirely from yaw coupling, not from lift tilt.
var _ballistic_vy: float = 0.0


func _ready() -> void:
	current_speed = speed_initial
	add_to_group("player_plane")
	_setup_pickup_area()
	print(get_path(), ": ready, initial_speed=", current_speed)


func _physics_process(delta: float) -> void:
	# pitch_forward (W) = nose down = negative; pitch_back (S) = nose up = positive
	var pitch_input: float = Input.get_axis("pitch_forward", "pitch_back")
	var roll_input: float = Input.get_axis("roll_left", "roll_right")
	var throttle_input: float = Input.get_axis("throttle_down", "throttle_up")

	_update_angular_velocity(pitch_input, roll_input, delta)
	_update_speed(throttle_input, delta)
	_update_stall_state()
	_apply_stall_recovery_torque(delta)
	_rotate_plane(delta)
	_update_ballistic_vy(delta)
	_apply_velocity()


func _update_angular_velocity(pitch_input: float, roll_input: float, delta: float) -> void:
	# Pitch — positive x = nose up
	if abs(pitch_input) > 0.05:
		_angular_velocity.x = move_toward(
				_angular_velocity.x, pitch_input * pitch_rate_max, angular_response * delta)
	else:
		_angular_velocity.x = move_toward(_angular_velocity.x, 0.0, angular_damping * delta)

	# Roll — positive z = right wing down (roll right)
	if abs(roll_input) > 0.05:
		_angular_velocity.z = move_toward(
				_angular_velocity.z, roll_input * roll_rate_max, angular_response * delta)
	else:
		_angular_velocity.z = move_toward(_angular_velocity.z, 0.0, angular_damping * delta)

	# Coupled yaw around world Y — rolling right yaws right (negative world-Y rotation)
	_angular_velocity.y = -_angular_velocity.z * yaw_coupling

	current_roll = _angular_velocity.z


func _update_speed(throttle_input: float, delta: float) -> void:
	current_speed += throttle_input * throttle_acceleration * delta

	if abs(throttle_input) < 0.05:
		current_speed -= idle_drag * delta

	# Nose-up attitude bleeds airspeed; nose-down gains it
	var climb_component: float = -basis.z.y  # positive when nose points up
	current_speed -= climb_component * pitch_speed_influence * delta

	current_speed = clamp(current_speed, speed_min * 0.4, speed_max)


func _update_stall_state() -> void:
	var was_stalling: bool = _is_stalling
	_is_stalling = current_speed < speed_min

	if _is_stalling and not was_stalling:
		print(get_path(), ": stall at speed=", snappedf(current_speed, 0.1))
	elif not _is_stalling and was_stalling:
		print(get_path(), ": stall recovered, speed=", snappedf(current_speed, 0.1))


func _apply_stall_recovery_torque(delta: float) -> void:
	if not _is_stalling:
		return
	# Proportional nose-down push — strongest at zero speed
	var stall_fraction: float = 1.0 - (current_speed / speed_min)
	_angular_velocity.x -= stall_recovery_torque * stall_fraction * delta


func _rotate_plane(delta: float) -> void:
	var t: Transform3D = transform
	# Pitch and roll use local axes so loops and rolls work in any orientation.
	# FORWARD (−Z) is the roll axis: positive av.z rotates the right wingtip downward.
	# BACK (+Z) rotates the right wingtip upward, which is the wrong direction.
	t = t.rotated_local(Vector3.RIGHT, _angular_velocity.x * delta)
	t = t.rotated_local(Vector3.FORWARD, _angular_velocity.z * delta)
	# Yaw uses world Y so banking always changes world heading predictably
	t = t.rotated(Vector3.UP, _angular_velocity.y * delta)
	transform = Transform3D(t.basis.orthonormalized(), t.origin)


func _update_ballistic_vy(delta: float) -> void:
	# Net vertical acceleration: lift (always world-up) minus gravity.
	# At lift_reference_speed the two cancel so the plane holds altitude hands-off.
	# Below that speed the plane sinks; above it gains slight upward tendency.
	var speed_ratio: float = current_speed / lift_reference_speed
	var net_vert_accel: float = gravity_force * (speed_ratio * speed_ratio - 1.0)
	_ballistic_vy += net_vert_accel * delta

	# Aerodynamic correction bleeds residual vertical drift toward zero — the plane
	# naturally wants to fly along its nose direction rather than fall off.
	_ballistic_vy = move_toward(_ballistic_vy, 0.0, aerodynamic_correction * delta)

	_ballistic_vy = clamp(_ballistic_vy, -40.0, 15.0)


func _apply_velocity() -> void:
	# Horizontal motion is entirely from the nose direction (turned by yaw coupling).
	# Only the ballistic component contributes a vertical offset.
	velocity = -basis.z * current_speed + Vector3(0.0, _ballistic_vy, 0.0)
	move_and_slide()


func _setup_pickup_area() -> void:
	var area := Area3D.new()
	area.name = "PickupArea"
	add_child(area)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 30.0
	shape.shape = sphere
	area.add_child(shape)

	area.body_entered.connect(_on_pickup_area_body_entered)
	area.body_exited.connect(_on_pickup_area_body_exited)


func _on_pickup_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("characters"):
		pickup_area_entered.emit(body)


func _on_pickup_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("characters"):
		pickup_area_exited.emit(body)
