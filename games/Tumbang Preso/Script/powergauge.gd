extends Node2D

signal locked(value: float)

@onready var line: TextureRect = $Line
@onready var target_zone: Control = $TargetZone

@export var bottom_pos: Vector2 = Vector2(-13.0, 853.0)  # line position at 0.0 (weakest)
@export var top_pos: Vector2 = Vector2(-13.0, 0.0)       # line position at 1.0 (strongest)
@export var speed: float = 1.0                       # higher = harder
@export var start_value: float = 0.5                 # 0.5 = starts in the middle

var value: float = 0.5
var direction: float = 1.0   # 1 = moving up, -1 = moving down
var running: bool = false

func _ready() -> void:
	reset()

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
	reset()
	running = true

func lock() -> float:
	running = false
	locked.emit(value)
	return value

func reset() -> void:
	running = false
	value = clampf(start_value, 0.0, 1.0)
	direction = 1.0
	_update_line()

func set_target(target: float, tolerance: float) -> void:
	var low := clampf(target - maxf(tolerance, 0.0), 0.0, 1.0)
	var high := clampf(target + maxf(tolerance, 0.0), 0.0, 1.0)
	target_zone.position.y = lerpf(bottom_pos.y, top_pos.y, high) + line.size.y * 0.5
	target_zone.size.y = maxf((bottom_pos.y - top_pos.y) * (high - low), 1.0)
