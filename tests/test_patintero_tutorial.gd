extends Node

const TUTORIAL := "res://src/UI/tutorial/patintero_tutorial.tscn"
const GAME := "res://games/Patintero/Scenes/main.tscn"
const GAME_SCRIPT := preload("res://games/Patintero/Scripts/patintero_game.gd")

var _failures := 0
var _capture_dir := ""
var _actions: Array[String] = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	get_tree().create_timer(35.0, true, false, true).timeout.connect(func() -> void:
		push_error("The Patintero tutorial test timed out")
		get_tree().quit(1)
	)
	call_deferred("_run")


func _run() -> void:
	get_tree().current_scene = null
	await get_tree().create_timer(0.7).timeout
	ScoreKeeper.reset()
	ScoreKeeper.add_round_scores([500, 250, 500, 250], &"tug_of_war")
	var starting_totals: Array[int] = ScoreKeeper.totals.duplicate()
	var starting_scores: Array[int] = ScoreKeeper.last_round_scores.duplicate()
	var spawn_order: Array[int] = GAME_SCRIPT._last_spawn_order.duplicate()
	GameSchedule.reset()
	GameSchedule.picked.assign(["patintero"])
	_check(GameSchedule.first_scene_path() == TUTORIAL, "Scheduled Patintero games enter their tutorial first")
	await SceneFader.change_scene(TUTORIAL)
	var tutorial := get_tree().current_scene
	var preview: Node2D = tutorial.get_node("Composition/GamePreview/SubViewport/Patintero")
	var key: TextureRect = tutorial.get_node("Composition/Key")
	var dash_key: TextureRect = tutorial.get_node("Composition/DashKey")
	preview.connect("demo_action_changed", func(action: String) -> void: _actions.append(action))
	_check(preview.get_viewport() != get_viewport() and preview.get_world_2d() != get_viewport().find_world_2d(), "The real court renders and simulates inside an isolated preview viewport")
	_check(preview.get_node("PauseMenu").process_mode == Node.PROCESS_MODE_DISABLED, "The preview cannot open its pause menu")
	var instructions: String = tutorial.get_node("Composition/Instructions").text
	var dash_instructions: String = tutorial.get_node("Composition/DashInstructions").text
	_check(instructions.contains("HOLD YOUR KEY") and instructions.contains("MOVE") and dash_instructions.contains("DOUBLE-TAP") and dash_instructions.contains("DASH"), "Separate key examples explain hold-to-move and double-tap-to-dash")
	_check(tutorial.get_node("Composition/AssignedKey").text == "A" and tutorial.get_node("Composition/DashAssignedKey").text == "A", "Both demonstrations display the same assigned player key")
	await _capture("patintero-tutorial")

	var saw_run := false
	var saw_dash := false
	var saw_finisher := false
	var furthest_x := 0.0
	var guard_start: Vector2 = preview.get_node("Platform").position
	var guard_moved := false
	var last_elapsed := float(preview.get("_demo_elapsed"))
	var hold_started := -1.0
	var longest_hold := 0.0
	var saw_hold_release := false
	var previous_dash_down: bool = dash_key.texture == tutorial.KEY_DOWN
	var dash_started := -1.0
	var dash_released := -1.0
	var previous_dash_press := -1.0
	var longest_dash_press := 0.0
	var longest_dash_release := 0.0
	var saw_double_tap := false
	var looped := false
	while not looped:
		await get_tree().physics_frame
		var elapsed := float(preview.get("_demo_elapsed"))
		looped = elapsed < last_elapsed
		last_elapsed = elapsed
		var now := Time.get_ticks_msec() / 1000.0
		if key.texture == tutorial.KEY_DOWN:
			if hold_started < 0.0:
				hold_started = now
			longest_hold = maxf(longest_hold, now - hold_started)
		else:
			hold_started = -1.0
			saw_hold_release = true
		var dash_down: bool = dash_key.texture == tutorial.KEY_DOWN
		if dash_down != previous_dash_down:
			if dash_down:
				if previous_dash_press >= 0.0 and now - previous_dash_press < 0.4:
					saw_double_tap = true
				if dash_released >= 0.0:
					longest_dash_release = maxf(longest_dash_release, now - dash_released)
				previous_dash_press = now
				dash_started = now
			else:
				if dash_started >= 0.0:
					longest_dash_press = maxf(longest_dash_press, now - dash_started)
				dash_released = now
			previous_dash_down = dash_down
		guard_moved = guard_moved or preview.get_node("Platform").position != guard_start
		var players: Array = preview.get("_players")
		for player in players:
			var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
			saw_run = saw_run or (sprite.is_playing() and sprite.animation == &"move")
			if sprite.is_playing() and sprite.animation == &"dash" and not saw_dash:
				saw_dash = true
				await _capture("patintero-tutorial-dash")
			furthest_x = maxf(furthest_x, player.position.x)
		saw_finisher = saw_finisher or not preview.get("_finish_order").is_empty()
	_check(saw_run and saw_dash and _actions.has("DOUBLE-TAP"), "The preview demonstrates normal running and the real double-tap dash animation")
	_check(guard_moved and _actions.has("WAIT"), "Live guards patrol while the demonstration waits for openings")
	_check(longest_hold >= 1.3 and saw_hold_release, "The movement key visibly stays held before releasing and repeating")
	_check(saw_double_tap and longest_dash_press > 0.0 and longest_dash_press < 0.3 and longest_dash_release >= 0.7, "The dash key repeats two quick presses followed by a clear pause")
	_check(furthest_x >= 316.0 and saw_finisher, "Demo runners cross scoring zones and reach the finish")
	_check(ScoreKeeper.totals == starting_totals and ScoreKeeper.last_round_scores == starting_scores, "An entire preview loop cannot alter earned scores")
	_check(GAME_SCRIPT._last_spawn_order == spawn_order and GameSchedule.current_game_index == 0, "The preview preserves lane-randomization history and the scheduled game")
	_check(not preview.get_node("HUD/Root/Timer").get("_running") and preview.get("_round_number") == 1, "The preview never starts a scored round or live round timer")
	_check(not Input.is_action_pressed("P1_Ready") and not Input.is_action_pressed("P2_Ready") and not Input.is_action_pressed("P3_Ready") and not Input.is_action_pressed("P4_Ready"), "Autoplay never presses global player inputs")

	var repeated_key := InputEventKey.new()
	repeated_key.keycode = KEY_SPACE
	repeated_key.pressed = true
	repeated_key.echo = true
	Input.parse_input_event(repeated_key)
	await get_tree().process_frame
	_check(get_tree().current_scene == tutorial, "Held-key repeats cannot dismiss the tutorial")
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		var window := get_window()
		window.size = Vector2i(1280, 800)
		window.content_scale_size = Vector2i(1280, 800)
		await get_tree().process_frame
		await get_tree().process_frame
		var composition: Control = tutorial.get_node("Composition")
		var end := composition.global_position + composition.size * composition.scale
		_check(composition.global_position.x >= 0.0 and composition.global_position.y >= 0.0 and end.x <= 1280.1 and end.y <= 800.1, "The tutorial fits a narrower window without clipping")
		await _capture("patintero-tutorial-1280x800")

	var music: AudioStreamPlayer = AudioManager.get("_game_music_player")
	var music_position := music.get_playback_position()
	for pressed in [true, false]:
		var proceed := InputEventKey.new()
		proceed.keycode = KEY_SPACE
		proceed.pressed = pressed
		Input.parse_input_event(proceed)
	while get_tree().current_scene == tutorial or SceneFader.get("_busy"):
		await get_tree().process_frame
	var game := get_tree().current_scene
	_check(game.scene_file_path == GAME and game.has_node("RoundIntro"), "A fresh key starts Patintero with its normal round-one countdown")
	_check(ScoreKeeper.totals == starting_totals and GameSchedule.next_scene_path == GAME, "Starting Patintero preserves scores and sets the actual game destination")
	_check(AudioManager.get("_game_music_player") == music and music.get_playback_position() > music_position, "Patintero music continues smoothly from tutorial to match")
	game.queue_free()
	get_tree().current_scene = null
	AudioManager.stop_game_music()
	await get_tree().create_timer(AudioManager.MUSIC_FADE_TIME + 0.15).timeout
	print("PATINTERO TUTORIAL: %d failure(s)" % _failures)
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
