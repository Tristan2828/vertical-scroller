extends Node
## Registers every input action in code instead of the editor's Input Map, so all
## bindings live in one readable, text-editable place (DESIGN.md §3 Controls).
##
## The default keyboard layout (WASD/Arrows, Shift, Space, F) and the classic
## layout (Arrows, Z, X, C) don't share any keys except the arrows, so both are
## always on: no setting needed. Mouse buttons have their own actions because
## they only count in mouse mode (otherwise a stray click would fire a special).

const STICK_DEADZONE: float = 0.2


func _enter_tree() -> void:
	_add_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _joy(JOY_BUTTON_DPAD_LEFT)])
	_add_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _joy(JOY_BUTTON_DPAD_RIGHT)])
	_add_action("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _joy(JOY_BUTTON_DPAD_UP)])
	_add_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _joy(JOY_BUTTON_DPAD_DOWN)])
	# Hold: slower ship, narrow strong shot, hitbox shown. Always fires.
	_add_action("focus", [_key(KEY_SHIFT), _key(KEY_Z), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _joy(JOY_BUTTON_A)])
	_add_action("special", [_key(KEY_SPACE), _key(KEY_X), _joy(JOY_BUTTON_B), _joy(JOY_BUTTON_RIGHT_SHOULDER)])
	# Auto-fire Toggle: press to switch firing on/off. Hold: fires while held.
	_add_action("fire", [_key(KEY_F), _key(KEY_C), _joy(JOY_BUTTON_Y)])
	_add_action("pause", [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)])
	# Host: copy the invite address again.
	_add_action("copy_invite", [_key(KEY_F1)])
	# Mouse mode only (LocalInput ignores these otherwise).
	_add_action("mouse_focus", [_mouse(MOUSE_BUTTON_RIGHT)])
	_add_action("mouse_special", [_mouse(MOUSE_BUTTON_LEFT)])
	_add_action("mouse_fire", [_mouse(MOUSE_BUTTON_MIDDLE)])
	# Godot's built-in "confirm" for menus has no gamepad button by default, so
	# controllers could move between buttons but not press them.
	_add_action("ui_accept", [_joy(JOY_BUTTON_A)])


func _add_action(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


func _key(physical_key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event
