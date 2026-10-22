extends Node2D   # use Control if your gauge is UI and Line is a TextureRect

signal locked(value: float)

@onready var line: TextureRect = $Line   # use Control if Line is a TextureRect

@export var bottom_pos: Vector2 = Vector2(126.0, 571.0)   # line position at 0.0 (weakest)
@export var top_pos: Vector2 = Vector2(126.0, 26.0)       # line position at 1.0 (strongest)
@export var speed: float = 1.0                       # higher = harder
@export var start_value: float = 0.5                 # 0.5 = starts in the middle

var value: float = 0.5
var direction: float = 1.0   # 1 = moving up, -1 = moving down
var running: bool = false

func _ready() -> void:
	value = start_value
	_update_line()

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

	_update_line()

func _update_line() -> void:
	line.position = bottom_pos.lerp(top_pos, value)

func start() -> void:
	value = start_value
	direction = 1.0
	running = true
	_update_line()

func lock() -> float:
	running = false
	locked.emit(value)
	return value
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if running:
			print("Power: ", lock())
		else:
			start()
