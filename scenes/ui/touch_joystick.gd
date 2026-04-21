## Virtual joystick for touchscreen.
## Attach to any Control node that acts as the touch zone.
## Requires a child named "Knob" (the moveable dot).
## Set action exports to drive any pair of InputActions on each axis.
extends Control
class_name TouchJoystick

@export var action_negative_x: String = ""
@export var action_positive_x: String = ""
@export var action_negative_y: String = ""
@export var action_positive_y: String = ""
@export var deadzone: float = 0.15

@onready var _knob: Control = $Knob

var _touch_index: int = -1
var _center: Vector2   ## fixed centre of the joystick in local coords
var _radius: float     ## max knob travel in pixels


func _ready() -> void:
	# Wait one frame so anchored layout has resolved before reading size.
	await get_tree().process_frame
	_center = size * 0.5
	_radius = _center.x - _knob.size.x * 0.5
	_reset_knob()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 \
				and get_global_rect().has_point(event.position):
			_touch_index = event.index
			_apply(_to_local(event.position))
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_reset_knob()
			_release_all()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_apply(_to_local(event.position))


func _apply(local: Vector2) -> void:
	var offset := (local - _center).limit_length(_radius)
	_knob.position = _center + offset - _knob.size * 0.5
	_drive_axis(action_negative_x, action_positive_x, offset.x / _radius)
	_drive_axis(action_negative_y, action_positive_y, offset.y / _radius)


func _drive_axis(neg: String, pos: String, value: float) -> void:
	if neg.is_empty() or pos.is_empty():
		return
	if value < -deadzone:
		Input.action_press(neg, -value)
		Input.action_release(pos)
	elif value > deadzone:
		Input.action_press(pos, value)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _release_all() -> void:
	_drive_axis(action_negative_x, action_positive_x, 0.0)
	_drive_axis(action_negative_y, action_positive_y, 0.0)


func _reset_knob() -> void:
	if _knob:
		_knob.position = _center - _knob.size * 0.5


## Control nodes don't have to_local(); convert via the global rect origin.
func _to_local(screen_pos: Vector2) -> Vector2:
	return screen_pos - get_global_rect().position
