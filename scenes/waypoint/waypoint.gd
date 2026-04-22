## World-space beacon. Visible only while its quest is ACTIVE.
## Place as a child of (or near) the destination landing zone in the editor.
extends Node3D


@export var quest_id: String = ""
@export var label_text: String = "DESTINATION"

@onready var _label: Label3D = $BeaconLabel

var _spin_speed: float = 1.2


func _ready() -> void:
	QuestManager.quest_state_changed.connect(_on_quest_changed)
	_refresh()


func _process(delta: float) -> void:
	if visible:
		rotate_y(delta * _spin_speed)


func _on_quest_changed(_id: String, _state: QuestManager.QuestState) -> void:
	_refresh()


func _refresh() -> void:
	visible = QuestManager.get_state(quest_id) == QuestManager.QuestState.ACTIVE
	if is_instance_valid(_label):
		_label.text = label_text
