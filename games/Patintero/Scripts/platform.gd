extends Node2D

enum State { PATROL, WINDUP, INTERCEPT, RECOVER }

@export_range(1, 4) var lane_difficulty: int = 1
@export var speed: float = 140.0
@export var top_y: float = 140.0
@export var bottom_y: float = 600.0
@export var start_dir: int = 1
@export var player_detection_distance: float = 175.0
@export var reaction_speed: float = 280.0
@export var reaction_delay: float = 0.28
@export var intercept_duration: float = 0.78
@export var recovery_duration: float = 0.95
@export var turn_pause: float = 0.16
@export var acceleration: float = 1100.0
@export var hit_cooldown: float = 0.6

var dir: int
var _state := State.PATROL
var _state_timer := 0.0
var _turn_timer := 0.0
var _velocity_y := 0.0
var _target_y := 0.0
var _retreat_y := 0.0
var _difficulty := 0.0
var _patrol_decision_timer := 0.0
var _patrol_pace := 1.0
var _feint_cooldown := 0.0
var _attack_speed := 0.0
var _follow_ups_left := 0
var _patrol_speed: float
var _intercept_speed: float
var _detection_distance: float
var _pressure_distance: float
var _reaction_time: float
var _intercept_time: float
var _recovery_time: float
var _turn_time: float
var _movement_acceleration: float
var _hit_cooldowns: Dictionary[int, float] = {}
var _rng := RandomNumberGenerator.new()
var _spawn_position := Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	dir = -1 if start_dir < 0 else 1
	position.y = clampf(position.y, top_y, bottom_y)
	_spawn_position = position
	_difficulty = float(clampi(lane_difficulty, 1, 4) - 1) / 3.0
	# Base patrol speeds climb 140 -> 210 -> 280 -> 350 across the court.
	_patrol_speed = speed * lerpf(1.0, 2.5, _difficulty)
	_intercept_speed = reaction_speed * lerpf(1.0, 2.0, _difficulty)
	_detection_distance = player_detection_distance * lerpf(1.0, 1.4, _difficulty)
	_pressure_distance = _detection_distance * lerpf(0.6, 0.8, _difficulty)
	_reaction_time = reaction_delay * lerpf(1.0, 0.5, _difficulty)
	_intercept_time = intercept_duration * lerpf(1.0, 1.35, _difficulty)
	_recovery_time = recovery_duration * lerpf(1.0, 0.5, _difficulty)
	_turn_time = turn_pause * lerpf(1.0, 0.4, _difficulty)
	_movement_acceleration = acceleration * lerpf(1.0, 2.1, _difficulty)
	# Independent random streams keep guards from sharing a repeatable patrol rhythm.
	_rng.randomize()
	_pick_patrol_variation(false)
	# The old animation tracks must not override physics-driven guard movement.
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.stop()
		animation_player.active = false
	$Hitbox.body_entered.connect(_on_touched)
	$Hitbox.area_entered.connect(_on_touched)


func reset_for_round() -> void:
	position = _spawn_position
	dir = -1 if start_dir < 0 else 1
	_state_timer = 0.0
	_turn_timer = 0.0
	_velocity_y = 0.0
	_target_y = position.y
	_retreat_y = position.y
	_feint_cooldown = 0.0
	_attack_speed = 0.0
	_follow_ups_left = 0
	_hit_cooldowns.clear()
	_pick_patrol_variation(false)
	_set_state(State.PATROL)


func _physics_process(delta: float) -> void:
	for player_instance_id in _hit_cooldowns.keys():
		_hit_cooldowns[player_instance_id] -= delta
		if _hit_cooldowns[player_instance_id] <= 0.0:
			_hit_cooldowns.erase(player_instance_id)
	_state_timer = maxf(_state_timer - delta, 0.0)

	match _state:
		State.PATROL:
			_patrol(delta)
			var target := _find_nearby_player()
			if target != null:
				_start_windup(target, true)
		State.WINDUP:
			# Close the gap during the warning instead of handing a dasher a free stop.
			_move_toward_y(_target_y, _intercept_speed * lerpf(0.55, 0.7, _difficulty), delta)
			if _state_timer <= 0.0:
				_state_timer = _intercept_time * _rng.randf_range(0.85, 1.1)
				_attack_speed = _intercept_speed * _rng.randf_range(0.92, 1.08)
				_set_state(State.INTERCEPT)
		State.INTERCEPT:
			_move_toward_y(_target_y, _attack_speed, delta)
			# Hold the crossing for the rest of the burst instead of leaving as soon
			# as the guard arrives. Runners need to bait or time their approach.
			if _state_timer <= 0.0:
				var next_target := _find_nearby_player()
				if _follow_ups_left > 0 and next_target != null:
					_follow_ups_left -= 1
					_start_windup(next_target)
				else:
					_begin_recovery()
		State.RECOVER:
			# Move away from the challenged runner and stay there until ready again.
			_move_toward_y(_retreat_y, _patrol_speed, delta)
			if _state_timer <= 0.0:
				_pick_patrol_variation(false)
				_feint_cooldown = maxf(_feint_cooldown, 0.35)
				_set_state(State.PATROL)


func _patrol(delta: float) -> void:
	_feint_cooldown = maxf(_feint_cooldown - delta, 0.0)
	if _turn_timer > 0.0:
		_turn_timer = maxf(_turn_timer - delta, 0.0)
		_move_vertical(0.0, delta)
		return
	_patrol_decision_timer -= delta
	if _patrol_decision_timer <= 0.0:
		_pick_patrol_variation()
		if _turn_timer > 0.0:
			_move_vertical(0.0, delta)
			return
	var endpoint := bottom_y if dir > 0 else top_y
	_move_toward_y(endpoint, _patrol_speed * _patrol_pace, delta)
	if absf(position.y - endpoint) < 1.0:
		dir *= -1
		_turn_timer = _turn_time * _rng.randf_range(0.65, 1.35)
		_pick_patrol_variation(false)


func _pick_patrol_variation(allow_feint: bool = true) -> void:
	_patrol_pace = _rng.randf_range(0.9, 1.18)
	_patrol_decision_timer = _rng.randf_range(0.45, 0.85) * lerpf(1.0, 0.7, _difficulty)
	if not allow_feint:
		return
	var choice := _rng.randf()
	var away_from_ends := position.y > top_y + 32.0 and position.y < bottom_y - 32.0
	if _feint_cooldown <= 0.0 and away_from_ends and choice < lerpf(0.28, 0.48, _difficulty):
		# Briefly plant before reversing, so a surprise move is still visible.
		dir *= -1
		_turn_timer = _rng.randf_range(0.08, 0.16)
		_feint_cooldown = _rng.randf_range(0.9, 1.5)
	elif choice > 0.84:
		_turn_timer = _rng.randf_range(0.07, 0.15)


func _move_toward_y(target_y: float, max_speed: float, delta: float) -> void:
	var distance := target_y - position.y
	if absf(distance) < 0.5:
		position.y = target_y
		_velocity_y = 0.0
		return
	var braking_speed := sqrt(2.0 * _movement_acceleration * absf(distance))
	_move_vertical(signf(distance) * minf(max_speed, braking_speed), delta)
	if (target_y - position.y) * distance <= 0.0:
		position.y = target_y
		_velocity_y = 0.0


func _move_vertical(desired_velocity: float, delta: float) -> void:
	_velocity_y = move_toward(_velocity_y, desired_velocity, _movement_acceleration * delta)
	position.y = clampf(position.y + _velocity_y * delta, top_y, bottom_y)


func _start_windup(target: CharacterBody2D, allow_follow_up: bool = false) -> void:
	if allow_follow_up:
		_follow_ups_left = 0
		if lane_difficulty >= 3 and _rng.randf() < lerpf(0.0, 0.65, _difficulty):
			_follow_ups_left = 1
	# Each attack commits to one runner. A follow-up gets its own visible warning.
	_target_y = clampf(_court_position(target).y, top_y, bottom_y)
	_state_timer = maxf(0.14, _reaction_time * _rng.randf_range(0.88, 1.18))
	_set_state(State.WINDUP)


func _begin_recovery() -> void:
	_follow_ups_left = 0
	var retreat_direction := 1.0 if _target_y <= (top_y + bottom_y) * 0.5 else -1.0
	# Later guards make a short withdrawal, leaving a dash-sized opening while
	# staying close enough to contest another poorly timed attempt.
	var retreat_distance := lerpf(bottom_y - top_y, 125.0, _difficulty)
	_retreat_y = clampf(_target_y + retreat_direction * retreat_distance, top_y, bottom_y)
	dir = -1 if retreat_direction > 0.0 else 1
	_turn_timer = _turn_time
	# Vary the next opening, but always leave time to get moving again after a tag.
	_state_timer = maxf(0.6, _recovery_time * _rng.randf_range(0.95, 1.15))
	_set_state(State.RECOVER)


func _set_state(next_state: State) -> void:
	_state = next_state
	match _state:
		State.WINDUP:
			_sprite.modulate = Color(1.15, 1.05, 0.65)
		State.INTERCEPT:
			_sprite.modulate = Color(1.2, 0.82, 0.8)
		State.RECOVER:
			_sprite.modulate = Color(0.85, 0.9, 1.0)
		State.PATROL:
			_sprite.modulate = Color.WHITE


func _court_position(player: Node2D) -> Vector2:
	# Bounds and position are court-local, not relative to the moving guard.
	return get_parent().to_local(player.global_position)


func _find_nearby_player() -> CharacterBody2D:
	var closest_player: CharacterBody2D
	var soonest_arrival := INF
	var closest_distance_squared := INF
	for node in get_tree().get_nodes_in_group(&"patintero_players"):
		var player := node as CharacterBody2D
		if player == null:
			continue

		var player_position := _court_position(player)
		var distance_ahead := position.x - player_position.x
		if player.velocity.x < 0.0 or distance_ahead < 0.0:
			continue
		if player_position.y < top_y or player_position.y > bottom_y:
			continue
		if distance_ahead > _detection_distance:
			continue
		# Waiting close to the line also draws pressure, so runners must bait a real
		# recovery opening rather than wait for the guard to patrol past them.
		if player.velocity.x < 20.0 and distance_ahead > _pressure_distance:
			continue

		var distance_squared := position.distance_squared_to(player_position)
		# React to the runner about to cross first, including a fast approaching dash.
		var arrival_time := distance_ahead / maxf(player.velocity.x, 80.0)
		if arrival_time < soonest_arrival or (is_equal_approx(arrival_time, soonest_arrival) and distance_squared < closest_distance_squared):
			closest_player = player
			soonest_arrival = arrival_time
			closest_distance_squared = distance_squared

	return closest_player


func _on_touched(other: Node) -> void:
	if not is_physics_processing():
		return
	var player := other
	while player != null and not player.is_in_group(&"patintero_players"):
		player = player.get_parent()
	if player == null or not player.has_method("_get_hit"):
		return
	# Body and area overlaps can both report the same tag. Cooldowns are per runner.
	var player_instance_id := player.get_instance_id()
	if _hit_cooldowns.has(player_instance_id):
		return
	_hit_cooldowns[player_instance_id] = hit_cooldown
	player._get_hit()
	# A tag always gives that runner room to retry, including when another runner
	# was the guard's original target.
	_target_y = _court_position(player).y
	_begin_recovery()
