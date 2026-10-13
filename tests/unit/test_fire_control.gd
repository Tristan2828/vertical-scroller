extends GutTest
## The auto-fire setting: Always / Toggle / Hold, and focus always fires.

const ALWAYS := FireControl.Mode.ALWAYS
const TOGGLE := FireControl.Mode.TOGGLE
const HOLD := FireControl.Mode.HOLD


func test_always_fires_without_any_button() -> void:
	assert_true(FireControl.wants_fire(ALWAYS, false, false, false))


func test_toggle_fires_only_while_switched_on() -> void:
	assert_true(FireControl.wants_fire(TOGGLE, true, false, false))
	assert_false(FireControl.wants_fire(TOGGLE, false, false, false))


func test_toggle_button_switches_on_and_off() -> void:
	var on := true
	on = FireControl.next_toggle(on, true)
	assert_false(on)
	on = FireControl.next_toggle(on, false)
	assert_false(on, "holding or not pressing keeps the state")
	on = FireControl.next_toggle(on, true)
	assert_true(on)


func test_hold_fires_only_while_held() -> void:
	assert_true(FireControl.wants_fire(HOLD, false, true, false))
	assert_false(FireControl.wants_fire(HOLD, true, false, false))


func test_focus_always_fires() -> void:
	for mode: FireControl.Mode in [ALWAYS, TOGGLE, HOLD]:
		assert_true(FireControl.wants_fire(mode, false, false, true))


func test_every_mode_has_a_name() -> void:
	assert_eq(FireControl.MODE_NAMES.size(), FireControl.Mode.size())
