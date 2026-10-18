extends Node

const WINDOWED_SIZE := Vector2i(1920, 1080)

var is_fullscreen := false


func _ready() -> void:
	if "--windowed" in OS.get_cmdline_user_args():
		set_fullscreen(false)
	else:
		set_fullscreen(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Toggle_Fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen)


func set_fullscreen(enabled: bool) -> void:
	is_fullscreen = enabled
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(WINDOWED_SIZE)
		_center_window()


func _center_window() -> void:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var position := usable.position + (usable.size - DisplayServer.window_get_size()) / 2
	DisplayServer.window_set_position(position)
