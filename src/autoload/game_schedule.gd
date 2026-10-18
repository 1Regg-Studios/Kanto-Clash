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


func roll() -> Array[String]:
	var pool: Array[String] = []
	for game in GAMES:
		pool.append(game["id"])
	pool.shuffle()
	picked = []
	for i in ROUNDS:
		picked.append(pool[i])
	skipped = pool[ROUNDS]
	roster_ready.emit(picked, skipped)
	return picked


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
	picked = []
	skipped = ""
	next_scene_path = ""
