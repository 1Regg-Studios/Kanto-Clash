extends Control

const READY_SCENE := "res://src/UI/rdyplyr/rdyplyr.tscn"
const OPTIONS_SCENE := preload("res://src/UI/options/options.tscn")
const LOGO_ZOOM := 1.03
const LOGO_ZOOM_TIME := 2.0
const LOGO_FLOAT_DISTANCE := 10.0
const LOGO_FLOAT_TIME := 2.6

@onready var _logo: TextureRect = $Logo
@onready var _start: TextureButton = $START
@onready var _options: TextureButton = $OPTIONS
@onready var _quit: TextureButton = $QUIT
@onready var _mute: TextureButton = $MuteButton

var _transitioning := false
var _options_screen: Node = null


func _ready() -> void:
	AudioManager.stop_game_music()
	AudioManager.start_menu_music()
	_animate_logo()
	for button in [_start, _options, _quit]:
		button.pressed.connect(AudioManager.play_click)


func _animate_logo() -> void:
	_logo.pivot_offset = _logo.size * 0.5
	var zoom := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(_logo, "scale", Vector2.ONE * LOGO_ZOOM, LOGO_ZOOM_TIME)
	zoom.tween_property(_logo, "scale", Vector2.ONE, LOGO_ZOOM_TIME)

	var home_top := _logo.offset_top
	var home_bottom := _logo.offset_bottom
	var float_tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(_logo, "offset_top", home_top - LOGO_FLOAT_DISTANCE, LOGO_FLOAT_TIME)
	float_tween.parallel().tween_property(_logo, "offset_bottom", home_bottom - LOGO_FLOAT_DISTANCE, LOGO_FLOAT_TIME)
	float_tween.tween_property(_logo, "offset_top", home_top, LOGO_FLOAT_TIME)
	float_tween.parallel().tween_property(_logo, "offset_bottom", home_bottom, LOGO_FLOAT_TIME)


func _on_start_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_set_buttons_disabled(true)
	await SceneFader.change_scene(READY_SCENE)


func _on_options_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_set_buttons_disabled(true)
	_options_screen = OPTIONS_SCENE.instantiate()
	_options_screen.connect("closed", _on_options_closed)
	add_child(_options_screen)


func _on_options_closed() -> void:
	if _options_screen != null:
		_options_screen.queue_free()
		_options_screen = null
	_transitioning = false
	_set_buttons_disabled(false)


func _on_quit_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_set_buttons_disabled(true)
	await SceneFader.fade_out()
	get_tree().quit()


func _set_buttons_disabled(disabled: bool) -> void:
	for button in [_start, _options, _quit, _mute]:
		button.disabled = disabled
