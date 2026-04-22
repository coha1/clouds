## Reusable landing zone. Place in the world and orient so the zone's +Z axis
## faces the direction planes approach from.
##
## Quest setup (set in the Inspector per instance):
##   - Giver zone:       quest_id set, is_quest_destination = false
##   - Destination zone: same quest_id, is_quest_destination = true
##                       (add a Waypoint child with the same quest_id)
##
## States:  IDLE → LANDING → LANDED → TAKING_OFF → IDLE
extends Node3D


enum State { IDLE, LANDING, LANDED, TAKING_OFF }

# ── NPC ───────────────────────────────────────────────────────────────────────
@export_group("NPC")
@export var npc_name: String = "Stranger"
@export var dialogue_lines: Array[String] = ["Line 1", "Line 2", "Line 3"]

# ── Quest ─────────────────────────────────────────────────────────────────────
@export_group("Quest")
## Must match on both the giver zone and the destination zone.
@export var quest_id: String = ""
@export var quest_title: String = "Delivery"
@export var quest_description: String = "Fly to the destination airstrip."
## True on the destination zone; false on the giver zone.
@export var is_quest_destination: bool = false

# ── Scene refs ────────────────────────────────────────────────────────────────
@onready var _trigger:  Area3D   = $TriggerArea
@onready var _approach: Marker3D = $ApproachPoint
@onready var _landing:  Marker3D = $LandingPoint

var _state: State = State.IDLE
var _plane: RigidBody3D
var _tween: Tween

const PROMPT_GROUP       := "land_prompt_label"
const INTERACT_BTN_GROUP := "touch_interact_btn"


func _ready() -> void:
	_trigger.body_entered.connect(_on_body_entered)
	_trigger.body_exited.connect(_on_body_exited)
	# Giver zones register the quest so QuestManager knows about it.
	if not quest_id.is_empty() and not is_quest_destination:
		QuestManager.register_quest(quest_id, quest_title, quest_description)


func _process(_delta: float) -> void:
	# Only the IDLE state is handled here; LANDED is handled by LandingMenu.
	if _state == State.IDLE and _plane and Input.is_action_just_pressed("interact"):
		_begin_landing()


# ── Trigger ───────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player_plane") and _state == State.IDLE:
		_plane = body as RigidBody3D
		_show_prompt("[ SPACE ]  LAND")


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player_plane") and _state == State.IDLE:
		_plane = null
		_hide_prompt()


# ── Landing sequence ──────────────────────────────────────────────────────────

func _begin_landing() -> void:
	_state = State.LANDING
	_hide_prompt()
	_plane.autopilot = true

	var app_pos  := _approach.global_position
	var land_pos := _landing.global_position

	var app_tfm := Transform3D(
		Basis.looking_at((land_pos - app_pos).normalized(), Vector3.UP), app_pos)
	var land_tfm := Transform3D(
		Basis.looking_at(-global_transform.basis.z, Vector3.UP), land_pos)

	if _tween:
		_tween.kill()
	_tween = create_tween()

	var dist := _plane.global_position.distance_to(app_pos)
	var from1 := _plane.global_transform
	_tween.tween_method(
		func(t: float) -> void:
			if _plane: _plane.global_transform = from1.interpolate_with(app_tfm, t),
		0.0, 1.0, maxf(2.0, dist / 25.0)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween.tween_method(
		func(t: float) -> void:
			if _plane: _plane.global_transform = app_tfm.interpolate_with(land_tfm, t),
		0.0, 1.0, 3.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_tween.tween_callback(_on_landed)


func _on_landed() -> void:
	_state = State.LANDED
	_open_landing_menu()


# ── Landing menu / dialogue ───────────────────────────────────────────────────

func _open_landing_menu() -> void:
	var menus := get_tree().get_nodes_in_group("landing_menu")
	if not menus.is_empty():
		(menus[0] as LandingMenu).show_for(self, npc_name)


## Called by LandingMenu when the player presses TALK.
func _on_talk_pressed() -> void:
	var dialogues := get_tree().get_nodes_in_group("dialogue_ui")
	if dialogues.is_empty():
		return
	(dialogues[0] as DialogueUI).begin(npc_name, dialogue_lines, _on_dialogue_finished)


func _on_dialogue_finished() -> void:
	# Advance the quest if conditions are met.
	if not quest_id.is_empty():
		if is_quest_destination \
				and QuestManager.get_state(quest_id) == QuestManager.QuestState.ACTIVE:
			QuestManager.complete(quest_id)
		elif not is_quest_destination \
				and QuestManager.get_state(quest_id) == QuestManager.QuestState.INACTIVE:
			QuestManager.activate(quest_id)
	# Return to the landing menu so the player can LEAVE when ready.
	_open_landing_menu()


# ── Takeoff sequence (called by LandingMenu via LEAVE, or _begin_takeoff directly) ──

func _begin_takeoff() -> void:
	_state = State.TAKING_OFF

	var app_pos  := _approach.global_position
	var land_pos := _landing.global_position

	var up_dir    := (app_pos - land_pos).normalized()
	var app_tfm   := Transform3D(Basis.looking_at(up_dir, Vector3.UP), app_pos)
	var land_tfm  := Transform3D(Basis.looking_at(up_dir, Vector3.UP), land_pos)
	var depart_pos := app_pos + up_dir * 40.0 + Vector3.UP * 15.0
	var depart_tfm := Transform3D(app_tfm.basis, depart_pos)

	if _tween:
		_tween.kill()
	_tween = create_tween()

	_tween.tween_method(
		func(t: float) -> void:
			if _plane: _plane.global_transform = land_tfm.interpolate_with(app_tfm, t),
		0.0, 1.0, 2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween.tween_method(
		func(t: float) -> void:
			if _plane: _plane.global_transform = app_tfm.interpolate_with(depart_tfm, t),
		0.0, 1.0, 1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween.tween_callback(_on_airborne)


func _on_airborne() -> void:
	if _plane:
		_plane._direction = -_plane.global_transform.basis.z
		_plane._av_roll   = 0.0
		_plane._av_pitch  = 0.0
		_plane._av_yaw    = 0.0
		_plane.autopilot  = false
	_plane = null
	_state = State.IDLE


# ── UI helpers ────────────────────────────────────────────────────────────────

func _show_prompt(text: String) -> void:
	for node: Node in get_tree().get_nodes_in_group(PROMPT_GROUP):
		(node as Label).text = text
		node.visible = true
	for btn: Node in get_tree().get_nodes_in_group(INTERACT_BTN_GROUP):
		btn.visible = true
		var lbl := btn.get_node_or_null("Label") as Label
		if lbl:
			lbl.text = text.replace("[ SPACE ]  ", "")


func _hide_prompt() -> void:
	for node: Node in get_tree().get_nodes_in_group(PROMPT_GROUP):
		node.visible = false
	for btn: Node in get_tree().get_nodes_in_group(INTERACT_BTN_GROUP):
		btn.visible = false
