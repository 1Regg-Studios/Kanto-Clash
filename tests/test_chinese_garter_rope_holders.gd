extends Node

const GAME: PackedScene = preload("res://games/Chinese Garter/chinese_garter.tscn")
const PLAYER_SCENE: PackedScene = preload("res://games/Chinese Garter/ChineseGarterPlayerScene.tscn")

var _failures := 0
var _capture_dir := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	get_tree().create_timer(25.0, true, false, true).timeout.connect(func() -> void:
		push_error("The Chinese Garter rope holder test timed out")
		get_tree().quit(1)
	)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(0.7).timeout
	_test_holder_selection()
	await _test_score_progression()
	Engine.time_scale = 1.0
	AudioManager.stop_game_music()
	await get_tree().create_timer(AudioManager.MUSIC_FADE_TIME + 0.15).timeout
	print("CHINESE GARTER ROPE HOLDERS: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _test_holder_selection() -> void:
	var scene := PLAYER_SCENE.instantiate()
	add_child(scene)
	scene.get_node("PlayerBody").set_physics_process(false)
	var holders: Node2D = scene.get_node("RopeHolders")
	seed(3814)
	for active_player in range(1, 5):
		var eligible := true
		var resets_low := true
		var correct_textures := true
		var pairs := {}
		for roll in 96:
			holders.call("start_turn", active_player)
			var ids: Array = holders.get("_holder_player_ids")
			eligible = eligible and ids.size() == 2 and ids[0] != ids[1] and not ids.has(active_player)
			for id in ids:
				eligible = eligible and id >= 1 and id <= 4
			pairs["%d,%d" % [ids[0], ids[1]]] = true
			resets_low = resets_low and holders.get("_height") == 0
			correct_textures = correct_textures and _holder_textures_match(holders, 0)
			holders.call("update_score", 5)
			correct_textures = correct_textures and _holder_textures_match(holders, 1)
			holders.call("update_score", 10)
			correct_textures = correct_textures and _holder_textures_match(holders, 2)
		_check(eligible, "P%d is never a holder, and the two randomized holders are different players" % active_player)
		_check(pairs.size() == 6, "P%d can receive every ordered pair of the other three colors" % active_player)
		_check(resets_low, "Every P%d handoff resets a previously high rope to low" % active_player)
		_check(correct_textures, "P%d's eligible holders display the matching color and filename-defined pose at all three heights" % active_player)
	var purple_texture: Texture2D = holders.get("_purple_low_texture")
	var image := purple_texture.get_image()
	var purple_pixels := 0
	var green_pixels := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a == 0.0:
				continue
			if color.to_html(false) in ["e297e2", "9a7ac3", "ffbfff"]:
				purple_pixels += 1
			elif color.to_html(false) in ["8fde5d", "3ca370", "cfff70"]:
				green_pixels += 1
	_check(purple_pixels == 32 and green_pixels == 0, "The missing purple low pose uses the purple shirt palette without green pixels")
	scene.queue_free()


func _holder_textures_match(holders: Node2D, height: int) -> bool:
	var ids: Array = holders.get("_holder_player_ids")
	var sprites: Array[Sprite2D] = [holders.get_node("LeftHolder"), holders.get_node("RightHolder")]
	for index in ids.size():
		var texture := sprites[index].texture
		if ids[index] == 3 and height == 0:
			if texture != holders.get("_purple_low_texture"):
				return false
		else:
			var color_suffix: String = ["", "orange", "purple", "blue"][ids[index] - 1]
			var pose_suffix: String = ["3", "2", ""][height]
			if texture.resource_path.get_file() != "ropeholder%s%s.png" % [pose_suffix, color_suffix]:
				return false
	return true


func _test_score_progression() -> void:
	Engine.time_scale = 4.0
	var game := GAME.instantiate() as Node2D
	game.set("practice_mode", true)
	add_child(game)
	await game.turn_started
	await get_tree().physics_frame
	await get_tree().physics_frame
	game.set_process(false)
	game.set_process_input(false)
	var gauge: Node2D = game.get_node("TimingGuage")
	gauge.set_process(false)
	var holders: Node2D = game.get_node("ChineseGarterPlayerScene/RopeHolders")
	var left: Sprite2D = holders.get_node("LeftHolder")
	var right: Sprite2D = holders.get_node("RightHolder")
	var rope: Sprite2D = holders.get_node("Rope")
	var ids: Array = holders.get("_holder_player_ids").duplicate()
	var low_y := rope.global_position.y
	var middle_y := low_y
	var high_y := low_y
	var positions := [left.position, right.position]
	_check(gauge.get("score") == 0 and holders.get("_height") == 0, "A fresh live turn starts in the low rope pose at score 0")
	_check(left.scale.x > 0.0 and right.scale.x < 0.0, "Both characters face inward toward the rope")
	await _capture("chinese-garter-rope-low")
	for score in range(1, 12):
		gauge.set("t", (float(gauge.get("zone_start")) + float(gauge.get("zone_end"))) * 0.5)
		gauge.call("attempt_hit")
		_check(gauge.get("score") == score and game.get_node("HUD/Score/Value").text == str(score), "Timing hit %d updates the real gameplay score" % score)
		var expected_height := 0 if score < 5 else (1 if score < 10 else 2)
		_check(holders.get("_height") == expected_height, "Score %d selects the correct low/middle/high holder pose" % score)
		_check(holders.get("_holder_player_ids") == ids and [left.position, right.position] == positions, "Score %d preserves the selected characters and their footing" % score)
		if score == 4:
			_check(rope.global_position.y == low_y, "The rope stays low through score 4")
		elif score == 5:
			middle_y = rope.global_position.y
			_check(middle_y < low_y, "The connected rope rises at exactly score 5")
			await _capture("chinese-garter-rope-middle")
		elif score == 9:
			_check(rope.global_position.y == middle_y, "The rope stays in the middle through score 9")
		elif score == 10:
			high_y = rope.global_position.y
			_check(high_y < middle_y, "The connected rope reaches its highest hold at exactly score 10")
			await _capture("chinese-garter-rope-high")
		elif score == 11:
			_check(rope.global_position.y == high_y, "The rope stays at its highest hold above score 10")
		await get_tree().create_timer(1.25, false).timeout
	gauge.set("t", 0.0)
	gauge.call("attempt_hit")
	_check(gauge.get("score") == 11 and holders.get("_height") == 2 and rope.global_position.y == high_y, "A miss preserves the score-based rope height")
	for player_index in range(1, 4):
		game.set("_turn_index", player_index)
		game.call("_prepare_turn")
		_check(gauge.get("score") == 0 and holders.get("_height") == 0 and rope.global_position.y == low_y, "P%d begins with a freshly lowered rope" % (player_index + 1))
		_check(not holders.get("_holder_player_ids").has(player_index + 1), "The live turn reset excludes P%d from both rope holders" % (player_index + 1))
	game.queue_free()
	await get_tree().process_frame


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
