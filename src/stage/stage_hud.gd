class_name StageHud
extends CanvasLayer
## M1's bare HUD: the auto-fire state, kills and a controls hint. The real HUD
## (HP bars for 1–4 players, specials, Scrap) comes with M4–M6.

@onready var _left: Label = $Left
@onready var _right: Label = $Right


func show_state(fire_mode: FireControl.Mode, firing: bool, kills: int) -> void:
	var fire_text := "Auto-fire: %s" % FireControl.MODE_NAMES[fire_mode]
	if fire_mode != FireControl.Mode.ALWAYS:
		fire_text += " (%s)" % ("firing" if firing else "off")
	var left := "%s\nMouse mode: %s\nEsc / Start: menu" % [fire_text, "on" if Settings.mouse_mode else "off"]
	if _left.text != left:
		_left.text = left
	var right := "Kills: %d" % kills
	if _right.text != right:
		_right.text = right
