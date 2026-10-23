extends "res://games/Patintero/Scripts/PlayerController.gd"

signal demo_key_changed(pressed: bool)
signal demo_action_changed(action: String)

var _demo_guards: Array[Node2D] = []
var _demo_key_down := false
var _demo_action := ""
var _tap_elapsed := -1.0


func configure_demo(guards: Array[Node2D]) -> void:
	_demo_guards.assign(guards)


func reset_demo(spawn_position: Vector2) -> void:
	set_demo_key(false)
	reset_for_round(spawn_position)
	_tap_elapsed = -1.0
	set_round_active(true)


func set_demo_key(pressed: bool) -> void:
	if pressed == _demo_key_down:
		return
	_demo_key_down = pressed
	# Use the game's tap timing locally; never inject global player input.
	if pressed:
		_press_time = _input_time
		if _input_time - _last_tap_time <= double_tap_window and _dash_cooldown_timer <= 0.0:
			_boost_timer = boost_duration
			_dash_cooldown_timer = dash_cooldown
			_last_tap_time = -1.0
	else:
		_last_tap_time = _input_time if _input_time - _press_time <= max_tap_hold else -2.0
	demo_key_changed.emit(pressed)


func _physics_process(delta: float) -> void:
	_input_time += delta
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_boost_timer = maxf(_boost_timer - delta, 0.0)
	queue_redraw()
	if _stun_timer > 0.0:
		set_demo_key(false)
		_show_action("TAGGED!")
		_tap_elapsed = -1.0
		_stun_timer = maxf(_stun_timer - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, knockback_deceleration * delta)
	else:
		_choose_demo_input(delta)
		var target_speed := (boost_speed if _boost_timer > 0.0 else base_speed) if _demo_key_down else 0.0
		var rate := acceleration if target_speed > velocity.x else deceleration
		velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	velocity.y = 0.0
	move_and_slide()
	_update_animation()


func _choose_demo_input(delta: float) -> void:
	if _input_time < 0.35 + (player_id - 1) * 0.15:
		set_demo_key(false)
		_show_action("GET READY")
		return
	if _tap_elapsed >= 0.0:
		_tap_elapsed += delta
		set_demo_key(_tap_elapsed < 0.09 or _tap_elapsed >= 0.18)
		_show_action("DOUBLE-TAP")
		if _tap_elapsed >= 0.45:
			_tap_elapsed = -1.0
		return

	var next_guard: Node2D
	var nearest_distance := INF
	for guard in _demo_guards:
		var distance := guard.position.x - position.x
		if position.y < guard.top_y or position.y > guard.bottom_y or distance < -35.0:
			continue
		if distance < nearest_distance:
			next_guard = guard
			nearest_distance = distance
	if next_guard != null and nearest_distance > 25.0 and nearest_distance < 110.0:
		# Bait the guard, release to wait, then dash through a clear opening.
		if absf(next_guard.position.y - position.y) < 90.0:
			set_demo_key(false)
			_show_action("WAIT")
			return
		if _dash_cooldown_timer <= 0.0:
			set_demo_key(false)
			_tap_elapsed = 0.0
			_show_action("DOUBLE-TAP")
			return
	set_demo_key(true)
	_show_action("HOLD")


func _update_animation() -> void:
	if _stun_timer > 0.0:
		sprite.stop()
	elif _demo_key_down:
		sprite.play(&"dash" if _boost_timer > 0.0 else &"move")
		sprite.speed_scale = 2.0 if _boost_timer > 0.0 else 1.0
	else:
		sprite.stop()
		sprite.animation = &"move"
		sprite.frame = 0
		sprite.speed_scale = 1.0


func _play_hit_sound() -> void:
	# Keep the looping preview quiet while retaining the real tag feedback.
	pass


func _show_action(action: String) -> void:
	if action != _demo_action:
		_demo_action = action
		demo_action_changed.emit(action)
