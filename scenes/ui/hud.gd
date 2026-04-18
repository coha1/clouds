## Minimal flight HUD. Shows speed and altitude.
## Finds the plane via the "player_plane" group — works with any Node3D subclass.
extends CanvasLayer


@onready var speed_label: Label = %SpeedLabel
@onready var alt_label: Label = %AltLabel
@onready var stall_label: Label = %StallLabel


var _plane: Node3D


func _ready() -> void:
	stall_label.visible = false
	await get_tree().process_frame
	var planes := get_tree().get_nodes_in_group("player_plane")
	if planes.is_empty():
		printerr(get_path(), ": No node found in group 'player_plane'")
		return
	_plane = planes[0] as Node3D


func _process(_delta: float) -> void:
	if not _plane:
		return
	# plane2.gd exposes 'speed'; fall back to 'current_speed' for the old model
	var spd: float = 0.0
	if _plane.get("speed") != null:
		spd = _plane.speed
	elif _plane.get("current_speed") != null:
		spd = _plane.current_speed
	speed_label.text = "SPD  %d m/s" % roundi(spd)
	alt_label.text   = "ALT  %d m"   % roundi(_plane.global_position.y)
