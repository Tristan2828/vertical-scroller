class_name FireControl
extends RefCounted
## The auto-fire setting (DESIGN.md §3 Controls). It runs on the player's own
## computer; only the result ("fire this tick") travels in ShipInput.
##   ALWAYS: the gun never stops (default).
##   TOGGLE: the fire button switches it on/off.
##   HOLD:   fires while the fire button is held (classic).
## Focus always fires, whatever the mode.

enum Mode { ALWAYS, TOGGLE, HOLD }

const MODE_NAMES: Array[String] = ["Always", "Toggle", "Hold"]


## Toggle mode's on/off state after this tick.
static func next_toggle(on: bool, fire_just_pressed: bool) -> bool:
	return on != fire_just_pressed


static func wants_fire(mode: Mode, toggle_on: bool, fire_held: bool, focus: bool) -> bool:
	if focus:
		return true
	match mode:
		Mode.TOGGLE:
			return toggle_on
		Mode.HOLD:
			return fire_held
	return true
