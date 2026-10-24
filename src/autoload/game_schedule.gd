extends Node

signal roster_ready(picked: Array[String], skipped: String)

const ROUNDS := 4
const ROUND_RESULTS_SCENE := "res://src/UI/roundleaderboard/roundleaderboard.tscn"
const OVERALL_RESULTS_SCENE := "res://src/UI/overallleaderboard/overall_leaderboard.tscn"

const GAMES: Array[Dictionary] = [
	{
		"id": "tug_of_war",
		"name": "Tug of War",
		"icon": "res://assets/Minigame Randomizer/Game Icon Formatted/Tugofwar.png",
		"scene": "res://games/Tug Of war/tug_ofwar.tscn",
		"tutorial": "res://src/UI/tutorial/tug_of_war_tutorial.tscn",
	},
	{
		"id": "patintero",
		"name": "Patintero",
		"icon": "res://assets/Minigame Randomizer/Game Icon Formatted/Patintero.png",
		"scene": "res://games/Patintero/Scenes/main.tscn",
		"tutorial": "res://src/UI/tutorial/patintero_tutorial.tscn",
	},
	{
		"id": "chinese_garter",
		"name": "Chinese Garter",
		"icon": "res://assets/Minigame Randomizer/Game Icon Formatted/Chinesegarter.png",
		"scene": "res://games/Chinese Garter/chinese_garter.tscn",
		"tutorial": "res://src/UI/tutorial/chinese_garter_tutorial.tscn",
	},
	{
		"id": "tumbang_preso",
		"name": "Tumbang Preso",
		"icon": "res://assets/Minigame Randomizer/Game Icon Formatted/TumbangPreso.png",
		"scene": "res://games/Tumbang Preso/Scene/game.tscn",
		"tutorial": "res://src/UI/tutorial/tumbang_preso_tutorial.tscn",
	},
]

var picked: Array[String] = []
var skipped := ""
var next_scene_path := ""
var current_game_index := -1
var tug_round := 1

# Keep game picks independent from menu music and reel animation randomness.
var _rng := RandomNumberGenerator.new()
var _history_path := "user://game_schedule.cfg"
var _last_picked: Array[String] = []
var _last_skipped := ""
var _skip_pool: Array[String] = []


func _ready() -> void:
	_rng.randomize()
	_load_history()


func roll() -> Array[String]:
	reset()
	var pool: Array[String] = []
	for game in GAMES:
		pool.append(game["id"])
	skipped = _pick_skipped(pool)
	pool.erase(skipped)
	picked = []
	# Shuffle before filling extra slots so smaller rosters repeat a random game.
	# Every available game still plays at least once.
	_shuffle(pool)
	while picked.size() < ROUNDS:
		picked.append(pool[picked.size() % pool.size()])
	_shuffle(picked)
	_avoid_repeated_slots()
	_last_picked = picked.duplicate()
	_last_skipped = skipped
	_save_history()
	roster_ready.emit(picked, skipped)
	return picked


func _shuffle(items: Array[String]) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var id := items[i]
		items[i] = items[j]
		items[j] = id


func _pick_skipped(pool: Array[String]) -> String:
	# Play every game when the roster fits within the round count.
	if pool.size() <= ROUNDS:
		return ""
	# Every game sits out once per roster cycle, in a random order.
	if _skip_pool.is_empty():
		_skip_pool = pool.duplicate()
	var candidates: Array[String] = _skip_pool.duplicate()
	# Also prevent repeating the skipped game across cycle boundaries.
	candidates.erase(_last_skipped)
	var id := candidates[_rng.randi_range(0, candidates.size() - 1)]
	_skip_pool.erase(id)
	return id


func _avoid_repeated_slots() -> void:
	for slot in mini(picked.size(), _last_picked.size()):
		if picked[slot] != _last_picked[slot]:
			continue
		for other in picked.size():
			if picked[other] == picked[slot]:
				continue
			# Do not move a repeat into a slot that would then repeat too.
			if other < _last_picked.size() and picked[slot] == _last_picked[other]:
				continue
			var id := picked[slot]
			picked[slot] = picked[other]
			picked[other] = id
			break


func _load_history() -> void:
	var config := ConfigFile.new()
	if config.load(_history_path) != OK:
		return
	var last_picked: Variant = config.get_value("variety", "last_picked", [])
	var last_skipped: Variant = config.get_value("variety", "last_skipped", "")
	var skip_pool: Variant = config.get_value("variety", "skip_pool", [])
	if not _valid_history_ids(last_picked) or not _valid_history_ids(skip_pool):
		return
	if not last_skipped is String:
		return
	if GAMES.size() <= ROUNDS:
		if last_skipped != "" or not skip_pool.is_empty():
			return
	elif index_of(last_skipped) == -1:
		return
	if last_picked.size() != ROUNDS or last_picked.has(last_skipped) or skip_pool.has(last_skipped):
		return
	_last_picked.assign(last_picked)
	_last_skipped = last_skipped
	_skip_pool.assign(skip_pool)


func _valid_history_ids(value: Variant) -> bool:
	if not value is Array:
		return false
	for id in value:
		if not id is String or index_of(id) == -1:
			return false
	return true


func _save_history() -> void:
	var config := ConfigFile.new()
	config.set_value("variety", "last_picked", _last_picked)
	config.set_value("variety", "last_skipped", _last_skipped)
	config.set_value("variety", "skip_pool", _skip_pool)
	var error := config.save(_history_path)
	if error != OK:
		push_warning("Could not save game schedule history: %s" % error_string(error))


func load_icons() -> Array[Texture2D]:
	var icons: Array[Texture2D] = []
	for game in GAMES:
		icons.append(load(game["icon"]) as Texture2D)
	return icons


func index_of(id: String) -> int:
	for i in GAMES.size():
		if GAMES[i]["id"] == id:
			return i
	return -1


func name_of(id: String) -> String:
	var game := _find(id)
	if game.is_empty():
		return id
	var name: String = game["name"]
	return name


func scene_path_for(id: String) -> String:
	var game := _find(id)
	if game.is_empty():
		return ""
	var path: String = game["scene"]
	return path if ResourceLoader.exists(path) else ""


func _find(id: String) -> Dictionary:
	for game in GAMES:
		if game["id"] == id:
			return game
	return {}


func first_scene_path() -> String:
	if picked.is_empty():
		current_game_index = -1
		next_scene_path = ""
		return ""
	current_game_index = 0
	_prepare_current_game()
	return next_scene_path


func next_game_id() -> String:
	if current_game_index < 0 or current_game_index + 1 >= picked.size():
		return ""
	return picked[current_game_index + 1]


func is_last_game() -> bool:
	return current_game_index >= 0 and current_game_index == picked.size() - 1


func show_results() -> void:
	var destination := ROUND_RESULTS_SCENE
	if is_last_game():
		advance_game()
		destination = OVERALL_RESULTS_SCENE
	await SceneFader.change_scene(destination)


func advance_game() -> bool:
	if current_game_index < 0 or current_game_index >= picked.size():
		next_scene_path = ""
		return false
	current_game_index += 1
	if current_game_index >= picked.size():
		next_scene_path = ""
		return false
	_prepare_current_game()
	return true


func _prepare_current_game() -> void:
	var id := picked[current_game_index]
	if id == "tug_of_war":
		reset_tug_rounds()
	next_scene_path = _find(id).get("tutorial", scene_path_for(id))


func reset_tug_rounds() -> void:
	tug_round = 1


func advance_tug_round() -> bool:
	if tug_round >= 2:
		return false
	tug_round += 1
	return true


func reset() -> void:
	# Keep variety history when clearing the active run.
	picked = []
	skipped = ""
	next_scene_path = ""
	current_game_index = -1
	tug_round = 1
