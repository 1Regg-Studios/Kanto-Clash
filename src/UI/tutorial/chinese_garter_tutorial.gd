extends "res://src/UI/tutorial/tutorial_screen.gd"

const GAME_SCRIPT := preload("res://games/Chinese Garter/chinese_garter_ui.gd")


func _init() -> void:
	next_scene_path = "res://games/Chinese Garter/chinese_garter.tscn"
	key_up_texture = GAME_SCRIPT.INDICATORS_IDLE[0]
	key_down_texture = GAME_SCRIPT.INDICATORS_PRESSED[0]
	music_track = GAME_SCRIPT.MAIN_MUSIC


func _assigned_key() -> String:
	return "SPACE"
