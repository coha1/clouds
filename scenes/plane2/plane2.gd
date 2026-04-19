extends RigidBody3D


# Speed -----------------------------------------------------------------------

@export_group("Speed")
@export var speed: float = 20.0
@export var speed_min: float = 5.0
@export var speed_max: float = 50.0
## How fast throttle_pct moves when the input is held (full range in ~4 s at 0.25)
@export var throttle_rate: float = 0.25
## How fast actual speed chases the throttle target
@export var throttle_speed: float = 8.0

# Controls --------------------------------------------------------------------

@export_group("Controls")
@export var roll_speed: float = 1.2
## Nose-up pitch rate (pulling back)
@export var pitch_up_speed: float = 1.0
## Nose-down pitch rate — less powerful than pulling up, as on a real plane
@export var pitch_down_speed: float = 0.5
@export var yaw_speed: float = 1.0

# Inertia ---------------------------------------------------------------------

@export_group("Inertia")
## How quickly angular velocity ramps up/down. Lower = more sluggish.
@export var angular_response: float = 3.5

# Aerodynamics ----------------------------------------------------------------

@export_group("Aerodynamics")
## How fast the travel direction steers toward the nose direction
@export var aero_correction: float = 1.2
## How strongly a banked wing curves the flight path sideways
@export var lift_factor: float = 0.35
## How much banking also yaws the nose into the turn (coordinated turn feel)
@export var bank_yaw_coupling: float = 0.55

# Energy ----------------------------------------------------------------------

@export_group("Energy")
## Climbing bleeds speed; diving builds it. Higher = stronger exchange.
@export var energy_transfer: float = 0.5

# Stall -----------------------------------------------------------------------

@export_group("Stall")
## Below this speed the plane begins to stall.
@export var stall_speed: float = 12.0
## Downward pull on travel direction at full stall.
@export var stall_gravity: float = 9.0
## Above this speed controls are at full authority; below it they get mushy.
@export var handling_full_speed: float = 16.0
## How fast the stall-assist rotates the nose down and levels the wings.
@export var stall_assist_rate: float = 2.0


## Actual travel direction — normalised. Banking gradually curves this sideways.
var _direction := Vector3.FORWARD

## 0.0 – 1.0 engine power setting, adjusted by the player and read by the HUD.
## Actual speed chases the target set by this value; energy/stall push it around.
var throttle_pct: float = 0.4

## Angular velocities — lerped toward target rates for inertia feel.
var _av_roll:  float = 0.0
var _av_pitch: float = 0.0
var _av_yaw:   float = 0.0


func _ready() -> void:
	_direction = -transform.basis.z
	add_to_group("player_plane")


func _physics_process(delta: float) -> void:
	var roll_input:  float = Input.get_axis("roll_left",     "roll_right")
	var pitch_input: float = Input.get_axis("pitch_forward", "pitch_back")
	var yaw_input:   float = Input.get_axis("yaw_left",      "yaw_right")
	var throttle:    float = Input.get_axis("throttle_down", "throttle_up")

	# Throttle — hold input moves the engine power setting; speed chases it
	throttle_pct = clampf(throttle_pct + throttle * throttle_rate * delta, 0.0, 1.0)
	var throttle_target := lerpf(speed_min, speed_max, throttle_pct)
	speed = move_toward(speed, throttle_target, throttle_speed * delta)

	# --- Asymmetric pitch rate ------------------------------------------------
	# Pulling up (pitch_input > 0) is more powerful than pushing down.
	var pitch_rate := pitch_up_speed if pitch_input >= 0.0 else pitch_down_speed

	# --- Stall & handling factor ----------------------------------------------
	# stall_t: 0.0 when flying fast, ramps to 1.0 as speed falls to zero.
	# handling_t: 1.0 above handling_full_speed, fades to 0.0 at stall_speed.
	# Both clamp so overshooting the range has no extra effect.
	var stall_t     := clampf(1.0 - speed / stall_speed, 0.0, 1.0)
	var handling_t  := clampf((speed - stall_speed) / (handling_full_speed - stall_speed), 0.0, 1.0)

	# --- Inertia: angular velocities lerp toward target rates -----------------
	# handling_t scales the target so controls go mushy near/below stall speed.
	# Rudder authority also shrinks with speed — at cruise it's a trim nudge,
	# not a drift handle. speed_min / speed = 1.0 at slowest, ~0.1 at top speed.
	var yaw_authority := yaw_speed * (speed_min / speed)

	_av_roll  = lerpf(_av_roll,  roll_input  * roll_speed    * handling_t, angular_response * delta)
	_av_pitch = lerpf(_av_pitch, pitch_input * pitch_rate    * handling_t, angular_response * delta)
	_av_yaw   = lerpf(_av_yaw,   yaw_input   * yaw_authority * handling_t, angular_response * delta)

	# --- Bank–yaw coupling ---------------------------------------------------
	# Project world-up onto local-right: when banked right the right wing tilts
	# down so basis.x points partly downward → dot product goes negative.
	# Negating gives a heading-independent +/- that drives yaw into the bank.
	var coupled_yaw: float = -Vector3.UP.dot(transform.basis.x) * bank_yaw_coupling

	# --- Rotate the plane's orientation --------------------------------------
	transform.basis = transform.basis.rotated(transform.basis.z, -_av_roll  * delta)
	transform.basis = transform.basis.rotated(transform.basis.x,  _av_pitch * delta)
	transform.basis = transform.basis.rotated(transform.basis.y, (-_av_yaw - coupled_yaw) * delta)
	transform.basis = transform.basis.orthonormalized()

	# --- Aerodynamic correction: travel direction gradually chases the nose --
	var nose := -transform.basis.z
	_direction = _direction.lerp(nose, aero_correction * delta).normalized()

	# --- Wing lift: banked wing curves the flight path sideways --------------
	var local_up := transform.basis.y
	var lift_lateral := Vector3(local_up.x, 0.0, local_up.z)
	if lift_lateral.length_squared() > 0.0001:
		_direction = (_direction + lift_lateral * lift_factor * delta).normalized()

	# --- Energy: climb bleeds speed, dive builds it --------------------------
	# _direction.y is +1 straight up, -1 straight down. Multiplying by current
	# speed makes the exchange proportional — a steep climb at 50 m/s bleeds
	# far more than a gentle nose-up at 10 m/s.
	speed = clampf(speed - _direction.y * energy_transfer * speed * delta, speed_min, speed_max)

	# --- Stall gravity -------------------------------------------------------
	# Pulls _direction downward proportional to stall_t. The nose drops, the
	# plane dives, speed builds, stall_t shrinks — self-recovering by design.
	# The player just needs to not hold the nose up against it.
	_direction = (_direction + Vector3.DOWN * stall_gravity * stall_t * delta).normalized()

	# --- Stall orientation assist --------------------------------------------
	# Rotates the plane's visual orientation so the nose tracks _direction
	# (which gravity is pulling down) and the wings level out. By the time
	# speed recovers, the player just needs to pull up.
	if stall_t > 0.01:
		# Target forward = travel direction (nose-down in a stall).
		# Target right = current right axis flattened to horizontal, then made
		# perpendicular to target forward so the basis stays orthonormal.
		var target_fwd   := _direction
		var flat_right   := Vector3(transform.basis.x.x, 0.0, transform.basis.x.z)
		if flat_right.length_squared() < 0.001:
			flat_right = Vector3.RIGHT
		flat_right = flat_right.normalized()
		var target_right := (flat_right - flat_right.dot(target_fwd) * target_fwd).normalized()
		var target_up    := (-target_fwd).cross(target_right).normalized()
		var target_basis := Basis(target_right, target_up, -target_fwd)
		transform.basis  = transform.basis.slerp(target_basis, stall_t * stall_assist_rate * delta).orthonormalized()

	move_and_collide(_direction * speed * delta)
