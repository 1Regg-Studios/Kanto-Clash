extends Node

const TUTORIAL := "res://src/UI/tutorial/tumbang_preso_tutorial.tscn"
const GAME := "res://games/Tumbang Preso/Scene/game.tscn"
const CONTROLLER := preload("res://games/Tumbang Preso/Script/controller.gd")

var _failures := 0
var _capture_dir := ""
var _demo_hits := 0
var _demo_misses := 0
var _demo_presses := 0


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	get_tree().create_timer(65.0, true, false, true).timeout.connect(func() -> void:
		push_error("The Tumbang Preso tutorial test timed out")
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
	GameSchedule.reset()
	GameSchedule.picked.assign(["chinese_garter", "patintero"])
	GameSchedule.first_scene_path()
	var starting_destination := GameSchedule.next_scene_path
	await SceneFader.change_scene(TUTORIAL)
	var tutorial := get_tree().current_scene
	var preview: Node2D = tutorial.get_node("Composition/GamePreview/SubViewport/TumbangPreso")
	var controller: Node = preview.get_node("Controller")
	var direction: Node = preview.get_node("DirectionGuage")
	var power: Node = preview.get_node("PowerGauge")
	var thrower: AnimatedSprite2D = preview.get_node("CharacterBody2D/AnimatedSprite2D")
	var can_sprite: AnimatedSprite2D = preview.get_node("Can/can")
	var key: TextureRect = tutorial.get_node("Composition/Key")
	controller.connect("demo_key_changed", func(pressed: bool) -> void:
		if pressed:
			_demo_presses += 1
	)
	preview.get_node("Can").connect("result", func(hit: bool) -> void:
		if hit:
			_demo_hits += 1
		else:
			_demo_misses += 1
	)
	_check(preview.get_viewport() != get_viewport() and preview.get_world_2d() != get_viewport().find_world_2d(), "The real game runs in an isolated preview world")
	_check(preview.get_node("PauseMenu").process_mode == Node.PROCESS_MODE_DISABLED and not controller.is_processing_input(), "The preview cannot pause the tutorial or consume its proceed key")
	_check(not controller.has_node("RoundIntro") and controller.get("state") == CONTROLLER.State.DIRECTION, "The demo starts the direction gauge without a match countdown")
	var instructions: String = tutorial.get_node("Composition/Instructions").text
	_check(tutorial.get_node("Composition/AssignedKey").text == "SPACE" and instructions.contains("LOCK DIRECTION") and instructions.contains("LOCK POWER"), "The tutorial explains both presses of the shared SPACE control")
	_check(tutorial.get_node("Composition/TurnOrder").text == "P1 > P2 > P3 > P4" and tutorial.get_node("Composition/ScoringHint").text.contains("3 THROWS EACH"), "The instructions show player order and three throws per player")
	await _capture("tumbang-preso-tutorial")

	Engine.time_scale = 4.0
	var seen_players: Array[int] = []
	var saw_power := false
	var saw_throw := false
	var saw_can_hit := false
	var saw_pressed_key := false
	var saw_released_key := false
	var saw_last_player := false
	while not (saw_last_player and controller.get("current_player") == 1):
		var player: int = controller.get("current_player")
		if not seen_players.has(player):
			seen_players.append(player)
		saw_last_player = saw_last_player or player == 4
		saw_power = saw_power or (controller.get("state") == CONTROLLER.State.POWER and not direction.get("running") and power.get("running"))
		saw_throw = saw_throw or (thrower.animation == &"throw" and thrower.is_playing())
		saw_pressed_key = saw_pressed_key or key.texture == tutorial.key_down_texture
		saw_released_key = saw_released_key or (saw_pressed_key and key.texture == tutorial.key_up_texture)
		if can_sprite.is_playing() and not saw_can_hit:
			saw_can_hit = true
			await _capture("tumbang-preso-tutorial-hit")
		await get_tree().process_frame
	_check(saw_power and saw_throw and saw_can_hit, "Autoplay locks direction, locks power, throws, and animates the falling can")
	_check(_demo_hits == 12 and _demo_misses == 0 and seen_players == [1, 2, 3, 4], "Three successful throws per player loop through P1 to P4 and restart at P1")
	_check(_demo_presses == 24 and saw_pressed_key and saw_released_key, "The key indicator presses and releases twice for each demonstrated throw")
	_check(controller.get("scores") == [0, 0, 0, 0] and controller.get("current_attempt") == 1, "A new demo loop resets its local scores and attempt count")
	_check(ScoreKeeper.totals == starting_totals and ScoreKeeper.last_round_scores == starting_scores, "A complete demo loop preserves all earned scores")
	_check(GameSchedule.current_game_index == 0 and GameSchedule.next_scene_path == starting_destination and GameSchedule.picked == ["chinese_garter", "patintero"], "Autoplay cannot change the scheduled lineup or its destination")
	_check(not Input.is_physical_key_pressed(KEY_SPACE), "The demo never injects global SPACE input")

	_send_key(KEY_SPACE, true)
	await get_tree().process_frame
	_check(get_tree().current_scene == tutorial, "Held-key repeats cannot dismiss the tutorial")
	Engine.time_scale = 1.0
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		var window := get_window()
		window.size = Vector2i(1280, 800)
		window.content_scale_size = Vector2i(1280, 800)
		await get_tree().process_frame
		await get_tree().process_frame
		var composition: Control = tutorial.get_node("Composition")
		var end := composition.global_position + composition.size * composition.scale
		_check(composition.global_position.x >= 0.0 and composition.global_position.y >= 0.0 and end.x <= 1280.1 and end.y <= 800.1, "The tutorial fits a narrower window without clipping")
		await _capture("tumbang-preso-tutorial-1280x800")

	# Dismiss during a throw to exercise cleanup of pending preview animations.
	while controller.get("state") != CONTROLLER.State.RESULT:
		await get_tree().process_frame
	_send_key(KEY_ENTER)
	while get_tree().current_scene == tutorial or SceneFader.get("_busy"):
		await get_tree().process_frame
	var game := get_tree().current_scene
	var live_controller: Node = game.get_node("Controller")
	_check(game.scene_file_path == GAME and live_controller.has_node("RoundIntro"), "A fresh key opens the real game with its normal countdown")
	_check(live_controller.get("current_player") == 1 and live_controller.get("current_attempt") == 1 and live_controller.get("scores") == [0, 0, 0, 0], "The live game starts fresh instead of inheriting demo progress")
	_check(ScoreKeeper.totals == starting_totals and GameSchedule.next_scene_path == GAME, "Starting the game preserves scores and updates the actual destination")
	game.queue_free()
	get_tree().current_scene = null
	await get_tree().process_frame
	print("TUMBANG PRESO TUTORIAL: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


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
