extends Control

const READY_SCENE := "res://src/UI/rdyplyr/rdyplyr.tscn"
const OPTIONS_SCENE := preload("res://src/UI/options/options.tscn")

@onready var _start: TextureButton = $START
@onready var _options: TextureButton = $OPTIONS
@onready var _quit: TextureButton = $QUIT
@onready var _mute: TextureButton = $MuteButton

var _transitioning := false
var _options_screen: Node = null


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
	_start.disabled = disabled
	_options.disabled = disabled
	_quit.disabled = disabled
	_mute.disabled = disabled
