class_name CameraRig
extends Camera3D


## Distance behind the plane in meters
@export var follow_distance: float = 16.0

## Height above the plane in meters
@export var follow_height: float = 5.0

## Lower = more lag, higher = tighter follow (position)
@export var position_smooth_speed: float = 4.5

## How much the camera tilts with the plane's bank angle (0 = none, 1 = full)
@export var roll_tilt_factor: float = 0.3

## Assigned by Main after instancing. Untyped to avoid cross-scene cast limitations.
var target_plane = null

# Smoothed flat heading direction, updated each frame.
# Preserved during vertical climbs/dives so the camera doesn't spin.
var _smooth_behind_dir: Vector3 = Vector3(0.0, 0.0, 1.0)


func _process(delta: float) -> void:
	if not target_plane:
		return

	_follow_position(delta)
	_orient_toward_plane()


func _follow_position(delta: float) -> void:
	# Derive the flat (horizontal) heading from the plane's actual nose direction
	# so the camera follows where the plane is pointed, not a stored angle.
	var nose_dir: Vector3 = -target_plane.global_transform.basis.z
	var flat_nose: Vector3 = Vector3(nose_dir.x, 0.0, nose_dir.z)

	# Only update the smoothed direction when the plane isn't nearly vertical —
	# during a full loop the flat component goes to zero and we hold the last heading.
	if flat_nose.length_squared() > 0.04:
		var new_behind: Vector3 = -flat_nose.normalized()
		_smooth_behind_dir = _smooth_behind_dir.lerp(new_behind, 8.0 * delta).normalized()

	var plane_pos: Vector3 = target_plane.global_position
	var desired_pos: Vector3 = (
		plane_pos
		+ _smooth_behind_dir * follow_distance
		+ Vector3.UP * follow_height
	)

	global_position = global_position.lerp(desired_pos, position_smooth_speed * delta)


func _orient_toward_plane() -> void:
	var plane_pos: Vector3 = target_plane.global_position
	var look_target: Vector3 = plane_pos + Vector3.UP * 1.5

	# Guard against degenerate look_at when camera is directly above or below
	var look_dir: Vector3 = look_target - global_position
	if look_dir.length_squared() < 0.0001:
		return

	look_at(look_target, Vector3.UP)

	# Tilt using bank angle: how far the plane's local right deviates from world-horizontal.
	# This reads directly from the basis so it works at any pitch attitude.
	var local_right: Vector3 = target_plane.global_transform.basis.x
	var bank_tilt: float = local_right.dot(Vector3.UP) * roll_tilt_factor
	rotate_object_local(Vector3(0.0, 0.0, 1.0), -bank_tilt)
