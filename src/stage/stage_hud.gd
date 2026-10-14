class_name StageHud
extends CanvasLayer
## Gray-box HUD: your red HP bar, power level (arrows), special charges (bomb or
## shield icons; used ones hollow) and boosts (icon + timer bar) at the top
## left, so the bottom where the ships fly stays clear; teammates' names in their ship colors with small HP bars (top right);
## kills, ground targets, the team's Scrap and respawn credits; a thin stage
## progress line that becomes the boss's HP bar; the auto-fire state; a center
## banner (stage name, boss warning, shot down, game over); the results panel
## after a stage clear (goals, payout, score); and (host, online) the invite. The real HUD layout for 1–4 players comes with
## the art pass (M6).

const HP_BAR: Rect2 = Rect2(8, 29, 140, 6)
## Top-left corner of the power arrows; special icons follow on the same row,
## boosts go on the row below.
const LOADOUT_AT: Vector2 = Vector2(8, 41)
const ICON_STEP: float = 11.0
const BOOST_AT: Vector2 = Vector2(8, 55)
const BOOST_BAR_SIZE: Vector2 = Vector2(28, 3)
const SPECIAL_ICONS: Array[String] = ["hud_bomb", "hud_shield"]
const PANEL: Rect2 = Rect2(3, 15, 152, 56)
const PANEL_COLOR: Color = Color(0.17, 0.18, 0.23, 0.85)
const TEAM_BAR_SIZE: Vector2 = Vector2(60, 3)
const PROGRESS_BAR: Rect2 = Rect2(330, 4, 300, 2)
const BOSS_BAR: Rect2 = Rect2(230, 18, 500, 6)
const BAR_BACK: Color = Color(0.05, 0.05, 0.08, 0.85)
const BAR_EMPTY: Color = Color(0.25, 0.1, 0.12)
const HP_COLOR: Color = Color(0.88, 0.2, 0.26)
## Low HP: the bar blinks to this.
const HP_LOW_COLOR: Color = Color(1.0, 0.55, 0.5)
const HP_LOW: float = 0.3
const PROGRESS_COLOR: Color = Color(0.6, 0.65, 0.8)
const BOSS_COLOR: Color = Color(0.95, 0.3, 0.4)
const BOOST_COLOR: Color = Color(1.0, 0.8, 0.4)
const GOAL_MET_COLOR: Color = Color(0.55, 0.95, 0.5)
const GOAL_MISSED_COLOR: Color = Color(0.55, 0.56, 0.62)
const TITLE_COLOR: Color = Color(0.95, 0.78, 0.4)

@onready var _left: Label = $Left
@onready var _right: Label = $Right
@onready var _players: VBoxContainer = $Players
@onready var _invite: Label = $Invite
@onready var _banner: Label = $Banner
@onready var _hp_label: Label = $HpLabel
@onready var _boss_label: Label = $BossLabel

## Names and slots last shown, so the player list is only rebuilt when it changes.
var _players_signature: String = ""
var _banner_left: float = 0.0
var _bars: Control = null
## What the bars show (copied in show_state, drawn in _draw_bars).
var _my_hp_ratio: float = 1.0
## Your loadout (null = no ship of yours: nothing drawn).
var _me: Ship = null
var _team: Array[Ship] = []
var _progress: float = 0.0
var _boss_ratio: float = -1.0
var _results: PanelContainer = null
var _results_lines: VBoxContainer = null
var _results_footer: Label = null
var _results_left: float = 0.0
var _results_next: String = ""


func _ready() -> void:
	_bars = Control.new()
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	# Behind the labels (its panel sits under the HP text).
	move_child(_bars, 0)
	_build_results()
	Net.invite.changed.connect(_show_invite)
	_show_invite()


func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.visible = _banner_left > 0.0
	if _results.visible:
		_results_left = maxf(_results_left - delta, 0.0)
		_results_footer.text = "%s in %d s" % [_results_next, ceili(_results_left)]


func _build_results() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_results = PanelContainer.new()
	_results.custom_minimum_size = Vector2(300, 0)
	_results.hide()
	center.add_child(_results)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_results.add_child(column)
	_results_lines = VBoxContainer.new()
	_results_lines.add_theme_constant_override("separation", 3)
	column.add_child(_results_lines)
	_results_footer = Label.new()
	_results_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_footer.add_theme_color_override("font_color", GOAL_MISSED_COLOR)
	column.add_child(_results_footer)


## The stage clear panel: every goal (met or not) with its reward, the payout
## for unused charges, and the score. `results` comes from Stage._finish_run_stage.
func show_results(results: Dictionary, seconds: float) -> void:
	_banner.visible = false
	_banner_left = 0.0
	for child: Node in _results_lines.get_children():
		child.queue_free()
	_results_line("Stage clear!", TITLE_COLOR, 18)
	var met: Array = results.get("goals", [])
	for goal: int in StageGoals.SHOWN:
		if goal == StageGoals.Id.TWIST and not met.has(goal):
			continue  # Only stages with a twist have this goal.
		var done := met.has(goal)
		_results_line("%s %s   +%d Scrap" % ["[x]" if done else "[ ]", StageGoals.NAMES[goal], StageGoals.REWARDS[goal]],
			GOAL_MET_COLOR if done else GOAL_MISSED_COLOR)
	var charges := int(results.get("unused_charges", 0))
	if charges > 0:
		_results_line("Unused special charges: %d x %d   +%d Scrap" % [charges, StageGoals.CHARGE_PAYOUT,
			charges * StageGoals.CHARGE_PAYOUT], BOOST_COLOR)
	_results_line("Scrap from goals: +%d" % int(results.get("payout", 0)), TITLE_COLOR)
	_results_line("Stage score %d   Run score %d" % [int(results.get("stage_score", 0)), int(results.get("run_score", 0))],
		Color.WHITE)
	_results_next = "Shop opens" if results.get("next", "") == "shop" else "Run summary"
	_results_left = seconds
	_results.show()


func _results_line(text: String, color: Color, size: int = 9) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if size > 9 else HORIZONTAL_ALIGNMENT_LEFT
	_results_lines.add_child(label)


func show_banner(text: String, seconds: float) -> void:
	_banner.text = text
	_banner_left = seconds
	_banner.visible = true


func show_state(stage: Stage, me: Ship) -> void:
	var fire_mode := Settings.fire_mode
	var left := "Auto-fire: %s" % FireControl.MODE_NAMES[fire_mode]
	if fire_mode != FireControl.Mode.ALWAYS and me != null:
		left += " (%s)" % ("firing" if me.firing else "off")
	_set_text(_left, left)
	_set_text(_right, "Kills: %d   Ground: %d/%d   Scrap: %d   Ships left: %d" % [
		stage.kills, stage.ground_kills, stage.ground.count(), stage.team_scrap, stage.credits])
	if me != null:
		_my_hp_ratio = me.health.ratio()
		var hp_text := "HP %d/%d" % [me.health.hp, me.health.max_hp]
		if me.is_down():
			hp_text = "DOWN - back in %.0f s" % ceilf(me.respawn_left) if me.respawn_left > 0.0 else "DOWN - no ships left: watching"
		_set_text(_hp_label, hp_text)
	_me = me
	_progress = stage.progress()
	var in_boss := stage.phase == Stage.Phase.BOSS
	_boss_ratio = stage.boss_hp_ratio if in_boss else -1.0
	_boss_label.visible = in_boss
	if in_boss:
		_set_text(_boss_label, stage.boss_name())
	_team = stage.ships()
	_show_players(_team)
	_bars.queue_redraw()


static func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func _show_players(ships: Array[Ship]) -> void:
	var signature := ""
	if ships.size() > 1:
		for ship: Ship in ships:
			signature += "%d:%s;" % [ship.slot, ship.display_name()]
	if signature == _players_signature:
		return
	_players_signature = signature
	for child: Node in _players.get_children():
		child.queue_free()
	if ships.size() <= 1:
		return
	for ship: Ship in ships:
		var label := Label.new()
		label.text = ship.display_name()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size = Vector2(0, 14)
		label.add_theme_color_override("font_color", ship.tint())
		_players.add_child(label)


func _draw_bars() -> void:
	# A backing panel, so icon outlines read over any ground.
	if _me != null and is_instance_valid(_me):
		var panel := PANEL
		if _me.state.rapid_fire_left <= 0.0 and _me.state.wingmen_left <= 0.0:
			panel.size.y -= 14.0  # No boost row.
		_bars.draw_rect(panel, PANEL_COLOR)
	var blink := _my_hp_ratio < HP_LOW and int(Time.get_ticks_msec() / 250.0) % 2 == 0
	_bar(HP_BAR, _my_hp_ratio, HP_LOW_COLOR if blink else HP_COLOR)
	if _me != null and is_instance_valid(_me):
		_draw_loadout(_me)
	if _boss_ratio >= 0.0:
		_bar(BOSS_BAR, _boss_ratio, BOSS_COLOR)
	else:
		_bar(PROGRESS_BAR, _progress, PROGRESS_COLOR)
	if _team.size() > 1:
		# Under each name in the player list (rows are 14 px tall).
		for i: int in _team.size():
			var at := Vector2(_players.position.x + _players.size.x - TEAM_BAR_SIZE.x, _players.position.y + 12.0 + i * 14.0)
			_bar(Rect2(at, TEAM_BAR_SIZE), _team[i].health.ratio(), _team[i].tint())


## Power arrows and special charges (filled = have, hollow = don't), then the
## running boosts with how long they have left.
func _draw_loadout(me: Ship) -> void:
	var at := LOADOUT_AT
	for i: int in ShipMotor.MAX_POWER:
		_bars.draw_texture(PixelArt.texture("hud_power", Color.WHITE, false, i >= me.state.power), at)
		at.x += ICON_STEP
	at.x += 8.0
	var icon := SPECIAL_ICONS[clampi(me.special_kind, 0, SPECIAL_ICONS.size() - 1)]
	for i: int in maxi(me.special_max, me.special_charges):
		_bars.draw_texture(PixelArt.texture(icon, Color.WHITE, false, i >= me.special_charges), at)
		at.x += ICON_STEP
	at = BOOST_AT
	for boost: Array in [["pickup_rapid", me.state.rapid_fire_left, Color(0.95, 0.55, 0.17)],
			["pickup_wingmen", me.state.wingmen_left, Color(0.45, 0.85, 0.5)]]:
		var left: float = boost[1]
		if left <= 0.0:
			continue
		_bars.draw_texture(PixelArt.texture(boost[0]), at)
		_bar(Rect2(at + Vector2(16, 5), BOOST_BAR_SIZE), left / maxf(Pickups.BOOST_SECONDS, left), boost[2])
		at.x += 16.0 + BOOST_BAR_SIZE.x + 8.0


func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	_bars.draw_rect(rect.grow(1.0), BAR_BACK)
	_bars.draw_rect(rect, BAR_EMPTY)
	_bars.draw_rect(Rect2(rect.position, Vector2(roundf(rect.size.x * clampf(ratio, 0.0, 1.0)), rect.size.y)), color)


func _show_invite() -> void:
	var text := ""
	if Net.is_online() and multiplayer.is_server():
		if Net.invite.address.is_empty():
			text = Net.invite.status
		else:
			text = "Invite: %s (copied; F1 copies again)\n%s" % [Net.invite.address, Net.invite.status]
	_invite.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("copy_invite") and Net.invite.copy_to_clipboard():
		_invite.text = "Invite: %s (copied!)\n%s" % [Net.invite.address, Net.invite.status]
