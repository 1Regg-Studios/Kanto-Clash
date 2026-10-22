extends Node

var _failures := 0


func _ready() -> void:
	await _test_patintero_progress()
	await _test_tug_scoring_wiring()
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
	_check(ScoreEngine.tug_round_scores(0, false) == [50, 50, 0, 0], "Tug standard-team win awards 50 points per winner")
	_check(ScoreEngine.tug_round_scores(1, true) == [0, 50, 0, 50], "Tug cross-team scoring follows the selected layout")
	_check(ScoreEngine.tug_round_scores(-1, false) == [25, 25, 25, 25], "Tug draws award 25 points to every player")
	var tug_win_scores := ScoreEngine.tug_round_scores(0, false)
	_check(tug_win_scores[0] <= ScoreEngine.TUG_ROUND_WIN_SCORE and tug_win_scores[1] <= ScoreEngine.TUG_ROUND_WIN_SCORE, "A Tug round stays inside its game score budget")
	var tug_two_rounds: Array[int] = [0, 0, 0, 0]
	for tug_round_scores in [ScoreEngine.tug_round_scores(0, false), ScoreEngine.tug_round_scores(0, true)]:
		for player_index in tug_two_rounds.size():
			tug_two_rounds[player_index] = ScoreEngine.award_points(&"tug_of_war", tug_two_rounds[player_index], tug_round_scores[player_index])
	_check(tug_two_rounds == [100, 50, 50, 0], "Two Tug rounds together remain balanced to the 100-point game cap")
	_check(ScoreEngine.score_cap(&"chinese_garter") == 100 and ScoreEngine.score_cap(&"tumbang_preso") == 100 and ScoreEngine.score_cap(&"sipa") == 100, "Future minigames share the same 100-point score budget")
	ScoreKeeper.reset()
	ScoreKeeper.add_round_scores([240, -4, 10, 0], &"patintero")
	_check(ScoreKeeper.last_round_scores == [200, 0, 10, 0], "ScoreKeeper applies the selected game's cap before recording a round")
	_check(ScoreKeeper.totals == [2000, 0, 100, 0], "Overall leaderboard totals are ten times the capped round scores")
	ScoreKeeper.add_round_scores([50, 50, 0, 0], &"tug_of_war")
	ScoreKeeper.add_round_scores([50, 0, 50, 0], &"tug_of_war", true)
	_check(ScoreKeeper.last_round_scores == [100, 50, 50, 0], "The Tug result preserves both rounds across scene reloads")
	_check(ScoreKeeper.last_round_points() == [1000, 500, 500, 0], "The visible multiplied result matches the complete minigame award")
	_check(ScoreKeeper.totals == [3000, 500, 600, 0], "Appending round two does not multiply or credit round one again")
	ScoreKeeper.add_round_scores([50, 100, 100, 100], &"tug_of_war", true)
	_check(ScoreKeeper.last_round_scores == [100, 100, 100, 100], "Combined rounds cannot exceed the minigame score cap")
	_check(ScoreKeeper.totals == [3000, 1000, 1100, 1000], "Only points within the combined cap reach the overall totals")
	ScoreKeeper.add_round_scores([25, 25, 25, 25], &"tug_of_war")
	_check(ScoreKeeper.last_round_scores == [25, 25, 25, 25], "A new instance of the same minigame starts a fresh result")
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
	game.set("cross_team_pairs", false)
	game.call("_finish_winning_team", false)
	var scores: Array = game.get("_round_scores")
	_check(scores == [0, 0, 50, 50], "Tug of War routes winners through the shared balanced score engine")
	game.queue_free()
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)
