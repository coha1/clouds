## Singleton — tracks all quest states and notifies listeners.
## Landing zones register their quests here on scene load.
extends Node


enum QuestState { INACTIVE, ACTIVE, COMPLETE }

## Emitted whenever a quest changes state. Wire objectives UI / waypoints here.
signal quest_state_changed(quest_id: String, state: QuestState)

## { quest_id: { title, description, state } }
var _quests: Dictionary = {}


func register_quest(id: String, title: String, description: String) -> void:
	if id not in _quests:
		_quests[id] = { "title": title, "description": description, "state": QuestState.INACTIVE }


func activate(id: String) -> void:
	if id in _quests and _quests[id]["state"] == QuestState.INACTIVE:
		_quests[id]["state"] = QuestState.ACTIVE
		quest_state_changed.emit(id, QuestState.ACTIVE)


func complete(id: String) -> void:
	if id in _quests and _quests[id]["state"] == QuestState.ACTIVE:
		_quests[id]["state"] = QuestState.COMPLETE
		quest_state_changed.emit(id, QuestState.COMPLETE)


func get_state(id: String) -> QuestState:
	return _quests.get(id, {}).get("state", QuestState.INACTIVE)


func get_all() -> Dictionary:
	return _quests
