class_name RunRecords
extends RefCounted
## The personal best score on this PC (DESIGN.md §4), in user://records.cfg.
## Not saved by headless or autopilot (test) runs, so they don't change a real
## player's records. (Trimmed from Medieval Survival's RunRecords.)

const PATH: String = "user://records.cfg"


static func best_score(path: String = PATH) -> int:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return 0
	return int(config.get_value("best", "score", 0))


## Saves `score` if it beats the best. Returns true if it's a new best.
static func submit(score: int, path: String = PATH) -> bool:
	if score <= best_score(path):
		return false
	var test_run := LaunchOptions.autopilot or DisplayServer.get_name() == "headless"
	# Tests pass their own file; the real records file is left alone by test runs.
	if path != PATH or not test_run:
		var config := ConfigFile.new()
		config.load(path)
		config.set_value("best", "score", score)
		config.save(path)
	return true
