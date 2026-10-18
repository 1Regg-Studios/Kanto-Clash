extends Node

const SCHEDULE := preload("res://src/autoload/game_schedule.gd")
const VALID_PICKED: Array[String] = ["patintero", "tug_of_war", "chinese_garter", "sipa"]

var _history_path := ""
var _failures := 0
var _completed_suites := 0
var _signal_count := 0
var _signal_picked: Array[String] = []
var _signal_skipped := ""


func _ready() -> void:
	_history_path = "user://test_game_schedule_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_variety()
	_test_invalid_history()
	_check(_completed_suites == 2, "All test suites must complete without script errors")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_history_path))
	print("[test] game schedule: ", "PASS" if _failures == 0 else "FAIL (%d checks)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _new_schedule() -> Node:
	var schedule := SCHEDULE.new()
	# Never overwrite the player's saved variety history.
	schedule._history_path = _history_path
	add_child(schedule)
	schedule._rng.seed = 20261019
	schedule.roster_ready.connect(_on_roster_ready)
	return schedule


func _test_variety() -> void:
	var schedule := _new_schedule()
	var previous: Array[String] = []
	var previous_skipped := ""
	var cycle_skips: Dictionary = {}
	var cycle_plays: Dictionary = {}
	var lineups: Dictionary = {}
	var seen_by_slot: Array[Dictionary] = [{}, {}, {}, {}]
	for run in 500:
		if run > 0 and run % 7 == 0:
			# Recreate the singleton to exercise history loading like an app restart.
			schedule.free()
			schedule = _new_schedule()
			_check(schedule.picked.is_empty(), "Loading history must not resume an active run")
		if run % 3 == 0:
			schedule.next_scene_path = "res://placeholder.tscn"
			schedule.reset()
			_check(schedule.picked.is_empty() and schedule.skipped == "" and schedule.next_scene_path == "", "Reset must clear the active run")
		seed(42)
		var picked: Array[String] = schedule.roll()
		_check_valid_roster(schedule)
		_check(_signal_count == run + 1, "Each roll must emit exactly one roster_ready signal")
		_check(_signal_picked == picked and _signal_skipped == schedule.skipped, "Signal must match the returned roster")
		if not previous.is_empty():
			_check(schedule.skipped != previous_skipped, "Consecutive runs must skip different games, including cycle boundaries")
			_check(picked.has(previous_skipped), "The previously skipped game must return next run")
			for slot in picked.size():
				_check(picked[slot] != previous[slot], "Game repeated in slot %d on run %d" % [slot, run])
		for slot in picked.size():
			var id := picked[slot]
			seen_by_slot[slot][id] = true
			cycle_plays[id] = int(cycle_plays.get(id, 0)) + 1
		cycle_skips[schedule.skipped] = int(cycle_skips.get(schedule.skipped, 0)) + 1
		if (run + 1) % 5 == 0:
			for game in SCHEDULE.GAMES:
				_check(cycle_skips.get(game["id"], 0) == 1, "Every game must sit out once per five-run cycle")
				_check(cycle_plays.get(game["id"], 0) == 4, "Every game must be played four times per five-run cycle")
			cycle_skips.clear()
			cycle_plays.clear()
		lineups[str(picked)] = true
		previous = picked.duplicate()
		previous_skipped = schedule.skipped
	for slot in seen_by_slot.size():
		_check(seen_by_slot[slot].size() == SCHEDULE.GAMES.size(), "Every game must be able to appear in slot %d" % slot)
	print("[test] 500 rolls / 100 skip cycles / 71 history reloads; distinct lineups: ", lineups.size())
	schedule.free()
	_completed_suites += 1


func _test_invalid_history() -> void:
	var invalid_values: Array[Dictionary] = [
		{"last_picked": "not an array"},
		{"last_picked": ["patintero", "tug_of_war", "sipa"]},
		{"last_picked": ["patintero", "patintero", "chinese_garter", "sipa"]},
		{"last_picked": ["unknown_game", "tug_of_war", "chinese_garter", "sipa"]},
		{"last_picked": [42, "tug_of_war", "chinese_garter", "sipa"]},
		{"last_skipped": "patintero"},
		{"last_skipped": 42},
		{"skip_pool": "not an array"},
		{"skip_pool": ["patintero", "patintero"]},
		{"skip_pool": ["tumbang_preso"]},
	]
	for values in invalid_values:
		var config := ConfigFile.new()
		config.set_value("variety", "last_picked", VALID_PICKED)
		config.set_value("variety", "last_skipped", "tumbang_preso")
		config.set_value("variety", "skip_pool", ["patintero", "tug_of_war"])
		for key in values:
			config.set_value("variety", key, values[key])
		_check(config.save(_history_path) == OK, "Could not create history fixture")
		var schedule := _new_schedule()
		_check(schedule._last_picked.is_empty() and schedule._skip_pool.is_empty(), "Invalid history must be ignored")
		schedule.roll()
		_check_valid_roster(schedule)
		schedule.free()
	print("[test] invalid history recovery: ", invalid_values.size(), " cases")
	_completed_suites += 1


func _check_valid_roster(schedule: Node) -> void:
	var picked: Array[String] = schedule.picked
	_check(picked.size() == SCHEDULE.ROUNDS, "Every run must contain exactly four games")
	var unique: Dictionary = {}
	for id in picked:
		_check(schedule.index_of(id) >= 0 and not unique.has(id), "Roster contains an unknown or duplicate game")
		unique[id] = true
	_check(schedule.index_of(schedule.skipped) >= 0 and not unique.has(schedule.skipped), "Skipped game must be the one unpicked game")


func _on_roster_ready(picked: Array[String], skipped: String) -> void:
	_signal_count += 1
	_signal_picked = picked.duplicate()
	_signal_skipped = skipped


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[test] FAIL: ", message)
