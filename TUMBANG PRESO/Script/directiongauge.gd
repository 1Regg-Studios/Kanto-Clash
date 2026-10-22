extends Node2D

@onready var line: TextureRect = $Line

@export var start_pos: Vector2 = Vector2(20.0, 39.0)    # left end (your numbers from step 4)
@export var end_pos: Vector2 = Vector2(834.0, 39.0)     # right end (your numbers from step 4)
@export var speed: float = 1.0                      # higher = faster

var value: float = 0.5       # 0.0 = left end, 0.5 = middle, 1.0 = right end
var direction: float = 1.0   # 1 = moving right, -1 = moving left
var running: bool = false


func _process(delta: float) -> void:
	if not running:
		return

	value += direction * speed * delta

	if value >= 1.0:
		value = 1.0
		direction = -1.0
	elif value <= 0.0:
		value = 0.0
		direction = 1.0

	line.position = start_pos.lerp(end_pos, value)

func start() -> void:
	value = 0.5
	direction = 1.0
	running = true

func lock() -> float:
	running = false
	return value

func _ready() -> void:
	start()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):   # Space or Enter
		var result := lock()
		print("Stopped at: ", result)
