extends Node

const TUTORIAL := "res://src/UI/tutorial/tug_of_war_tutorial.tscn"
const GAME := "res://games/Tug Of war/tug_ofwar.tscn"

var _failures := 0
var _capture_dir := ""
var _key_states: Array[bool] = []
var _tutorial_started_at := 0


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	get_tree().create_timer(25.0, true, false, true).timeout.connect(func() -> void:
		push_error("The Tug tutorial test timed out")
		get_tree().quit(1)
	)
	call_deferred("_run")


func _run() -> void:
	get_tree().current_scene = null
	await get_tree().create_timer(0.7).timeout
	ScoreKeeper.reset()
	ScoreKeeper.add_round_scores([10, 20, 30, 40], &"patintero")
	var starting_totals: Array[int] = ScoreKeeper.totals.duplicate()
	var starting_scores: Array[int] = ScoreKeeper.last_round_scores.duplicate()
	GameSchedule.reset()
	GameSchedule.picked.assign(["tug_of_war"])
	_check(GameSchedule.first_scene_path() == TUTORIAL, "Scheduled Tug games enter the tutorial first")
	get_tree().scene_changed.connect(func() -> void: _tutorial_started_at = Time.get_ticks_msec(), CONNECT_ONE_SHOT)
	await SceneFader.change_scene(TUTORIAL)
	var tutorial := get_tree().current_scene
	var countdown: Label = tutorial.get_node("Composition/Continue")
	var countdown_texts: Array[String] = [countdown.text]
	_check(countdown.text == "GAME STARTS IN 5...", "The tutorial announces its five-second automatic start")
	var preview: Node2D = tutorial.get_node("Composition/GamePreview/SubViewport/TugOfWar")
	var key: TextureRect = tutorial.get_node("Composition/Key")
	preview.connect("demo_key_changed", func(pressed: bool) -> void:
		_key_states.append(pressed)
		_check(key.texture == tutorial.KEY_DOWN if pressed else key.texture == tutorial.KEY_UP, "The large key follows the preview's press/release state")
	)
	_check(preview.get_viewport() != get_viewport(), "The actual Tug arena renders inside its own preview viewport")
	_check(not preview.is_processing_unhandled_input() and preview.get_node("PauseMenu").process_mode == Node.PROCESS_MODE_DISABLED, "The preview cannot accept gameplay input or open its pause menu")
	_check(not preview.get_node("World/P2").flip_h and preview.get_node("World/P3").flip_h, "The preview keeps P1/P2 facing P3/P4")
	_check(tutorial.get_node("Composition/Teams").text == "P1 + P2 VS P3 + P4", "The tutorial explains the fixed teams")
	_check(tutorial.get_node("Composition/AssignedKey").text == "A", "The tutorial shows Player 1's assigned input")

	while not _key_states.has(true) or not _key_states.has(false):
		await get_tree().process_frame
	await _capture("tug-tutorial")
	var puller: AnimatedSprite2D = preview.get_node("World/P1")
	_check(puller.is_playing(), "The preview plays the real pull animations")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_SPACE
	key_event.pressed = true
	key_event.echo = true
	Input.parse_input_event(key_event)
	await get_tree().process_frame
	_check(get_tree().current_scene == tutorial, "Held-key repeat events cannot skip the tutorial")

	# Thousands of demo pulls must not end a match or affect the live run.
	for player in 4:
		for _tap_index in 1000:
			preview.call("_demo_pull", player)
	_check(not preview.get("_game_over") and not preview.get("_results_started"), "The looping demonstration cannot finish a real round")
	_check(ScoreKeeper.totals == starting_totals and ScoreKeeper.last_round_scores == starting_scores, "Preview pulls cannot modify scores from earlier games")
	_check(GameSchedule.tug_round == 1, "Preview pulls preserve the scheduled round")
	_check(get_tree().current_scene == tutorial and not SceneFader.get("_busy"), "The tutorial stays visible until its countdown finishes")

	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		var window := get_window()
		window.size = Vector2i(1280, 800)
		window.content_scale_size = Vector2i(1280, 800)
		await get_tree().process_frame
		await get_tree().process_frame
		var composition: Control = tutorial.get_node("Composition")
		var end := composition.global_position + composition.size * composition.scale
		_check(composition.global_position.x >= 0.0 and composition.global_position.y >= 0.0 and end.x <= 1280.1 and end.y <= 800.1, "The tutorial fits a narrower window without clipping")
		await _capture("tug-tutorial-1280x800")

	for pressed in [true, false]:
		var proceed := InputEventKey.new()
		proceed.keycode = KEY_SPACE
		proceed.pressed = pressed
		Input.parse_input_event(proceed)
	Input.flush_buffered_events()
	await get_tree().process_frame
	_check(get_tree().current_scene == tutorial and not SceneFader.get("_busy"), "A fresh key press cannot skip the countdown")
	var transition_started_at := 0
	while get_tree().current_scene == tutorial or SceneFader.get("_busy"):
		if get_tree().current_scene == tutorial and not countdown_texts.has(countdown.text):
			countdown_texts.append(countdown.text)
		if transition_started_at == 0 and SceneFader.get("_busy"):
			transition_started_at = Time.get_ticks_msec()
		await get_tree().process_frame
	var countdown_seconds := (transition_started_at - _tutorial_started_at) / 1000.0
	_check(absf(countdown_seconds - 5.0) < 0.25, "The game transition starts automatically after five seconds")
	for seconds in range(5, 0, -1):
		_check(countdown_texts.has("GAME STARTS IN %d..." % seconds), "The visible countdown shows %d" % seconds)
	var game := get_tree().current_scene
	_check(game.scene_file_path == GAME, "The countdown starts the real Tug of War scene without input")
	_check(GameSchedule.tug_round == 1 and game.get("_round_intro_active"), "The match starts with its normal first-round countdown")
	_check(ScoreKeeper.totals == starting_totals, "Entering the match preserves all previous scores")
	game.queue_free()
	get_tree().current_scene = null
	AudioManager.stop_game_music()
	await get_tree().create_timer(AudioManager.MUSIC_FADE_TIME + 0.15).timeout
	print("TUG TUTORIAL: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


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
