extends Node

@export var direction_gauge: Node
@export var power_gauge: Node
@export var can: Node
@export var turn_label: Label
@export var result_label: Label
@export var score_label: Label

@export var total_players: int = 4
@export var result_delay: float = 2.0     # seconds the result stays on screen

@export var direction_speed: float = 1.2
@export var power_speed: float = 1.0
@export var speed_increase_per_turn: float = 0.2   # 0 = same for everyone

@export var thrower: AnimatedSprite2D                  # the hand/player sprite
@export var throw_animation: StringName = &"throw"     # must match SpriteFrames name
@export var idle_animation: StringName = &"idle"       # optional, falls back to throw frame 0

enum State { DIRECTION, POWER, RESULT, GAME_OVER }
var state: State = State.RESULT

var current_player: int = 1
var scores: Array[int] = [0, 0, 0, 0]
var direction_value: float = 0.5
var power_value: float = 0.5
var _action: String = "p1_move"

func _ready() -> void:
	start_turn()

func start_turn() -> void:
	_action = "p%d_move" % current_player
	turn_label.text = "PLAYER %d" % current_player
	result_label.text = ""
	_update_scores()

	can.reset_can()
	reset_thrower()          # <-- new
	direction_gauge.reset()
	power_gauge.reset()
	var bonus := (current_player - 1) * speed_increase_per_turn
	direction_gauge.speed = direction_speed + bonus
	power_gauge.speed = power_speed + bonus
	state = State.DIRECTION
	direction_gauge.start()

func _input(event: InputEvent) -> void:
	# Restart after the game ends
	if state == State.GAME_OVER:
		if event.is_action_pressed("ui_accept"):
			restart()
		return

	if not event.is_action_pressed(_action):
		return

	match state:
		State.DIRECTION:
			direction_value = direction_gauge.lock()
			state = State.POWER
			power_gauge.start()
		State.POWER:
			power_value = power_gauge.lock()
			state = State.RESULT
			finish_turn()

func finish_turn() -> void:
	await play_throw()       # <-- new: plays on hit AND miss

	var hit: bool = can.check_hit(direction_value, power_value)
	var points: int = can.get_points(direction_value, power_value) if hit else 0

	# ...the rest of your function stays exactly the same

	var miss_penalty := 10
	scores[current_player - 1] += points if hit else -miss_penalty
	scores[current_player - 1] = maxi(scores[current_player - 1], 0)   # never below 0
	result_label.text = ("HIT! +%d" % points) if hit else ("MISS -%d" % miss_penalty)
	_update_scores()

	await get_tree().create_timer(result_delay).timeout

	current_player += 1
	if current_player > total_players:
		show_final()
	else:
		start_turn()

func show_final() -> void:
	state = State.GAME_OVER

	var best_score: int = scores.slice(0, total_players).max()
	var winners: Array[String] = []
	for i in total_players:
		if scores[i] == best_score:
			winners.append("P%d" % (i + 1))

	turn_label.text = "GAME OVER"
	if winners.size() == 1:
		result_label.text = "%s WINS!\nPress Space to play again" % winners[0]
	else:
		result_label.text = "TIE: %s\nPress Space to play again" % " & ".join(winners)

func restart() -> void:
	scores = [0, 0, 0, 0]
	current_player = 1
	start_turn()

func _update_scores() -> void:
	var parts: Array[String] = []
	for i in total_players:
		parts.append("P%d: %d" % [i + 1, scores[i]])
	score_label.text = "   ".join(parts)

func reset_thrower() -> void:
	if thrower == null:
		return
	if thrower.sprite_frames.has_animation(idle_animation):
		thrower.play(idle_animation)
	else:
		thrower.animation = throw_animation
		thrower.frame = 0
		thrower.stop()

func play_throw() -> void:
	# Plays the throw and waits until it finishes. Does nothing if not set up.
	if thrower == null:
		push_warning("Thrower is not assigned on the Controller node.")
		return
	if not thrower.sprite_frames.has_animation(throw_animation):
		push_warning("Animation '%s' not found on thrower." % throw_animation)
		return

	thrower.sprite_frames.set_animation_loop(throw_animation, false)  # never loop
	thrower.play(throw_animation)
	await thrower.animation_finished
