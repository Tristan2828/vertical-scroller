extends GutTest
## Player names, colors and the lobby's start rule.


func test_names_are_trimmed_capped_and_drawable() -> void:
	assert_eq(PlayerNames.sanitize("  Tristan  "), "Tristan")
	assert_eq(PlayerNames.sanitize("A   B"), "A B", "runs of spaces collapse")
	assert_eq(PlayerNames.sanitize("Zoë★"), "Zo", "characters the pixel font can't draw are dropped")
	assert_eq(PlayerNames.sanitize("abcdefghijklmnopqrstuvwxyz").length(), PlayerNames.MAX_LENGTH)
	assert_eq(PlayerNames.sanitize("   "), "")


func test_players_without_a_name_go_by_their_color() -> void:
	assert_eq(PlayerNames.display("", 1), "Purple")
	assert_eq(PlayerNames.display("Mo", 1), "Mo")


func test_every_slot_has_a_color_and_a_name() -> void:
	assert_eq(PlayerNames.SLOT_COLORS.size(), 4)
	assert_eq(PlayerNames.SLOT_NAMES.size(), PlayerNames.SLOT_COLORS.size())


func test_no_player_color_is_red_like_the_enemies() -> void:
	for color: Color in PlayerNames.SLOT_COLORS:
		var reddish := color.r > 0.6 and color.g < 0.5 and color.b < 0.5
		assert_false(reddish, "%s looks like an enemy" % color)


func test_host_can_start_alone() -> void:
	var state := LobbyState.new()
	state.add(1, 0)
	assert_true(state.can_start(1))


func test_host_waits_for_every_client_to_be_ready() -> void:
	var state := LobbyState.new()
	state.add(1, 0)
	state.add(42, 0)
	state.add(77, 0)
	assert_false(state.can_start(1))
	assert_eq(state.not_ready(1), [42, 77] as Array[int])
	state.set_ready(42, true)
	state.set_ready(77, true)
	assert_true(state.can_start(1))


func test_a_player_leaving_no_longer_blocks_the_start() -> void:
	var state := LobbyState.new()
	state.add(1, 0)
	state.add(42, 0)
	state.remove(42)
	assert_true(state.can_start(1))


func test_only_real_ships_can_be_chosen() -> void:
	var state := LobbyState.new()
	state.add(1, 0)
	assert_false(state.choose(1, Ships.ALL.size()))
	assert_false(state.choose(99, 0), "not in the lobby")
	assert_true(state.choose(1, 0))


func test_unknown_ship_choice_falls_back_to_the_first_ship() -> void:
	RunSetup.ships = {5: 99}
	assert_eq(RunSetup.ship_for(5), 0)
	assert_eq(RunSetup.ship_for(6), 0)
	RunSetup.ships = {}
