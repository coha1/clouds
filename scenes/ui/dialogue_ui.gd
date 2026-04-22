## Fullscreen dialogue strip — call begin() to start a conversation.
## Interact key or the Continue button advances through lines.
## on_finished callback fires when the last line is dismissed.
extends CanvasLayer
class_name DialogueUI


@onready var _speaker_lbl:  Label  = %SpeakerLabel
@onready var _body_lbl:     Label  = %BodyLabel
@onready var _continue_btn: Button = %ContinueButton

var _lines:      Array[String] = []
var _index:      int = 0
var _on_finished: Callable


func _ready() -> void:
	add_to_group("dialogue_ui")
	_continue_btn.pressed.connect(_advance)
	hide()


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("interact"):
		_advance()


## Start dialogue. on_finished is called after the last line is dismissed.
func begin(speaker: String, lines: Array[String], on_finished: Callable) -> void:
	_speaker_lbl.text = speaker.to_upper()
	_lines            = lines
	_index            = 0
	_on_finished      = on_finished
	_refresh()
	show()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		hide()
		if _on_finished.is_valid():
			_on_finished.call()
	else:
		_refresh()


func _refresh() -> void:
	_body_lbl.text = _lines[_index] if _index < _lines.size() else ""
