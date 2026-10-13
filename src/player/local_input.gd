class_name LocalInput
extends RefCounted
## Reads this computer's keyboard, gamepad or mouse and turns it into a
## ShipInput once per physics tick. The auto-fire setting (FireControl) and
## mouse mode are applied here, on the player's own computer, so the host only
## ever sees "move this way, focus, fire".

## True while a menu is open: the ship stands still (and Always auto-fire keeps going).
static var blocked: bool = false

const AUTOPILOT_SPECIAL_EVERY: float = 20.0

## Autopilot: given the ship's position, the x to line up under (a target), or
## NAN for none. The stage sets this; tests and menus leave it empty.
static var autopilot_aim: Callable = Callable()

## Auto-fire Toggle mode: firing on/off (starts on).
var toggle_on: bool = true
## Special button presses so far (ShipInput.special_count).
var special_count: int = 0
## Autopilot: shifts the weaving path, so co-op autopilots don't fly on top of each other.
var autopilot_phase: float = 0.0
var _autopilot_time: float = 0.0


## `mouse_position` is the cursor in stage coordinates. The caller sets `seq`.
func sample(ship: ShipState, stats: ShipStats, mouse_position: Vector2, delta: float) -> ShipInput:
	var input := ShipInput.new()
	input.special_count = special_count
	if LaunchOptions.autopilot:
		_autopilot(input, ship, stats, delta)
		return input
	if blocked:
		input.fire = FireControl.wants_fire(Settings.fire_mode, toggle_on, false, false)
		return input
	var mouse := Settings.mouse_mode
	if Input.is_action_just_pressed("special") or (mouse and Input.is_action_just_pressed("mouse_special")):
		special_count += 1
		input.special_count = special_count
	input.focus = Input.is_action_pressed("focus") or (mouse and Input.is_action_pressed("mouse_focus"))
	input.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if mouse and input.move == Vector2.ZERO:
		input.move = ShipMotor.glide_move(ship.position, mouse_position, ShipMotor.speed_of(stats, input.focus), delta)
	var fire_pressed := Input.is_action_just_pressed("fire") or (mouse and Input.is_action_just_pressed("mouse_fire"))
	var fire_held := Input.is_action_pressed("fire") or (mouse and Input.is_action_pressed("mouse_fire"))
	if Settings.fire_mode == FireControl.Mode.TOGGLE:
		toggle_on = FireControl.next_toggle(toggle_on, fire_pressed)
	input.fire = FireControl.wants_fire(Settings.fire_mode, toggle_on, fire_held, input.focus)
	return input


## Test mode (`--autopilot`): weave across the lower screen, focusing now and
## then, and use the special every AUTOPILOT_SPECIAL_EVERY seconds.
func _autopilot(input: ShipInput, ship: ShipState, stats: ShipStats, delta: float) -> void:
	var before := _autopilot_time
	_autopilot_time += delta
	if floori(_autopilot_time / AUTOPILOT_SPECIAL_EVERY) > floori(before / AUTOPILOT_SPECIAL_EVERY):
		special_count += 1
		input.special_count = special_count
	var t := _autopilot_time + autopilot_phase
	input.focus = fmod(t, 8.0) > 5.0
	var target := Vector2(480.0 + 320.0 * sin(t * 0.6), 400.0 + 70.0 * sin(t * 1.3))
	if autopilot_aim.is_valid():
		# Line up under a target, still weaving a little so it dodges some.
		var aim_x: float = autopilot_aim.call(ship.position)
		if not is_nan(aim_x):
			target.x = aim_x + 18.0 * sin(t * 2.3)
	input.move = ShipMotor.glide_move(ship.position, target, ShipMotor.speed_of(stats, input.focus), delta)
	input.fire = true
