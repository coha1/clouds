class_name CompletionUI
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


func show_completion(item_name: String, to_name: String, completion_text: String) -> void:
	_header_label.text = "Delivered!"
	_body_label.text = "%s delivered to %s.\n\n\"%s\"" % [item_name.capitalize(), to_name, completion_text]
	_panel.visible = true
	_dismiss_timer.start(5.0)


func _on_dismiss_timer_timeout() -> void:
	_panel.visible = false
