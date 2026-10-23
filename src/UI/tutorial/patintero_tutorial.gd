extends "res://src/UI/tutorial/tutorial_screen.gd"

const KEY_UP: Texture2D = preload("res://games/Patintero/UI/Player Press Indicator/Not Pressed/P1.png")
const KEY_DOWN: Texture2D = preload("res://games/Patintero/UI/Player Press Indicator/Pressed/P1.png")
const MAIN_MUSIC := preload("res://assets/Music/Main/Patintero/tatamusic-game-gaming-music-557995.mp3")

@onready var _dash_key: TextureRect = $Composition/DashKey
@onready var _dash_key_label: Label = $Composition/DashAssignedKey

var _dash_key_home := Vector2.ZERO


func _init() -> void:
	next_scene_path = "res://games/Patintero/Scenes/main.tscn"
	key_up_texture = KEY_UP
	key_down_texture = KEY_DOWN
	music_track = MAIN_MUSIC


func _ready() -> void:
	super._ready()
	_dash_key_home = _dash_key.position
	_dash_key_label.text = _assigned_key()
	_set_dash_key_pressed(false)

	var hold := create_tween().set_loops()
	hold.tween_callback(_on_demo_key_changed.bind(true))
	hold.tween_interval(1.6)
	hold.tween_callback(_on_demo_key_changed.bind(false))
	hold.tween_interval(0.55)

	var double_tap := create_tween().set_loops()
	double_tap.tween_callback(_set_dash_key_pressed.bind(true))
	double_tap.tween_interval(0.12)
	double_tap.tween_callback(_set_dash_key_pressed.bind(false))
	double_tap.tween_interval(0.1)
	double_tap.tween_callback(_set_dash_key_pressed.bind(true))
	double_tap.tween_interval(0.12)
	double_tap.tween_callback(_set_dash_key_pressed.bind(false))
	double_tap.tween_interval(1.0)


func _set_dash_key_pressed(pressed: bool) -> void:
	_dash_key.texture = KEY_DOWN if pressed else KEY_UP
	_dash_key.position = _dash_key_home + Vector2(0.0, 8.0 if pressed else 0.0)
	_dash_key.modulate = Color.WHITE if pressed else Color(0.65, 0.65, 0.65)
	_dash_key_label.add_theme_color_override("font_color", Color.WHITE if pressed else Color("fbc052"))
