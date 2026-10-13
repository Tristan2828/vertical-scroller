extends GutTest
## Controls from DESIGN.md §3: default keyboard, classic keyboard and gamepad all
## bound at once, and every menu usable with a gamepad alone.


func _has_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == key:
			return true
	return false


func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var joy := event as InputEventJoypadButton
		if joy != null and joy.button_index == button:
			return true
	return false


func test_default_keyboard_layout() -> void:
	assert_true(_has_key(&"move_up", KEY_W))
	assert_true(_has_key(&"move_left", KEY_A))
	assert_true(_has_key(&"focus", KEY_SHIFT))
	assert_true(_has_key(&"special", KEY_SPACE))
	assert_true(_has_key(&"fire", KEY_F))
	assert_true(_has_key(&"pause", KEY_ESCAPE))


func test_classic_keyboard_layout() -> void:
	assert_true(_has_key(&"move_up", KEY_UP))
	assert_true(_has_key(&"focus", KEY_Z))
	assert_true(_has_key(&"special", KEY_X))
	assert_true(_has_key(&"fire", KEY_C))


func test_gamepad_layout() -> void:
	assert_true(_has_joy_button(&"focus", JOY_BUTTON_A))
	assert_true(_has_joy_button(&"special", JOY_BUTTON_B))
	assert_true(_has_joy_button(&"special", JOY_BUTTON_RIGHT_SHOULDER))
	assert_true(_has_joy_button(&"fire", JOY_BUTTON_Y))
	assert_true(_has_joy_button(&"pause", JOY_BUTTON_START))


func test_no_key_does_two_gameplay_jobs() -> void:
	var seen: Dictionary[Key, StringName] = {}
	for action: StringName in [&"focus", &"special", &"fire", &"pause"]:
		for event: InputEvent in InputMap.action_get_events(action):
			var key_event := event as InputEventKey
			if key_event == null:
				continue
			assert_false(seen.has(key_event.physical_keycode), "%s is also %s" % [action, seen.get(key_event.physical_keycode, &"")])
			seen[key_event.physical_keycode] = action


func test_gamepad_a_confirms_menu_buttons() -> void:
	assert_true(_has_joy_button(&"ui_accept", JOY_BUTTON_A))


func test_gamepad_dpad_moves_between_menu_buttons() -> void:
	assert_true(_has_joy_button(&"ui_left", JOY_BUTTON_DPAD_LEFT))
	assert_true(_has_joy_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT))
