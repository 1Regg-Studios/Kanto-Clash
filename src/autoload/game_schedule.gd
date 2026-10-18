extends Node

signal roster_ready(picked: Array[String], skipped: String)

const ROUNDS := 4

const GAMES: Array[Dictionary] = [
	{
		"id": "patintero",
		"name": "Patintero",
		"icon": "res://assets/Minigame Randomizer/Game Icon Formatted/Patintero.png",
		"scene": "res://games/patintero/patintero.tscn",
	},
	{
		"id": "tug_of_war",
		"name": "Tug of War",
		"icon": "res://assets/Minigame Randomizer/Game Icon Formatted/Tugofwar.png",
		"scene": "res://games/tug_of_war/tug_of_war.tscn",
	},
	{
		"id": "chinese_garter",
		"name": "Chinese Garter",
		"icon": "res://assets/Minigame Randomizer/Game Icon Formatted/Chinesegarter.png",
		"scene": "res://games/chinese_garter/chinese_garter.tscn",
	},
	{
		"id": "sipa",
		"name": "Sipa",
		"icon": "res://assets/Minigame Randomizer/Game Icon Formatted/Sipa.png",
		"scene": "res://games/sipa/sipa.tscn",
	},
	{
		"id": "tumbang_preso",
		"name": "Tumbang Preso",
		"icon": "res://assets/Minigame Randomizer/Game Icon Formatted/TumbangPreso.png",
		"scene": "res://games/tumbang_preso/tumbang_preso.tscn",
	},
]

var picked: Array[String] = []
var skipped := ""
var next_scene_path := ""

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
	var pool: Array[String] = []
	for game in GAMES:
		pool.append(game["id"])
	skipped = _pick_skipped(pool)
	pool.erase(skipped)
	picked = []
	for _round in ROUNDS:
		var index := _rng.randi_range(0, pool.size() - 1)
		picked.append(pool.pop_at(index))
	_avoid_repeated_slots()
	_last_picked = picked.duplicate()
	_last_skipped = skipped
	_save_history()
	roster_ready.emit(picked, skipped)
	return picked


func _pick_skipped(pool: Array[String]) -> String:
	# Every game sits out once per five-run cycle, in a random order.
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
		var other := _rng.randi_range(0, picked.size() - 2)
		if other >= slot:
			other += 1
		# Unique IDs mean moving a matched game cannot create a repeat elsewhere.
		var id := picked[slot]
		picked[slot] = picked[other]
		picked[other] = id


func _load_history() -> void:
	var config := ConfigFile.new()
	if config.load(_history_path) != OK:
		return
	var last_picked: Variant = config.get_value("variety", "last_picked", [])
	var last_skipped: Variant = config.get_value("variety", "last_skipped", "")
	var skip_pool: Variant = config.get_value("variety", "skip_pool", [])
	if not _valid_history_ids(last_picked) or not _valid_history_ids(skip_pool):
		return
	if not last_skipped is String or index_of(last_skipped) == -1:
		return
	if last_picked.size() != ROUNDS or last_picked.has(last_skipped) or skip_pool.has(last_skipped):
		return
	_last_picked.assign(last_picked)
	_last_skipped = last_skipped
	_skip_pool.assign(skip_pool)


func _valid_history_ids(value: Variant) -> bool:
	if not value is Array:
		return false
	var seen: Array[String] = []
	for id in value:
		if not id is String or index_of(id) == -1 or seen.has(id):
			return false
		seen.append(id)
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
		return ""
	return scene_path_for(picked[0])


func reset() -> void:
	# Keep variety history when clearing the active run.
	picked = []
	skipped = ""
	next_scene_path = ""
