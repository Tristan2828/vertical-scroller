class_name LocalInput
extends RefCounted
## Reads this computer's keyboard, gamepad or mouse and turns it into a
## ShipInput once per physics tick. The auto-fire setting (FireControl) and
## mouse mode are applied here, on the player's own computer, so the host only
## ever sees "move this way, focus, fire".

## True while a menu is open: the ship stands still.
static var blocked: bool = false

## Auto-fire Toggle mode: firing on/off (starts on).
var toggle_on: bool = true
var _seq: int = 0
var _autopilot_time: float = 0.0


## `mouse_position` is the cursor in stage coordinates.
func sample(ship: ShipState, stats: ShipStats, mouse_position: Vector2, delta: float) -> ShipInput:
	var input := ShipInput.new()
	_seq += 1
	input.seq = _seq
	if LaunchOptions.autopilot:
		_autopilot(input, ship, stats, delta)
		return input
	if blocked:
		return input
	var mouse := Settings.mouse_mode
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


## Test mode (`--autopilot`): weave across the lower screen, focusing now and then.
func _autopilot(input: ShipInput, ship: ShipState, stats: ShipStats, delta: float) -> void:
	_autopilot_time += delta
	var t := _autopilot_time
	input.focus = fmod(t, 8.0) > 5.0
	var target := Vector2(480.0 + 320.0 * sin(t * 0.6), 400.0 + 70.0 * sin(t * 1.3))
	input.move = ShipMotor.glide_move(ship.position, target, ShipMotor.speed_of(stats, input.focus), delta)
	input.fire = true
