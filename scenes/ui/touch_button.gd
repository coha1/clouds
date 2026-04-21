## A virtual hold-button for touchscreen.
## Fires Input.action_press while a finger is down inside the control rect,
## and Input.action_release when the finger lifts. Works with multi-touch.
extends Control
class_name TouchButton

@export var action: String = ""

var _touch_index: int = -1


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 \
				and get_global_rect().has_point(event.position):
			_touch_index = event.index
			if not action.is_empty():
				Input.action_press(action)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			if not action.is_empty():
				Input.action_release(action)
