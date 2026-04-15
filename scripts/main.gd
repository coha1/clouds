class_name Main
extends Node3D


func _ready() -> void:
	# Cross-scene node references are untyped — GDScript resolves properties
	# via duck typing at runtime, which avoids the Node→custom-class cast limitation.
	var plane = %Plane
	var camera = %CameraRig
	var delivery_manager = %DeliveryManager
	var hud = %HUD
	var delivery_ui = %DeliveryUI
	var completion_ui = %CompletionUI

	camera.target_plane = plane
	hud.assign_plane(plane)

	delivery_manager.delivery_assigned.connect(_on_delivery_assigned.bind(hud, delivery_ui))
	delivery_manager.package_picked_up.connect(_on_package_picked_up.bind(hud, delivery_ui))
	delivery_manager.delivery_completed.connect(_on_delivery_completed.bind(hud, completion_ui))

	print(get_path(), ": all nodes wired")


func _on_delivery_assigned(
		from_name: String, to_name: String, item_name: String, request_text: String,
		hud, delivery_ui) -> void:
	hud.show_delivery_status("Pick up %s from %s" % [item_name, from_name])
	delivery_ui.show_new_delivery(from_name, to_name, item_name, request_text)


func _on_package_picked_up(item_name: String, to_name: String, hud, delivery_ui) -> void:
	hud.show_delivery_status("Deliver %s to %s" % [item_name, to_name])
	delivery_ui.show_pickup(item_name, to_name)


func _on_delivery_completed(
		item_name: String, to_name: String, completion_text: String,
		hud, completion_ui) -> void:
	hud.show_delivery_status("Looking for the next job...")
	completion_ui.show_completion(item_name, to_name, completion_text)
