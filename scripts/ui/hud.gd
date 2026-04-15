class_name HUD
extends CanvasLayer


var _plane = null  # Untyped — cross-scene reference resolved at runtime
var _speed_label: Label
var _altitude_label: Label
var _delivery_status_label: Label
var _stall_label: Label


func _ready() -> void:
	_speed_label = %SpeedLabel
	_altitude_label = %AltitudeLabel
	_delivery_status_label = %DeliveryStatusLabel
	_stall_label = %StallLabel
	_stall_label.visible = false
	print(get_path(), ": ready")


func assign_plane(plane) -> void:
	_plane = plane


func show_delivery_status(text: String) -> void:
	_delivery_status_label.text = text


func _process(_delta: float) -> void:
	if not _plane:
		return

	var speed_kmh: float = _plane.current_speed * 3.6
	_speed_label.text = "SPD  %d km/h" % int(speed_kmh)
	_altitude_label.text = "ALT  %d m" % int(_plane.global_position.y)
	_stall_label.visible = _plane._is_stalling
