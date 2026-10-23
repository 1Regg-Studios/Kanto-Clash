extends "res://src/UI/tutorial/tutorial_screen.gd"

const KEY_UP: Texture2D = preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P1.png")
const KEY_DOWN: Texture2D = preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P1.png")
const MAIN_MUSIC := preload("res://assets/Music/Main/Tug Of War/tatamusic-gaming-minecraft-game-gaming-music-423630.mp3")


func _init() -> void:
	next_scene_path = "res://games/Tug Of war/tug_ofwar.tscn"
	key_up_texture = KEY_UP
	key_down_texture = KEY_DOWN
	music_track = MAIN_MUSIC
