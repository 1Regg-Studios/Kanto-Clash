extends Node

const GAME := preload("res://games/Patintero/Scenes/main.tscn")
const RESULTS := "res://src/UI/roundleaderboard/roundleaderboard.tscn"
const START_YS := [119.0, 257.0, 387.0, 527.0]

var _failures := 0
var _score_updates := 0
var _capture_dir := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	get_tree().create_timer(40.0).timeout.connect(func() -> void:
		push_error("Patintero round flow did not finish within 40 seconds")
		get_tree().quit(1)
	)
	call_deferred("_run")


func _run() -> void:
	# Keep this runner alive while the actual game changes to its leaderboard.
	get_tree().current_scene = null
	ScoreKeeper.reset()
	ScoreKeeper.totals_changed.connect(_on_score_update)
	await get_tree().create_timer(0.7).timeout

	var game := GAME.instantiate() as Node2D
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	var players: Array = game.get("_players")
	var guards: Array = game.get("_guards")
	var timer: Node = game.get_node("HUD/Root/Timer")
	var music: AudioStreamPlayer = AudioManager.get("_game_music_player")
	var positions := _player_positions(players)
	_check_valid_positions(players)
	_check(music != null and music.playing and music.stream == game.MAIN_MUSIC, "Patintero uses persistent game music")
	_check((music.stream as AudioStreamMP3).loop, "The Patintero track loops natively without a finished-signal restart")
	await _capture("patintero-round-one-countdown")

	Input.action_press("P1_Ready")
	await get_tree().create_timer(0.15).timeout
	_check(_player_positions(players) == positions, "Players cannot move during the round countdown")
	_check(is_equal_approx(float(timer.get("_time_left")), 60.0) and not timer.get("_running"), "The countdown does not consume any of the 60-second round")
	players[0].call("_get_hit")
	guards[0].call("_on_touched", players[0])
	_check(players[0].get("_stun_timer") == 0.0, "Frozen guards cannot tag players during the countdown")
	Input.action_release("P1_Ready")

	var countdown_label: Label = game.get_node("RoundIntro/Shade/Countdown")
	var countdown_text := countdown_label.text
	var countdown_alpha := countdown_label.modulate.a
	var countdown_scale := countdown_label.scale
	get_tree().paused = true
	await get_tree().create_timer(0.85, true).timeout
	_check(countdown_label.text == countdown_text and countdown_label.modulate.a == countdown_alpha and countdown_label.scale == countdown_scale, "Pausing also freezes the round countdown text and animation")
	get_tree().paused = false
	var countdown_steps: Array[String] = [countdown_text]
	var timer_stayed_stopped := true
	while game.get("_round_intro_active"):
		if countdown_label.text != countdown_steps[-1]:
			countdown_steps.append(countdown_label.text)
		timer_stayed_stopped = timer_stayed_stopped and not timer.get("_running")
		await get_tree().process_frame
	_check(countdown_steps == ["GET READY...", "ROUND 1", "5", "4", "3", "2", "1", "START!"], "Patintero follows Tug of War's full round countdown sequence")
	_check(timer_stayed_stopped, "The round timer waits until START! finishes")
	_check(timer.get("_running") and game.get("_round_number") == 1, "Round one starts after the countdown")
	await _capture("patintero-round-one")

	_award_progress(game, [1024.0, 855.0, 582.0, 316.0])
	_check(game.get("_round_scores") == [100, 60, 30, 10], "Round one keeps the existing zone awards for each player ID")
	_check(game.get("_finish_order") == [0] and not game.get("_round_finished"), "One finisher is recorded without ending the round for the other runners")
	_check(not players[0].is_physics_processing() and players[1].is_physics_processing(), "A finisher stops moving while unfinished players keep racing")
	players[0].call("_get_hit")
	_check(players[0].get("_stun_timer") == 0.0, "A finished runner cannot be tagged again")
	_check(players[0].get_node("PlayerLabel").text == "P1 - #1", "The finished runner displays their placement without a multiplier")
	players[0].set("_stun_timer", 1.0)
	players[1].set("_boost_timer", 0.2)
	players[2].set("_dash_cooldown_timer", 1.0)
	guards[0].set("_state_timer", 1.0)
	var hit_cooldowns: Dictionary = guards[0].get("_hit_cooldowns")
	hit_cooldowns[players[0].get_instance_id()] = 1.0
	timer.set("_time_left", 0.01)
	await get_tree().create_timer(0.1).timeout
	_check(game.get("_round_finished"), "The timer ends round one")
	game.call("_on_round_timeout")
	_check(game.get("_game_scores") == [100, 30, 15, 5], "A timeout applies the finisher's bonus once and leaves unfinished zone scores at x1")
	_check(_score_updates == 0 and ScoreKeeper.totals == [0, 0, 0, 0], "Round one waits for round two before posting game scores")
	var first_round_music_position := music.get_playback_position()
	await _capture("patintero-round-one-complete")

	await game.round_started
	_check(game.get("_round_number") == 2 and game.get_node("HUD/Root/Round").text == "ROUND 2 / 2", "The second and final round starts automatically")
	_check_valid_positions(players)
	var all_changed := true
	for player_index in players.size():
		all_changed = all_changed and players[player_index].position.y != positions[player_index].y
	_check(all_changed, "Every player gets a different lane in round two")
	_check(game.get("_round_scores") == [0, 0, 0, 0] and game.get("_next_zone_by_player") == [0, 0, 0, 0], "Round two has fresh scores and can earn all zones again")
	_check(game.get("_finish_order").is_empty(), "Finish placements reset before the second round")
	_check(players[0].is_physics_processing() and players[0].get_node("PlayerLabel").text == "P1", "A previous finisher can race again with their original player label")
	_check(players[0].get("_stun_timer") == 0.0 and players[1].get("_boost_timer") == 0.0 and players[2].get("_dash_cooldown_timer") == 0.0, "Stuns, boosts, and dash cooldowns reset between rounds")
	_check(guards[0].get("_hit_cooldowns").is_empty() and guards[0].get("_state_timer") == 0.0, "Guard attack state and tag cooldowns reset between rounds")
	_check(is_equal_approx(float(timer.get("_time_left")), 60.0), "Round two receives a full 60-second timer")
	_check(AudioManager.get("_game_music_player") == music and music.get_playback_position() > first_round_music_position, "The same music player advances continuously into round two")
	await _capture("patintero-round-two")

	positions = _player_positions(players)
	Input.action_press("P2_Ready")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("P2_Ready")
	_check(players[1].position.x > positions[1].x and is_equal_approx(players[1].position.y, positions[1].y), "P2's original key still controls P2 in the shuffled lane")

	# Exercise the audio boundary itself, not just the scene hand-off.
	music.seek(music.stream.get_length() - 0.1)
	await get_tree().create_timer(0.3).timeout
	_check(music.playing and music.get_playback_position() < 1.0, "The track remains playing as it wraps seamlessly to its start")
	_award_progress(game, [316.0, 582.0, 855.0, 1024.0])
	_check(game.get("_round_scores") == [10, 30, 60, 100], "Each player's new lane scores independently in round two")
	_check(game.get("_finish_order") == [3], "Round two's first place belongs to the first arrival, regardless of player ID")
	_award_progress(game, [316.0, 1024.0, 1000.0, 1024.0])
	_award_progress(game, [1000.0, 1024.0, 1020.0, 1024.0])
	_check(game.get("_finish_order") == [3, 1] and not game.get("_round_finished"), "Finished players cannot claim another placement while other runners approach")
	# P3 crosses 40% into this tick, before P1 at 80%, despite P1's lower ID.
	_award_progress(game, [1030.0, 1024.0, 1030.0, 1024.0])
	_check(game.get("_finish_order") == [3, 1, 2, 0], "Same-tick finishes follow the estimated crossing instant rather than player iteration order")
	_check(game.get("_round_finished") and not timer.get("_running") and float(timer.get("_time_left")) > 0.0, "The final finisher automatically ends the round without waiting for the timer")
	var court_frozen := true
	for player in players:
		court_frozen = court_frozen and not player.is_physics_processing()
	for guard in guards:
		court_frozen = court_frozen and not guard.is_physics_processing()
	_check(court_frozen, "Automatic completion freezes every runner and guard")
	game.call("_on_round_timeout")
	game.call("_physics_process", 0.0)
	_check(game.get("_game_scores") == [170, 120, 95, 105], "Both rounds contribute equally with their own finish multipliers and cannot be counted twice")
	_check(_score_updates == 0, "The final result is not posted early or twice")

	var leaderboard := await _wait_for_results()
	if leaderboard == null:
		get_tree().quit(1)
		return
	_check(ScoreKeeper.last_round_scores == [170, 120, 95, 105], "The game leaderboard receives the combined placement-adjusted scores without clipping bonuses")
	_check(ScoreKeeper.totals == [1700, 1200, 950, 1050], "The combined game result uses the ×10 overall-score multiplier")
	_check(_score_updates == 1, "Patintero posts its completed game exactly once")
	_check(leaderboard.get("_scores") == [1700, 1200, 950, 1050], "The leaderboard animates the multiplied combined scores directly")
	_check(AudioManager.get("_game_music_player") == music and music.playing and music.volume_db == 0.0, "Music survives the scene change and plays through leaderboard counting")
	await get_tree().create_timer(0.7).timeout
	await _capture("patintero-game-leaderboard")
	await leaderboard.sort_finished
	await get_tree().process_frame
	_check(music.playing, "Music fades rather than cutting off after the leaderboard finishes")
	await get_tree().create_timer(AudioManager.MUSIC_FADE_TIME + 0.15).timeout
	_check(not music.playing and music.stream == null, "Game music stops after the leaderboard's fade-out")

	await _test_repeated_games()
	AudioManager.stop_game_music()
	await get_tree().create_timer(AudioManager.MUSIC_FADE_TIME + 0.15).timeout
	print("PATINTERO ROUNDS: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _test_repeated_games() -> void:
	var previous: Array[Vector2] = []
	var layouts: Dictionary = {}
	var all_valid := true
	var all_changed := true
	var identities_preserved := true
	for _run_index in 24:
		var game := GAME.instantiate() as Node2D
		add_child(game)
		var players: Array = game.get("_players")
		var positions := _player_positions(players)
		var occupied: Array[float] = []
		for player_index in players.size():
			var player: CharacterBody2D = players[player_index]
			all_valid = all_valid and player.position.x == 177.0 and START_YS.has(player.position.y) and not occupied.has(player.position.y)
			occupied.append(player.position.y)
			identities_preserved = identities_preserved and player.get("player_id") == player_index + 1 and player.get("_action") == "P%d_Ready" % (player_index + 1)
			identities_preserved = identities_preserved and player.get_node("PlayerLabel").text == "P%d" % (player_index + 1)
			if not previous.is_empty():
				all_changed = all_changed and player.position.y != previous[player_index].y
		layouts[str(positions)] = true
		previous = positions
		game.free()
	_check(all_valid, "Repeated games always use four unique, safe starting lanes")
	_check(all_changed and layouts.size() >= 4, "Fresh games produce varied layouts without repeating any player's previous lane")
	_check(identities_preserved, "Position randomization preserves player IDs and controls across new games")
	await get_tree().process_frame


func _player_positions(players: Array) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for player in players:
		positions.append(player.position)
	return positions


func _check_valid_positions(players: Array) -> void:
	var occupied: Array[float] = []
	var valid := true
	for player in players:
		valid = valid and player.position.x == 177.0 and START_YS.has(player.position.y) and not occupied.has(player.position.y)
		occupied.append(player.position.y)
	_check(valid, "Every player starts in a distinct safe lane before the first scoring line")


func _award_progress(game: Node2D, crossing_xs: Array) -> void:
	var players: Array = game.get("_players")
	for player_index in players.size():
		players[player_index].position.x = crossing_xs[player_index]
	game.call("_physics_process", 0.0)


func _wait_for_results() -> Node:
	for _attempt in 100:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == RESULTS:
			return current
		await get_tree().create_timer(0.05).timeout
	_check(false, "Exactly two rounds lead to the game leaderboard")
	return null


func _on_score_update(_totals: Array[int]) -> void:
	_score_updates += 1


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
