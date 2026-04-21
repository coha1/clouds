## Shows / hides the virtual touch controls via the top-right toggle button.
extends CanvasLayer


@onready var _controls: Control = %Controls
@onready var _btn: Button       = %ToggleBtn


func _ready() -> void:
	_btn.button_pressed = true
	_btn.toggled.connect(func(on: bool) -> void: _controls.visible = on)
	%InteractBtn.add_to_group("touch_interact_btn")
