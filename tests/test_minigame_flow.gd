extends Node

const RESULTS := "res://src/UI/roundleaderboard/roundleaderboard.tscn"
const OVERALL := "res://src/UI/overallleaderboard/overall_leaderboard.tscn"
const LOADING := "res://src/UI/ldscrn/ldscrn.tscn"
const MAIN_MENU := "res://src/UI/main/mainmenu.tscn"
# Consecutive Tug games must each play two rounds and have separate scores.
const LINEUP: Array[String] = ["patintero", "tug_of_war", "tug_of_war", "patintero"]

var _failures := 0
var _score_updates := 0
var _capture_dir := ""
var _leaderboard_start_scores: Array[int] = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	get_tree().create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		push_error("The minigame sequence did not finish within 60 seconds")
		get_tree().quit(1)
	)
	call_deferred("_run")


func _run() -> void:
	# Survive the real scene changes without replacing the test driver.
	get_tree().current_scene = null
	await get_tree().create_timer(0.7).timeout
	Engine.time_scale = 4.0
	ScoreKeeper.reset()
	GameSchedule.reset()
	ScoreKeeper.totals_changed.connect(_on_score_update)
	get_tree().scene_changed.connect(_on_scene_changed)
	GameSchedule.picked.assign(LINEUP)
	_check(GameSchedule.first_scene_path() == GameSchedule.scene_path_for(LINEUP[0]), "The first game initializes the schedule position and loading target")
	await SceneFader.change_scene(LOADING)

	var expected_totals: Array[int] = [0, 0, 0, 0]
	var expected_updates := 0
	for game_index in LINEUP.size():
		var game_id := LINEUP[game_index]
		var game := await _wait_for_scene(GameSchedule.scene_path_for(game_id))
		if game == null:
			get_tree().quit(1)
			return
		_check(GameSchedule.current_game_index == game_index, "Scheduled game %d starts in the revealed order" % (game_index + 1))
		_check(ScoreKeeper.totals == expected_totals, "Loading game %d preserves all earlier totals" % (game_index + 1))
		var previous_totals: Array[int] = expected_totals.duplicate()
		var scores: Array[int] = []
		if game_id == "patintero":
			scores = await _finish_patintero(game)
			expected_updates += 1
		else:
			scores = await _finish_tug(game)
			expected_updates += 2
		var points: Array[int] = []
		for player in scores.size():
			points.append(scores[player] * 10)
			expected_totals[player] += points[player]

		var results := await _wait_for_scene(RESULTS)
		if results == null:
			get_tree().quit(1)
			return
		_check(ScoreKeeper.last_round_scores == scores, "Game %d results contain both internal rounds" % (game_index + 1))
		_check(ScoreKeeper.totals == expected_totals, "Game %d credits exactly ×10 to the overall totals" % (game_index + 1))
		_check(_score_updates == expected_updates, "Game %d posts each result only once" % (game_index + 1))
		_check(_leaderboard_start_scores == previous_totals, "Game %d's leaderboard starts counting from the previous totals" % (game_index + 1))
		_check(results.get("_scores") == expected_totals, "Game %d's leaderboard includes points from every completed minigame" % (game_index + 1))
		await results.sort_finished
		for player in scores.size():
			var label: Label = results.get_node("Board/Row%d/Score" % (player + 1))
			_check(label.text == str(expected_totals[player]), "P%d visibly keeps all earned points on game %d's leaderboard" % [player + 1, game_index + 1])
		_check_standings(results, expected_totals, "Game %d ranks players by their cumulative totals" % (game_index + 1))
		_check(not results.has_node("Multiplier"), "The leaderboard has no multiplier subtitle")
		_check(ScoreKeeper.totals == expected_totals, "The leaderboard animation cannot credit the score twice")
		await get_tree().process_frame
		var next_id := LINEUP[game_index + 1] if game_index + 1 < LINEUP.size() else ""
		_check(GameSchedule.next_game_id() == next_id, "The next destination follows the schedule, including repeated games")
		var prompt: String = results.get_node("Continue").text
		_check(prompt.contains("OVERALL RESULTS" if next_id.is_empty() else GameSchedule.name_of(next_id).to_upper()), "The countdown announces the correct next screen")
		# Repeated finish callbacks must not skip a scheduled game.
		results.call("_on_sorted")
		await _capture("game-%d-multiplied-results" % (game_index + 1))

	var overall := await _wait_for_scene(OVERALL)
	if overall == null:
		get_tree().quit(1)
		return
	_check(GameSchedule.current_game_index == LINEUP.size() and GameSchedule.next_scene_path.is_empty(), "The schedule ends after exactly four minigames")
	_check(overall.get("_scores") == expected_totals, "The final leaderboard displays all four multiplied game awards")
	await overall.sort_finished
	for player in expected_totals.size():
		var label: Label = overall.get_node("Board/Row%d/Score" % (player + 1))
		_check(label.text == str(expected_totals[player]), "P%d's final score matches the cumulative minigame leaderboards" % (player + 1))
	await get_tree().create_timer(0.5).timeout
	await _capture("final-overall-results")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	var menu := await _wait_for_scene(MAIN_MENU)
	_check(menu != null, "The final results return to the main menu on input")
	_check(ScoreKeeper.totals == [0, 0, 0, 0] and ScoreKeeper.last_round_scores == [0, 0, 0, 0], "The next match starts with fresh scores")
	_check(GameSchedule.picked.is_empty() and GameSchedule.current_game_index == -1 and GameSchedule.tug_round == 1 and GameSchedule.tug_team_layouts.is_empty(), "Returning to the menu clears the lineup and Tug round state")
	_check(not GameSchedule.advance_game() and GameSchedule.next_scene_path.is_empty(), "An empty schedule cannot replay a stale minigame")
	Engine.time_scale = 1.0
	# Let audio playback release its streams before the headless runner exits.
	AudioManager.stop_menu_music()
	AudioManager.stop_game_music()
	var score_sound: AudioStreamPlayer = AudioManager.get("_score_player")
	score_sound.stop()
	await get_tree().create_timer(AudioManager.MUSIC_FADE_TIME + 0.15).timeout
	print("MINIGAME FLOW: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _finish_patintero(game: Node) -> Array[int]:
	await game.round_started
	_award_progress(game, [1024.0, 855.0, 582.0, 316.0])
	game.call("_on_round_timeout")
	game.call("_on_round_timeout")
	await game.round_started
	_award_progress(game, [316.0, 582.0, 855.0, 1024.0])
	game.call("_on_round_timeout")
	game.call("_on_round_timeout")
	return [105, 45, 45, 105]


func _finish_tug(game: Node) -> Array[int]:
	_check(GameSchedule.tug_round == 1, "Every scheduled Tug game starts at round one")
	await _wait_for_tug_intro(game)
	# Switching layouts leaves one player scoreless, exercising score carry-over.
	GameSchedule.tug_team_layouts[1] = not bool(game.get("cross_team_pairs"))
	var first_scores := ScoreEngine.tug_round_scores(0, bool(game.get("cross_team_pairs")))
	var old_instance := game.get_instance_id()
	game.call("_finish_winning_team", true)
	game.call("_finish_winning_team", false)
	game = await _wait_for_scene(GameSchedule.scene_path_for("tug_of_war"), old_instance)
	if game == null:
		get_tree().quit(1)
		return [0, 0, 0, 0]
	_check(GameSchedule.tug_round == 2, "Tug plays its second internal round before advancing the schedule")
	_check(ScoreKeeper.last_round_scores == first_scores, "Tug preserves round one's scores across its scene reload")
	await _wait_for_tug_intro(game)
	var second_scores := ScoreEngine.tug_round_scores(1, bool(game.get("cross_team_pairs")))
	var combined: Array[int] = []
	for player in first_scores.size():
		combined.append(first_scores[player] + second_scores[player])
	_check(combined.has(0), "A scoreless Tug player must still retain points from earlier minigames")
	game.call("_finish_winning_team", false)
	game.call("_finish_winning_team", true)
	return combined


func _wait_for_tug_intro(game: Node) -> void:
	while game.get("_round_intro_active"):
		await get_tree().process_frame


func _award_progress(game: Node, crossing_xs: Array) -> void:
	var players: Array = game.get("_players")
	for player in players.size():
		players[player].position.x = crossing_xs[player]
	game.call("_physics_process", 0.0)


func _wait_for_scene(path: String, previous_instance := 0) -> Node:
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == path and current.get_instance_id() != previous_instance and not SceneFader.get("_busy"):
			return current
		await get_tree().process_frame
	_check(false, "Timed out waiting for " + path)
	return null


func _on_score_update(_totals: Array[int]) -> void:
	_score_updates += 1


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != RESULTS:
		return
	_leaderboard_start_scores.clear()
	for player in range(4):
		var label: Label = scene.get_node("Board/Row%d/Score" % (player + 1))
		_leaderboard_start_scores.append(int(label.text))
	_check_standings(scene, _leaderboard_start_scores, "The next leaderboard opens in the previous standings order")


func _check_standings(board: Node, scores: Array[int], message: String) -> void:
	var order: Array[int] = [0, 1, 2, 3]
	order.sort_custom(func(a: int, b: int) -> bool:
		return a < b if scores[a] == scores[b] else scores[a] > scores[b]
	)
	var previous_y := -INF
	var ranked := true
	for player in order:
		var row: Control = board.get_node("Board/Row%d" % (player + 1))
		ranked = ranked and row.position.y > previous_y
		previous_y = row.position.y
	_check(ranked, message)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)


func _capture(filename: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(filename + ".png"))
	_check(error == OK, "Captured " + filename)
