extends Node

const GAME_SCENES: Array[PackedScene] = [
	preload("res://games/Chinese Garter/chinese_garter.tscn"),
	preload("res://games/Chinese Garter/chinese_garter_draft.tscn"),
]

var _failures := 0


func _ready() -> void:
	get_tree().create_timer(20.0, true, false, true).timeout.connect(func() -> void:
		push_error("The Chinese Garter countdown test timed out")
		get_tree().quit(1)
	)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(0.7).timeout
	Engine.time_scale = 4.0
	for packed in GAME_SCENES:
		await _test_countdown(packed)
	Engine.time_scale = 1.0
	AudioManager.stop_game_music()
	await get_tree().create_timer(AudioManager.MUSIC_FADE_TIME + 0.15).timeout
	print("CHINESE GARTER COUNTDOWN: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _test_countdown(packed: PackedScene) -> void:
	var game := packed.instantiate() as Node2D
	game.set("practice_mode", true)
	add_child(game)
	print("Testing ", game.scene_file_path)
	var gauge: Node2D = game.get_node("TimingGuage")
	var player: CharacterBody2D = game.get_node("ChineseGarterPlayerScene/PlayerBody")
	var label: Label = game.get_node("RoundIntro/Shade/Countdown")
	var timer: Label = game.get_node("HUD/Timer/Label")
	var initial_position := player.position
	var initial_needle: float = gauge.get("t")
	var initial_zone := Vector2(gauge.get("zone_start"), gauge.get("zone_end"))
	_check(game.get("_round_intro_active") and not gauge.get("game_active") and not player.is_physics_processing(), "The game opens with the gauge and player frozen")

	# Test manual-restart input too: SPACE must not queue a timing attempt.
	gauge.set("auto_restart", false)
	Input.action_press("ui_right")
	_send_space()
	await get_tree().create_timer(0.15).timeout
	Input.action_release("ui_right")
	_check(player.position == initial_position and gauge.get("score") == 0 and game.get("_press_time_left") == 0.0, "Countdown inputs cannot move, score, or light the press indicator")
	_check(Vector2(gauge.get("zone_start"), gauge.get("zone_end")) == initial_zone, "Countdown input cannot move the target zone")

	var paused_text := label.text
	var paused_alpha := label.modulate.a
	var paused_scale := label.scale
	get_tree().paused = true
	await get_tree().create_timer(0.15, true, false, true).timeout
	_check(label.text == paused_text and label.modulate.a == paused_alpha and label.scale == paused_scale, "Pausing freezes the countdown text and animation")
	get_tree().paused = false

	var steps: Array[String] = []
	var gameplay_stayed_frozen := true
	while game.get("_round_intro_active"):
		if not label.text.is_empty() and (steps.is_empty() or label.text != steps[-1]):
			steps.append(label.text)
			_send_space()
		gameplay_stayed_frozen = gameplay_stayed_frozen and (
			game.get("_time_left") == 30.0 and timer.text == "00 : 30"
			and not gauge.get("game_active") and not gauge.get("running")
			and gauge.get("t") == initial_needle and gauge.get("score") == 0
			and player.position == initial_position
		)
		await get_tree().process_frame
	_check(steps == ["GET READY...", "PLAYER 1", "5", "4", "3", "2", "1", "START!"], "The full countdown identifies the active player before play")
	_check(gameplay_stayed_frozen, "The countdown preserves all 30 seconds and keeps gameplay frozen through START!")
	_check(gauge.get("game_active") and gauge.get("running") and player.is_physics_processing(), "Gameplay activates after the countdown finishes")
	gauge.set("auto_restart", true)
	await get_tree().create_timer(0.1).timeout
	_check(not game.has_node("RoundIntro"), "The countdown overlay is removed before play")
	_check(float(game.get("_time_left")) < 30.0 and gauge.get("t") != initial_needle, "The game timer and needle start moving together")

	gauge.set("t", (float(gauge.get("zone_start")) + float(gauge.get("zone_end"))) * 0.5)
	_send_space()
	_check(gauge.get("score") == 1 and game.get_node("HUD/Score/Value").text == "1", "A timing hit scores normally after the countdown")
	_check(player.velocity.y < 0.0 and player.get("_jump_animation_active"), "A successful hit still triggers the jump animation")

	# End during the hit's pending restart to check the timer/start boundary.
	game.set("_time_left", 0.01)
	await get_tree().create_timer(0.1).timeout
	_check(game.get("_round_finished") and timer.text == "00 : 00" and game.get_node("TimeUpOverlay/Dimmer").visible, "The round still ends with the TIME'S UP overlay")
	_send_space()
	await get_tree().create_timer(float(gauge.get("restart_delay")) + 0.1).timeout
	_check(not gauge.get("game_active") and not gauge.get("running") and gauge.get("score") == 1, "Input and pending attempts cannot restart an expired round")
	game.queue_free()
	await get_tree().process_frame


func _send_space() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.physical_keycode = KEY_SPACE
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)
