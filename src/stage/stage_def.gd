class_name StageDef
extends RefCounted
## One stage's data, read from a plain text `.stage` file in src/stage/stages/
## (DESIGN.md §3: waves are text data). Lines:
##
##   # a comment (also allowed after a line)
##   name = Planet Base
##   length = 240          seconds of waves before the boss (M4)
##   scroll_speed = 60     pixels per second (60 = 1 px per tick, the smoothest)
##   wave <time> <enemy> <shape> [x=480] [y=-16] [count=1] [spacing=0.4] [dx=0] [pace=1] [mirror] [variant=a1]
##   ground <time> <type> x=<x> [mirror]
##   boss <type> [x=480]
##   boss_step <phase 1|2> <pattern> [aim=nearest|each|fixed|spin] [angle=90] [wait=1] [dx=0] [dy=0]
##
## wave: `count` enemies of type <enemy> (EnemyType.key) fly path <shape>
## (PathShapes.NAMES), one every `spacing` seconds from `time`, starting at
## (x, y), each `dx` pixels further right. `pace` speeds the path up (2 = twice
## as fast). `variant=a1` makes the line option 1 of group "a": each run picks
## one option per group, so the lines of the other options are skipped.
## ground: a ground object of <type> that scrolls in at the top of the screen at
## `time`, at x. Its index among the ground lines is its network id, so ground
## objects need no spawn messages.
## boss: when the waves are over (`length`), the scroll stops and this boss
## flies in. Its attack script is the boss_step lines: phase 1 loops until it
## drops below half HP, then phase 2 loops (phase 1 again if there's none).
## A step fires <pattern> (ShotPatterns.NAMES) from the boss (+dx, dy), aimed
## at the nearest ship, at each ship, at a fixed angle (degrees: 90 = down),
## or spinning further each time, then waits `wait` seconds.

## Every peer reads the same file, so these ids match everywhere.
class WaveDef:
	extends RefCounted
	var time: float = 0.0
	var type_id: int = 0
	var shape: int = 0
	var origin: Vector2 = Vector2(480, -16)
	var count: int = 1
	var spacing: float = 0.4
	var dx: float = 0.0
	var pace: float = 1.0
	var mirror: bool = false
	## "" = always flown.
	var variant_group: String = ""
	var variant_option: String = ""


class GroundDef:
	extends RefCounted
	var time: float = 0.0
	var type_id: int = 0
	var x: float = 480.0
	var mirror: bool = false


var name: String = ""
var length: float = 240.0
var scroll_speed: float = 60.0
## In file order.
var waves: Array[WaveDef] = []
## In file order; the index is the ground object's id.
var grounds: Array[GroundDef] = []
## The boss (EnemyTypes id, -1 = none), where it comes in, and its script.
var boss_type: int = -1
var boss_x: float = 480.0
var boss_steps_one: Array[BossStep] = []
var boss_steps_two: Array[BossStep] = []
## "line 12: unknown enemy 'dron'" (empty when the file is fine).
var errors: PackedStringArray = PackedStringArray()


static func load_file(path: String) -> StageDef:
	if not FileAccess.file_exists(path):
		var missing := StageDef.new()
		missing.errors.append("%s: file not found" % path)
		return missing
	return parse(FileAccess.get_file_as_string(path))


static func parse(text: String) -> StageDef:
	var def := StageDef.new()
	var lines := text.split("\n")
	for number: int in range(1, lines.size() + 1):
		var line := lines[number - 1].get_slice("#", 0).strip_edges()
		if line.is_empty():
			continue
		if line.contains("="):
			var first_word := line.get_slice(" ", 0)
			if not first_word in ["wave", "ground", "boss", "boss_step"]:
				def._parse_setting(number, line)
				continue
		var words := line.split(" ", false)
		match words[0]:
			"wave":
				def._parse_wave(number, words)
			"ground":
				def._parse_ground(number, words)
			"boss":
				def._parse_boss(number, words)
			"boss_step":
				def._parse_boss_step(number, words)
			_:
				def.errors.append("line %d: don't know '%s'" % [number, words[0]])
	return def


func has_boss() -> bool:
	return boss_type >= 0


## How far the map has scrolled at `stage_time`: it stops when the boss comes.
func scroll_distance(stage_time: float) -> float:
	return scroll_speed * (minf(stage_time, length) if has_boss() else stage_time)


## The waves one run flies: every line without a variant, plus one option per
## variant group, picked from `seed_value`. Sorted by time.
func waves_for_seed(seed_value: int) -> Array[WaveDef]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var picks: Dictionary[String, String] = {}
	for group: String in variant_groups():
		var options := variant_options(group)
		picks[group] = options[rng.randi_range(0, options.size() - 1)]
	var result: Array[WaveDef] = []
	for wave: WaveDef in waves:
		if wave.variant_group.is_empty() or picks.get(wave.variant_group, "") == wave.variant_option:
			result.append(wave)
	result.sort_custom(func(a: WaveDef, b: WaveDef) -> bool: return a.time < b.time)
	return result


## Variant group names, sorted (so the pick doesn't depend on file order).
func variant_groups() -> Array[String]:
	var groups: Array[String] = []
	for wave: WaveDef in waves:
		if not wave.variant_group.is_empty() and not groups.has(wave.variant_group):
			groups.append(wave.variant_group)
	groups.sort()
	return groups


func variant_options(group: String) -> Array[String]:
	var options: Array[String] = []
	for wave: WaveDef in waves:
		if wave.variant_group == group and not options.has(wave.variant_option):
			options.append(wave.variant_option)
	options.sort()
	return options


func _parse_setting(number: int, line: String) -> void:
	var key := line.get_slice("=", 0).strip_edges()
	var value := line.get_slice("=", 1).strip_edges()
	match key:
		"name":
			name = value
		"length":
			length = _number(number, key, value)
		"scroll_speed":
			scroll_speed = _number(number, key, value)
		_:
			errors.append("line %d: unknown setting '%s'" % [number, key])


func _parse_wave(number: int, words: PackedStringArray) -> void:
	if words.size() < 4:
		errors.append("line %d: a wave needs a time, an enemy and a shape" % number)
		return
	var wave := WaveDef.new()
	wave.time = _number(number, "time", words[1])
	wave.type_id = EnemyTypes.from_key(words[2])
	if wave.type_id < 0 or EnemyTypes.ALL[wave.type_id].ground or EnemyTypes.ALL[wave.type_id].is_boss:
		errors.append("line %d: unknown air enemy '%s'" % [number, words[2]])
		return
	wave.shape = PathShapes.from_name(words[3])
	if wave.shape < 0:
		errors.append("line %d: unknown shape '%s' (shapes: %s)" % [number, words[3], ", ".join(PathShapes.NAMES)])
		return
	for i: int in range(4, words.size()):
		var word := words[i]
		if word == "mirror":
			wave.mirror = true
			continue
		var key := word.get_slice("=", 0)
		var value := word.get_slice("=", 1)
		match key:
			"x":
				wave.origin.x = _number(number, key, value)
			"y":
				wave.origin.y = _number(number, key, value)
			"count":
				wave.count = maxi(int(_number(number, key, value)), 1)
			"spacing":
				wave.spacing = maxf(_number(number, key, value), 0.0)
			"dx":
				wave.dx = _number(number, key, value)
			"pace":
				wave.pace = maxf(_number(number, key, value), 0.1)
			"variant":
				if value.length() < 2:
					errors.append("line %d: a variant is a group letter and an option, like variant=a1" % number)
				wave.variant_group = value.left(1)
				wave.variant_option = value.substr(1)
			_:
				errors.append("line %d: unknown wave option '%s'" % [number, word])
	waves.append(wave)


func _parse_ground(number: int, words: PackedStringArray) -> void:
	if words.size() < 4:
		errors.append("line %d: a ground object needs a time, a type and x=" % number)
		return
	var ground := GroundDef.new()
	ground.time = _number(number, "time", words[1])
	ground.type_id = EnemyTypes.from_key(words[2])
	if ground.type_id < 0 or not EnemyTypes.ALL[ground.type_id].ground:
		errors.append("line %d: unknown ground type '%s'" % [number, words[2]])
		return
	var has_x := false
	for i: int in range(3, words.size()):
		var word := words[i]
		if word == "mirror":
			ground.mirror = true
		elif word.begins_with("x="):
			ground.x = _number(number, "x", word.trim_prefix("x="))
			has_x = true
		else:
			errors.append("line %d: unknown ground option '%s'" % [number, word])
	if not has_x:
		errors.append("line %d: a ground object needs x=" % number)
	grounds.append(ground)


func _parse_boss(number: int, words: PackedStringArray) -> void:
	if words.size() < 2:
		errors.append("line %d: a boss line needs a boss type" % number)
		return
	var type_id := EnemyTypes.from_key(words[1])
	if type_id < 0 or not EnemyTypes.ALL[type_id].is_boss:
		errors.append("line %d: unknown boss '%s'" % [number, words[1]])
		return
	boss_type = type_id
	for i: int in range(2, words.size()):
		if words[i].begins_with("x="):
			boss_x = _number(number, "x", words[i].trim_prefix("x="))
		else:
			errors.append("line %d: unknown boss option '%s'" % [number, words[i]])


func _parse_boss_step(number: int, words: PackedStringArray) -> void:
	if words.size() < 3:
		errors.append("line %d: a boss_step needs a phase (1 or 2) and a pattern" % number)
		return
	var step := BossStep.new()
	var phase := words[1]
	if phase != "1" and phase != "2":
		errors.append("line %d: the boss_step phase is 1 or 2, not '%s'" % [number, phase])
		return
	step.pattern = ShotPatterns.from_name(words[2])
	if step.pattern < 0 or ShotPatterns.is_ship_pattern(step.pattern):
		errors.append("line %d: unknown enemy pattern '%s'" % [number, words[2]])
		return
	for i: int in range(3, words.size()):
		var key := words[i].get_slice("=", 0)
		var value := words[i].get_slice("=", 1)
		match key:
			"aim":
				var aim := BossStep.AIM_NAMES.find(value)
				if aim < 0:
					errors.append("line %d: aim is one of %s, not '%s'" % [number, ", ".join(BossStep.AIM_NAMES), value])
				else:
					step.aim = aim as BossStep.Aim
			"angle":
				step.angle = deg_to_rad(_number(number, key, value))
			"wait":
				step.wait = maxf(_number(number, key, value), 0.05)
			"dx":
				step.offset.x = _number(number, key, value)
			"dy":
				step.offset.y = _number(number, key, value)
			_:
				errors.append("line %d: unknown boss_step option '%s'" % [number, words[i]])
	if phase == "1":
		boss_steps_one.append(step)
	else:
		boss_steps_two.append(step)


func _number(number: int, key: String, value: String) -> float:
	if not value.is_valid_float():
		errors.append("line %d: %s should be a number, not '%s'" % [number, key, value])
		return 0.0
	return value.to_float()
