extends "res://games/Tumbang Preso/Script/controller.gd"

signal demo_key_changed(pressed: bool)

const MIN_STAGE_SECONDS := 0.65
const PRESS_SECONDS := 0.18
const LOCK_WINDOW := 0.04

var _stage_elapsed := 0.0
var _press_time_left := 0.0
var _indicator_down := false


func _ready() -> void:
	# Autoplay the real gauges, throw, and can without accepting player input or
	# starting a match countdown. All displayed scores belong only to this demo.
	set_process_input(false)
	if thrower != null:
		thrower.animation_finished.connect(_on_thrower_animation_finished)
	start_turn()


func start_turn() -> void:
	state = State.INTRO
	current_attempt = 1
	turn_label.text = "PLAYER %d'S TURN  /  %d" % [current_player, total_players]
	turn_label.add_theme_color_override("font_color", PLAYER_COLORS[current_player - 1])
	turn_end_overlay.hide()
	_prepare_attempt()
	_begin_attempt()


func _begin_attempt() -> void:
	super._begin_attempt()
	_stage_elapsed = 0.0
	instruction_label.text = "SPACE: LOCK DIRECTION"


func _process(delta: float) -> void:
	_press_time_left = maxf(0.0, _press_time_left - delta)
	_set_demo_key(_press_time_left > 0.0)
	if state not in [State.DIRECTION, State.POWER]:
		return
	_stage_elapsed += delta
	if _stage_elapsed < MIN_STAGE_SECONDS:
		return
	var gauge: Node = direction_gauge if state == State.DIRECTION else power_gauge
	var target: float = can.target_direction if state == State.DIRECTION else can.target_power
	if absf(float(gauge.get("value")) - target) > LOCK_WINDOW:
		return

	_press_time_left = PRESS_SECONDS
	_set_demo_key(true)
	_stage_elapsed = 0.0
	if state == State.DIRECTION:
		direction_value = direction_gauge.lock()
		state = State.POWER
		power_gauge.start()
		instruction_label.text = "SPACE AGAIN: LOCK POWER"
	else:
		power_value = power_gauge.lock()
		finish_turn()


func _finish_player_turn() -> void:
	# Repeat three real throws per player, then loop P4 back to P1 instead of
	# opening final results or advancing the scheduled game.
	current_player = current_player % total_players + 1
	if current_player == 1:
		scores.fill(0)
	start_turn()


func _set_demo_key(pressed: bool) -> void:
	if pressed == _indicator_down:
		return
	_indicator_down = pressed
	_set_key_indicator(pressed)
	demo_key_changed.emit(pressed)
