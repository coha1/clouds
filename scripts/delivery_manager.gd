class_name DeliveryManager
extends Node


signal delivery_assigned(from_name: String, to_name: String, item_name: String, request_text: String)

signal package_picked_up(item_name: String, to_name: String)

signal delivery_completed(item_name: String, to_name: String, completion_text: String)


var _deliveries: Array[Dictionary] = [
	{
		"from": "Marina",
		"to": "Finn",
		"item": "sealed bottle",
		"request": "Marina has a sealed bottle that needs to reach Finn at the Cove.",
		"completion": "Finn turns the bottle in his hands. \"The lighthouse keeper never forgets.\""
	},
	{
		"from": "Finn",
		"to": "Yuki",
		"item": "fresh catch",
		"request": "Finn wrapped up his best catch for Yuki up on the Mesa.",
		"completion": "Yuki doesn't look up from her charts. \"Set it there. Thank you.\""
	},
	{
		"from": "Yuki",
		"to": "Otto",
		"item": "wind chart",
		"request": "Yuki's annotated wind charts need to reach Otto in the Grove.",
		"completion": "Otto unfolds the chart carefully. \"She thinks of everything.\""
	},
	{
		"from": "Otto",
		"to": "Bea",
		"item": "grove honey",
		"request": "Otto has a jar of grove honey set aside for Bea.",
		"completion": "Bea pries the lid up and sniffs. She smiles — rare for her."
	},
	{
		"from": "Bea",
		"to": "Marina",
		"item": "mirror shard",
		"request": "Bea found a polished mirror shard that belongs to Marina.",
		"completion": "Marina holds the shard to the light. \"I wondered where this went.\""
	},
]

var _current_delivery_index: int = 0
var _holding_package: bool = false
var _active_delivery: Dictionary = {}

var _characters: Dictionary = {}  # character_name -> Character node


func _ready() -> void:
	# Characters register themselves via _on_character_ready; wait one frame
	await get_tree().process_frame
	_gather_characters()
	_assign_next_delivery()
	print(get_path(), ": ready, delivery count=", _deliveries.size())


func _gather_characters() -> void:
	for node in get_tree().get_nodes_in_group("characters"):
		if node is Character:
			_characters[node.character_name] = node
			node.player_entered.connect(_on_player_entered_character_area)
	print(get_path(), ": found characters=", _characters.keys())


func _assign_next_delivery() -> void:
	if _deliveries.is_empty():
		printerr(get_path(), ": no deliveries defined")
		return

	_active_delivery = _deliveries[_current_delivery_index]
	_holding_package = false

	delivery_assigned.emit(
		_active_delivery["from"],
		_active_delivery["to"],
		_active_delivery["item"],
		_active_delivery["request"]
	)

	print(get_path(), ": delivery assigned — ", _active_delivery["from"],
			" → ", _active_delivery["to"], " [", _active_delivery["item"], "]")


func _on_player_entered_character_area(character: Character) -> void:
	if _active_delivery.is_empty():
		return

	if not _holding_package and character.character_name == _active_delivery["from"]:
		_holding_package = true
		package_picked_up.emit(_active_delivery["item"], _active_delivery["to"])
		print(get_path(), ": picked up '", _active_delivery["item"], "' from ", character.character_name)
		return

	if _holding_package and character.character_name == _active_delivery["to"]:
		var completed := _active_delivery.duplicate()
		_current_delivery_index = (_current_delivery_index + 1) % _deliveries.size()
		_active_delivery = {}
		_holding_package = false

		delivery_completed.emit(
			completed["item"],
			completed["to"],
			completed["completion"]
		)

		print(get_path(), ": delivered '", completed["item"], "' to ", completed["to"])

		await get_tree().create_timer(3.5).timeout
		_assign_next_delivery()
