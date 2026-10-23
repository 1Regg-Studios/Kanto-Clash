extends Node

const GAME := "res://games/Tumbang Preso/Scene/game.tscn"
const CONTROLLER := preload("res://games/Tumbang Preso/Script/controller.gd")
const LEGACY_KEYS: Array[Key] = [KEY_A, KEY_F, KEY_J, KEY_SEMICOLON]
const SHOTS: Array[Vector2] = [Vector2(0.5, 0.7), Vector2(0.9, 0.7), Vector2(0.6, 0.8)]
const PLAYER_SHOTS: Array = [[0, 1, 2], [1, 1, 1], [2, 2, 1], [0, 1, 2]]
const EXPECTED_ATTEMPT_SCORES: Array = [[150, 140, 190], [0, 0, 0], [50, 100, 90], [150, 140, 190]]
const EXPECTED_SCORES: Array[int] = [190, 0, 90, 190]
const HAND_SKIN_COLORS: Array[Color] = [Color("ffc6a7"), Color("faae86"), Color("f7d499"), Color("cca486")]

var _failures := 0
var _capture_dir := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	get_tree().create_timer(65.0, true, false, true).timeout.connect(func() -> void:
		push_error("The Tumbang Preso test timed out")
		get_tree().quit(1)
	)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(0.7).timeout
	Engine.time_scale = 4.0
	var packed := load(GAME) as PackedScene
	_check(packed != null, "The main game and its scene dependencies load")
	if packed == null:
		get_tree().quit(1)
		return
	var game := packed.instantiate() as Node2D
	add_child(game)
	var controller: Node = game.get_node("Controller")
	var direction: Node2D = game.get_node("DirectionGuage")
	var power: Node2D = game.get_node("PowerGauge")
	var can: Node2D = game.get_node("Can")
	var thrower: AnimatedSprite2D = game.get_node("CharacterBody2D/AnimatedSprite2D")
	controller.set("result_delay", 0.3)
	controller.set("turn_end_delay", 0.8)
	# Keep shot values deterministic while the real input and animations run.
	direction.set_process(false)
	power.set_process(false)
	_test_scoring(can)
	_check(controller.get("state") == CONTROLLER.State.INTRO and not direction.get("running") and not power.get("running"), "P1 starts behind a frozen countdown")
	var viewport_size := get_viewport().get_visible_rect().size
	var expected_scale := minf(viewport_size.x / 1152.0, viewport_size.y / 648.0)
	var camera: Camera2D = game.get_node("Camera2D")
	_check(camera.zoom.is_equal_approx(Vector2.ONE * expected_scale), "The imported playfield fits the project's viewport")
	var can_transform := can.transform
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(can.transform.is_equal_approx(can_transform), "Viewport fitting preserves the can's physics transform")
	var completed: Array[int] = [0, 0, 0, 0]
	for player in range(4):
		_check(controller.get("current_player") == player + 1, "P%d receives the next turn" % (player + 1))
		_check(controller.get("state") == CONTROLLER.State.INTRO and controller.get("current_attempt") == 1 and controller.get("scores") == completed, "Each player starts at attempt one with earlier players' scores preserved")
		_test_animation_assets(game, player + 1)
		if player == 0:
			await _test_pause(game, controller, "countdown")
		await _test_countdown(controller, completed)
		_check(direction.get("speed") == controller.get("direction_speed") and power.get("speed") == controller.get("power_speed"), "Every player receives the same starting gauge difficulty")
		if player == 0:
			await _capture("tumbang-preso-start")
		else:
			await _capture("tumbang-preso-player-%d" % (player + 1))
		for attempt in range(3):
			controller.set("result_delay", 1.2 if attempt == 0 else 0.3)
			_check(controller.get("current_player") == player + 1 and controller.get("current_attempt") == attempt + 1, "P%d keeps attempt %d of three" % [player + 1, attempt + 1])
			_check(thrower.animation == &"idle" and thrower.is_playing() and thrower.sprite_frames.get_frame_texture(&"idle", 0).resource_path.begins_with("res://games/Tumbang Preso/assets/Animation P%d/" % (player + 1)), "Every attempt restores the current player's ready animation")
			_check(game.get_node("CanvasLayer/AttemptLabel").text == "ATTEMPT %d / 3" % (attempt + 1), "The HUD shows the current attempt")
			_check(game.get_node("CanvasLayer/InstructionLabel").text.is_empty(), "The direction-lock instruction is removed from the HUD")
			_check(direction.get("value") == 0.5 and power.get("value") == power.get("start_value") and not can.get_node("can").is_playing() and can.get_node("can").frame == 0, "Both gauges and the can reset before every throw")
			for key in LEGACY_KEYS:
				_send_key(key)
			_send_key(KEY_SPACE, true)
			_check(controller.get("state") == CONTROLLER.State.DIRECTION and direction.get("running") and not power.get("running"), "Legacy keys and held Space repeats cannot lock direction")
			var shot: Vector2 = SHOTS[PLAYER_SHOTS[player][attempt]]
			direction.set("value", shot.x)
			direction.call("_update_line")
			_send_key(KEY_SPACE)
			_check(controller.get("state") == CONTROLLER.State.POWER and not direction.get("running") and power.get("running"), "The first press locks direction and starts power")
			_check(controller.get("current_attempt") == attempt + 1 and controller.get("scores") == completed, "Locking direction neither spends an extra attempt nor changes scores")
			for key in LEGACY_KEYS:
				_send_key(key)
			_send_key(KEY_SPACE, true)
			_check(controller.get("state") == CONTROLLER.State.POWER and power.get("running"), "Legacy keys and held Space repeats cannot interrupt the power stage")
			power.set("value", shot.y)
			power.call("_update_line")
			if player == 0 and attempt == 0:
				_check_target_contains_marker(direction, false)
				_check_target_contains_marker(power, true)
				await _capture("tumbang-preso-power")
			_send_key(KEY_SPACE)
			_check(controller.get("state") == CONTROLLER.State.RESULT and not direction.get("running") and not power.get("running"), "The second press freezes both gauges and starts one throw")
			_check(thrower.animation == &"throw" and thrower.is_playing(), "The current player's throw animation plays after locking power")
			_send_key(KEY_SPACE)
			controller.call("finish_turn")
			while game.get_node("CanvasLayer/ResultLabel").text.is_empty():
				await get_tree().process_frame
			completed[player] = EXPECTED_ATTEMPT_SCORES[player][attempt]
			_check(controller.get("scores") == completed, "P%d's attempt %d accumulates its score exactly once" % [player + 1, attempt + 1])
			_check(game.get_node("CanvasLayer/ResultLabel").text.begins_with("MISS" if PLAYER_SHOTS[player][attempt] == 1 else "HIT!"), "The shot displays the correct hit or miss result")
			_check(thrower.animation == &"follow_through" and thrower.is_playing(), "Scoring begins when the throw finishes while the matching empty hand follows through")
			if player == 0 and attempt == 0:
				await _capture("tumbang-preso-hit")
			if attempt == 0:
				while thrower.animation == &"follow_through":
					await get_tree().process_frame
				_check(thrower.animation == &"empty_idle" and thrower.is_playing() and controller.get("scores") == completed, "P%d settles into its matching empty-hand idle without scoring twice" % (player + 1))
			while controller.get("state") == CONTROLLER.State.RESULT:
				await get_tree().process_frame
			if attempt < 2:
				_check(controller.get("state") == CONTROLLER.State.DIRECTION and controller.get("current_player") == player + 1 and not game.get_node("TurnEndOverlay/Dimmer").visible, "A hit or miss before attempt three returns to the same player immediately")
		_check(controller.get("state") == CONTROLLER.State.TURN_END and game.get_node("TurnEndOverlay/Dimmer").visible, "Only the third throw opens the turn-complete summary")
		var expected_detail := "PLAYER %d: %d POINTS IN 3 THROWS" % [player + 1, EXPECTED_SCORES[player]]
		expected_detail += "\nNEXT: PLAYER %d" % (player + 2) if player < 3 else "\nFINAL RESULTS..."
		_check(game.get_node("TurnEndOverlay/Dimmer/Detail").text == expected_detail, "The summary shows the player's complete three-throw score and correct next destination")
		_send_key(KEY_SPACE)
		controller.call("finish_turn")
		controller.call("_finish_player_turn")
		_check(controller.get("state") == CONTROLLER.State.TURN_END and controller.get("scores") == completed, "Handoff presses and repeated callbacks cannot add scores or skip a player")
		if player == 0:
			await _capture("tumbang-preso-handoff")
			await _test_pause(game, controller, "handoff")
		while controller.get("state") == CONTROLLER.State.TURN_END:
			await get_tree().process_frame

	_check(controller.get("state") == CONTROLLER.State.GAME_OVER and controller.get("scores") == EXPECTED_SCORES, "All twelve throws finish with the expected independent three-attempt scores")
	_check(game.get_node("CanvasLayer/ResultLabel").text == "TIE: P1 & P4", "The final result identifies both tied winners")
	await _capture("tumbang-preso-game-over")
	_send_key(KEY_SPACE, true)
	_check(controller.get("state") == CONTROLLER.State.GAME_OVER, "A held restart key cannot reset the game")
	_send_key(KEY_ENTER)
	_check(controller.get("state") == CONTROLLER.State.GAME_OVER, "ENTER cannot restart the game")
	_send_key(KEY_SPACE)
	_check(controller.get("current_player") == 1 and controller.get("current_attempt") == 1 and controller.get("scores") == [0, 0, 0, 0] and controller.get("state") == CONTROLLER.State.INTRO, "SPACE restarts at P1's countdown with three fresh attempts and four clean scores")
	_test_animation_assets(game, 1)
	_check(not direction.get("running") and not power.get("running"), "Restarting keeps both gauges frozen during the countdown")
	await controller.turn_started

	# A pending result timer must not advance a freshly restarted match.
	controller.set("result_delay", 0.6)
	direction.set("value", 0.5)
	_send_key(KEY_SPACE)
	power.set("value", 0.7)
	_send_key(KEY_SPACE)
	while game.get_node("CanvasLayer/ResultLabel").text.is_empty():
		await get_tree().process_frame
	controller.call("restart")
	await get_tree().create_timer(0.75).timeout
	_check(controller.get("current_player") == 1 and controller.get("current_attempt") == 1 and controller.get("scores") == [0, 0, 0, 0] and controller.get("state") == CONTROLLER.State.INTRO, "An old result timer cannot spend an attempt or interrupt a restarted countdown")
	controller.call("restart")
	await get_tree().process_frame
	_check(controller.find_children("RoundIntro*", "CanvasLayer", true, false).size() == 1, "Restarting during a countdown removes the previous countdown")
	await controller.turn_started
	# Cancel a throw before its animation completes, then complete three new shots.
	_send_key(KEY_SPACE)
	_send_key(KEY_SPACE)
	thrower.frame = thrower.sprite_frames.get_frame_count(&"throw") - 1
	_check(thrower.get_node("ReleasedHand").visible, "The empty hand stays visible during a throw's slipper-only frames")
	controller.call("restart")
	_check(not thrower.get_node("ReleasedHand").visible and thrower.get_node("ReleasedHand").texture == null, "Restarting mid-flight clears the layered hand before the new ready pose")
	await controller.turn_started
	controller.set("result_delay", 0.1)
	for attempt in range(3):
		direction.set("value", 0.5)
		_send_key(KEY_SPACE)
		power.set("value", 0.7)
		_send_key(KEY_SPACE)
		while controller.get("state") == CONTROLLER.State.RESULT:
			await get_tree().process_frame
		_check(controller.get("scores") == [(attempt + 1) * 150, 0, 0, 0], "A canceled throw cannot score when a later throw's animation finishes")
	_check(controller.get("state") == CONTROLLER.State.TURN_END, "The restarted player still receives exactly three attempts")
	controller.call("restart")
	await get_tree().create_timer(1.0).timeout
	_check(controller.get("current_player") == 1 and controller.get("current_attempt") == 1 and controller.get("scores") == [0, 0, 0, 0] and controller.get("state") == CONTROLLER.State.INTRO and not game.get_node("TurnEndOverlay/Dimmer").visible, "An old handoff timer cannot skip P1 or reopen a summary after restart")

	can.set("randomize_target", true)
	controller.call("restart")
	await controller.turn_started
	direction.set("value", can.get("target_direction"))
	direction.call("_update_line")
	power.set("value", can.get("target_power"))
	power.call("_update_line")
	_check_target_contains_marker(direction, false)
	_check_target_contains_marker(power, true)
	_check(can.call("get_points", direction.get("value"), power.get("value")) == 150, "Randomized target zones remain aligned with perfect scoring")

	game.queue_free()
	await get_tree().process_frame
	Engine.time_scale = 1.0
	print("TUMBANG PRESO: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _test_countdown(controller: Node, completed: Array[int]) -> void:
	var observed: Array[String] = []
	while controller.get("state") == CONTROLLER.State.INTRO:
		var label: Label = controller.get_node("RoundIntro/Shade/Countdown")
		if not label.text.is_empty() and not observed.has(label.text):
			observed.append(label.text)
			_send_key(KEY_SPACE)
			_check(controller.get("state") == CONTROLLER.State.INTRO and controller.get("current_attempt") == 1 and controller.get("scores") == completed and not controller.get("direction_gauge").get("running") and not controller.get("power_gauge").get("running"), "Countdown presses cannot throw, spend attempts, or score")
		await get_tree().process_frame
	_check(observed == ["GET READY...", "PLAYER %d" % controller.get("current_player"), "5", "4", "3", "2", "1", "START!"], "Every player receives Chinese Garter's complete intro sequence")
	_check(controller.get("state") == CONTROLLER.State.DIRECTION and controller.get("direction_gauge").get("running") and not controller.get("power_gauge").get("running"), "Only direction starts after the countdown, without carrying over a countdown press")


func _test_pause(game: Node, controller: Node, phase: String) -> void:
	_send_key(KEY_ESCAPE)
	var state: int = controller.get("state")
	var player: int = controller.get("current_player")
	var attempt: int = controller.get("current_attempt")
	var scores: Array = controller.get("scores").duplicate()
	var countdown := ""
	if state == CONTROLLER.State.INTRO:
		countdown = controller.get_node("RoundIntro/Shade/Countdown").text
	await get_tree().create_timer(1.0, true).timeout
	_send_key(KEY_SPACE)
	_check(get_tree().paused and controller.get("state") == state and controller.get("current_player") == player and controller.get("current_attempt") == attempt and controller.get("scores") == scores, "Pause freezes the %s and blocks gameplay input" % phase)
	if state == CONTROLLER.State.INTRO:
		_check(controller.get_node("RoundIntro/Shade/Countdown").text == countdown, "Pause also freezes the animated countdown")
	else:
		_check(game.get_node("TurnEndOverlay/Dimmer").visible, "Pause keeps the turn summary in place")
	_send_key(KEY_ESCAPE)
	while get_tree().paused:
		await get_tree().process_frame


func _test_animation_assets(game: Node, player: int) -> void:
	var sprites: Array[AnimatedSprite2D] = [game.get_node("CharacterBody2D/AnimatedSprite2D"), game.get_node("Can/can")]
	var all_local := true
	for sprite in sprites:
		for animation in sprite.sprite_frames.get_animation_names():
			for frame in sprite.sprite_frames.get_frame_count(animation):
				var texture := sprite.sprite_frames.get_frame_texture(animation, frame)
				all_local = all_local and texture != null and texture.resource_path.begins_with("res://games/Tumbang Preso/assets/")
	_check(all_local, "Every throw and can animation frame resolves from Tumbang Preso's own assets")
	var frames := sprites[0].sprite_frames
	var all_player_local := true
	for animation in [&"idle", &"throw", &"follow_through", &"empty_idle"]:
		if not frames.has_animation(animation) or frames.get_frame_count(animation) == 0:
			all_player_local = false
			continue
		for frame_index in frames.get_frame_count(animation):
			var texture := frames.get_frame_texture(animation, frame_index)
			all_player_local = all_player_local and texture != null and texture.resource_path.begins_with("res://games/Tumbang Preso/assets/Animation P%d/" % player)
	_check(all_player_local, "P%d uses its own color and skin tone in every ready, throw, follow-through, and empty-idle frame" % player)
	_check(not frames.get_animation_loop(&"throw") and not frames.get_animation_loop(&"follow_through"), "Throw and follow-through animations finish instead of looping forever")
	_check(sprites[0].animation == &"idle" and sprites[0].is_playing(), "The player's turn starts with its ready animation")
	_test_hand_continuity(game, player)


func _test_hand_continuity(game: Node, player: int) -> void:
	var thrower: AnimatedSprite2D = game.get_node("CharacterBody2D/AnimatedSprite2D")
	var released_hand: Sprite2D = thrower.get_node("ReleasedHand")
	var skin := HAND_SKIN_COLORS[player - 1]
	var playfield := get_viewport().get_visible_rect().grow(-48.0)
	var missing: Array[String] = []
	thrower.stop()
	for animation in [&"idle", &"throw", &"follow_through", &"empty_idle"]:
		thrower.animation = animation
		for frame_index in thrower.sprite_frames.get_frame_count(animation):
			thrower.frame = frame_index
			var texture := thrower.sprite_frames.get_frame_texture(animation, frame_index)
			if not _has_visible_skin(thrower, texture, skin, playfield) and not _has_visible_skin(released_hand, released_hand.texture, skin, playfield):
				missing.append("%s/%d" % [animation, frame_index])
	_check(missing.is_empty(), "P%d has a visible, correctly colored hand in every animation frame (missing: %s)" % [player, ", ".join(missing)])
	game.get_node("Controller").call("reset_thrower")
	_check(not released_hand.visible and released_hand.texture == null, "Resetting the thrower removes the extra hand layer")


func _has_visible_skin(sprite: Node2D, texture: Texture2D, skin: Color, playfield: Rect2) -> bool:
	if texture == null or not sprite.is_visible_in_tree():
		return false
	var image := texture.get_image()
	var transform := sprite.get_global_transform_with_canvas()
	var center := texture.get_size() * 0.5
	for y in range(0, image.get_height(), 24):
		for x in range(0, image.get_width(), 24):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.5 and absf(pixel.r - skin.r) < 0.035 and absf(pixel.g - skin.g) < 0.035 and absf(pixel.b - skin.b) < 0.035:
				if playfield.has_point(transform * (Vector2(x, y) - center)):
					return true
	return false


func _test_scoring(can: Node) -> void:
	_check(can.call("get_points", 0.5, 0.7) == 150, "A centered shot includes the perfect bonus")
	_check(can.call("get_points", 0.6, 0.8) == 50, "Both edges of the hit zone count as a minimum-points hit")
	_check(can.call("get_points", 0.7, 0.7) == 0, "A shot outside the direction zone earns no points")
	_check(can.call("get_points", 0.5, 0.9) == 0, "A shot outside the power zone earns no points")
	can.set("direction_tolerance", 0.0)
	can.set("power_tolerance", 0.0)
	_check(can.call("get_points", 0.5, 0.7) == 150, "An exact target with zero tolerance scores without division by zero")
	can.set("direction_tolerance", 0.1)
	can.set("power_tolerance", 0.1)


func _check_target_contains_marker(gauge: Node2D, vertical: bool) -> void:
	var marker: TextureRect = gauge.get_node("Line")
	var target: Control = gauge.get_node("TargetZone")
	var center := marker.position + marker.size * 0.5
	var inside := center.y >= target.position.y and center.y <= target.position.y + target.size.y if vertical else center.x >= target.position.x and center.x <= target.position.x + target.size.x
	_check(inside, "The power target matches the scoring zone" if vertical else "The direction target matches the scoring zone")


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
