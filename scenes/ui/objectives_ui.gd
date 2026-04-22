## Top-right objectives checklist.
## Listens to QuestManager and rebuilds whenever any quest changes state.
extends CanvasLayer


@onready var _list: VBoxContainer = %QuestList


func _ready() -> void:
	QuestManager.quest_state_changed.connect(_rebuild)
	_rebuild("", QuestManager.QuestState.INACTIVE)


func _rebuild(_id: String, _state: QuestManager.QuestState) -> void:
	for child in _list.get_children():
		child.queue_free()

	var all: Dictionary = QuestManager.get_all()
	for id: String in all:
		var entry: Dictionary = all[id]
		if entry["state"] == QuestManager.QuestState.INACTIVE:
			continue  # player hasn't discovered this quest yet

		var lbl := Label.new()
		var done: bool = entry["state"] == QuestManager.QuestState.COMPLETE
		lbl.text = ("✓  " if done else "○  ") + entry["title"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color",
			Color(0.55, 0.9, 0.55, 0.9) if done else Color(1.0, 0.88, 0.4, 1.0))
		_list.add_child(lbl)
