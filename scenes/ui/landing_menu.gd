## Talk / Leave menu — shown automatically when the plane parks at a landing zone.
## Landing zones find this via the "landing_menu" group and call show_for().
extends CanvasLayer
class_name LandingMenu


@onready var _name_label: Label  = %NpcNameLabel
@onready var _talk_btn:   Button = %TalkButton
@onready var _leave_btn:  Button = %LeaveButton

## The landing zone that opened this menu.
var _zone: Node = null


func _ready() -> void:
	add_to_group("landing_menu")
	_talk_btn.pressed.connect(_on_talk)
	_leave_btn.pressed.connect(_on_leave)
	hide()


func _process(_delta: float) -> void:
	# Interact shortcut = TALK when the menu is open (hidden during dialogue,
	# so no conflict with dialogue_ui which also listens to interact).
	if visible and Input.is_action_just_pressed("interact"):
		_on_talk()


## Called by the landing zone to open this menu for a given NPC.
func show_for(zone: Node, npc_name: String) -> void:
	_zone = zone
	_name_label.text = npc_name.to_upper()
	show()


func _on_talk() -> void:
	if not is_instance_valid(_zone):
		return
	hide()
	_zone._on_talk_pressed()


func _on_leave() -> void:
	if not is_instance_valid(_zone):
		return
	hide()
	_zone._begin_takeoff()
