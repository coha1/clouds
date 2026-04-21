## Reusable landing zone. Place in the world and orient so the zone's -Z axis
## faces the direction planes approach from. The ApproachPoint marker sits in
## front of the strip (local +Z, up in Y); LandingPoint is on the ground.
##
## States:  IDLE → LANDING → LANDED → TAKING_OFF → IDLE
##
## Communication with the HUD and touch controls is done via groups so this
## scene stays decoupled from the UI:
##   "land_prompt_label"   — Label nodes that show the current prompt text
##   "touch_interact_btn"  — Control nodes (the touch interact button)
extends Node3D


enum State { IDLE, LANDING, LANDED, TAKING_OFF }

const PROMPT_GROUP      := "land_prompt_label"
const INTERACT_BTN_GROUP := "touch_interact_btn"

@onready var _trigger:  Area3D  = $TriggerArea
@onready var _approach: Marker3D = $ApproachPoint
@onready var _landing:  Marker3D = $LandingPoint

var _state: State = State.IDLE
var _plane: RigidBody3D          ## non-null only while plane is in trigger range
var _tween: Tween


func _ready() -> void:
	_trigger.body_entered.connect(_on_body_entered)
	_trigger.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	match _state:
		State.IDLE:
			if _plane and Input.is_action_just_pressed("interact"):
				_begin_landing()
		State.LANDED:
			if Input.is_action_just_pressed("interact"):
				_begin_takeoff()


# ── Trigger callbacks ─────────────────────────────────────────────────────────

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

	# Approach transform: nose aimed from approach point down toward landing.
	var app_pos  := _approach.global_position
	var land_pos := _landing.global_position
	var app_tfm  := Transform3D(
		Basis.looking_at((land_pos - app_pos).normalized(), Vector3.UP),
		app_pos
	)

	# Landing transform: flat on the strip, facing down the runway.
	var land_tfm := Transform3D(
		Basis.looking_at(-global_transform.basis.z, Vector3.UP),
		land_pos
	)

	if _tween:
		_tween.kill()
	_tween = create_tween()

	# Phase 1 — fly to approach point (speed proportional to distance).
	var dist := _plane.global_position.distance_to(app_pos)
	var t1 := maxf(2.0, dist / 25.0)
	var from1 := _plane.global_transform
	_tween.tween_method(
		func(t: float) -> void:
			if _plane:
				_plane.global_transform = from1.interpolate_with(app_tfm, t),
		0.0, 1.0, t1
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Phase 2 — descend to the strip.
	_tween.tween_method(
		func(t: float) -> void:
			if _plane:
				_plane.global_transform = app_tfm.interpolate_with(land_tfm, t),
		0.0, 1.0, 3.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_tween.tween_callback(_on_landed)


func _on_landed() -> void:
	_state = State.LANDED
	_show_prompt("[ SPACE ]  TAKE OFF")


# ── Takeoff sequence ──────────────────────────────────────────────────────────

func _begin_takeoff() -> void:
	_state = State.TAKING_OFF
	_hide_prompt()

	var app_pos  := _approach.global_position
	var land_pos := _landing.global_position

	# Approach transform (reversed — nose now aimed away from landing).
	var app_tfm := Transform3D(
		Basis.looking_at((app_pos - land_pos).normalized(), Vector3.UP),
		app_pos
	)

	# Departure transform — continue beyond approach, gaining altitude.
	var depart_dir := (app_pos - land_pos).normalized()
	var depart_pos := app_pos + depart_dir * 40.0 + Vector3.UP * 15.0
	var depart_tfm := Transform3D(app_tfm.basis, depart_pos)

	var land_tfm := Transform3D(
		Basis.looking_at(-global_transform.basis.z, Vector3.UP),
		_landing.global_position
	)
	# Flip landing basis so nose aims toward approach (same as app_tfm direction).
	land_tfm.basis = Basis.looking_at((app_pos - land_pos).normalized(), Vector3.UP)

	if _tween:
		_tween.kill()
	_tween = create_tween()

	# Phase 1 — accelerate up to approach point.
	_tween.tween_method(
		func(t: float) -> void:
			if _plane:
				_plane.global_transform = land_tfm.interpolate_with(app_tfm, t),
		0.0, 1.0, 2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Phase 2 — climb away; ease in for smooth hand-off to player.
	_tween.tween_method(
		func(t: float) -> void:
			if _plane:
				_plane.global_transform = app_tfm.interpolate_with(depart_tfm, t),
		0.0, 1.0, 1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween.tween_callback(_on_airborne)


func _on_airborne() -> void:
	if _plane:
		# Sync flight-model state to the new orientation so the plane continues smoothly.
		_plane._direction  = -_plane.global_transform.basis.z
		_plane._av_roll    = 0.0
		_plane._av_pitch   = 0.0
		_plane._av_yaw     = 0.0
		_plane.autopilot   = false
	# Explicitly release the plane reference. The plane may still be physically
	# inside this trigger sphere after takeoff, so body_exited won't fire yet —
	# if we leave _plane non-null, this zone keeps intercepting interact presses
	# even after the player has flown to a different landing strip.
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
