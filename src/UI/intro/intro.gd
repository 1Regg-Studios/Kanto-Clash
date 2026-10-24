extends Control

const MENU_LOADING_SCENE := "res://src/UI/ldscrn/main_menu_loading.tscn"
const START_DELAY := 0.5
const FADE_IN_TIME := 0.6
const HOLD_TIME := 1.2
const FADE_OUT_TIME := 0.6

@onready var _logo: TextureRect = $Logo
@onready var _audio: AudioStreamPlayer = $IntroAudio

var _finished := false


func _ready() -> void:
	_logo.modulate.a = 0.0
	await get_tree().create_timer(START_DELAY).timeout
	if _finished:
		return
	_audio.play()
	var tween := create_tween()
	tween.tween_property(_logo, "modulate:a", 1.0, FADE_IN_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(_logo, "modulate:a", 0.0, FADE_OUT_TIME)
	await tween.finished
	await _go_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_go_to_main_menu()
	elif event is InputEventMouseButton and event.pressed:
		_go_to_main_menu()
	elif event is InputEventJoypadButton and event.pressed:
		_go_to_main_menu()


func _go_to_main_menu() -> void:
	if _finished:
		return
	_finished = true
	_audio.stop()
	await SceneFader.change_scene(MENU_LOADING_SCENE)
