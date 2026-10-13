class_name RunSummary
extends Control
## The end of a run, won or lost: stages cleared, the run's score and this PC's
## personal best, and each player's kills, damage and times shot down. The
## host goes back to the lobby (autopilot: by itself). Built in code; spawned
## by Main's LevelSpawner. Every peer saves its own personal best (RunRecords).

## Host: back to the lobby.
signal finished

const AUTOPILOT_SECONDS: float = 6.0
const TITLE_COLOR: Color = Color(0.95, 0.78, 0.4)
const LOST_COLOR: Color = Color(0.95, 0.45, 0.45)
const DIM_COLOR: Color = Color(0.65, 0.66, 0.75)
const BEST_COLOR: Color = Color(0.55, 0.95, 0.5)

var new_best: bool = false
var _back_button: Button


func _ready() -> void:
	var run := RunState.current
	var best_before := RunRecords.best_score()
	new_best = RunRecords.submit(run.score)
	_build(run, best_before)
	print("[summary] run %s: %d of %d stages, score %d" % [run.result, run.stages_done, run.stage_plan.size(), run.score])
	if multiplayer.is_server() and LaunchOptions.autopilot:
		get_tree().create_timer(AUTOPILOT_SECONDS).timeout.connect(func() -> void: finished.emit())


func _build(run: RunState, best_before: int) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.05, 0.09)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var won := run.result == "won"
	_line(column, "Run complete!" if won else "Run over", TITLE_COLOR if won else LOST_COLOR, 18)
	_line(column, "Stages cleared: %d of %d" % [run.stages_done, run.stage_plan.size()], DIM_COLOR)
	_line(column, "Score: %d" % run.score, Color.WHITE, 18)
	if new_best:
		_line(column, "New personal best!", BEST_COLOR)
	else:
		_line(column, "Personal best: %d" % best_before, DIM_COLOR)
	# The run lists players in lobby order (dictionaries keep insertion order).
	var order: Array[int] = []
	order.assign(run.players.keys())
	for slot: int in order.size():
		var peer_id := order[slot]
		var player := run.players[peer_id]
		_line(column, "%s   %d kills   %d damage   shot down %d times" % [Net.name_of(peer_id, slot), player.kills,
			player.damage, player.downs], PlayerNames.color_of(slot))
	if multiplayer.is_server():
		_back_button = Button.new()
		_back_button.text = "Back to the lobby"
		_back_button.pressed.connect(func() -> void: finished.emit())
		column.add_child(_back_button)
		_back_button.grab_focus()
	else:
		_line(column, "The host goes back to the lobby.", DIM_COLOR)


func _line(column: VBoxContainer, text: String, color: Color, size: int = 9) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)


## Text summary for headless smoke tests.
func debug_report() -> String:
	var run := RunState.current
	return "[report] peer %d at the run summary: %s, %d of %d stages, score %d" % [multiplayer.get_unique_id(),
		run.result, run.stages_done, run.stage_plan.size(), run.score]
