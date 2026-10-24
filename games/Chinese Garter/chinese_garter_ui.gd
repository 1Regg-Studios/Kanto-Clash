extends Node2D

signal turn_started(player_id: int)

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const PLAYER_COUNT := 4
const ROUND_DURATION_SECONDS := 30.0
const TURN_END_SECONDS := 2.0
const GAME_FONT: Font = preload("res://assets/Fonts/UpheavalPro.ttf")
const MAIN_MUSIC := preload("res://assets/Music/Main/Chinese Garter/tatamusic-game-gaming-minecraft-background-music-377647.mp3")
const PLAYER_COLORS: Array[Color] = [Color("8cdb64"), Color("fbc052"), Color("f08dc6"), Color("70c8f0")]
const INDICATORS_IDLE: Array[Texture2D] = [
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P1.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P2.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P3.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P4.png"),
]
const INDICATORS_PRESSED: Array[Texture2D] = [
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P1.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P2.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P3.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P4.png"),
]
const INDICATOR_SCALE := 1.12
const INDICATOR_SLOT_WIDTH := 240.0
const KEY_LABEL_SIZE := Vector2(164.0, 36.0)
const PRESS_HOLD := 0.12

## The individual player scenes keep their standalone practice behavior.
@export var practice_mode := false

@onready var _camera: Camera2D = $Camera2D
@onready var _gauge: Node2D = $TimingGuage
@onready var _player: CharacterBody2D = $ChineseGarterPlayerScene/PlayerBody
@onready var _rope_holders: Node2D = $ChineseGarterPlayerScene/RopeHolders
@onready var _score: Label = $HUD/Score/Value
@onready var _timer: Label = $HUD/Timer/Label
@onready var _feedback: Label = $HUD/Feedback
@onready var _turn_label: Label = $HUD/Turn
@onready var _turn_scores: Label = $HUD/TurnScores
@onready var _indicator: TextureRect = $HUD/PlayerIndicator/Indicator
@onready var _key_label: Label = $HUD/PlayerIndicator/Key
@onready var _time_up_overlay: ColorRect = $TimeUpOverlay/Dimmer
@onready var _time_up_detail: Label = $TimeUpOverlay/Dimmer/Detail

var _turn_index := 0
var _game_scores: Array[int] = [0, 0, 0, 0]
var _player_spawn := Vector2.ZERO
var _time_left := ROUND_DURATION_SECONDS
var _round_finished := false
var _round_intro_active := true
var _press_time_left := 0.0
var _indicator_down := false
var _application_focused := true
var _indicator_idle: Texture2D
var _indicator_pressed: Texture2D


func _ready() -> void:
	_gauge.stop_game()
	_player.set_physics_process(false)
	# One input owner prevents the HUD and gauge from judging the same press twice.
	_gauge.set_process_input(false)
	_gauge.hit.connect(_on_hit)
	_gauge.missed.connect(_on_missed)
	_gauge.round_started.connect(_on_round_started)
	_player_spawn = _player.position
	if practice_mode:
		_turn_index = _player.player_id - 1
	AudioManager.stop_menu_music()
	AudioManager.play_game_music(MAIN_MUSIC)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()
	_start_turn()


func _prepare_turn() -> void:
	_round_intro_active = true
	_round_finished = false
	_time_left = ROUND_DURATION_SECONDS
	_press_time_left = 0.0
	_gauge.reset_game()
	_player.reset_for_turn(_turn_index + 1, _player_spawn)
	_rope_holders.start_turn(_turn_index + 1)
	_score.text = "0"
	_timer.text = _format_time(_time_left)
	_feedback.text = ""
	_time_up_overlay.hide()
	_indicator_idle = INDICATORS_IDLE[_turn_index]
	_indicator_pressed = INDICATORS_PRESSED[_turn_index]
	_indicator_down = false
	_indicator.texture = _indicator_idle
	_key_label.text = "SPACE"
	_key_label.add_theme_color_override("font_color", Color("fbc052"))
	_place_indicator()
	_turn_label.text = "PLAYER %d'S TURN  /  %d" % [_turn_index + 1, PLAYER_COUNT]
	_turn_label.add_theme_color_override("font_color", PLAYER_COLORS[_turn_index])
	_update_turn_scores()


func _start_turn() -> void:
	_prepare_turn()
	await _show_round_intro()
	_round_intro_active = false
	_gauge.start_game()
	_player.set_physics_process(true)
	turn_started.emit(_turn_index + 1)


func _finish_turn() -> void:
	if _round_finished or _round_intro_active:
		return
	_round_finished = true
	_gauge.stop_game()
	_player.set_physics_process(false)
	_game_scores[_turn_index] = ScoreEngine.clamp_score(&"chinese_garter", _gauge.score)
	_feedback.text = ""
	_press_time_left = 0.0
	_set_indicator(false)
	_update_turn_scores()
	var jumps := _game_scores[_turn_index]
	_time_up_detail.text = "PLAYER %d: %d SUCCESSFUL %s" % [_turn_index + 1, jumps, "JUMP" if jumps == 1 else "JUMPS"]
	if practice_mode:
		_time_up_overlay.show()
		return
	var results := "OPENING OVERALL RESULTS..." if GameSchedule.is_last_game() else "OPENING GAME LEADERBOARD..."
	_time_up_detail.text += "\nNEXT: PLAYER %d" % (_turn_index + 2) if _turn_index + 1 < PLAYER_COUNT else "\n" + results
	_time_up_overlay.show()
	await get_tree().create_timer(TURN_END_SECONDS, false).timeout
	if _turn_index + 1 < PLAYER_COUNT:
		_turn_index += 1
		_start_turn()
	else:
		ScoreKeeper.add_round_scores(_game_scores, &"chinese_garter")
		await GameSchedule.show_results()


func _update_turn_scores() -> void:
	var entries: Array[String] = []
	for player_index in PLAYER_COUNT:
		var value := str(_game_scores[player_index])
		if player_index == _turn_index and not _round_finished:
			value = "PLAYING"
		elif player_index > _turn_index:
			value = "WAITING"
		entries.append("P%d: %s" % [player_index + 1, value])
	_turn_scores.text = "    |    ".join(entries)


func _show_round_intro() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "RoundIntro"
	overlay.layer = 20
	add_child(overlay)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.015, 0.025, 0.06, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var label := Label.new()
	label.name = "Countdown"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", GAME_FONT)
	label.add_theme_font_size_override("font_size", 108)
	label.add_theme_color_override("font_color", Color("fbc052"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	label.modulate.a = 0.0
	label.scale = Vector2.ONE * 0.8
	label.resized.connect(func() -> void: label.pivot_offset = label.size * 0.5)
	shade.add_child(label)
	label.pivot_offset = label.size * 0.5
	var reveal := create_tween()
	for text in ["GET READY...", "PLAYER %d" % (_turn_index + 1), "5", "4", "3", "2", "1", "START!"]:
		var is_countdown_number: bool = text in ["5", "4", "3", "2", "1"]
		reveal.tween_callback(func() -> void:
			label.text = text
			label.modulate.a = 0.0
			label.scale = Vector2.ONE * 0.8
		)
		reveal.set_parallel(true)
		reveal.tween_property(label, "modulate:a", 1.0, 0.2)
		reveal.tween_property(label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.set_parallel(false)
		reveal.tween_interval(0.75 if is_countdown_number or text == "START!" else 1.15)
		reveal.tween_property(label, "modulate:a", 0.0, 0.16)
	await reveal.finished
	overlay.queue_free()


func _input(event: InputEvent) -> void:
	if _round_finished or _round_intro_active or not _application_focused:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if key != KEY_SPACE:
		return
	get_viewport().set_input_as_handled()
	_press_time_left = PRESS_HOLD
	_set_indicator(true)
	_attempt_jump()


func _attempt_jump() -> void:
	# A timing hit must be able to produce a real jump before it can score.
	if _player.can_jump():
		_gauge.attempt_hit()


func _process(delta: float) -> void:
	if _round_finished or _round_intro_active:
		return
	_press_time_left = maxf(0.0, _press_time_left - delta)
	var pressed := _application_focused and (Input.is_physical_key_pressed(KEY_SPACE) or _press_time_left > 0.0)
	_set_indicator(pressed)
	_time_left = maxf(0.0, _time_left - delta)
	_timer.text = _format_time(_time_left)
	if _time_left <= 0.0:
		_finish_turn()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_application_focused = false
		_press_time_left = 0.0
		_set_indicator(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_application_focused = true


func _set_indicator(down: bool) -> void:
	if _indicator_down == down:
		return
	_indicator_down = down
	_indicator.texture = _indicator_pressed if down else _indicator_idle
	_key_label.add_theme_color_override("font_color", Color.WHITE if down else Color("fbc052"))
	_place_indicator()


func _place_indicator() -> void:
	var indicator_size := _indicator_idle.get_size() * INDICATOR_SCALE
	_indicator.size = indicator_size
	_indicator.position = Vector2((INDICATOR_SLOT_WIDTH - indicator_size.x) * 0.5, 0.0)
	_key_label.size = KEY_LABEL_SIZE
	_key_label.position = _indicator.position + Vector2((indicator_size.x - KEY_LABEL_SIZE.x) * 0.5, indicator_size.y - 52.0)


func _fit_layout() -> void:
	# Keep the entire reference composition visible on wider or taller displays.
	var viewport_size := get_viewport_rect().size
	var fit := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	_camera.zoom = Vector2.ONE * fit


func _format_time(seconds_left: float) -> String:
	var total_seconds := ceili(seconds_left)
	var minutes := int(total_seconds / 60.0)
	return "%02d : %02d" % [minutes, total_seconds % 60]


func _on_hit(perfect: bool, points: int) -> void:
	_score.text = str(_gauge.score)
	_rope_holders.update_score(_gauge.score)
	_feedback.text = ("PERFECT! +%d" if perfect else "GOOD! +%d") % points
	_press_time_left = PRESS_HOLD
	_player.jump()


func _on_missed() -> void:
	_feedback.text = "MISS!"
	_press_time_left = PRESS_HOLD
	_player.play_miss_feedback()
	AudioManager.play_error()


func _on_round_started() -> void:
	_feedback.text = ""
