extends "res://src/UI/tutorial/tutorial_screen.gd"

const GAME_SCRIPT := preload("res://games/Tumbang Preso/Script/game.gd")
const KEY_UP: Texture2D = preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P1.png")
const KEY_DOWN: Texture2D = preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P1.png")


func _init() -> void:
	next_scene_path = "res://games/Tumbang Preso/Scene/game.tscn"
	key_up_texture = KEY_UP
	key_down_texture = KEY_DOWN
	music_track = GAME_SCRIPT.MAIN_MUSIC


func _ready() -> void:
	$Composition/GamePreview/SubViewport/TumbangPreso/PauseMenu.process_mode = Node.PROCESS_MODE_DISABLED
	super._ready()


func _assigned_key() -> String:
	return "SPACE"
