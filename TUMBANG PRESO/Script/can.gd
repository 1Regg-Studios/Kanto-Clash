extends Node2D

signal result(hit: bool)

@onready var sprite: AnimatedSprite2D = $can

@export var target_direction: float = 0.5       # where the direction must land (0.5 = center)
@export var direction_tolerance: float = 0.1    # how far off is still a hit
@export var target_power: float = 0.7           # where the power must land
@export var power_tolerance: float = 0.1
@export var randomize_target: bool = false      # new sweet spot every round

@export var min_points: int = 50        # points for a hit at the edge of the zone
@export var max_points: int = 100       # points for a hit near the center
@export var perfect_bonus: int = 50     # extra points for a nearly perfect shot
@export var perfect_zone: float = 0.9   # accuracy needed for the bonus (0 to 1)

func _ready() -> void:
	reset_can()

func reset_can() -> void:
	if randomize_target:
		target_direction = randf_range(0.2, 0.8)
		target_power = randf_range(0.3, 0.9)

	# Static: show the first frame of the hit animation without playing it
	sprite.animation = "default"
	sprite.frame = 0
	sprite.stop()

func check_hit(direction_value: float, power_value: float) -> bool:
	print("can received: ", direction_value, " / ", power_value)
	print("needs direction ", target_direction, " +/- ", direction_tolerance)
	print("needs power ", target_power, " +/- ", power_tolerance)

	var direction_ok := absf(direction_value - target_direction) <= direction_tolerance
	var power_ok := absf(power_value - target_power) <= power_tolerance
	var hit := direction_ok and power_ok

	if hit:
		print("HIT! playing animation")
		sprite.play("default")   # use your animation's real name
	else:
		print("MISS")

	result.emit(hit)
	return hit

func get_points(direction_value: float, power_value: float) -> int:
	var d_err := absf(direction_value - target_direction)
	var p_err := absf(power_value - target_power)

	# Outside the sweet spot = miss
	if d_err > direction_tolerance or p_err > power_tolerance:
		return 0

	# 1.0 = dead center, 0.0 = right at the edge
	var accuracy := 1.0 - ((d_err / direction_tolerance) + (p_err / power_tolerance)) / 2.0

	var points := int(round(lerpf(float(min_points), float(max_points), accuracy)))
	if accuracy >= perfect_zone:
		points += perfect_bonus
	return points
