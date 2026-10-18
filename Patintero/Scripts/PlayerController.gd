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

var _action: String = ""
var _last_tap_time: float = -1.0
var _boost_timer: float = 0.0
var _press_time: float = 0.0
var _stun_timer: float = 0.0

var _flash_tween: Tween


func _ready() -> void:
	_setup_flash()
	_action = "p%d_move" % player_id
	sprite.animation = "move"
	sprite.frame = 0

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

	_boost_timer = max(_boost_timer - delta, 0.0)

	
	var target_speed := 0.0
	if Input.is_action_pressed(_action):
		target_speed = boost_speed if _boost_timer > 0.0 else base_speed

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
	# No running animation while stunned
	if _stun_timer > 0.0:
		sprite.stop()
		return

	if Input.is_action_pressed(_action):
		sprite.play("move")
		sprite.speed_scale = 2.0 if _boost_timer > 0.0 else 1.0
	else:
		sprite.stop()
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
