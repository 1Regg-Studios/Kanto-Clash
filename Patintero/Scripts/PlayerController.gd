extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export_range(1, 4) var player_id: int = 1

@export var base_speed: float = 200.0        # normal speed
@export var boost_speed: float = 2000.0      # speed after a double-tap
@export var double_tap_window: float = 0.3   # max seconds between taps
@export var boost_duration: float = 0.3      # how long the boost lasts
@export var acceleration: float = 3000.0     # how fast it speeds up
@export var deceleration: float = 2500.0     # how fast it slows down
@export var max_tap_hold: float = 0.2        # a press longer than this is not a tap
@export var knockback_speed: float = 600.0   # how hard you get pushed back
@export var stun_duration: float = 0.5       # how long you can't move
@export var ghost_interval: float = 0.04


var _action: String = ""
var _last_tap_time: float = -1.0
var _boost_timer: float = 0.0
var _press_time: float = 0.0
var _stun_timer: float = 0.0
var _dashing: bool = false
var _flash_tween: Tween
var _base_scale: Vector2
var _ghost_timer: float = 0.0

func _ready() -> void:
	_setup_flash()
	_action = "p%d_move" % player_id
	sprite.animation = "move"
	sprite.frame = 0
	_base_scale = sprite.scale

func _physics_process(delta: float) -> void:
	# While stunned: ignore input, just slide back and slow down
	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.1, deceleration * delta)
		velocity.y = 0.0
		move_and_slide()
		_update_animation()
		return

	var now := Time.get_ticks_msec() / 1000.0

	# Key goes down
	if Input.is_action_just_pressed(_action):
		_press_time = now
	
		# Second quick tap after a short first tap = boost
		if now - _last_tap_time <= double_tap_window:
			_boost_timer = boost_duration
			_last_tap_time = -1.0

	
	if Input.is_action_just_released(_action):
		if now - _press_time <= max_tap_hold:
			_last_tap_time = now
		else:
			_last_tap_time = -2.0   
		if now - _last_tap_time <= double_tap_window:
			_boost_timer = boost_duration
			velocity.x = boost_speed        # instant burst
			_last_tap_time = -1.0
	_boost_timer = max(_boost_timer - delta, 0.0)

	
		# Choose target speed
	var target_speed := 0.0
	if _boost_timer > 0.0:
		target_speed = boost_speed          # dash runs even if the key is released
	elif Input.is_action_pressed(_action):
		target_speed = base_speed

	var rate := acceleration if target_speed > velocity.x else deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	velocity.y = 0.0



	move_and_slide()
	_update_animation()

# Called by the platform's Hitbox
func _get_hit() -> void:
	print("player _get_hit called")
	hit_flash()
	if _stun_timer > 0.0:
		return
	_stun_timer = stun_duration
	_boost_timer = 0.0
	_last_tap_time = -1.0
	velocity.x = -knockback_speed

func _update_animation() -> void:
	# Stunned: no running or dash animation
	if _stun_timer > 0.0:
		_dashing = false
		sprite.stop()
		return

	if _boost_timer > 0.0:
		# Double-tap: play the dash once when the boost starts
		if not _dashing:
			_dashing = true
			sprite.speed_scale = 1.0
			sprite.play("dash")
			sprite.scale = _base_scale * Vector2(1.5, 0.7)   # stretched
			create_tween().tween_property(sprite, "scale", _base_scale, 0.2)
			_ghost_timer -= get_physics_process_delta_time()
		if _ghost_timer <= 0.0:
			_ghost_timer = ghost_interval
			_spawn_ghost()
			
	elif Input.is_action_pressed(_action):
		# Normal movement while holding
		_dashing = false
		sprite.speed_scale = 1.0
		sprite.play("move")
	else:
		# Idle
		_dashing = false
		sprite.stop()
		sprite.animation = "move"
		sprite.frame = 0


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

func _spawn_ghost() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.global_position = sprite.global_position
	ghost.global_scale = sprite.global_scale
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(1, 1, 1, 0.5)
	ghost.z_index = z_index - 1
	get_tree().current_scene.add_child(ghost)

	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)
