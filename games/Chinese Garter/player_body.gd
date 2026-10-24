@tool
extends CharacterBody2D

@export_range(1, 4) var player_id: int = 1:
	set(value):
		player_id = clampi(value, 1, 4)
		if is_node_ready():
			_setup_player_sprites()

@export var speed: float = 3000.0
@export var jump_force: float = -550.0
@export var allow_horizontal_movement := false

const PLAYER_SPRITE_SHEETS: Array[Texture2D] = [
	preload("res://games/Chinese Garter/assets/player character/p1.png"),
	preload("res://assets/orange p2 revised/jumping animationorange.png"),
	preload("res://games/Chinese Garter/assets/player character/p3.png"),
	preload("res://games/Chinese Garter/assets/player character/p4.png"),
]
const MISS_TINT := Color(1.0, 0.25, 0.25, 1.0)
const MISS_SHAKE_DISTANCE := 14.0
const JUMP_SOUND: AudioStream = preload("res://assets/Sfx/shidenbeatsmusic-sound-effect-jumping-in-tv-gameanimation-type-of-sound-137602.mp3")
# Skip the lead-in and stop before the next take in the source file.
const JUMP_SOUND_FIRST_VARIATION_START := 1.45
const JUMP_SOUND_FIRST_VARIATION_LENGTH := 2.4

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _sprite_home_position := Vector2.ZERO
var _miss_tween: Tween
var _jump_animation_active := false
var _jump_sound_player: AudioStreamPlayer
var _jump_sound_timer: Timer


func _ready() -> void:
	_sprite_home_position = _sprite.position
	_setup_player_sprites()
	_setup_jump_sound()
	if Engine.is_editor_hint():
		set_physics_process(false)


func _setup_player_sprites() -> void:
	# Keep the scene's frame regions and timing, with a separate atlas per player.
	var frames := _sprite.sprite_frames.duplicate(true) as SpriteFrames
	for animation in frames.get_animation_names():
		for frame_index in frames.get_frame_count(animation):
			var texture := frames.get_frame_texture(animation, frame_index) as AtlasTexture
			if texture != null:
				texture.atlas = PLAYER_SPRITE_SHEETS[player_id - 1]
	_sprite.sprite_frames = frames


func _physics_process(delta: float) -> void:
	# Add gravity if the character is not on the floor
	if not is_on_floor():
		velocity.y += gravity * delta

	# Timing gameplay stays centered; movement can be enabled for scene testing.
	var direction := Input.get_axis("ui_left", "ui_right") if allow_horizontal_movement else 0.0
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	# Move the character using Godot's built-in physics engine
	move_and_slide()
	if _jump_animation_active and is_on_floor():
		_sprite.stop()
		_sprite.frame = 0
		_sprite.frame_progress = 0.0
		_sprite.speed_scale = 1.0
		_jump_animation_active = false
		_stop_jump_sound()


func reset_for_turn(id: int, spawn_position: Vector2) -> void:
	set_physics_process(false)
	_clear_miss_feedback()
	_stop_jump_sound()
	player_id = id
	position = spawn_position
	velocity = Vector2.ZERO
	_sprite.stop()
	_sprite.frame = 0
	_sprite.frame_progress = 0.0
	_sprite.speed_scale = 1.0
	_jump_animation_active = false


func can_jump() -> bool:
	return is_physics_processing() and is_on_floor() and not _jump_animation_active


func jump() -> void:
	if not can_jump():
		return
	_clear_miss_feedback()
	velocity.y = jump_force
	_play_jump_sound()
	_play_jump_animation()


func _setup_jump_sound() -> void:
	_jump_sound_player = AudioStreamPlayer.new()
	_jump_sound_player.stream = JUMP_SOUND
	_jump_sound_player.bus = &"Sfx"
	add_child(_jump_sound_player)
	_jump_sound_timer = Timer.new()
	_jump_sound_timer.one_shot = true
	_jump_sound_timer.wait_time = JUMP_SOUND_FIRST_VARIATION_LENGTH
	_jump_sound_timer.timeout.connect(_jump_sound_player.stop)
	add_child(_jump_sound_timer)


func _play_jump_sound() -> void:
	_jump_sound_player.stop()
	_jump_sound_player.play(JUMP_SOUND_FIRST_VARIATION_START)
	_jump_sound_timer.start()


func _stop_jump_sound() -> void:
	_jump_sound_timer.stop()
	_jump_sound_player.stop()


func _play_jump_animation() -> void:
	var frames := _sprite.sprite_frames
	var animation := _sprite.animation
	var frame_count := frames.get_frame_count(animation)
	var animation_speed := frames.get_animation_speed(animation)
	var airtime := 0.0
	if gravity > 0.0:
		airtime = 2.0 * absf(jump_force) / gravity
	if frame_count > 0 and animation_speed > 0.0 and airtime > 0.0:
		_sprite.speed_scale = float(frame_count) / (animation_speed * airtime)
	else:
		_sprite.speed_scale = 1.0
	_sprite.play(animation)
	_jump_animation_active = true


func play_miss_feedback() -> void:
	_stop_jump_sound()
	_clear_miss_feedback()
	_sprite.modulate = MISS_TINT
	_miss_tween = create_tween()
	_miss_tween.tween_property(_sprite, "position:x", _sprite_home_position.x - MISS_SHAKE_DISTANCE, 0.05)
	_miss_tween.tween_property(_sprite, "position:x", _sprite_home_position.x + MISS_SHAKE_DISTANCE, 0.08)
	_miss_tween.tween_property(_sprite, "position:x", _sprite_home_position.x - MISS_SHAKE_DISTANCE * 0.6, 0.07)
	_miss_tween.tween_property(_sprite, "position:x", _sprite_home_position.x + MISS_SHAKE_DISTANCE * 0.6, 0.07)
	_miss_tween.tween_property(_sprite, "position", _sprite_home_position, 0.05)
	_miss_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.3)


func _clear_miss_feedback() -> void:
	if _miss_tween != null and _miss_tween.is_valid():
		_miss_tween.kill()
	_miss_tween = null
	_sprite.position = _sprite_home_position
	_sprite.modulate = Color.WHITE
