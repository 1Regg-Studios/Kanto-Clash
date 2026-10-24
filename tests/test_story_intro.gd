extends Node

const RANDOMIZER := "res://src/UI/randomizer/minigame_randomizer.tscn"
const INTRO := "res://src/UI/story_intro/story_intro.tscn"
const LOADING := "res://src/UI/ldscrn/ldscrn.tscn"
const TUTORIALS := {
	"tug_of_war": "res://src/UI/tutorial/tug_of_war_tutorial.tscn",
	"patintero": "res://src/UI/tutorial/patintero_tutorial.tscn",
	"chinese_garter": "res://src/UI/tutorial/chinese_garter_tutorial.tscn",
	"tumbang_preso": "res://src/UI/tutorial/tumbang_preso_tutorial.tscn",
}

var _failures := 0
var _intro_visits := 0
var _loading_visits := 0
var _capture_dir := ""
var _history_path := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	get_tree().create_timer(45.0, true, false, true).timeout.connect(func() -> void:
		push_error("The story intro test timed out")
		get_tree().quit(1)
	)
	call_deferred("_run")


func _run() -> void:
	get_tree().current_scene = null
	await get_tree().create_timer(0.7).timeout
	Engine.time_scale = 4.0
	ScoreKeeper.reset()
	GameSchedule.reset()
	_history_path = "user://test_story_intro_%d.cfg" % OS.get_process_id()
	GameSchedule.set("_history_path", _history_path)
	get_tree().scene_changed.connect(_on_scene_changed)

	# Exercise the real randomizer hand-off, including its scheduled tutorial.
	await SceneFader.change_scene(RANDOMIZER)
	var intro := await _wait_for_scene(INTRO)
	if intro == null:
		return
	# Capture at normal speed so rendering and window resizing cannot skip a shot.
	if not _capture_dir.is_empty():
		Engine.time_scale = 1.0
	var lineup: Array[String] = GameSchedule.picked.duplicate()
	var first_tutorial: String = TUTORIALS[lineup[0]]
	_check(GameSchedule.current_game_index == 0 and GameSchedule.next_scene_path == first_tutorial, "The randomizer shows the intro with the first tutorial already scheduled")
	_check(_intro_visits == 1 and _loading_visits == 0, "The story plays before the first loading screen")
	var first_panel: TextureRect = intro.get_node("Frame/Panel1")
	var initial_scale := first_panel.scale
	# Held-key repeats must not dismiss the story.
	await get_tree().create_timer(0.9).timeout
	var echo := InputEventKey.new()
	echo.keycode = KEY_SPACE
	echo.pressed = true
	echo.echo = true
	Input.parse_input_event(echo)
	Input.flush_buffered_events()
	_check(not intro.get("_finished") and first_panel.scale != initial_scale, "The picture animates while held-key repeats leave the intro playing")

	var shown: Array[String] = []
	while is_instance_valid(intro) and not intro.get("_finished"):
		var picture := ""
		for node_name in ["Panel1", "Panel2", "Panel3"]:
			var panel: TextureRect = intro.get_node("Frame/" + node_name)
			if panel.visible and panel.modulate.a >= 0.999:
				picture = panel.texture.resource_path.get_file()
		if not picture.is_empty() and not shown.has(picture):
			shown.append(picture)
			await _capture("intro-" + picture.get_basename())
			if picture == "2.png":
				await _check_narrow_layout(intro)
		await get_tree().process_frame
	_check(shown == ["1.png", "2.png", "3.png"], "The complete intro plays all three supplied pictures in numbered order")
	var tutorial := await _wait_for_scene(first_tutorial)
	if tutorial == null:
		return
	Engine.time_scale = 4.0
	_check(_loading_visits == 1 and GameSchedule.picked == lineup and GameSchedule.current_game_index == 0, "Automatic playback loads the first tutorial without advancing or rerolling the lineup")
	_check(ScoreKeeper.totals == [0, 0, 0, 0], "The story and its transitions preserve the match scores")

	# Every possible first minigame keeps its own destination when skipped.
	var game_ids: Array = TUTORIALS.keys()
	for index in game_ids.size():
		GameSchedule.reset()
		GameSchedule.picked.assign([game_ids[index]])
		GameSchedule.first_scene_path()
		await SceneFader.change_scene(INTRO)
		intro = get_tree().current_scene
		var skip: Button = intro.get_node("Frame/Skip")
		while skip.disabled:
			await get_tree().process_frame
		var loads_before := _loading_visits
		var input_name: String = ["Space", "Escape", "The skip button", "Controller confirm"][index]
		_send_skip(index, skip)
		Input.flush_buffered_events()
		_check(intro.get("_finished"), "%s responds immediately to a skip request" % input_name)
		# A second input during the fade cannot start another transition.
		_send_skip(0, skip)
		Input.flush_buffered_events()
		tutorial = await _wait_for_scene(TUTORIALS[game_ids[index]])
		if tutorial == null:
			return
		_check(_loading_visits == loads_before + 1 and GameSchedule.current_game_index == 0, "%s skips once to its correct tutorial" % input_name)

	# Subsequent games use the existing loading flow without repeating the story.
	GameSchedule.reset()
	GameSchedule.picked.assign(["tug_of_war", "patintero"])
	GameSchedule.first_scene_path()
	var visits_before := _intro_visits
	_check(GameSchedule.advance_game(), "The schedule can advance after the first minigame")
	await SceneFader.change_scene(LOADING)
	tutorial = await _wait_for_scene(TUTORIALS["patintero"])
	if tutorial == null:
		return
	_check(_intro_visits == visits_before and GameSchedule.current_game_index == 1, "Later minigames go straight to their tutorial without replaying the intro")
	tutorial.queue_free()
	get_tree().current_scene = null
	AudioManager.stop_menu_music()
	AudioManager.stop_game_music()
	await get_tree().create_timer(AudioManager.MUSIC_FADE_TIME + 0.15).timeout
	DirAccess.remove_absolute(_history_path)
	Engine.time_scale = 1.0
	print("STORY INTRO: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _send_skip(kind: int, skip: Button) -> void:
	for pressed in [true, false]:
		if kind == 2:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = skip.get_global_rect().get_center()
			click.pressed = pressed
			Input.parse_input_event(click)
		elif kind == 3:
			var button := InputEventJoypadButton.new()
			button.button_index = JOY_BUTTON_A
			button.pressed = pressed
			Input.parse_input_event(button)
		else:
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE if kind == 1 else KEY_SPACE
			key.pressed = pressed
			Input.parse_input_event(key)


func _check_narrow_layout(intro: Node) -> void:
	var window := get_window()
	window.size = Vector2i(1280, 800)
	window.content_scale_size = Vector2i(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	var frame: Control = intro.get_node("Frame")
	var end := frame.global_position + frame.size * frame.scale
	_check(frame.global_position.x >= 0.0 and frame.global_position.y >= 0.0 and end.x <= 1280.1 and end.y <= 800.1, "The intro fits a narrower screen without stretching or clipping its frame")
	_check(is_equal_approx(frame.scale.x, frame.scale.y), "Screen resizing preserves the artwork's aspect ratio")
	await _capture("intro-1280x800")


func _wait_for_scene(path: String) -> Node:
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == path and not SceneFader.get("_busy"):
			return scene
		await get_tree().process_frame
	_check(false, "Timed out waiting for " + path)
	get_tree().quit(1)
	return null


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene.scene_file_path == INTRO:
		_intro_visits += 1
	elif scene.scene_file_path == LOADING:
		_loading_visits += 1


func _capture(filename: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(filename + ".png"))
	_check(error == OK, "Captured " + filename)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)
