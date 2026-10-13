class_name Ship
extends Node2D
## One player's ship. The simulation is ShipMotor (pure); this node owns the
## ship's stats and state, moves it each tick, and draws it. The stage calls
## tick() in its fixed order; nothing here runs gameplay on its own.
##
## Who simulates what (as Medieval Survival's Player):
## - Host: every ship. Its own from local input, clients' ships from the inputs
##   they send (_submit_input), one per tick. HP, power, boosts, special
##   charges and respawns are host-owned and travel in snapshots.
## - Client: only its own ship, predicted from local input right away, and
##   corrected by host snapshots (ClientPredictor). Other players' ships glide
##   toward the positions in the snapshots.

## The main gun shot on input `seq` (host: every ship; client: its own, predicted).
signal fired(ship: Ship, seq: int, focus: bool)
## Host: the special button was pressed (the stage decides if a charge is left).
signal special_requested(ship: Ship)
## Every peer: this ship lost HP / was shot down / came back (for effects).
signal hurt(ship: Ship, amount: int)
signal downed(ship: Ship)
signal respawned(ship: Ship)

## Seconds per engine flicker frame.
const FLICKER_SECONDS: float = 0.06
const HITBOX_COLOR: Color = Color(1.0, 0.3, 0.35)
const HITBOX_CORE: Color = Color(1.0, 1.0, 1.0)
## Seconds per blink frame while invulnerable after a hit.
const BLINK_SECONDS: float = 0.08
## Seconds the whole ship flashes white when hit.
const HURT_FLASH_SECONDS: float = 0.1
## Host: inputs kept waiting at most; with more than CATCH_UP_THRESHOLD queued it
## simulates two per tick until it has caught up.
const MAX_QUEUED_INPUTS: int = 6
const CATCH_UP_THRESHOLD: int = 3
## How fast drawn positions follow corrections / remote snapshots (per second).
const CORRECTION_SMOOTHING: float = 10.0
const REMOTE_SMOOTHING: float = 18.0
## A remote ship further than this from its snapshot jumps there.
const REMOTE_SNAP_DISTANCE: float = 48.0
## Death (DESIGN.md §5, draft): seconds before a downed ship comes back (if the
## team has a respawn credit), and seconds of safety after it does.
const RESPAWN_DELAY: float = 3.0
const RESPAWN_SAFE_SECONDS: float = 2.0
## Wingmen boost: where the two side drones fly, relative to the ship.
const WINGMAN_OFFSET: Vector2 = Vector2(26, 6)
const SHIELD_COLOR: Color = Color(0.45, 0.85, 1.0, 0.35)
const SHIELD_EDGE: Color = Color(0.75, 0.95, 1.0, 0.8)

var peer_id: int = 1
## 0-3: color and name order.
var slot: int = 0
var ship_id: int = 0
var stats: ShipStats = null
var state: ShipState = ShipState.new()
## Host-owned; clients copy it from snapshots.
var health: ShipHealth = ShipHealth.new()
var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(ScreenFit.BASE))
## Specials.Kind equipped, and charges left this stage (host-owned).
var special_kind: int = Specials.Kind.MEGA_BOMB
var special_charges: int = 0
## Seconds until a downed ship comes back (host-owned; 0 while flying, or when
## the team is out of respawn credits).
var respawn_left: float = 0.0
## Tests: used instead of reading the keyboard (seq is still filled in).
var test_input: ShipInput = null
## False once the stage is won or lost: no more inputs. (The host frees the
## stage a few seconds later; inputs still on their way would arrive for a
## ship that no longer exists.)
var controls_enabled: bool = true
## Host: sequence number of the last input it simulated for this ship.
var last_processed_seq: int = -1
## The last simulated input wanted to fire (HUD: auto-fire Toggle / Hold state).
var firing: bool = false
## Client debug stats for its own ship.
var correction_count: int = 0
var largest_correction: float = 0.0

var _local_input: LocalInput = LocalInput.new()
var _next_input_seq: int = 0
var _input_queue: Array[ShipInput] = []
var _newest_received_seq: int = -1
## Special presses already handled (ShipInput.special_count).
var _special_presses_seen: int = 0
var _predictor: ClientPredictor = ClientPredictor.new()
## Drawn offset from the simulated position; shrinks to zero so corrections look smooth.
var _visual_offset: Vector2 = Vector2.ZERO
var _remote_target: Vector2 = Vector2.ZERO
var _flicker_time: float = 0.0
var _hurt_flash_left: float = 0.0


## Called by the stage's spawn function, before the node enters the tree.
## `run` is this player's part of the run (RunState.PlayerRun.to_dict()):
## shop upgrades, power and HP carried over from the last stage.
func setup(owner_peer_id: int, player_slot: int, ship: int, start: Vector2, area: Rect2,
		special: int = Specials.Kind.MEGA_BOMB, run: Dictionary = {}) -> void:
	peer_id = owner_peer_id
	slot = player_slot
	ship_id = ship
	bounds = area
	name = str(owner_peer_id)
	var carried := RunState.PlayerRun.from_dict(run)
	# Each player gets its own copy so in-run changes only affect this ship.
	stats = Ships.ALL[ship].duplicate() as ShipStats
	stats.max_hp += carried.max_hp_bonus
	stats.move_speed *= 1.0 + carried.speed_bonus
	stats.focus_speed *= 1.0 + carried.speed_bonus
	health.reset(stats.max_hp)
	if carried.hp > 0:
		health.hp = mini(carried.hp, stats.max_hp)
	state.power = carried.power
	special_kind = special if Specials.is_valid(special) else Specials.Kind.MEGA_BOMB
	# Charges refill at the start of each stage (plus any bought in the shop).
	special_charges = Specials.charges_of(special_kind) + carried.extra_charges
	state.position = start
	position = start
	_remote_target = start
	_local_input.autopilot_phase = player_slot * 2.5


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


## Shot down (waiting to respawn, or out of credits).
func is_down() -> bool:
	return health.is_empty()


func tint() -> Color:
	return PlayerNames.color_of(slot)


func display_name() -> String:
	return Net.name_of(peer_id, slot)


## Advances this ship by one physics tick.
func tick(delta: float) -> void:
	if not controls_enabled:
		return
	if multiplayer.is_server():
		health.tick(delta)
		if is_local():
			_simulate(_read_local_input(delta), delta)
		else:
			_simulate_queued_inputs(delta)
	elif is_local():
		var input := _read_local_input(delta)
		_submit_input.rpc_id(1, input.seq, input.move, input.focus, input.fire, input.special_count)
		_simulate(input, delta)
		_predictor.record(input.seq, state.position)


## Host: an enemy bullet or a collision. Returns true if it landed.
func take_hit(amount: int) -> bool:
	if is_down() or state.shield_left > 0.0 or not health.take_hit(amount):
		return false
	if LaunchOptions.invincible:
		health.hp = health.max_hp  # The hit counts (blink, flash), the HP comes back.
	_on_hurt(amount)
	if is_down():
		_go_down()
	return true


## Host: back in the fight at `at` (the stage spends a respawn credit).
func respawn(at: Vector2) -> void:
	health.reset(stats.max_hp)
	health.invulnerable_left = RESPAWN_SAFE_SECONDS
	respawn_left = 0.0
	state.position = at
	position = at
	respawned.emit(self)


func _go_down() -> void:
	# Dying costs a power level (draft) and every boost.
	state.power = maxi(state.power - 1, 1)
	state.rapid_fire_left = 0.0
	state.wingmen_left = 0.0
	state.shield_left = 0.0
	respawn_left = RESPAWN_DELAY
	downed.emit(self)


func _on_hurt(amount: int) -> void:
	_hurt_flash_left = HURT_FLASH_SECONDS
	hurt.emit(self, amount)


## Client: this ship's entry from a host snapshot. `extra` is the byte block
## Stage.pack_ship_extra() makes (power, charges, boosts, shield, respawn countdown).
func apply_server_state(server_position: Vector2, ack_seq: int, focused: bool, hp: int, max_hp: int,
		invulnerable: bool, extra: PackedByteArray) -> void:
	var was_down := is_down()
	health.max_hp = max_hp
	if hp < health.hp:
		_on_hurt(health.hp - hp)
	health.hp = hp
	var came_back := was_down and not is_down()
	if is_down() and not was_down:
		downed.emit(self)
	elif came_back:
		respawned.emit(self)
	# Blinks on this screen too (the exact time left doesn't matter here).
	health.invulnerable_left = ShipHealth.HIT_SAFE_SECONDS if invulnerable else 0.0
	if extra.size() >= 6:
		state.power = clampi(extra[0], 1, ShipMotor.MAX_POWER)
		special_charges = extra[1]
		state.rapid_fire_left = extra[2] / 10.0
		state.wingmen_left = extra[3] / 10.0
		state.shield_left = extra[4] / 10.0
		respawn_left = extra[5] / 10.0
	if is_local() and came_back:
		# A respawn is a jump on purpose, not a prediction mistake: take the
		# host's spot and start predicting afresh from there.
		state.position = server_position
		position = server_position
		_visual_offset = Vector2.ZERO
		_predictor = ClientPredictor.new()
	elif is_local():
		var error := _predictor.reconcile(ack_seq, server_position)
		if error == Vector2.ZERO:
			return
		correction_count += 1
		largest_correction = maxf(largest_correction, error.length())
		state.position = ShipMotor.clamp_to_bounds(state.position + error, bounds, stats.body_radius)
		if error.length() >= ClientPredictor.SNAP_DISTANCE:
			_visual_offset = Vector2.ZERO
		else:
			# Keep drawing where we were, then glide to the corrected spot.
			_visual_offset -= error
	else:
		state.position = server_position
		state.focused = focused
		if position.distance_to(server_position) > REMOTE_SNAP_DISTANCE:
			position = server_position
		_remote_target = server_position


func _read_local_input(delta: float) -> ShipInput:
	var input := test_input
	if input == null:
		input = _local_input.sample(state, stats, get_global_mouse_position(), delta)
	input.seq = _next_input_seq
	_next_input_seq += 1
	return input


func _simulate_queued_inputs(delta: float) -> void:
	# No input arrived in time: wait instead of guessing, so the client's
	# prediction (which used the real input) stays in sync with us.
	if _input_queue.is_empty():
		return
	var steps := 2 if _input_queue.size() > CATCH_UP_THRESHOLD else 1
	for i: int in steps:
		_simulate(_input_queue.pop_front(), delta)


func _simulate(input: ShipInput, delta: float) -> void:
	last_processed_seq = input.seq
	if input.special_count > _special_presses_seen:
		_special_presses_seen = input.special_count
		if multiplayer.is_server() and not is_down():
			special_requested.emit(self)
	if is_down():
		# Shot down: no moving or shooting until the respawn.
		firing = false
		return
	firing = input.fire
	if ShipMotor.step(state, input, stats, bounds, delta) & ShipMotor.FIRED:
		fired.emit(self, input.seq, input.focus)


## Client -> host, every tick. Unreliable: a lost packet is cheaper than a delay.
@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _submit_input(seq: int, move: Vector2, focus: bool, fire: bool, special_count: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	if seq <= _newest_received_seq:
		return
	_newest_received_seq = seq
	var input := ShipInput.new()
	input.seq = seq
	input.move = move.limit_length(1.0)
	input.focus = focus
	input.fire = fire
	input.special_count = special_count
	_input_queue.append(input)
	while _input_queue.size() > MAX_QUEUED_INPUTS:
		_input_queue.pop_front()


func _process(delta: float) -> void:
	_flicker_time += delta
	_hurt_flash_left = maxf(_hurt_flash_left - delta, 0.0)
	if not multiplayer.is_server():
		# Count down between snapshots (the host's numbers win when they arrive).
		state.shield_left = maxf(state.shield_left - delta, 0.0)
		respawn_left = maxf(respawn_left - delta, 0.0)
	if multiplayer.is_server():
		position = state.position
	elif is_local():
		_visual_offset = _visual_offset.lerp(Vector2.ZERO, 1.0 - exp(-CORRECTION_SMOOTHING * delta))
		position = state.position + _visual_offset
	else:
		position = position.lerp(_remote_target, 1.0 - exp(-REMOTE_SMOOTHING * delta))
	queue_redraw()


func _draw() -> void:
	if stats == null or is_down():
		return
	var blink_hidden := health.is_invulnerable() and int(_flicker_time / BLINK_SECONDS) % 2 == 1
	if not blink_hidden:
		var frame := stats.sprite
		if int(_flicker_time / FLICKER_SECONDS) % 2 == 1 and PixelArt.has_sprite(stats.sprite + "_1"):
			frame = stats.sprite + "_1"
		PixelArt.draw(self, frame, Vector2.ZERO, tint(), _hurt_flash_left > 0.0)
		if state.wingmen_left > 0.0:
			for side: float in [-1.0, 1.0]:
				PixelArt.draw(self, "wingman", Vector2(side * WINGMAN_OFFSET.x, WINGMAN_OFFSET.y), tint())
	if state.shield_left > 0.0:
		var bubble := PixelArt.disc_texture(Specials.SHIELD_RADIUS, SHIELD_EDGE, Specials.SHIELD_RADIUS - 1.0, SHIELD_COLOR)
		draw_texture(bubble, -(Vector2(bubble.get_size()) / 2.0).floor())
	if state.focused:
		# The real hitbox: a ring the size of the hitbox around a white dot.
		var ring := PixelArt.disc_texture(stats.hitbox_radius + 1.0, HITBOX_COLOR, stats.hitbox_radius - 0.5, HITBOX_CORE)
		draw_texture(ring, -(Vector2(ring.get_size()) / 2.0).floor())
