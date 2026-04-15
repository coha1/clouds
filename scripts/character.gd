class_name Character
extends StaticBody3D


## Displayed name of this character
@export var character_name: String = "Unknown"

## Short line of dialogue shown when a delivery is available or completed
@export var flavor_text: String = ""

## Which island this character lives on (used in UI hints)
@export var island_name: String = ""


signal player_entered(character: Character)

signal player_exited(character: Character)


func _ready() -> void:
	add_to_group("characters")
	_build_mesh()
	_build_trigger_area()
	_build_name_label()
	print(get_path(), ": ready — ", character_name, " on ", island_name)


func _build_mesh() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"

	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.72, 0.55)
	capsule.surface_set_material(0, mat)

	mesh_instance.mesh = capsule
	mesh_instance.position = Vector3(0.0, 0.9, 0.0)
	add_child(mesh_instance)

	# Collision shape for StaticBody3D
	var col := CollisionShape3D.new()
	col.name = "CollisionShape"
	var col_shape := CapsuleShape3D.new()
	col_shape.radius = 0.4
	col_shape.height = 1.8
	col.shape = col_shape
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)


func _build_trigger_area() -> void:
	var area := Area3D.new()
	area.name = "TriggerArea"
	area.collision_layer = 0  # area has no physical surface
	area.collision_mask = 1   # detect bodies on default layer (where the plane lives)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 35.0
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)

	area.body_entered.connect(_on_trigger_body_entered)
	area.body_exited.connect(_on_trigger_body_exited)


func _build_name_label() -> void:
	var label_3d := Label3D.new()
	label_3d.name = "NameLabel"
	label_3d.text = character_name
	label_3d.position = Vector3(0.0, 2.2, 0.0)
	label_3d.pixel_size = 0.01
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.modulate = Color(1.0, 1.0, 0.8)
	add_child(label_3d)


func _on_trigger_body_entered(body: Node3D) -> void:
	if body.is_in_group("player_plane"):
		player_entered.emit(self)


func _on_trigger_body_exited(body: Node3D) -> void:
	if body.is_in_group("player_plane"):
		player_exited.emit(self)
