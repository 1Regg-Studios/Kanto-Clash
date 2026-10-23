extends Node

signal turn_started(player_id: int)

const MAX_PLAYERS := 4
const ATTEMPTS_PER_PLAYER := 3
# Throw frames 0-4 include the arm; frames 5-9 contain only the flying slipper.
const FIRST_RELEASED_THROW_FRAME := 5
const ROUND_RESULTS_SCENE := "res://src/UI/roundleaderboard/roundleaderboard.tscn"
const GAME_FONT: Font = preload("res://assets/Fonts/UpheavalPro.ttf")
const PLAYER_COLORS: Array[Color] = [Color("8cdb64"), Color("fbc052"), Color("f08dc6"), Color("70c8f0")]
const PLAYER_ANIMATION_PATHS: Array[String] = [
	"res://games/Tumbang Preso/Scene/player_1_frames.tres",
	"res://games/Tumbang Preso/Scene/player_2_frames.tres",
	"res://games/Tumbang Preso/Scene/player_3_frames.tres",
	"res://games/Tumbang Preso/Scene/player_4_frames.tres",
]
const KEY_INDICATORS_IDLE: Array[Texture2D] = [
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P1.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P2.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P3.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P4.png"),
]
const KEY_INDICATORS_PRESSED: Array[Texture2D] = [
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P1.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P2.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P3.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P4.png"),
]
const KEY_PRESS_HOLD := 0.12

@export var direction_gauge: Node
@export var power_gauge: Node
@export var can: Node
@export var turn_label: Label
@export var result_label: Label
@export var score_label: Label
@export var instruction_label: Label
@export var attempt_label: Label
@export var key_indicator: TextureRect
@export var key_label: Label
@export var turn_end_overlay: ColorRect
@export var turn_end_detail: Label

@export_range(1, 4) var total_players: int = 4
@export_range(0.0, 10.0) var result_delay: float = 2.0
@export_range(0.0, 10.0) var turn_end_delay: float = 2.0

@export var direction_speed: float = 1.2
@export var power_speed: float = 1.0
@export var speed_increase_per_turn: float = 0.0   # 0 = same for everyone

@export var thrower: AnimatedSprite2D
@export var released_hand: Sprite2D
@export var throw_animation: StringName = &"throw"
@export var idle_animation: StringName = &"idle"
@export var follow_through_animation: StringName = &"follow_through"
@export var empty_idle_animation: StringName = &"empty_idle"

enum State { INTRO, DIRECTION, POWER, RESULT, TURN_END, GAME_OVER }
var state: State = State.INTRO

var current_player: int = 1
var current_attempt: int = 1
var scores: Array[int] = [0, 0, 0, 0]
var direction_value: float = 0.5
var power_value: float = 0.5
var _turn_id := 0
var _intro_overlay: CanvasLayer
var _intro_tween: Tween
var _key_press_time_left := 0.0
var _key_indicator_down := false


func _ready() -> void:
	total_players = clampi(total_players, 1, MAX_PLAYERS)
	if direction_gauge == null or power_gauge == null or can == null or turn_label == null or result_label == null or score_label == null:
		push_error("Tumbang Preso's Controller needs both gauges, the can, and its HUD labels assigned.")
		set_process_input(false)
		return
	if thrower != null:
		thrower.frame_changed.connect(_update_released_hand)
		thrower.animation_changed.connect(_update_released_hand)
		thrower.animation_finished.connect(_on_thrower_animation_finished)
	start_turn()


func start_turn() -> void:
	_clear_round_intro()
	state = State.INTRO
	current_attempt = 1
	turn_label.text = "PLAYER %d'S TURN  /  %d" % [current_player, total_players]
	turn_label.add_theme_color_override("font_color", PLAYER_COLORS[current_player - 1])
	if turn_end_overlay != null:
		turn_end_overlay.hide()
	_prepare_attempt()
	if instruction_label != null:
		instruction_label.text = ""
	_show_round_intro()


func _prepare_attempt() -> void:
	_turn_id += 1
	result_label.text = ""
	_reset_key_indicator()
	if attempt_label != null:
		attempt_label.text = "ATTEMPT %d / %d" % [current_attempt, ATTEMPTS_PER_PLAYER]
	_update_scores()

	can.reset_can()
	reset_thrower()
	direction_value = 0.5
	power_value = 0.5
	direction_gauge.reset()
	power_gauge.reset()
	direction_gauge.set_target(can.target_direction, can.direction_tolerance)
	power_gauge.set_target(can.target_power, can.power_tolerance)
	var bonus := (current_player - 1) * speed_increase_per_turn
	direction_gauge.speed = direction_speed + bonus
	power_gauge.speed = power_speed + bonus


func _begin_attempt() -> void:
	state = State.DIRECTION
	direction_gauge.start()


func _input(event: InputEvent) -> void:
	if not _is_space_press(event):
		return
	if state == State.GAME_OVER:
		get_viewport().set_input_as_handled()
		restart()
		return

	if state in [State.INTRO, State.RESULT, State.TURN_END]:
		return

	get_viewport().set_input_as_handled()
	_key_press_time_left = KEY_PRESS_HOLD
	_set_key_indicator(true)
	match state:
		State.DIRECTION:
			direction_value = direction_gauge.lock()
			state = State.POWER
			power_gauge.start()
		State.POWER:
			power_value = power_gauge.lock()
			finish_turn()


func _is_space_press(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return false
	var key_event := event as InputEventKey
	return key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE


func _process(delta: float) -> void:
	_key_press_time_left = maxf(0.0, _key_press_time_left - delta)
	var down := _key_press_time_left > 0.0 or (_key_indicator_down and Input.is_physical_key_pressed(KEY_SPACE))
	_set_key_indicator(down)


func _reset_key_indicator() -> void:
	_key_press_time_left = 0.0
	_key_indicator_down = false
	if key_indicator != null:
		key_indicator.texture = KEY_INDICATORS_IDLE[current_player - 1]
	if key_label != null:
		key_label.add_theme_color_override("font_color", Color("fbc052"))


func _set_key_indicator(down: bool) -> void:
	if _key_indicator_down == down:
		return
	_key_indicator_down = down
	if key_indicator != null:
		key_indicator.texture = KEY_INDICATORS_PRESSED[current_player - 1] if down else KEY_INDICATORS_IDLE[current_player - 1]
	if key_label != null:
		key_label.add_theme_color_override("font_color", Color.WHITE if down else Color("fbc052"))


func finish_turn() -> void:
	if state != State.POWER:
		return
	state = State.RESULT
	direction_gauge.lock()
	power_gauge.lock()
	if instruction_label != null:
		instruction_label.text = "THROWING..."
	var turn_id := _turn_id
	await play_throw()
	if turn_id != _turn_id or not is_inside_tree():
		return

	var hit: bool = can.check_hit(direction_value, power_value)
	var points: int = can.get_points(direction_value, power_value) if hit else 0

	var miss_penalty := 10
	scores[current_player - 1] += points if hit else -miss_penalty
	scores[current_player - 1] = maxi(scores[current_player - 1], 0)
	result_label.text = ("HIT! +%d" % points) if hit else ("MISS -%d" % miss_penalty)
	_update_scores()
	if instruction_label != null:
		instruction_label.text = ""

	await get_tree().create_timer(maxf(result_delay, 0.0), false).timeout
	if turn_id != _turn_id:
		return

	if current_attempt < ATTEMPTS_PER_PLAYER:
		current_attempt += 1
		_prepare_attempt()
		_begin_attempt()
	else:
		_finish_player_turn()


func _finish_player_turn() -> void:
	if state != State.RESULT or current_attempt != ATTEMPTS_PER_PLAYER:
		return
	state = State.TURN_END
	_reset_key_indicator()
	result_label.text = ""
	var turn_id := _turn_id
	var detail := "PLAYER %d: %d POINTS IN %d THROWS" % [current_player, scores[current_player - 1], ATTEMPTS_PER_PLAYER]
	detail += "\nNEXT: PLAYER %d" % (current_player + 1) if current_player < total_players else "\nFINAL RESULTS..."
	if turn_end_detail != null:
		turn_end_detail.text = detail
	if turn_end_overlay != null:
		turn_end_overlay.show()
	else:
		result_label.text = "TURN COMPLETE!\n" + detail
	await get_tree().create_timer(maxf(turn_end_delay, 0.0), false).timeout
	if turn_id != _turn_id:
		return
	if current_player >= total_players:
		show_final()
	else:
		current_player += 1
		start_turn()


func show_final() -> void:
	if state == State.GAME_OVER:
		return
	state = State.GAME_OVER
	_reset_key_indicator()
	if turn_end_overlay != null:
		turn_end_overlay.hide()
	if attempt_label != null:
		attempt_label.text = ""

	var best_score: int = scores.slice(0, total_players).max()
	var winners: Array[String] = []
	for i in total_players:
		if scores[i] == best_score:
			winners.append("P%d" % (i + 1))

	turn_label.text = "GAME OVER"
	if winners.size() == 1:
		result_label.text = "%s WINS!" % winners[0]
	else:
		result_label.text = "TIE: %s" % " & ".join(winners)
	var scheduled := _is_scheduled_game()
	if instruction_label != null:
		instruction_label.text = "OPENING GAME LEADERBOARD..." if scheduled else "Press SPACE to play again"
	if scheduled:
		set_process_input(false)
		ScoreKeeper.add_round_scores(scores, &"tumbang_preso")
		await SceneFader.change_scene(ROUND_RESULTS_SCENE)


func _is_scheduled_game() -> bool:
	var index := GameSchedule.current_game_index
	return index >= 0 and index < GameSchedule.picked.size() and GameSchedule.picked[index] == "tumbang_preso"


func restart() -> void:
	scores = [0, 0, 0, 0]
	current_player = 1
	start_turn()


func _update_scores() -> void:
	score_label.text = str(scores[current_player - 1])


func _show_round_intro() -> void:
	_intro_overlay = CanvasLayer.new()
	_intro_overlay.name = "RoundIntro"
	_intro_overlay.layer = 20
	add_child(_intro_overlay)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.015, 0.025, 0.06, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_overlay.add_child(shade)
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
	_intro_tween = create_tween()
	for text in ["GET READY...", "PLAYER %d" % current_player, "5", "4", "3", "2", "1", "START!"]:
		var is_countdown_number: bool = text in ["5", "4", "3", "2", "1"]
		_intro_tween.tween_callback(func() -> void:
			label.text = text
			label.modulate.a = 0.0
			label.scale = Vector2.ONE * 0.8
		)
		_intro_tween.set_parallel(true)
		_intro_tween.tween_property(label, "modulate:a", 1.0, 0.2)
		_intro_tween.tween_property(label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_intro_tween.set_parallel(false)
		_intro_tween.tween_interval(0.75 if is_countdown_number or text == "START!" else 1.15)
		_intro_tween.tween_property(label, "modulate:a", 0.0, 0.16)
	_intro_tween.finished.connect(_on_round_intro_finished.bind(_turn_id))


func _on_round_intro_finished(turn_id: int) -> void:
	if turn_id != _turn_id:
		return
	_clear_round_intro()
	_begin_attempt()
	turn_started.emit(current_player)


func _clear_round_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null
	if is_instance_valid(_intro_overlay):
		remove_child(_intro_overlay)
		_intro_overlay.queue_free()
	_intro_overlay = null


func reset_thrower() -> void:
	if thrower == null:
		return
	thrower.stop()
	# Swap the complete set together so the hand and slipper keep this player's colors.
	# Load on handoff rather than retaining all four full-resolution sets at once.
	var frames_path := PLAYER_ANIMATION_PATHS[current_player - 1]
	if thrower.sprite_frames == null or thrower.sprite_frames.resource_path != frames_path:
		thrower.sprite_frames = load(frames_path) as SpriteFrames
	if thrower.sprite_frames == null:
		return
	if thrower.sprite_frames.has_animation(idle_animation):
		thrower.play(idle_animation)
	elif thrower.sprite_frames.has_animation(throw_animation):
		thrower.animation = throw_animation
		thrower.frame = 0
	_update_released_hand()


func play_throw() -> void:
	if thrower == null or thrower.sprite_frames == null:
		return
	if not thrower.sprite_frames.has_animation(throw_animation):
		return

	thrower.sprite_frames.set_animation_loop(throw_animation, false)
	thrower.stop()
	thrower.play(throw_animation)
	await thrower.animation_finished


func _on_thrower_animation_finished() -> void:
	if thrower.animation == throw_animation and thrower.sprite_frames.has_animation(follow_through_animation):
		# The first follow-through poses already played underneath the flying slipper.
		var played_hand_frames := thrower.sprite_frames.get_frame_count(throw_animation) - FIRST_RELEASED_THROW_FRAME
		thrower.play(follow_through_animation)
		thrower.set_frame_and_progress(clampi(played_hand_frames, 0, thrower.sprite_frames.get_frame_count(follow_through_animation) - 1), 0.0)
	elif thrower.animation == follow_through_animation and thrower.sprite_frames.has_animation(empty_idle_animation):
		thrower.play(empty_idle_animation)


func _update_released_hand() -> void:
	if released_hand == null:
		return
	# Clear the layer on reset/handoff as well as when a different pose is shown.
	released_hand.hide()
	released_hand.texture = null
	if thrower.animation != throw_animation or thrower.frame < FIRST_RELEASED_THROW_FRAME:
		return
	var frames := thrower.sprite_frames
	if not frames.has_animation(follow_through_animation) or frames.get_frame_count(follow_through_animation) == 0:
		return
	var hand_frame := mini(thrower.frame - FIRST_RELEASED_THROW_FRAME, frames.get_frame_count(follow_through_animation) - 1)
	released_hand.texture = frames.get_frame_texture(follow_through_animation, hand_frame)
	released_hand.show()
