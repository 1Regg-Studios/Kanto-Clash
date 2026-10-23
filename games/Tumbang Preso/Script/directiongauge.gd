extends Node2D

@onready var line: TextureRect = $Line
@onready var target_zone: Control = $TargetZone

@export var start_pos: Vector2 = Vector2(0.0, 41.0)    # marker center at the left edge of the track
@export var end_pos: Vector2 = Vector2(853.0, 41.0)    # marker center at the right edge of the track
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

	_update_line()

func start() -> void:
	reset()
	running = true

func lock() -> float:
	running = false
	return value

func _ready() -> void:
	reset()

func reset() -> void:
	running = false
	value = 0.5
	direction = 1.0
	_update_line()

func _update_line() -> void:
	line.position = start_pos.lerp(end_pos, value)

func set_target(target: float, tolerance: float) -> void:
	var low := clampf(target - maxf(tolerance, 0.0), 0.0, 1.0)
	var high := clampf(target + maxf(tolerance, 0.0), 0.0, 1.0)
	target_zone.position.x = lerpf(start_pos.x, end_pos.x, low) + line.size.x * 0.5
	target_zone.size.x = maxf((end_pos.x - start_pos.x) * (high - low), 1.0)
