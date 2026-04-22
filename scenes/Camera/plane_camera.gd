## Chase camera — follows the plane's roll, pitch, and yaw.
## Default: sits behind and above the plane; look_at uses the plane's own up
## so the horizon tilts with rolls.
## Right stick: orbits the camera around the plane and auto-returns to behind.
extends Camera3D
class_name PlaneCamera


@export var follow_distance: float = 10.0  ## Meters behind the plane (local +Z)
@export var follow_height: float = 5.5     ## Meters above the plane (local +Y)
@export var smooth: float = 6.0            ## Position lerp speed

@export_group("Camera Look (right stick)")
@export var cam_look_speed: float = 2.0    ## Orbit speed in rad/s
@export var cam_return_speed: float = 3.0  ## Auto-return speed when stick released


var target: Node3D

var _cam_yaw: float = 0.0    # accumulated orbit angle around plane's local Y
var _cam_pitch: float = 0.0  # accumulated orbit angle around plane's local X


func _ready() -> void:
	if target != null:
		return
	await get_tree().process_frame
	var planes := get_tree().get_nodes_in_group("player_plane")
	if planes.is_empty():
		printerr(get_path(), ": No node in group 'player_plane' and no target assigned")
		return
	target = planes[0]


func _physics_process(delta: float) -> void:
	if not target:
		return
	_update_look(delta)
	_follow(delta)


func _update_look(delta: float) -> void:
	var look_x := Input.get_axis("camera_look_left", "camera_look_right")
	var look_y := Input.get_axis("camera_look_up",   "camera_look_down")

	if absf(look_x) > 0.05:
		_cam_yaw -= look_x * cam_look_speed * delta
	else:
		_cam_yaw = lerpf(_cam_yaw, 0.0, cam_return_speed * delta)

	if absf(look_y) > 0.05:
		_cam_pitch += look_y * cam_look_speed * delta
		_cam_pitch = clampf(_cam_pitch, -0.5, 0.8)
	else:
		_cam_pitch = lerpf(_cam_pitch, 0.0, cam_return_speed * delta)


func _follow(delta: float) -> void:
	# Rotate the base offset (behind + above) by the camera-look angles.
	# Rotations are in the plane's LOCAL space so the orbit stays relative
	# to the plane regardless of its world orientation.
	var yaw_rot   := Basis(Vector3.UP,    _cam_yaw)
	var pitch_rot := Basis(Vector3.RIGHT, _cam_pitch)
	var local_offset := yaw_rot * pitch_rot * Vector3(0.0, follow_height, follow_distance)

	# Transform local offset into world space via the plane's transform
	var desired_pos: Vector3 = target.global_transform * local_offset
	global_position = global_position.lerp(desired_pos, smooth * delta)

	# Look at a point just above the plane's origin.
	# Passing the plane's own up vector makes the camera's horizon tilt with rolls.
	var plane_up := target.global_transform.basis.y
	var look_pos := target.global_position + plane_up * 1.5
	if (look_pos - global_position).length_squared() > 0.001:
		look_at(look_pos, plane_up)
