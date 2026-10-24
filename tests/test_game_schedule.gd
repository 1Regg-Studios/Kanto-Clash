extends Node

const SCHEDULE := preload("res://src/autoload/game_schedule.gd")
const GAME_IDS: Array[String] = ["tug_of_war", "patintero", "chinese_garter", "tumbang_preso"]
const BALANCE_SAMPLES := 1800

var _history_path := ""
var _failures := 0
var _signal_count := 0
var _signal_picked: Array[String] = []
var _signal_skipped := ""


func _ready() -> void:
	_history_path = "user://test_game_schedule_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	var schedule := _new_schedule()
	_test_variety(schedule)
	schedule = _test_history(schedule)
	_test_balanced_orders(schedule)
	schedule.free()
	DirAccess.remove_absolute(_history_path)
	print("GAME SCHEDULE: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _new_schedule() -> Node:
	var schedule := SCHEDULE.new()
	schedule._history_path = _history_path
	add_child(schedule)
	schedule.roster_ready.connect(_on_roster_ready)
	return schedule


func _test_variety(schedule: Node) -> void:
	schedule._rng.seed = 203
	var previous: Array[String] = []
	var orders: Dictionary = {}
	for run in 500:
		if run % 3 == 0:
			schedule.reset()
			_check(schedule.picked.is_empty() and schedule.current_game_index == -1 and schedule.next_scene_path == "", "Reset clears the active run")
		# Menu and animation randomness must not determine the game order.
		seed(42)
		var lineup := _roll(schedule)
		for slot in previous.size():
			_check(lineup[slot] != previous[slot], "Consecutive runs change every game slot")
		orders[",".join(lineup)] = true
		previous = lineup.duplicate()
	_check(orders.size() == 24, "All 24 four-game orders remain reachable across runs")
	print("[test] 500 rolls: %d distinct orders" % orders.size())


func _test_history(schedule: Node) -> Node:
	var previous: Array[String] = schedule.picked.duplicate()
	schedule.reset()
	schedule.free()
	var restored := _new_schedule()
	_check(restored.picked.is_empty() and restored.current_game_index == -1, "Loading history does not resume an active match")
	_check(restored._last_picked == previous, "The previous order survives reset and restart")
	var lineup := _roll(restored)
	for slot in previous.size():
		_check(lineup[slot] != previous[slot], "The first roll after restarting respects the saved game order")
	var first_tutorial: String = SCHEDULE.GAMES[restored.index_of(lineup[0])]["tutorial"]
	_check(restored.first_scene_path() == first_tutorial, "The first randomized game determines the tutorial destination")
	for slot in range(1, lineup.size()):
		_check(restored.next_game_id() == lineup[slot] and restored.advance_game(), "Game progression follows the randomized order")
	_check(restored.is_last_game() and not restored.advance_game(), "The randomized schedule ends after four games")
	return restored


func _test_balanced_orders(schedule: Node) -> void:
	schedule._rng.seed = 20261024
	var counts: Dictionary = {}
	for trial in BALANCE_SAMPLES:
		# Hold history constant to measure the choice among its nine valid orders.
		schedule._last_picked = GAME_IDS.duplicate()
		var lineup := _roll(schedule)
		for slot in GAME_IDS.size():
			_check(lineup[slot] != GAME_IDS[slot], "A balanced roll still avoids previous-slot repeats")
		var key := ",".join(lineup)
		counts[key] = int(counts.get(key, 0)) + 1
	_check(counts.size() == 9, "All nine orders without previous-slot repeats are possible")
	var lowest := BALANCE_SAMPLES
	var highest := 0
	# A fixed seed makes this reproducible; the wide bounds catch systematic bias.
	var expected := float(BALANCE_SAMPLES) / 9.0
	for count: int in counts.values():
		lowest = mini(lowest, count)
		highest = maxi(highest, count)
		_check(count >= expected * 0.5 and count <= expected * 1.5, "Valid game orders receive comparable chances (observed %d, expected about %.0f)" % [count, expected])
	print("[test] %d rolls / nine valid orders: frequencies %d-%d (expected %.0f)" % [BALANCE_SAMPLES, lowest, highest, expected])


func _roll(schedule: Node) -> Array[String]:
	var previous_signals := _signal_count
	var lineup: Array[String] = schedule.roll()
	_check(lineup.size() == 4 and schedule.skipped == "", "Each roll schedules four games with none skipped")
	for id in GAME_IDS:
		_check(lineup.count(id) == 1, "Each available game appears exactly once")
	_check(_signal_count == previous_signals + 1 and _signal_picked == lineup and _signal_skipped == "", "Each roll emits the actual randomized lineup exactly once")
	return lineup


func _on_roster_ready(lineup: Array[String], skipped: String) -> void:
	_signal_count += 1
	_signal_picked = lineup.duplicate()
	_signal_skipped = skipped


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[test] FAIL: ", message)
