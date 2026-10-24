extends Node2D
## Vertical timing gauge (gauge only, no character logic).
## The handle moves up and down on its own.
## Press SPACE when the whole handle is inside the green zone.
## Attach this ONLY to a dedicated gauge Node2D, never to the character.

signal hit(perfect: bool, points: int)
signal missed
signal round_started

@export var bar_size: Vector2 = Vector2(76, 880)
@export var min_handle_height: float = 28.0
@export var auto_position: bool = false ## Otherwise, use the position set in the scene.
@export var needle_speed: float = 1.0
@export var speed_increase: float = 0.04
## Speed increases taper near this limit to keep long streaks playable.
@export var max_needle_speed: float = 1.5
@export var speed_ramp_rate: float = 0.2
@export var green_height: float = 0.24
@export var green_shrink: float = 0.015
@export var min_green_height: float = 0.12
@export var zone_transition_duration: float = 0.25
@export var perfect_margin: float = 0.3
@export var auto_restart: bool = true
@export var restart_delay: float = 0.45

var t: float = 0.0
var direction: float = 1.0
var running: bool = true
var game_active: bool = true
var target_needle_speed: float = 0.0
var zone_start: float = 0.4
var zone_end: float = 0.52
var _zone_transition_from_start: float = 0.0
var _zone_transition_to_start: float = 0.0
var _zone_transition_from_height: float = 0.0
var _zone_transition_to_height: float = 0.0
var _zone_transition_elapsed: float = 1.0
var message: String = "Press SPACE!"
var score: int = 0
var streak: int = 0
var _initial_needle_speed := 0.0
var _initial_green_height := 0.0
var _session_id := 0
var _restart_pending := false

var outline_box := StyleBoxFlat.new()
var bar_box := StyleBoxFlat.new()
var handle_box := StyleBoxFlat.new()


func _new_round(initial: bool = false) -> void:
	if not game_active:
		return
	if initial:
		t = 0.5
		direction = 1.0
		zone_start = 0.9 - green_height
		zone_end = 0.9
	running = true
	message = "Press SPACE!"
	round_started.emit()
	queue_redraw()


func _ready() -> void:
	_initial_needle_speed = needle_speed
	_initial_green_height = green_height
	target_needle_speed = needle_speed
	if auto_position:
		position = Vector2(bar_size.x * 1.5, get_viewport_rect().size.y / 2.0)
		
	var border := bar_size.x * 0.08

	outline_box.bg_color = Color.BLACK
	outline_box.set_corner_radius_all(int(bar_size.x * 0.16))

	bar_box.bg_color = Color("2e2e2e")
	bar_box.border_color = Color("f0b73e")
	bar_box.set_border_width_all(int(border))
	bar_box.set_corner_radius_all(int(bar_size.x * 0.12))

	handle_box.bg_color = Color("f0b73e")
	handle_box.border_color = Color.BLACK
	handle_box.set_border_width_all(3)
	handle_box.set_corner_radius_all(int(bar_size.x * 0.1))

	_new_round(true)


func _process(delta: float) -> void:
	if game_active:
		# Hold the judged position during feedback, then resume from that position.
		if running:
			needle_speed = move_toward(needle_speed, target_needle_speed, speed_ramp_rate * delta)
			t += direction * needle_speed * delta
			while t > 1.0 or t < 0.0:
				if t > 1.0:
					t = 2.0 - t
					direction = -1.0
				else:
					t = -t
					direction = 1.0

		if _zone_transition_elapsed < zone_transition_duration:
			_zone_transition_elapsed = minf(_zone_transition_elapsed + delta, zone_transition_duration)
			var progress := _zone_transition_elapsed / zone_transition_duration
			var eased_progress := smoothstep(0.0, 1.0, progress)
			zone_start = lerpf(_zone_transition_from_start, _zone_transition_to_start, eased_progress)
			var current_height := lerpf(_zone_transition_from_height, _zone_transition_to_height, eased_progress)
			zone_end = zone_start + current_height
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not game_active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		attempt_hit()


func attempt_hit() -> void:
	if not game_active or _restart_pending:
		return
	if running:
		_check_hit()
	elif not auto_restart:
		_start_next_zone_transition()
		_resume_after_zone_transition()


func _check_hit() -> void:
	if not game_active or not running:
		return
	var session := _session_id
	running = false
	_restart_pending = auto_restart
	# Judge the same geometry that is drawn, including the handle's thickness.
	var green_rect := _get_green_zone_rect()
	var handle_rect := _get_handle_rect()
	if green_rect.size.y > 0.0 and handle_rect.position.y >= green_rect.position.y and handle_rect.end.y <= green_rect.end.y:
		var center := (zone_start + zone_end) * 0.5
		var half := (zone_end - zone_start) * 0.5
		var offset: float = abs(t - center) / half
		var is_perfect := offset <= perfect_margin
		streak += 1
		
		# Point system set to 1 point per successful timing hit
		var points := 1
		score += points
		
		message = ("PERFECT! +%d Pt" if is_perfect else "GOOD! +%d Pt") % points
		# Increase difficulty for the next round after every successful landing.
		var speed_headroom := maxf(0.0, max_needle_speed - target_needle_speed)
		target_needle_speed += minf(speed_increase, speed_headroom * 0.25)
		green_height = maxf(min_green_height, green_height - green_shrink)
		hit.emit(is_perfect, points)
	else:
		streak = 0
		message = "MISSED!"
		missed.emit()

	queue_redraw()
	if not game_active or session != _session_id:
		return
	if auto_restart:
		await get_tree().create_timer(restart_delay, false).timeout
		if game_active and session == _session_id:
			# Show the result against its original zone before moving the next target.
			_start_next_zone_transition()
			_resume_after_zone_transition()
	else:
		message += "\nPress SPACE to continue"


func _start_next_zone_transition() -> void:
	_zone_transition_from_start = zone_start
	_zone_transition_to_start = randf_range(0.1, 0.9 - green_height)
	_zone_transition_from_height = zone_end - zone_start
	_zone_transition_to_height = green_height
	_zone_transition_elapsed = 0.0
	if zone_transition_duration <= 0.0:
		zone_start = _zone_transition_to_start
		zone_end = zone_start + _zone_transition_to_height


func _resume_after_zone_transition() -> void:
	var session := _session_id
	_restart_pending = true
	await get_tree().create_timer(zone_transition_duration, false).timeout
	if game_active and session == _session_id:
		zone_start = _zone_transition_to_start
		zone_end = zone_start + _zone_transition_to_height
		_zone_transition_elapsed = zone_transition_duration
		_restart_pending = false
		_new_round()


func reset_game() -> void:
	stop_game()
	score = 0
	streak = 0
	needle_speed = _initial_needle_speed
	target_needle_speed = _initial_needle_speed
	green_height = _initial_green_height
	t = 0.5
	direction = 1.0
	zone_start = 0.9 - green_height
	zone_end = 0.9
	_zone_transition_elapsed = zone_transition_duration
	message = "Press SPACE!"
	queue_redraw()


func start_game() -> void:
	_session_id += 1
	_restart_pending = false
	game_active = true
	set_process(true)
	_new_round(true)
	queue_redraw()


func stop_game() -> void:
	_session_id += 1
	_restart_pending = false
	game_active = false
	running = false
	set_process(false)
	queue_redraw()


func _get_inner_rect() -> Rect2:
	return Rect2(-bar_size / 2.0, bar_size).grow(-bar_size.x * 0.08)


func _get_green_zone_rect() -> Rect2:
	var inner := _get_inner_rect()
	var y_top: float = lerp(inner.end.y, inner.position.y, zone_end)
	var y_bottom: float = lerp(inner.end.y, inner.position.y, zone_start)
	return Rect2(inner.position.x, y_top, inner.size.x, y_bottom - y_top)


func _get_handle_rect() -> Rect2:
	var inner := _get_inner_rect()
	var handle_w := bar_size.x * 1.4
	var handle_h := maxf(bar_size.x * 0.25, min_handle_height)
	var y: float = lerp(inner.end.y, inner.position.y, t)
	return Rect2(-handle_w / 2.0, y - handle_h / 2.0, handle_w, handle_h)


func _draw() -> void:
	var bar_rect := Rect2(-bar_size / 2.0, bar_size)

	# Draw background and outline
	draw_style_box(outline_box, bar_rect.grow(4.0))
	draw_style_box(bar_box, bar_rect)

	# Draw green timing zone
	draw_rect(_get_green_zone_rect(), Color("4a8a10"))

	# Draw moving handle
	draw_style_box(handle_box, _get_handle_rect())
