extends Node

@export_range(1, 4) var player_id: int = 1
@export var direction_gauge: Node
@export var power_gauge: Node
@export var can: Node2D
@export var min_angle: float = -45.0     # direction range in degrees
@export var max_angle: float = 45.0
@export var min_power: float = 200.0
@export var max_power: float = 1000.0

enum State { IDLE, DIRECTION, POWER }
var state: State = State.IDLE

var direction_value: float = 0.5
var power_value: float = 0.5
var _action: String = ""

func _ready() -> void:
	_action = "p%d_move" % player_id
	print("controller ready | action: ", _action, " | exists: ", InputMap.has_action(_action))
	print("direction_gauge: ", direction_gauge, " | power_gauge: ", power_gauge, " | can: ", can)
	start_aim()

func start_aim() -> void:
	state = State.DIRECTION
	direction_gauge.start()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(_action):
		return
	print("key pressed | state: ", state)

	match state:
		State.DIRECTION:
			direction_value = direction_gauge.lock()
			print("direction locked at: ", direction_value)
			state = State.POWER
			power_gauge.start()
		State.POWER:
			power_value = power_gauge.lock()
			print("power locked at: ", power_value)
			state = State.IDLE
			launch()

func launch() -> void:
	print("launch called | can is: ", can)
	var hit: bool = can.check_hit(direction_value, power_value)
	print("Direction: ", direction_value, " Power: ", power_value, " Hit: ", hit)
