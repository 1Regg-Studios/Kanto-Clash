extends Node

const RESULTS := "res://src/UI/roundleaderboard/roundleaderboard.tscn"
const OVERALL := "res://src/UI/overallleaderboard/overall_leaderboard.tscn"
const LOADING := "res://src/UI/ldscrn/ldscrn.tscn"
const MAIN_MENU := "res://src/UI/main/mainmenu.tscn"
const OUTRO := "res://src/UI/story_outro/story_outro.tscn"
const TUTORIALS := {
	"tug_of_war": "res://src/UI/tutorial/tug_of_war_tutorial.tscn",
	"patintero": "res://src/UI/tutorial/patintero_tutorial.tscn",
	"chinese_garter": "res://src/UI/tutorial/chinese_garter_tutorial.tscn",
	"tumbang_preso": "res://src/UI/tutorial/tumbang_preso_tutorial.tscn",
}
# Consecutive Tug games must each play two rounds and have separate scores.
const LINEUP: Array[String] = ["chinese_garter", "tug_of_war", "tug_of_war", "patintero"]
const TUMBANG_LINEUP: Array[String] = ["chinese_garter", "tug_of_war", "tumbang_preso", "patintero"]

var _lineup: Array[String] = LINEUP.duplicate()
var _failures := 0
var _score_updates := 0
var _round_leaderboards := 0
var _capture_dir := ""
var _leaderboard_start_scores: Array[int] = []


func _ready() -> void:
	var last_game := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
		elif argument == "--with-tumbang-preso":
			_lineup = TUMBANG_LINEUP.duplicate()
		elif argument.begins_with("--last-game="):
			last_game = argument.trim_prefix("--last-game=")
	if not last_game.is_empty():
		if not _lineup.has(last_game):
			push_error("The requested final minigame is not in the test lineup: " + last_game)
			get_tree().quit(1)
			return
		_lineup.erase(last_game)
		_lineup.append(last_game)
	# Include the visible loading-screen crossfades and final audio fade-out.
	get_tree().create_timer(75.0, true, false, true).timeout.connect(func() -> void:
		push_error("The minigame sequence did not finish within 75 seconds")
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
	GameSchedule.picked.assign(_lineup)
	_check(GameSchedule.first_scene_path() == TUTORIALS[_lineup[0]], "The first game initializes the schedule position and tutorial loading target")
	await SceneFader.change_scene(LOADING)

	var expected_totals: Array[int] = [0, 0, 0, 0]
	var expected_updates := 0
	for game_index in _lineup.size():
		var game_id := _lineup[game_index]
		if TUTORIALS.has(game_id):
			var tutorial := await _wait_for_scene(TUTORIALS[game_id])
			if tutorial == null:
				get_tree().quit(1)
				return
			_check(ScoreKeeper.totals == expected_totals, "%s's tutorial preserves earlier scores" % GameSchedule.name_of(game_id))
			if game_id == "tug_of_war":
				_check(GameSchedule.tug_round == 1, "The Tug tutorial starts before round one")
			_check(tutorial.get_node("Composition/Continue").text == "GAME STARTS IN 5...", "The tutorial displays its automatic countdown")
			await _capture("game-%d-tutorial" % (game_index + 1))
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
		elif game_id == "chinese_garter":
			scores = await _finish_chinese_garter(game)
			expected_updates += 1
		elif game_id == "tumbang_preso":
			scores = _finish_tumbang_preso(game)
			expected_updates += 1
		else:
			scores = await _finish_tug(game)
			expected_updates += 2
		var points: Array[int] = []
		for player in scores.size():
			var multiplier := 1 if game_id == "tug_of_war" else (30 if game_id == "chinese_garter" else 10)
			if game_id == "tumbang_preso":
				multiplier = 2
			points.append(scores[player] * multiplier)
			expected_totals[player] += points[player]

		var is_final_game := game_index == _lineup.size() - 1
		var results := await _wait_for_scene(OVERALL if is_final_game else RESULTS)
		if results == null:
			get_tree().quit(1)
			return
		_check(ScoreKeeper.last_round_scores == scores, "Game %d results contain every player's complete score" % (game_index + 1))
		_check(ScoreKeeper.totals == expected_totals, "Game %d credits its exact leaderboard award to the overall totals" % (game_index + 1))
		_check(_score_updates == expected_updates, "Game %d posts each result only once" % (game_index + 1))
		_check(results.get("_scores") == expected_totals, "Game %d's leaderboard includes points from every completed minigame" % (game_index + 1))
		if is_final_game:
			_check(_round_leaderboards == _lineup.size() - 1, "The final minigame opens overall results directly without an extra round leaderboard")
			break
		_check(_leaderboard_start_scores == previous_totals, "Game %d's leaderboard starts counting from the previous totals" % (game_index + 1))
		await results.sort_finished
		for player in scores.size():
			var label: Label = results.get_node("Board/Row%d/Score" % (player + 1))
			_check(label.text == str(expected_totals[player]), "P%d visibly keeps all earned points on game %d's leaderboard" % [player + 1, game_index + 1])
		_check_standings(results, expected_totals, "Game %d ranks players by their cumulative totals" % (game_index + 1))
		_check(not results.has_node("Multiplier"), "The leaderboard has no multiplier subtitle")
		_check(ScoreKeeper.totals == expected_totals, "The leaderboard animation cannot credit the score twice")
		await get_tree().process_frame
		var next_id := _lineup[game_index + 1]
		_check(GameSchedule.next_game_id() == next_id, "The next destination follows the schedule, including repeated games")
		var prompt: String = results.get_node("Continue").text
		_check(prompt.contains(GameSchedule.name_of(next_id).to_upper()), "The countdown announces the correct next screen")
		# Repeated finish callbacks must not skip a scheduled game.
		results.call("_on_sorted")
		await _capture("game-%d-multiplied-results" % (game_index + 1))

	var overall := await _wait_for_scene(OVERALL)
	if overall == null:
		get_tree().quit(1)
		return
	_check(GameSchedule.current_game_index == _lineup.size() and GameSchedule.next_scene_path.is_empty(), "The schedule ends after exactly four minigames")
	_check(overall.get("_scores") == expected_totals, "The final leaderboard displays all four game awards")
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
	var outro := await _wait_for_scene(OUTRO)
	_check(outro != null, "Continuing from the final results plays the story outro")
	if outro == null:
		get_tree().quit(1)
		return
	await _capture("story-outro")
	var menu := await _wait_for_scene(MAIN_MENU)
	_check(menu != null, "The story outro returns to the main menu automatically")
	_check(ScoreKeeper.totals == [0, 0, 0, 0] and ScoreKeeper.last_round_scores == [0, 0, 0, 0], "The next match starts with fresh scores")
	_check(GameSchedule.picked.is_empty() and GameSchedule.current_game_index == -1 and GameSchedule.tug_round == 1, "Returning to the menu clears the lineup and Tug round state")
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


func _finish_chinese_garter(game: Node) -> Array[int]:
	for player_index in range(4):
		await game.turn_started
		_check(game.get("_turn_index") == player_index, "Chinese Garter gives P%d the next full-screen turn" % (player_index + 1))
		var gauge: Node2D = game.get_node("TimingGuage")
		gauge.set("t", (float(gauge.get("zone_start")) + float(gauge.get("zone_end"))) * 0.5)
		gauge.call("attempt_hit")
		game.set("_time_left", 0.001)
		game.call("_process", 0.01)
		game.call("_finish_turn")
	return [1, 1, 1, 1]


func _finish_tumbang_preso(game: Node) -> Array[int]:
	var controller: Node = game.get_node("Controller")
	controller.call("_clear_round_intro")
	var scores: Array[int] = [450, 0, 190, 50]
	controller.set("scores", scores)
	controller.call("show_final")
	controller.call("show_final")
	for pressed in [true, false]:
		var restart := InputEventKey.new()
		restart.keycode = KEY_SPACE
		restart.pressed = pressed
		Input.parse_input_event(restart)
	Input.flush_buffered_events()
	_check(controller.get("scores") == scores and not controller.is_processing_input(), "A scheduled Tumbang Preso result blocks restart presses during the leaderboard transition")
	return scores


func _finish_tug(game: Node) -> Array[int]:
	_check(GameSchedule.tug_round == 1, "Every scheduled Tug game starts at round one")
	await _wait_for_tug_intro(game)
	var first_scores: Array[int] = [500, 500, 250, 250]
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
	var second_scores: Array[int] = [500, 500, 250, 250]
	var combined: Array[int] = []
	for player in first_scores.size():
		combined.append(first_scores[player] + second_scores[player])
	game.call("_finish_winning_team", true)
	_check(game.get("_round_scores") == second_scores, "Round two keeps P1/P2 on Team 1 and P3/P4 on Team 2")
	game.call("_finish_winning_team", false)
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
	_round_leaderboards += 1
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
