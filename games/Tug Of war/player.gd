extends CharacterBody2D
# Attach this directly to your CharacterBody2D (the one with the AnimatedSprite2D child).
# Team 1 (left):  P1 = A, P2 = F  -> each click pulls the rope left
# Team 2 (right): P3 = J, P4 = ;  -> each click pulls the rope right
# Enter = restart.
# Every key press advances the sprite animation by one frame. It never plays on its own.

@export var pull_anim := "pull"                 # animation to step through (uses the current one if not found)
@export var frames_per_press := 1               # frames advanced per key press
@export var animate_on_team2 := true            # also step the animation when Team 2 presses
@export var rest_after := 0.4                   # seconds without a press before returning to frame 0
@export var character_y := -70.0                # height of the character above the rope
@export var character_spacing := 60.0           # distance of each character from the rope marker (left/right)
@export var flip_left_character := false        # flip the LEFT character's sprite; the right one is always the opposite
@export var pull_per_click := 12.0              # force added to the rope by ONE click from ONE player
@export var recover_speed := 0.0                # > 0 makes the rope drift back to center
@export var win_distance_ratio := 0.35          # rope half-length as a fraction of screen width

# Key -> player index (0 = P1, 1 = P2, 2 = P3, 3 = P4)
const KEY_TO_PLAYER := {
	KEY_A: 0,
	KEY_F: 1,
	KEY_J: 2,
	KEY_SEMICOLON: 3,
}

var anim: AnimatedSprite2D                      # Team 1 character (left of the marker)
var anim2: AnimatedSprite2D                     # Team 2 character: a flipped duplicate (right of the marker)
var rope_pos := 0.0                             # negative = Team 1 winning, positive = Team 2 winning
var clicks := [0, 0, 0, 0]                      # per-player click counts (P1..P4)
var game_over := false
var winner_text := ""
var last_press := -10.0

func _ready() -> void:
	var found := find_children("*", "AnimatedSprite2D", true, false)
	if found.size() > 0:
		anim = found[0]
		anim.autoplay = ""
		if anim.sprite_frames and anim.sprite_frames.has_animation(pull_anim):
			anim.animation = pull_anim
		anim.pause()                             # stop any autoplay
		anim.frame = 0

		# Duplicate the character and mirror it so the two teams face each other
		anim2 = anim.duplicate() as AnimatedSprite2D
		anim.get_parent().add_child(anim2)
		anim.position.x = -character_spacing
		anim2.position = Vector2(character_spacing, anim.position.y)
		anim.flip_h = flip_left_character
		anim2.flip_h = not flip_left_character
		anim2.pause()
		anim2.frame = 0

func _screen_center() -> Vector2:
	return get_canvas_transform().affine_inverse() * (get_viewport_rect().size / 2.0)

func _win_distance() -> float:
	return get_viewport_rect().size.x * win_distance_ratio

func _team1_clicks() -> int:
	return clicks[0] + clicks[1]

func _team2_clicks() -> int:
	return clicks[2] + clicks[3]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if game_over:
			if event.keycode == KEY_ENTER:
				_restart()
			return
		if not KEY_TO_PLAYER.has(event.keycode):
			return
		var player: int = KEY_TO_PLAYER[event.keycode]
		clicks[player] += 1
		if player <= 1:
			# P1 / P2 -> Team 1 pulls left
			rope_pos -= pull_per_click
			_step_frame()
		else:
			# P3 / P4 -> Team 2 pulls right
			rope_pos += pull_per_click
			if animate_on_team2:
				_step_frame()
		rope_pos = clampf(rope_pos, -_win_distance(), _win_distance())
		_check_winner()

# One key press = one animation step
func _step_frame() -> void:
	last_press = Time.get_ticks_msec() / 1000.0
	if anim == null or anim.sprite_frames == null:
		return
	var count := anim.sprite_frames.get_frame_count(anim.animation)
	if count > 0:
		anim.frame = (anim.frame + frames_per_press) % count
		if anim2:
			anim2.frame = anim.frame

func _process(delta: float) -> void:
	if not game_over and recover_speed > 0.0:
		rope_pos = move_toward(rope_pos, 0.0, recover_speed * delta)

	# The character rides along the rope
	global_position = _screen_center() + Vector2(rope_pos, character_y)

	# Keep the animation frozen unless a key was pressed
	if anim:
		if anim.is_playing():
			anim.pause()
		if anim2 and anim2.is_playing():
			anim2.pause()
		if Time.get_ticks_msec() / 1000.0 - last_press > rest_after:
			anim.frame = 0
			if anim2:
				anim2.frame = 0
	queue_redraw()

func _check_winner() -> void:
	if rope_pos <= -_win_distance():
		game_over = true
		winner_text = "TEAM 1 WINS!"
	elif rope_pos >= _win_distance():
		game_over = true
		winner_text = "TEAM 2 WINS!"

func _restart() -> void:
	rope_pos = 0.0
	clicks = [0, 0, 0, 0]
	game_over = false
	winner_text = ""

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var wd := _win_distance()
	# (0, 0) below = middle of the screen, even though this node moves
	draw_set_transform(to_local(_screen_center()), 0.0, Vector2.ONE)

	draw_line(Vector2(-wd, 0), Vector2(wd, 0), Color.SADDLE_BROWN, 6.0)
	draw_line(Vector2(0, -40), Vector2(0, 40), Color.WHITE, 2.0)
	draw_circle(Vector2(-wd, 0), 10, Color.DODGER_BLUE)
	draw_circle(Vector2(wd, 0), 10, Color.TOMATO)
	draw_circle(Vector2(rope_pos, 0), 16, Color.YELLOW)

	# Team 1 (left) labels
	draw_string(font, Vector2(-wd - 100, 70), "TEAM 1: %d" % _team1_clicks(), HORIZONTAL_ALIGNMENT_CENTER, 200, 24)
	draw_string(font, Vector2(-wd - 100, 100), "P1 (A): %d" % clicks[0], HORIZONTAL_ALIGNMENT_CENTER, 200, 20)
	draw_string(font, Vector2(-wd - 100, 125), "P2 (F): %d" % clicks[1], HORIZONTAL_ALIGNMENT_CENTER, 200, 20)

	# Team 2 (right) labels
	draw_string(font, Vector2(wd - 100, 70), "TEAM 2: %d" % _team2_clicks(), HORIZONTAL_ALIGNMENT_CENTER, 200, 24)
	draw_string(font, Vector2(wd - 100, 100), "P3 (J): %d" % clicks[2], HORIZONTAL_ALIGNMENT_CENTER, 200, 20)
	draw_string(font, Vector2(wd - 100, 125), "P4 (;): %d" % clicks[3], HORIZONTAL_ALIGNMENT_CENTER, 200, 20)

	if anim == null:
		draw_string(font, Vector2(-250, -120), "No AnimatedSprite2D child found!", HORIZONTAL_ALIGNMENT_CENTER, 500, 22, Color.RED)

	if game_over:
		draw_string(font, Vector2(-200, 190), winner_text, HORIZONTAL_ALIGNMENT_CENTER, 400, 36)
		draw_string(font, Vector2(-200, 230), "Press Enter to restart", HORIZONTAL_ALIGNMENT_CENTER, 400, 20)
