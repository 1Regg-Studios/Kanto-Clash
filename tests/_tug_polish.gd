extends Node

const GAME := preload("res://games/Tug Of war/tug_ofwar.tscn")
const RESULTS := "res://src/UI/roundleaderboard/roundleaderboard.tscn"

var _failures := 0
var _score_updates := 0
var _capture_dir := "user://"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	call_deferred("_run")


func _run() -> void:
	# Keep the runner alive as a sibling while testing real scene changes.
	get_tree().current_scene = null
	ScoreKeeper.reset()
	ScoreKeeper.totals_changed.connect(_on_score_update)
	await get_tree().create_timer(0.7).timeout

	var game := await _start_game()
	await _capture("tug-polish-arena")
	var idle_puller: AnimatedSprite2D = game.get_node("World/P1")
	_check(idle_puller.is_playing(), "Puller animation starts before any input")
	var idle_frame := idle_puller.frame
	await get_tree().create_timer(0.25).timeout
	_check(idle_puller.is_playing() and idle_puller.frame != idle_frame, "Puller animation continues while players are idle")
	var rope: Line2D = game.get_node("World/Rope")
	_check(rope.texture != null and rope.width == 24.0, "Continuous textured rope is present")
	_check(not game.has_node("World/RopeConnector"), "Old oversized connector is removed")

	for frame in 4:
		for player in 4:
			var puller: AnimatedSprite2D = game.get_node("World/P%d" % (player + 1))
			puller.frame = frame
			var high_grip := frame == 0 or (player == 1 and frame == 3)
			var grip_row := 19.5 if high_grip else 20.5
			var grip_y := puller.position.y + (grip_row - 16.0 + puller.offset.y) * puller.scale.y
			_check(is_equal_approx(grip_y, rope.points[0].y), "P%d frame %d stays on the rope" % [player + 1, frame])
		await _capture("tug-polish-frame-%d" % frame)

	_tap(KEY_A)
	await get_tree().process_frame
	_check(game.get_node("HUD/Root/Composition/P1Indicator").texture == game.INDICATOR_PRESSED_TEXTURES[0], "Pull indicator still responds")
	await _capture("tug-polish-pull")
	var p1_puller: AnimatedSprite2D = game.get_node("World/P1")
	_check(p1_puller.is_playing(), "Pull input keeps the character animation active")
	await get_tree().create_timer(0.5).timeout
	_check(p1_puller.is_playing(), "The character animation continues after input stops")
	for _tap_index in 57:
		_tap(KEY_J)
	await get_tree().process_frame
	_check(game.get("_game_over"), "Team two can finish by pulling")
	_check(not game.get_node("World/P3").is_playing(), "Puller animations stop when the round ends")
	var prompt: Control = game.get_node("HUD/Root/GameOver")
	var card: Panel = prompt.get_node("Composition/Card")
	var entered_from: float = card.position.y
	await get_tree().create_timer(0.8).timeout
	_check(is_equal_approx(card.position.y, entered_from), "Result card stays in place during its fade-in")
	await get_tree().create_timer(0.8).timeout
	_check(is_equal_approx(card.position.y, entered_from), "Result card has no floating movement after entry")
	_check(prompt.get_node("Composition/Card/Winner").text == "TEAM 2 WINS!", "Winning team is shown")
	_check(not prompt.has_node("Restart"), "Enter restart prompt is removed")
	var final_rope: float = game.get("_rope_pos")
	_tap(KEY_ENTER)
	_tap(KEY_A)
	await get_tree().process_frame
	_check(game.get("_game_over") and game.get("_rope_pos") == final_rope, "Enter and pull keys cannot restart a finished round")
	await _capture("tug-polish-win")

	if DisplayServer.get_name() != "headless":
		var window := get_window()
		var original_size := window.size
		var original_content_size := window.content_scale_size
		window.size = Vector2i(1280, 800)
		window.content_scale_size = Vector2i(1280, 800)
		await get_tree().create_timer(0.2).timeout
		_check(get_viewport().get_visible_rect().size == Vector2(1280, 800), "Narrow-window check uses the requested viewport size")
		var card_end := card.global_position + card.size * card.get_global_transform().get_scale()
		_check(card.global_position.x >= 0.0 and card_end.x <= get_viewport().get_visible_rect().size.x, "Result card fits a narrower window")
		await _capture("tug-polish-win-1280x800")
		window.size = original_size
		window.content_scale_size = original_content_size

	await _expect_results([0, 0, 100, 100])
	await _capture("tug-polish-round-results")
	_check(ScoreKeeper.totals == [0, 0, 1000, 1000], "Winning scores are recorded once, multiplied by ten")

	game = await _start_game(1.2)
	_tap(KEY_A)
	await get_tree().process_frame
	game.set("_time_left", 0.01)
	await get_tree().create_timer(0.1).timeout
	_check(game.get_node("HUD/Root/GameOver/Composition/Card/Winner").text == "TEAM 1 WINS!", "Timer awards the leading team")
	await get_tree().create_timer(0.55).timeout
	await _capture("tug-polish-team-one")
	await _expect_results([100, 100, 0, 0])

	game = await _start_game(1.2)
	game.set("_time_left", 0.01)
	await get_tree().create_timer(0.1).timeout
	_check(game.get_node("HUD/Root/GameOver/Composition/Card/Winner").text == "DRAW!", "An even timer finish shows a draw")
	await get_tree().create_timer(0.55).timeout
	await _capture("tug-polish-draw")
	await _expect_results([50, 50, 50, 50])
	_check(ScoreKeeper.totals == [1500, 1500, 1500, 1500], "Round scores accumulate correctly, multiplied by ten")
	_check(_score_updates == 3, "Each result posts scores exactly once")
	print("TUG POLISH: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _start_game(display_seconds := 3.6) -> Node:
	var previous := get_tree().current_scene
	get_tree().current_scene = null
	if previous != null:
		previous.queue_free()
		await get_tree().process_frame
	var game := GAME.instantiate()
	game.get_node("HUD/Root/GameOver").display_seconds = display_seconds
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().process_frame
	await get_tree().process_frame
	return game


func _expect_results(expected: Array) -> void:
	for _attempt in 120:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == RESULTS:
			await get_tree().create_timer(1.1).timeout
			_check(ScoreKeeper.last_round_scores == expected, "Results receive the finished round's scores")
			var expected_points: Array[int] = []
			for score in expected:
				expected_points.append(int(score) * 10)
			_check(current.get("_scores") == expected_points, "Leaderboard animates the multiplied scores directly")
			return
		await get_tree().create_timer(0.05).timeout
	_check(false, "Finished round automatically redirects to the leaderboard")


func _tap(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)


func _on_score_update(_totals: Array[int]) -> void:
	_score_updates += 1


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _capture_dir.path_join(filename + ".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	_check(error == OK, "Saved " + filename)
