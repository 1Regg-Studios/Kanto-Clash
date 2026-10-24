extends Node

const GAME := preload("res://games/Tug Of war/tug_ofwar.tscn")
const PLAYER_KEYS: Array[Key] = [KEY_A, KEY_F, KEY_J, KEY_SEMICOLON]

var _failures := 0
var _capture_dir := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	call_deferred("_run")


func _run() -> void:
	_test_atlases()
	for round_number in [1, 2]:
		await _test_arena(round_number)
	print("TUG EFFECTS: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _test_atlases() -> void:
	for player in 4:
		var original := load("res://games/Tug Of war/assets/p%d effect.png" % (player + 1)) as Texture2D
		var cleaned := load("res://games/Tug Of war/assets/p%d-pull-effect.png" % (player + 1)) as Texture2D
		var idle := load("res://games/Tug Of war/assets/p%d-puller.png" % (player + 1)) as Texture2D
		var source := original.get_image()
		var effect := cleaned.get_image()
		var rest := idle.get_image()
		_check(effect.get_size() == Vector2i(160, 32), "P%d has five complete effect frames" % (player + 1))
		var rope_removed := true
		var artwork_preserved := true
		for y in 32:
			for x in source.get_width():
				var frame := x / 32
				var high_grip := frame == 0 or (player == 1 and frame == 3)
				var rope_start := 22 if high_grip else 21
				var rope_top := 18 if high_grip else 19
				if x % 32 >= rope_start and y >= rope_top and y <= rope_top + 2:
					rope_removed = rope_removed and effect.get_pixel(x, y).a == 0.0
				else:
					artwork_preserved = artwork_preserved and _same_pixel(source.get_pixel(x, y), effect.get_pixel(x, y))
		_check(rope_removed, "P%d effect has no baked-in rope beyond its hands" % (player + 1))
		_check(artwork_preserved, "P%d character and motion lines are preserved" % (player + 1))
		var matches_rest := true
		for y in 32:
			for x in 32:
				matches_rest = matches_rest and _same_pixel(effect.get_pixel(128 + x, y), rest.get_pixel(96 + x, y))
		_check(matches_rest, "P%d effect ends in the same pose as its idle animation" % (player + 1))


func _test_arena(round_number: int) -> void:
	GameSchedule.tug_round = round_number
	var game = GAME.instantiate()
	game.match_seconds = 300.0
	game.get_node("HUD/Root/GameOver").display_seconds = 10.0
	add_child(game)
	while game.get("_round_intro_active"):
		await get_tree().process_frame
	var layout := "round-%d" % round_number
	var world: Node2D = game.get_node("World")
	var rope: Line2D = world.get_node("Rope")
	for player in 4:
		var puller: AnimatedSprite2D = world.get_node("P%d" % (player + 1))
		_check(puller.flip_h == (player >= 2), "%s: P%d faces the opposing fixed team" % [layout, player + 1])
		_check(is_equal_approx(puller.position.x, game.PLAYER_X[player]), "%s: P%d keeps its fixed arena slot" % [layout, player + 1])
	_check(world.find_children("*", "AnimatedSprite2D", false, false).size() == 4, layout + ": one sprite per player")
	_check(world.find_children("*", "Line2D", false, false).size() == 1, layout + ": one continuous rope")
	_check(rope.get_point_count() == 2, layout + ": rope has both endpoints")
	if rope.get_point_count() != 2:
		game.queue_free()
		await get_tree().process_frame
		return
	await _capture(layout + "-idle")

	var aligned := true
	for animation in [&"pull", &"pull_effect"]:
		var frame_count := 4 if animation == &"pull" else 5
		for frame in frame_count:
			for player in 4:
				var puller: AnimatedSprite2D = world.get_node("P%d" % (player + 1))
				puller.pause()
				puller.animation = animation
				puller.frame = frame
				var high_grip := frame == 0 or (player == 1 and frame >= 3)
				var grip_row := 19.5 if high_grip else 20.5
				var grip_y := puller.to_global(Vector2(0.0, grip_row - 16.0 + puller.offset.y)).y
				aligned = aligned and is_equal_approx(grip_y, rope.to_global(rope.points[0]).y)
			await _check_rope_ends(world, rope, "%s %s frame %d" % [layout, animation, frame])
			if animation == &"pull_effect":
				await _capture("%s-effect-%d" % [layout, frame])
	_check(aligned, layout + ": every idle and effect frame keeps the hands on the rope")
	for player in 4:
		world.get_node("P%d" % (player + 1)).play(&"pull")

	for player in 4:
		var before: float = game.get("_rope_pos")
		_key(PLAYER_KEYS[player], true)
		await get_tree().process_frame
		var puller: AnimatedSprite2D = world.get_node("P%d" % (player + 1))
		var team_one := player < 2
		var expected: float = before + (-12.0 if team_one else 12.0)
		_check(game.get("_rope_pos") == expected, "%s: P%d pulls once in its team's direction" % [layout, player + 1])
		_check(puller.animation == &"pull_effect" and puller.is_playing() and puller.visible, "%s: P%d plays its effect on the visible sprite" % [layout, player + 1])
		_key(PLAYER_KEYS[player], true, true)
		await get_tree().process_frame
		_check(game.get("_rope_pos") == expected, "%s: P%d held-key repeats do not add pulls" % [layout, player + 1])
		_key(PLAYER_KEYS[player], false)
	await get_tree().create_timer(0.55).timeout
	var resumed := true
	for player in 4:
		var puller: AnimatedSprite2D = world.get_node("P%d" % (player + 1))
		resumed = resumed and puller.visible and puller.is_playing() and puller.animation == &"pull"
	_check(resumed, layout + ": all four effects return to the idle loop")

	for _round in 5:
		for key in PLAYER_KEYS:
			_tap(key)
		await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	for key in PLAYER_KEYS:
		_tap(key)
	await get_tree().process_frame
	var restarted := true
	for player in 4:
		var puller: AnimatedSprite2D = world.get_node("P%d" % (player + 1))
		restarted = restarted and puller.visible and puller.animation == &"pull_effect" and puller.frame == 0
	_check(restarted, layout + ": rapid taps consistently restart each effect")
	_check(game.get("_rope_pos") == 0.0, layout + ": equal opposing taps keep the rope centered")
	_check(world.find_children("*", "AnimatedSprite2D", false, false).size() == 4, layout + ": rapid taps create no duplicate sprites")
	await _capture(layout + "-rapid-taps")

	if round_number == 2:
		game.set("_time_left", 0.0)
	else:
		for _tap_index in 56:
			_tap(KEY_A)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(game.get("_game_over"), layout + ": round ends during an active effect")
	var stopped := true
	for player in 4:
		var puller: AnimatedSprite2D = world.get_node("P%d" % (player + 1))
		stopped = stopped and puller.visible and not puller.is_playing() and puller.animation == &"pull" and puller.frame == 1
	_check(stopped, layout + ": round end clears every effect and holds the resting pose")
	game.queue_free()
	await get_tree().process_frame


func _check_rope_ends(world: Node2D, rope: Line2D, context: String) -> void:
	var left: AnimatedSprite2D = world.get_node("P1")
	var right: AnimatedSprite2D = world.get_node("P4")
	var start := rope.to_global(rope.points[0])
	var end := rope.to_global(rope.points[1])
	_check(start.x >= left.global_position.x and end.x <= right.global_position.x, context + ": rope ends stay inside the outer players")
	if DisplayServer.get_name() == "headless":
		return

	# Compare actual rendered pixels with the rope hidden. Nothing behind the
	# outer hands should change, including gaps in the animated silhouettes.
	await RenderingServer.frame_post_draw
	var with_rope := get_viewport().get_texture().get_image()
	rope.hide()
	await RenderingServer.frame_post_draw
	var without_rope := get_viewport().get_texture().get_image()
	rope.show()
	_check(with_rope.get_data() != without_rope.get_data(), context + ": rope is visible between the players")
	var left_grip_column := 22.0 if left.frame == 0 else 21.0
	var right_grip_column := 22.0 if right.frame == 0 else 21.0
	var left_grip := left.get_global_transform_with_canvas() * Vector2(left_grip_column - 16.0, 0.0)
	var right_grip := right.get_global_transform_with_canvas() * Vector2(16.0 - right_grip_column, 0.0)
	var transform := rope.get_global_transform_with_canvas()
	var top := floori((transform * (rope.points[0] - Vector2(0.0, rope.width * 0.5))).y)
	var bottom := ceili((transform * (rope.points[0] + Vector2(0.0, rope.width * 0.5))).y)
	var left_strip := Rect2i(0, top, floori(left_grip.x), bottom - top)
	var right_strip := Rect2i(ceili(right_grip.x), top, with_rope.get_width() - ceili(right_grip.x), bottom - top)
	_check(with_rope.get_region(left_strip).get_data() == without_rope.get_region(left_strip).get_data(), context + ": no visible rope behind the left player")
	_check(with_rope.get_region(right_strip).get_data() == without_rope.get_region(right_strip).get_data(), context + ": no visible rope behind the right player")


func _same_pixel(a: Color, b: Color) -> bool:
	return a.a == b.a and (a.a == 0.0 or a == b)


func _tap(key: Key) -> void:
	_key(key, true)
	_key(key, false)


func _key(key: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)


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
	var error := get_viewport().get_texture().get_image().save_png(_capture_dir.path_join("tug-" + filename + ".png"))
	_check(error == OK, "Saved " + filename)
