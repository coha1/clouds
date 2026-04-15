class_name DeliveryUI
extends CanvasLayer


var _panel: PanelContainer
var _header_label: Label
var _body_label: Label
var _dismiss_timer: Timer


func _ready() -> void:
	_panel = %Panel
	_header_label = %HeaderLabel
	_body_label = %BodyLabel

	_dismiss_timer = Timer.new()
	_dismiss_timer.one_shot = true
	_dismiss_timer.timeout.connect(_on_dismiss_timer_timeout)
	add_child(_dismiss_timer)

	_panel.visible = false
	print(get_path(), ": ready")


func show_new_delivery(from_name: String, to_name: String, item_name: String, request_text: String) -> void:
	_header_label.text = "New Delivery"
	_body_label.text = "%s\n\n%s  →  %s\n[%s]" % [request_text, from_name, to_name, item_name]
	_panel.visible = true
	_dismiss_timer.start(5.0)


func show_pickup(item_name: String, to_name: String) -> void:
	_header_label.text = "Package Picked Up"
	_body_label.text = "Deliver the %s to %s." % [item_name, to_name]
	_panel.visible = true
	_dismiss_timer.start(3.5)


func _on_dismiss_timer_timeout() -> void:
	_panel.visible = false
