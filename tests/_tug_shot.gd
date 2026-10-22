extends Node


func _ready() -> void:
	var packed: PackedScene = load("res://games/Tug Of war/tug_ofwar.tscn")
	var game: Node = packed.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	_capture("res://tests/_tug_shot.png")

	_press(KEY_A)
	await get_tree().process_frame
	await get_tree().process_frame
	_capture("res://tests/_tug_shot_pressed.png")

	await get_tree().create_timer(1.4).timeout
	_capture("res://tests/_tug_shot_timer.png")

	for _i in 56:
		_press(KEY_J)
	await get_tree().process_frame
	await get_tree().process_frame
	_capture("res://tests/_tug_shot_gameover.png")

	_press(KEY_ENTER)
	await get_tree().process_frame
	await get_tree().process_frame
	_capture("res://tests/_tug_shot_restart.png")
	get_tree().quit()


func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)


func _capture(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("saved ", path)
