extends Node

var _failures := 0


func _ready() -> void:
	await _test_patintero_progress()
	await _test_tug_scoring_wiring()
	_test_score_carry_over_isolation()
	await _test_numbered_tug_results()
	_test_tug_outcome_combinations()
	_test_tumbang_preso_scoring()
	await _test_leaderboard_replay()
	await _test_instant_leaderboard_scores()
	_check(ScoreEngine.patintero_zone_score(&"zone_1") == 10, "Patintero Zone 1 awards 10 points")
	_check(ScoreEngine.patintero_zone_score(&"zone_2") == 20, "Patintero Zone 2 awards 20 points")
	_check(ScoreEngine.patintero_zone_score(&"zone_3") == 30, "Patintero Zone 3 awards 30 points")
	_check(ScoreEngine.patintero_zone_score(&"fn") == 40, "FN is Patintero's highest-value zone")
	_check(ScoreEngine.award_points(&"patintero", 60, 40) == 100, "A complete Patintero run earns 100 base zone points")
	_check(ScoreEngine.award_points(&"patintero", 200, 40) == 200, "Patintero's game cap accommodates the largest finish bonus")
	_check(ScoreEngine.clamp_score(&"patintero", 140) == 140 and ScoreEngine.clamp_score(&"patintero", 240) == 200, "Patintero retains placement bonuses within its 200-point cap")
	var finish_scores: Array[int] = []
	for finish_place in range(1, 5):
		finish_scores.append(ScoreEngine.patintero_round_score(100, finish_place))
	_check(finish_scores == [200, 180, 160, 140], "First through fourth place apply x2, x1.8, x1.6, and x1.4")
	_check(ScoreEngine.patintero_round_score(60, 0) == 60, "Unfinished runners retain their earned zone points without a finish bonus")
	_check(ScoreEngine.patintero_round_score(7, 2) == 13, "Fractional placement bonuses round up rather than truncate")
	_check(ScoreEngine.patintero_round_score(5, 4) == 7, "An exact whole-number bonus does not round up an extra point")
	_check(ScoreEngine.tug_round_scores(0) == [500, 500, 250, 250], "Tug Team 1 always awards wins to P1/P2 and losses to P3/P4")
	_check(ScoreEngine.tug_round_scores(1) == [250, 250, 500, 500], "Tug Team 2 always awards wins to P3/P4 and losses to P1/P2")
	_check(ScoreEngine.tug_round_scores(-1) == [125, 125, 125, 125], "Tug draws award exactly 125 points to every player")
	var tug_win_scores := ScoreEngine.tug_round_scores(0)
	_check(tug_win_scores[0] <= ScoreEngine.TUG_ROUND_WIN_SCORE and tug_win_scores[1] <= ScoreEngine.TUG_ROUND_WIN_SCORE, "A Tug round stays inside its game score budget")
	var tug_two_rounds: Array[int] = [0, 0, 0, 0]
	for tug_round_scores in [ScoreEngine.tug_round_scores(0), ScoreEngine.tug_round_scores(0)]:
		for player_index in tug_two_rounds.size():
			tug_two_rounds[player_index] = ScoreEngine.award_points(&"tug_of_war", tug_two_rounds[player_index], tug_round_scores[player_index])
	_check(tug_two_rounds == [1000, 1000, 500, 500], "Two Tug rounds award 1000 for two wins and 500 for two losses to the fixed teams")
	_check(ScoreEngine.score_cap(&"chinese_garter") == 100 and ScoreEngine.score_cap(&"sipa") == 100, "Chinese Garter and Sipa keep their 100-point score budget")
	_check(ScoreEngine.score_cap(&"tumbang_preso") == 450, "Tumbang Preso retains all three perfect throws within its score cap")
	ScoreKeeper.reset()
	ScoreKeeper.add_round_scores([240, -4, 10, 0], &"patintero")
	_check(ScoreKeeper.last_round_scores == [200, 0, 10, 0], "ScoreKeeper applies the selected game's cap before recording a round")
	_check(ScoreKeeper.totals == [2000, 0, 100, 0], "Overall leaderboard totals are ten times the capped round scores")
	ScoreKeeper.add_round_scores([500, 500, 250, 250], &"tug_of_war")
	ScoreKeeper.add_round_scores([500, 500, 250, 250], &"tug_of_war", true)
	_check(ScoreKeeper.last_round_scores == [1000, 1000, 500, 500], "The Tug result preserves both rounds across scene reloads")
	_check(ScoreKeeper.last_round_points() == [1000, 1000, 500, 500], "Tug's complete leaderboard award is not multiplied a second time")
	_check(ScoreKeeper.totals == [3000, 1000, 600, 500], "Appending round two does not multiply or credit round one again")
	ScoreKeeper.add_round_scores([500, 1000, 1000, 1000], &"tug_of_war", true)
	_check(ScoreKeeper.last_round_scores == [1000, 1000, 1000, 1000], "Combined rounds cannot exceed the minigame score cap")
	_check(ScoreKeeper.totals == [3000, 1000, 1100, 1000], "Only points within the combined cap reach the overall totals")
	ScoreKeeper.add_round_scores([125, 125, 125, 125], &"tug_of_war")
	_check(ScoreKeeper.last_round_scores == [125, 125, 125, 125], "A new instance of the same minigame starts a fresh result")
	ScoreKeeper.add_round_scores([125, 125, 125, 125], &"tug_of_war", true)
	_check(ScoreKeeper.last_round_points() == [250, 250, 250, 250], "Drawing both Tug rounds awards exactly 250 leaderboard points")
	ScoreKeeper.reset()
	ScoreKeeper.add_round_scores([
		ScoreEngine.patintero_round_score(7, 2),
		ScoreEngine.patintero_round_score(5, 4),
		finish_scores[0],
		finish_scores[3],
	], &"patintero")
	_check(ScoreKeeper.last_round_scores == [13, 7, 200, 140] and ScoreKeeper.last_round_points() == [130, 70, 2000, 1400], "Scores round up before the x10 leaderboard conversion and keep the full finish bonuses")
	ScoreKeeper.reset()
	AudioManager.stop_game_music()
	await get_tree().create_timer(AudioManager.MUSIC_FADE_TIME + 0.15).timeout
	print("SCORE ENGINE: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _test_patintero_progress() -> void:
	var game := load("res://games/Patintero/Scenes/main.tscn").instantiate() as Node2D
	add_child(game)
	await game.round_started
	var player_one: CharacterBody2D = game.get_node("Player")
	player_one.position.x = 1024.0
	game.call("_physics_process", 0.0)
	var game_scores: Array = game.get("_round_scores")
	_check(game_scores[0] == 100, "Clearing all Patintero zones including FN awards 100 points")
	var player_two: CharacterBody2D = game.get_node("Player2")
	player_two.position.x = 855.0
	game.call("_physics_process", 0.0)
	game_scores = game.get("_round_scores")
	_check(game_scores[1] == 60, "Reaching Zone 3 awards the first three zone values")
	player_two.position.x = 200.0
	game.call("_physics_process", 0.0)
	game_scores = game.get("_round_scores")
	_check(game_scores[1] == 60, "Patintero progress cannot be farmed by moving backward")
	player_one.position.x = 200.0
	game.call("_physics_process", 0.0)
	player_one.position.x = 1024.0
	game.call("_physics_process", 0.0)
	_check(game.get("_finish_order") == [0], "Crossing again cannot duplicate a finished runner's placement")
	game.get_node("Player3").position.x = 1024.0
	game.get_node("Player4").position.x = 1024.0
	game.call("_physics_process", 0.0)
	_check(game.get("_finish_order") == [0, 2, 3], "Exact same-tick ties use player ID consistently without displacing earlier finishers")
	game.queue_free()
	await get_tree().process_frame


func _test_tug_scoring_wiring() -> void:
	var game := load("res://games/Tug Of war/tug_ofwar.tscn").instantiate() as Node2D
	game.get_node("HUD/Root/GameOver").set("display_seconds", 10.0)
	add_child(game)
	await get_tree().process_frame
	game.call("_finish_winning_team", false)
	var scores: Array = game.get("_round_scores")
	_check(scores == [250, 250, 500, 500], "Tug of War routes winner and loser rewards through the shared score engine")
	game.queue_free()
	await get_tree().process_frame


func _test_score_carry_over_isolation() -> void:
	ScoreKeeper.reset()
	ScoreKeeper.add_round_scores([200, 180, 160, 140], &"patintero")
	ScoreKeeper.add_round_scores([500, 500, 250, 250], &"tug_of_war", true)
	_check(ScoreKeeper.last_round_scores == [500, 500, 250, 250], "Tug cannot append its round to another minigame's result")
	_check(ScoreKeeper.totals == [2500, 2300, 1850, 1650], "A stale carry-over request cannot clip or subtract earlier leaderboard points")
	ScoreKeeper.reset()


func _test_numbered_tug_results() -> void:
	ScoreKeeper.reset()
	ScoreKeeper.add_round_scores([105, 45, 45, 105], &"patintero")
	var starting_totals: Array[int] = [1050, 450, 450, 1050]
	var first_scores: Array[int] = [500, 500, 250, 250]
	var second_scores: Array[int] = [500, 500, 250, 250]
	var final_totals: Array[int] = [2050, 1450, 950, 1550]
	var updates: Array[bool] = []
	var on_update := func(_totals: Array[int]) -> void: updates.append(true)
	ScoreKeeper.totals_changed.connect(on_update)
	ScoreKeeper.add_round_scores(first_scores, &"tug_of_war", false, 1)
	ScoreKeeper.add_round_scores(second_scores, &"tug_of_war", true, 2)
	ScoreKeeper.add_round_scores(second_scores, &"tug_of_war", true, 2)
	ScoreKeeper.add_round_scores(first_scores, &"tug_of_war", true, 1)
	_check(ScoreKeeper.last_round_scores == [1000, 1000, 500, 500] and ScoreKeeper.totals == final_totals, "Repeated Tug round submissions cannot award a round twice")
	_check(updates.size() == 2, "Each numbered Tug round publishes exactly one score update")
	_check(ScoreKeeper.last_round_starting_totals == starting_totals, "Both Tug rounds retain one unchanged pre-game totals snapshot")

	var board := load("res://src/UI/roundleaderboard/roundleaderboard.tscn").instantiate() as Control
	add_child(board)
	_check(_leaderboard_scores(board) == starting_totals, "The Tug leaderboard starts from the recorded totals before both rounds")
	await board.sort_finished
	_check(_leaderboard_scores(board) == final_totals, "The Tug leaderboard displays the exact combined award plus earlier game points")
	var order: Array[int] = [0, 3, 1, 2]
	var previous_y := -INF
	var ranked := true
	for player in order:
		var row: Control = board.get_node("Board/Row%d" % (player + 1))
		ranked = ranked and row.position.y > previous_y
		previous_y = row.position.y
	_check(ranked, "Tug leaderboard rows stay attached to their player totals, with stable ties")
	_check(ScoreKeeper.totals == final_totals, "Showing the Tug leaderboard does not add another copy of the award")
	board.queue_free()
	await get_tree().process_frame

	ScoreKeeper.add_round_scores([250, 250, 500, 500], &"tug_of_war", false, 1)
	ScoreKeeper.add_round_scores([125, 125, 125, 125], &"tug_of_war", true, 2)
	_check(ScoreKeeper.last_round_scores == [375, 375, 625, 625] and ScoreKeeper.totals == [2425, 1825, 1575, 2175], "A consecutive Tug game accepts fresh round numbers and preserves all previous points")
	_check(ScoreKeeper.last_round_starting_totals == final_totals and updates.size() == 4, "A new Tug game starts its own totals snapshot and round-submission history")
	ScoreKeeper.totals_changed.disconnect(on_update)
	ScoreKeeper.reset()
	_check(ScoreKeeper.last_round_starting_totals == [0, 0, 0, 0], "Reset clears the leaderboard's pre-game snapshot")


func _test_tug_outcome_combinations() -> void:
	# Expected player awards are independent of the scoring engine under test.
	var outcomes: Array[Dictionary] = [
		{"winner": 0, "scores": [500, 500, 250, 250]},
		{"winner": 1, "scores": [250, 250, 500, 500]},
		{"winner": -1, "scores": [125, 125, 125, 125]},
	]
	var starting_totals: Array[int] = [1000, 600, 300, 100]
	for first in outcomes:
		for second in outcomes:
			ScoreKeeper.reset()
			ScoreKeeper.add_round_scores([100, 60, 30, 10], &"patintero")
			ScoreKeeper.add_round_scores(ScoreEngine.tug_round_scores(first["winner"]), &"tug_of_war", false, 1)
			ScoreKeeper.add_round_scores(ScoreEngine.tug_round_scores(second["winner"]), &"tug_of_war", true, 2)
			var expected_scores: Array[int] = []
			var expected_totals: Array[int] = []
			for player in 4:
				expected_scores.append(int(first["scores"][player]) + int(second["scores"][player]))
				expected_totals.append(starting_totals[player] + expected_scores[player])
			_check(ScoreKeeper.last_round_scores == expected_scores and ScoreKeeper.totals == expected_totals and ScoreKeeper.last_round_starting_totals == starting_totals,
				"Tug outcomes %d then %d preserve exact per-player leaderboard totals" % [first["winner"], second["winner"]])
	ScoreKeeper.reset()


func _test_tumbang_preso_scoring() -> void:
	ScoreKeeper.reset()
	ScoreKeeper.add_round_scores([500, 250, 125, 1000], &"tug_of_war")
	ScoreKeeper.add_round_scores([450, 190, -10, 999], &"tumbang_preso")
	_check(ScoreKeeper.last_round_scores == [450, 190, 0, 450], "Tumbang Preso preserves complete three-throw scores and clamps invalid values")
	_check(ScoreKeeper.last_round_points() == [900, 380, 0, 900], "Tumbang Preso awards exactly twice each player's final score")
	_check(ScoreKeeper.totals == [1400, 630, 125, 1900] and ScoreKeeper.last_round_starting_totals == [500, 250, 125, 1000], "Tumbang Preso adds its doubled award while preserving earlier totals")
	ScoreKeeper.add_round_scores([1, 0, 25, 100], &"tumbang_preso")
	_check(ScoreKeeper.last_round_scores == [1, 0, 25, 100] and ScoreKeeper.totals == [1402, 630, 175, 2100], "A new Tumbang Preso game doubles only its own fresh scores")
	ScoreKeeper.reset()


func _test_leaderboard_replay() -> void:
	var board := load("res://src/UI/roundleaderboard/roundleaderboard.tscn").instantiate() as Control
	# Exercise the shared animation without the round board's scene countdown.
	board.set_script(load("res://src/UI/leaderboard/leaderboard.gd"))
	add_child(board)
	var first_scores: Array[int] = [1500, 900, 300, 100]
	var final_scores: Array[int] = [1600, 1450, 1300, 650]
	var completed: Array[bool] = []
	board.connect("count_finished", func() -> void:
		board.call("play", final_scores, first_scores)
	, CONNECT_ONE_SHOT)
	board.connect("sort_finished", func() -> void:
		completed.append(true)
		_check(_leaderboard_scores(board) == final_scores, "A replayed leaderboard only announces complete, exact player totals")
	)
	board.call("play", first_scores)
	await get_tree().create_timer(6.0).timeout
	_check(completed.size() == 1, "Replacing a leaderboard animation completes the replacement exactly once")
	_check(_leaderboard_scores(board) == final_scores, "Old leaderboard callbacks cannot overwrite replacement scores")
	board.queue_free()
	await get_tree().process_frame


func _test_instant_leaderboard_scores() -> void:
	var board := load("res://src/UI/roundleaderboard/roundleaderboard.tscn").instantiate() as Control
	add_child(board)
	var final_scores: Array[int] = [1050, 1450, 550, 2100]
	var completed: Array[bool] = []
	board.connect("count_finished", func() -> void:
		board.call("set_scores", final_scores)
	, CONNECT_ONE_SHOT)
	board.connect("sort_finished", func() -> void: completed.append(true))
	await get_tree().create_timer(3.0).timeout
	_check(completed.is_empty(), "An instant leaderboard update cancels the old result's completion callbacks")
	_check(not board.get("_continuing"), "A cancelled leaderboard cannot start an outdated next-game countdown")
	_check(_leaderboard_scores(board) == final_scores, "Instant leaderboard scores retain the exact requested values")
	board.queue_free()
	await get_tree().process_frame


func _leaderboard_scores(board: Control) -> Array[int]:
	var scores: Array[int] = []
	for player in range(1, 5):
		scores.append(int(board.get_node("Board/Row%d/Score" % player).text))
	return scores


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)
