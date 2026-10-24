extends Node

const GAME := "res://games/Chinese Garter/chinese_garter.tscn"
const TUTORIAL := "res://src/UI/tutorial/chinese_garter_tutorial.tscn"
const RESULTS := "res://src/UI/roundleaderboard/roundleaderboard.tscn"
const EXPECTED_SCORES: Array[int] = [1, 2, 3, 0]
const STARTING_TOTALS: Array[int] = [500, 250, 500, 250]

var _failures := 0
var _score_updates := 0
var _capture_dir := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	get_tree().create_timer(65.0, true, false, true).timeout.connect(func() -> void:
		push_error("The Chinese Garter turn test timed out")
		get_tree().quit(1)
	)
	call_deferred("_run")


func _run() -> void:
	get_tree().current_scene = null
	await get_tree().create_timer(0.7).timeout
	Engine.time_scale = 4.0
	_test_roster()
	await _test_restart_isolation()
	ScoreKeeper.reset()
	ScoreKeeper.add_round_scores(STARTING_TOTALS, &"tug_of_war")
	ScoreKeeper.totals_changed.connect(func(_totals: Array[int]) -> void: _score_updates += 1)
	GameSchedule.reset()
	GameSchedule.picked.assign(["chinese_garter", "chinese_garter", "patintero"])
	_check(GameSchedule.first_scene_path() == TUTORIAL, "Chinese Garter is scheduled through its tutorial")
	await SceneFader.change_scene(TUTORIAL)
	await _test_tutorial()
	var game := get_tree().current_scene
	_check(game.scene_file_path == GAME and game.get("_turn_index") == 0, "The live game always opens with P1")
	_check(game.find_children("*", "SubViewport").is_empty(), "Live play uses one shared full-screen world")
	var player: CharacterBody2D = game.get_node("ChineseGarterPlayerScene/PlayerBody")
	var gauge: Node2D = game.get_node("TimingGuage")
	var spawn := player.position
	var initial_speed: float = gauge.get("needle_speed")
	var initial_height: float = gauge.get("green_height")
	var completed: Array[int] = [0, 0, 0, 0]
	for player_index in range(4):
		_check(game.get("_turn_index") == player_index and player.get("player_id") == player_index + 1, "P%d gets the correct character in fixed player order" % (player_index + 1))
		_check(game.get("_round_intro_active") and not gauge.get("game_active") and not player.is_physics_processing(), "P%d waits behind a frozen countdown" % (player_index + 1))
		_check(gauge.get("score") == 0 and gauge.get("streak") == 0 and gauge.get("needle_speed") == initial_speed and gauge.get("green_height") == initial_height, "P%d starts with a fresh score and the same initial difficulty" % (player_index + 1))
		_check(player.position == spawn and player.velocity == Vector2.ZERO and not player.get("_jump_animation_active"), "P%d starts at rest in the original jump position" % (player_index + 1))
		_check(game.get("_time_left") == 30.0 and game.get_node("HUD/Timer/Label").text == "00 : 30", "P%d receives all 30 seconds" % (player_index + 1))
		_send_key(KEY_SPACE)
		_check(gauge.get("score") == 0 and game.get("_press_time_left") == 0.0, "Countdown presses cannot score or carry into P%d's turn" % (player_index + 1))
		await game.turn_started
		await get_tree().physics_frame
		await get_tree().physics_frame
		var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
		var frame := sprite.sprite_frames.get_frame_texture(&"default", 0) as AtlasTexture
		_check(frame.atlas == player.PLAYER_SPRITE_SHEETS[player_index], "P%d's actual sprite atlas changes with their turn" % (player_index + 1))
		_check(game.get_node("HUD/PlayerIndicator/Indicator").texture == game.INDICATORS_IDLE[player_index], "The press indicator follows P%d" % (player_index + 1))
		_send_key(KEY_A)
		_check(gauge.get("score") == 0, "Other keys cannot trigger the shared SPACE timing control")
		for hit_index in EXPECTED_SCORES[player_index]:
			gauge.set("t", (float(gauge.get("zone_start")) + float(gauge.get("zone_end"))) * 0.5)
			_send_key(KEY_SPACE)
			_check(gauge.get("score") == hit_index + 1, "A fresh SPACE press scores once for the active player")
			_send_key(KEY_SPACE, true)
			_send_key(KEY_SPACE)
			_check(gauge.get("score") == hit_index + 1, "Repeats and cooldown mashing cannot duplicate a timing hit")
			if hit_index + 1 < EXPECTED_SCORES[player_index]:
				await get_tree().create_timer(float(gauge.get("restart_delay")) + 0.08, false).timeout
		if player_index == 0:
			await _capture("chinese-garter-p1-jump")
			await _test_pause(game, false)
		if player_index == 3:
			gauge.set("t", 0.0)
			_send_key(KEY_SPACE)
			_check(gauge.get("score") == 0 and game.get_node("HUD/Feedback").text == "MISS!", "A missed attempt keeps P4's score at zero")
		game.set("_time_left", 0.001)
		game.call("_process", 0.01)
		game.call("_finish_turn")
		completed[player_index] = EXPECTED_SCORES[player_index]
		_check(game.get("_game_scores") == completed, "Completed turn scores remain attached to their original player")
		_check(game.get("_round_finished") and not gauge.get("game_active") and not player.is_physics_processing(), "Time-up stops both timing input and player movement")
		_check(ScoreKeeper.totals == STARTING_TOTALS and _score_updates == 0, "Partial turns preserve earlier minigame totals until P4 finishes")
		_send_key(KEY_SPACE)
		_check(gauge.get("score") == EXPECTED_SCORES[player_index], "Handoff presses cannot add points to an expired turn")
		if player_index == 0:
			await _capture("chinese-garter-p1-handoff")
			await _test_pause(game, true)
		if player_index < 3:
			while game.get("_turn_index") == player_index:
				await get_tree().process_frame

	while get_tree().current_scene == game or SceneFader.get("_busy"):
		await get_tree().process_frame
	var results := get_tree().current_scene
	_check(results.scene_file_path == RESULTS, "Only P4's completion opens the game leaderboard")
	_check(ScoreKeeper.last_round_scores == EXPECTED_SCORES and _score_updates == 1, "All four scores are submitted exactly once")
	_check(ScoreKeeper.last_round_points() == [30, 60, 90, 0] and ScoreKeeper.totals == [530, 310, 590, 250], "Chinese Garter applies its existing x3 and x10 conversion once and preserves earlier totals")
	_check(ScoreKeeper.last_round_starting_totals == STARTING_TOTALS, "The leaderboard counts up from the totals before Chinese Garter")
	await results.sort_finished
	await _capture("chinese-garter-results")
	_check(GameSchedule.next_game_id() == "chinese_garter", "Finishing four player turns advances only one scheduled minigame")
	_check(GameSchedule.advance_game() and GameSchedule.next_scene_path == TUTORIAL, "A consecutive Chinese Garter game returns through its tutorial")
	await SceneFader.change_scene(GAME)
	game = get_tree().current_scene
	_check(game.get("_turn_index") == 0 and game.get("_game_scores") == [0, 0, 0, 0] and game.get_node("TimingGuage").get("score") == 0, "A later Chinese Garter game resets to P1 with four clean scores")
	_check(ScoreKeeper.totals == [530, 310, 590, 250] and _score_updates == 1, "Starting another game cannot replay or erase the previous award")
	game.queue_free()
	get_tree().current_scene = null
	Engine.time_scale = 1.0
	AudioManager.stop_game_music()
	await get_tree().create_timer(AudioManager.MUSIC_FADE_TIME + 0.15).timeout
	print("CHINESE GARTER TURNS: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _test_roster() -> void:
	var schedule := load("res://src/autoload/game_schedule.gd").new() as Node
	var history_path := "user://test_garter_roster_%d.cfg" % Time.get_ticks_usec()
	schedule.set("_history_path", history_path)
	add_child(schedule)
	var rng: RandomNumberGenerator = schedule.get("_rng")
	rng.seed = 203
	var included := true
	var variety_preserved := true
	var previous: Array = []
	for roll_index in 30:
		var lineup: Array = schedule.call("roll")
		included = included and lineup.size() == 4 and schedule.get("skipped") == ""
		for slot in previous.size():
			variety_preserved = variety_preserved and lineup[slot] != previous[slot]
		previous = lineup.duplicate()
		for id in ["tug_of_war", "patintero", "chinese_garter", "tumbang_preso"]:
			included = included and lineup.count(id) == 1
	_check(included, "Every roll includes all four available games exactly once")
	_check(variety_preserved, "The four-game roster preserves consecutive-slot variety")
	var icons: Array = schedule.call("load_icons")
	_check(icons.size() == 4 and not icons.has(null), "All four randomizer icons load successfully")
	_check(schedule.call("scene_path_for", "chinese_garter") == GAME, "The roster resolves the real Chinese Garter scene")
	_check(schedule.call("scene_path_for", "tumbang_preso") == "res://games/Tumbang Preso/Scene/game.tscn", "The roster resolves the real Tumbang Preso scene")
	schedule.queue_free()
	DirAccess.remove_absolute(history_path)


func _test_restart_isolation() -> void:
	var gauge := Node2D.new()
	gauge.set_script(load("res://games/Chinese Garter/timing_guage.gd"))
	add_child(gauge)
	gauge.set_process_input(false)
	gauge.set("t", 0.8)
	gauge.call("attempt_hit")
	await get_tree().create_timer(0.3).timeout
	gauge.call("reset_game")
	gauge.call("start_game")
	gauge.set("t", 0.8)
	gauge.call("attempt_hit")
	await get_tree().create_timer(0.35).timeout
	_check(not gauge.get("running") and gauge.get("score") == 1, "A delayed restart from an earlier turn cannot release the next player's cooldown")
	await get_tree().create_timer(0.3).timeout
	_check(gauge.get("running"), "The new turn's own restart still completes normally")
	gauge.queue_free()
	await get_tree().process_frame


func _test_tutorial() -> void:
	var tutorial := get_tree().current_scene
	# Inspect a complete demo handoff independently of the tutorial countdown.
	tutorial.set_process(false)
	var preview: Node2D = tutorial.get_node("Composition/GamePreview/SubViewport/ChineseGarter")
	_check(tutorial.get_node("Composition/AssignedKey").text == "SPACE" and tutorial.get_node("Composition/TurnOrder").text == "P1 > P2 > P3 > P4", "The tutorial explains SPACE and the exact player order")
	_check(preview.get_world_2d() != get_viewport().find_world_2d() and preview.get_node("PauseMenu").process_mode == Node.PROCESS_MODE_DISABLED, "The tutorial demo has an isolated world and inactive pause menu")
	var saw_jump := false
	var saw_key := false
	while preview.get("_turn_index") == 0:
		saw_jump = saw_jump or preview.get_node("ChineseGarterPlayerScene/PlayerBody").get("_jump_animation_active")
		saw_key = saw_key or tutorial.get_node("Composition/Key").texture == tutorial.key_down_texture
		await get_tree().process_frame
	_check(saw_jump and saw_key and preview.get("_turn_index") == 1, "The live preview demonstrates successful jumps, the SPACE indicator, and a player handoff")
	_check(ScoreKeeper.totals == STARTING_TOTALS and _score_updates == 0 and GameSchedule.current_game_index == 0, "Tutorial autoplay never scores or advances the live schedule")
	await _capture("chinese-garter-tutorial")
	_send_key(KEY_SPACE, true)
	await get_tree().process_frame
	_check(get_tree().current_scene == tutorial, "Held-key repeats cannot dismiss the tutorial")
	_send_key(KEY_SPACE)
	await get_tree().process_frame
	_check(get_tree().current_scene == tutorial and not SceneFader.get("_busy"), "A fresh key press cannot skip the countdown")
	tutorial.set_process(true)
	while get_tree().current_scene == tutorial or SceneFader.get("_busy"):
		await get_tree().process_frame
	_check(get_tree().current_scene.scene_file_path == GAME, "The tutorial countdown automatically opens Chinese Garter")


func _test_pause(game: Node, handoff: bool) -> void:
	_send_key(KEY_ESCAPE)
	var paused_time: float = game.get("_time_left")
	var paused_needle: float = game.get_node("TimingGuage").get("t")
	var paused_player: int = game.get("_turn_index")
	await get_tree().create_timer(0.65, true).timeout
	_send_key(KEY_SPACE)
	_check(get_tree().paused and game.get("_time_left") == paused_time and game.get_node("TimingGuage").get("t") == paused_needle and game.get("_turn_index") == paused_player, "Pause freezes the player handoff" if handoff else "Pause freezes the live turn and timing gauge")
	_send_key(KEY_ESCAPE)
	while get_tree().paused:
		await get_tree().process_frame


func _send_key(key: Key, echo := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		event.echo = echo
		Input.parse_input_event(event)
	Input.flush_buffered_events()


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
