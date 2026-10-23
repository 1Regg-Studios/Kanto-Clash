extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _player_label: Label = $PlayerLabel

@export_range(1, 4) var player_id: int = 1

@export var base_speed: float = 200.0        # normal speed
@export var boost_speed: float = 850.0       # speed after a double-tap
@export var double_tap_window: float = 0.3   # max seconds between taps
@export var boost_duration: float = 0.24     # how long the boost lasts
@export var dash_cooldown: float = 1.1       # minimum time between boosts
@export var acceleration: float = 3000.0     # how fast it speeds up
@export var deceleration: float = 2500.0     # how fast it slows down
@export var max_tap_hold: float = 0.2        # a press longer than this is not a tap
@export var knockback_speed: float = 600.0   # how hard you get pushed back
@export var knockback_deceleration: float = 1400.0 # how smoothly knockback eases out
@export var stun_duration: float = 1.0       # how long you can't move

const HIT_SOUND := preload("res://assets/Sfx/freesound_community-golpes-hits-80041.mp3")
const HIT_SAMPLE_STARTS: Array[float] = [0.08, 2.18, 3.85, 5.97, 7.94, 9.99]
const HIT_SAMPLE_PLAYBACK := 0.36
const HIT_SOUND_DB := -6.0
const HIT_PITCH_MIN := 0.94
const HIT_PITCH_MAX := 1.06

const SPRITE_FRAME_SIZE := 32
const SPRITE_FRAME_COUNT := 11
const SPRITE_FPS := 15.0
const NORMAL_SPRITE_SHEETS: Array[Texture2D] = [
	preload("res://games/Patintero/Sprites/per player/p1.png"),
	preload("res://games/Patintero/Sprites/per player/p2.png"),
	preload("res://games/Patintero/Sprites/per player/p3.png"),
	preload("res://games/Patintero/Sprites/per player/p4.png"),
]
const DASH_SPRITE_SHEETS: Array[Texture2D] = [
	preload("res://games/Patintero/Sprites/per player/p1 dash.png"),
	preload("res://games/Patintero/Sprites/per player/p2 dash.png"),
	preload("res://games/Patintero/Sprites/per player/p3 dash.png"),
	preload("res://games/Patintero/Sprites/per player/p4 dash.png"),
]

var _action: String = ""
var _last_tap_time: float = -1.0
var _boost_timer: float = 0.0
var _press_time: float = 0.0
var _stun_timer: float = 0.0
var _input_time: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _hit_sound_timer: float = 0.0
var _last_hit_sample: int = -1

var _hit_sound_player: AudioStreamPlayer
var _flash_tween: Tween


func _ready() -> void:
	add_to_group(&"patintero_players")
	_player_label.text = "P%d" % player_id
	_setup_player_sprites()
	_setup_flash()
	_setup_hit_audio()
	# Hold the shared player key (A, F, J or ;) to move; double-tap it to dash.
	_action = "P%d_Ready" % player_id
	sprite.animation = &"move"
	sprite.frame = 0


func reset_for_round(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	_player_label.text = "P%d" % player_id
	_last_tap_time = -1.0
	_boost_timer = 0.0
	_press_time = 0.0
	_stun_timer = 0.0
	_input_time = 0.0
	_dash_cooldown_timer = 0.0
	_hit_sound_timer = 0.0
	_hit_sound_player.stop()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_set_flash(Color.WHITE, 0.0)
	sprite.stop()
	sprite.animation = &"move"
	sprite.frame = 0
	sprite.speed_scale = 1.0
	queue_redraw()


func set_round_active(active: bool) -> void:
	set_physics_process(active)
	if not active:
		velocity = Vector2.ZERO
		sprite.pause()
		_hit_sound_player.stop()
		_hit_sound_timer = 0.0


func finish_run(finish_place: int) -> void:
	set_round_active(false)
	_player_label.text = "P%d - #%d" % [player_id, finish_place]


func _physics_process(delta: float) -> void:
	_input_time += delta
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	if _hit_sound_timer > 0.0:
		_hit_sound_timer = maxf(_hit_sound_timer - delta, 0.0)
		if _hit_sound_timer <= 0.0:
			_hit_sound_player.stop()
	queue_redraw()
	# While stunned: ignore input and let the knockback ease out smoothly.
	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, knockback_deceleration * delta)
		velocity.y = 0.0
		move_and_slide()
		_update_animation()
		return

	var now := _input_time

	# A short press followed by another press inside the window triggers one dash.
	if Input.is_action_just_pressed(_action):
		_press_time = now

		# Second quick tap after a short first tap = boost
		if now - _last_tap_time <= double_tap_window and _dash_cooldown_timer <= 0.0:
			_boost_timer = boost_duration
			_dash_cooldown_timer = dash_cooldown
			_last_tap_time = -1.0


	if Input.is_action_just_released(_action):
		if now - _press_time <= max_tap_hold:
			_last_tap_time = now
		else:
			_last_tap_time = -2.0

	_boost_timer = max(_boost_timer - delta, 0.0)


	# Regular movement only continues while the control button is held.
	var target_speed := 0.0
	if Input.is_action_pressed(_action):
		target_speed = boost_speed if _boost_timer > 0.0 else base_speed

	var rate := acceleration if target_speed > velocity.x else deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	velocity.y = 0.0

	move_and_slide()
	_update_animation()


func _draw() -> void:
	if _dash_cooldown_timer <= 0.0:
		return
	var charge := clampf(1.0 - _dash_cooldown_timer / maxf(dash_cooldown, 0.01), 0.0, 1.0)
	draw_rect(Rect2(-5.5, -16.0, 13.0, 2.5), Color(0.08, 0.1, 0.15, 0.9))
	draw_rect(Rect2(-5.0, -15.5, 12.0 * charge, 1.5), Color(0.9, 0.95, 1.0))


# Called by the platform's Hitbox
func _get_hit() -> void:
	if not is_physics_processing():
		return
	hit_flash()
	if _stun_timer > 0.0:
		return
	_stun_timer = stun_duration
	_boost_timer = 0.0
	_last_tap_time = -1.0
	velocity.x = -knockback_speed
	_play_hit_sound()
	var impact_camera := get_tree().get_first_node_in_group(&"patintero_cameras")
	if impact_camera != null and impact_camera.has_method("trigger_impact"):
		impact_camera.trigger_impact()


func _setup_hit_audio() -> void:
	_hit_sound_player = AudioStreamPlayer.new()
	_hit_sound_player.stream = HIT_SOUND
	_hit_sound_player.bus = &"Sfx"
	_hit_sound_player.volume_db = HIT_SOUND_DB
	add_child(_hit_sound_player)


func _play_hit_sound() -> void:
	var sample_index := randi() % HIT_SAMPLE_STARTS.size()
	if sample_index == _last_hit_sample:
		sample_index = (sample_index + 1) % HIT_SAMPLE_STARTS.size()
	_last_hit_sample = sample_index
	_hit_sound_player.pitch_scale = randf_range(HIT_PITCH_MIN, HIT_PITCH_MAX)
	_hit_sound_player.play(HIT_SAMPLE_STARTS[sample_index])
	_hit_sound_timer = HIT_SAMPLE_PLAYBACK


func _update_animation() -> void:
	# No running animation while stunned
	if _stun_timer > 0.0:
		sprite.stop()
		return

	if not Input.is_action_pressed(_action):
		sprite.stop()
		sprite.animation = &"move"
		sprite.frame = 0
		sprite.speed_scale = 1.0
		return

	var is_boosting := _boost_timer > 0.0
	sprite.play(&"dash" if is_boosting else &"move")
	sprite.speed_scale = 2.0 if is_boosting else 1.0


func _setup_player_sprites() -> void:
	if player_id < 1 or player_id > NORMAL_SPRITE_SHEETS.size():
		push_error("Patintero player_id must be between 1 and 4 (got %d)" % player_id)
		return

	var player_index := player_id - 1
	var frames := SpriteFrames.new()
	_add_sprite_animation(frames, &"move", NORMAL_SPRITE_SHEETS[player_index])
	_add_sprite_animation(frames, &"dash", DASH_SPRITE_SHEETS[player_index])
	sprite.sprite_frames = frames


func _add_sprite_animation(frames: SpriteFrames, animation_name: StringName, texture: Texture2D) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, SPRITE_FPS)
	for frame_index in SPRITE_FRAME_COUNT:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(frame_index * SPRITE_FRAME_SIZE, 0, SPRITE_FRAME_SIZE, SPRITE_FRAME_SIZE)
		frames.add_frame(animation_name, frame)


const FLASH_SHADER := """
shader_type canvas_item;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash_amount), tex.a * COLOR.a);
}
"""

var _flash_mats: Array[ShaderMaterial] = []

func _setup_flash() -> void:
	var shader := Shader.new()
	shader.code = FLASH_SHADER
	for s in find_children("*", "AnimatedSprite2D", true, false):
		var mat := ShaderMaterial.new()
		mat.shader = shader
		s.material = mat
		_flash_mats.append(mat)

func _set_flash(color: Color, amount: float) -> void:
	for m in _flash_mats:
		m.set_shader_parameter("flash_color", color)
		m.set_shader_parameter("flash_amount", amount)

func hit_flash(flashes: int = 3, step: float = 0.06) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	for i in flashes:
		_flash_tween.tween_callback(_set_flash.bind(Color.RED, 1.0))
		_flash_tween.tween_interval(step)
		_flash_tween.tween_callback(_set_flash.bind(Color.WHITE, 1.0))
		_flash_tween.tween_interval(step)
	_flash_tween.tween_callback(_set_flash.bind(Color.WHITE, 0.0))  # back to normal
