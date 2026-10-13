extends GutTest
## ShipMotor: movement, focus speed, screen edges, fire rate and mouse glide.

const DELTA: float = 1.0 / 60.0
const SCREEN: Rect2 = Rect2(0, 0, 960, 540)

var stats: ShipStats


func before_each() -> void:
	stats = Ships.ALL[0].duplicate() as ShipStats


func _state_at(at: Vector2) -> ShipState:
	var state := ShipState.new()
	state.position = at
	return state


func _make_input(move: Vector2, focus: bool = false, fire: bool = false) -> ShipInput:
	var input := ShipInput.new()
	input.move = move
	input.focus = focus
	input.fire = fire
	return input


func test_moves_at_ship_speed() -> void:
	var state := _state_at(Vector2(480, 270))
	for i: int in 60:
		ShipMotor.step(state, _make_input(Vector2.RIGHT), stats, SCREEN, DELTA)
	assert_almost_eq(state.position.x, 480.0 + stats.move_speed, 0.01)


func test_focus_is_slower() -> void:
	var state := _state_at(Vector2(480, 270))
	ShipMotor.step(state, _make_input(Vector2.UP, true), stats, SCREEN, 1.0)
	assert_almost_eq(state.position.y, 270.0 - stats.focus_speed, 0.01)
	assert_true(state.focused)


func test_diagonal_is_not_faster() -> void:
	var state := _state_at(Vector2(480, 270))
	ShipMotor.step(state, _make_input(Vector2(1, 1)), stats, SCREEN, 0.1)
	assert_almost_eq(state.position.distance_to(Vector2(480, 270)), stats.move_speed * 0.1, 0.01)


func test_stays_on_screen() -> void:
	var state := _state_at(Vector2(20, 20))
	ShipMotor.step(state, _make_input(Vector2(-1, -1)), stats, SCREEN, 1.0)
	assert_eq(state.position, Vector2(stats.body_radius, stats.body_radius))
	state.position = Vector2(950, 530)
	ShipMotor.step(state, _make_input(Vector2(1, 1)), stats, SCREEN, 1.0)
	assert_eq(state.position, SCREEN.end - Vector2(stats.body_radius, stats.body_radius))


func test_fires_at_the_ship_fire_rate() -> void:
	var state := _state_at(Vector2(480, 270))
	var shots := 0
	for i: int in 60:
		shots += ShipMotor.step(state, _make_input(Vector2.ZERO, false, true), stats, SCREEN, DELTA) & ShipMotor.FIRED
	assert_eq(shots, roundi(1.0 / stats.fire_interval))


func test_focus_fires_faster() -> void:
	var state := _state_at(Vector2(480, 270))
	var shots := 0
	for i: int in 60:
		shots += ShipMotor.step(state, _make_input(Vector2.ZERO, true, true), stats, SCREEN, DELTA) & ShipMotor.FIRED
	assert_eq(shots, roundi(1.0 / stats.focus_fire_interval))


func test_no_fire_without_fire_input() -> void:
	var state := _state_at(Vector2(480, 270))
	assert_eq(ShipMotor.step(state, _make_input(Vector2.ZERO), stats, SCREEN, DELTA), 0)


func test_glide_reaches_the_cursor_and_stops_without_shaking() -> void:
	var state := _state_at(Vector2(100, 400))
	var target := Vector2(300.3, 250.7)
	for i: int in 120:
		var move := ShipMotor.glide_move(state.position, target, stats.move_speed, DELTA)
		ShipMotor.step(state, _make_input(move), stats, SCREEN, DELTA)
	assert_almost_eq(state.position.x, target.x, 0.01)
	assert_almost_eq(state.position.y, target.y, 0.01)
	assert_eq(ShipMotor.glide_move(state.position, target, stats.move_speed, DELTA), Vector2.ZERO)


func test_glide_far_away_is_full_speed() -> void:
	assert_almost_eq(ShipMotor.glide_move(Vector2.ZERO, Vector2(500, 0), stats.move_speed, DELTA).length(), 1.0, 0.0001)


func test_same_inputs_give_same_result() -> void:
	var a := _state_at(Vector2(480, 270))
	var b := _state_at(Vector2(480, 270))
	for i: int in 200:
		var move := Vector2.from_angle(i * 0.37)
		ShipMotor.step(a, _make_input(move, i % 3 == 0, true), stats, SCREEN, DELTA)
		ShipMotor.step(b, _make_input(move, i % 3 == 0, true), stats, SCREEN, DELTA)
	assert_eq(a.position, b.position)
	assert_eq(a.fire_cooldown_left, b.fire_cooldown_left)
