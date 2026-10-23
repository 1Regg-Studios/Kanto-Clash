extends "res://games/Chinese Garter/chinese_garter_ui.gd"

signal demo_key_changed(pressed: bool)

const DEMO_TURN_SECONDS := 8.0

var _demo_elapsed := 0.0


func _ready() -> void:
	# Autoplay the real gauge and jump animation in an isolated world. The
	# preview never starts the match countdown, submits scores, or changes scenes.
	set_process_input(false)
	_gauge.set_process_input(false)
	_gauge.hit.connect(_on_hit)
	_gauge.missed.connect(_on_missed)
	_gauge.round_started.connect(_on_round_started)
	$PauseMenu.process_mode = Node.PROCESS_MODE_DISABLED
	_player_spawn = _player.position
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()
	_restart_demo()


func _restart_demo() -> void:
	_demo_elapsed = 0.0
	_prepare_turn()
	_round_intro_active = false
	_gauge.start_game()
	_player.set_physics_process(true)


func _process(delta: float) -> void:
	_demo_elapsed += delta
	_press_time_left = maxf(0.0, _press_time_left - delta)
	var down := _press_time_left > 0.0
	if down != _indicator_down:
		_set_indicator(down)
		demo_key_changed.emit(down)
	if _demo_elapsed >= DEMO_TURN_SECONDS:
		_turn_index = (_turn_index + 1) % PLAYER_COUNT
		_restart_demo()
		demo_key_changed.emit(false)
	elif _gauge.running and _player.is_on_floor():
		var center: float = (_gauge.zone_start + _gauge.zone_end) * 0.5
		if absf(_gauge.t - center) <= 0.04:
			_gauge.attempt_hit()
