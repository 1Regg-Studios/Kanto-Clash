extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_force: float = -400.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
	# Add gravity if the character is not on the floor
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle Jump using the Space bar
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force

	# Optional: Basic horizontal movement so you can move left/right while testing
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	# Move the character using Godot's built-in physics engine
	move_and_slide()
