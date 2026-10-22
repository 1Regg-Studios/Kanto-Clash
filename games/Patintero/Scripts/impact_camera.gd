extends Camera2D

@export_range(0.1, 4.0) var base_zoom: float = 1.0
@export_range(0.0, 0.1) var impact_zoom: float = 0.035
@export_range(0.0, 0.1) var max_zoom_bump: float = 0.06
@export_range(0.0, 20.0) var impact_shake: float = 5.0
@export_range(0.0, 30.0) var max_shake: float = 8.0
@export var zoom_recovery_speed: float = 10.0
@export var shake_recovery_speed: float = 34.0

var _zoom_bump := 0.0
var _shake_strength := 0.0


func _ready() -> void:
	add_to_group(&"patintero_cameras")
	make_current()


func _process(delta: float) -> void:
	_zoom_bump = move_toward(_zoom_bump, 0.0, zoom_recovery_speed * delta)
	_shake_strength = move_toward(_shake_strength, 0.0, shake_recovery_speed * delta)
	zoom = Vector2.ONE * base_zoom * (1.0 + _zoom_bump)
	if _shake_strength > 0.01:
		offset = Vector2.from_angle(randf() * TAU) * _shake_strength
	else:
		offset = Vector2.ZERO


func trigger_impact() -> void:
	_zoom_bump = minf(_zoom_bump + impact_zoom, max_zoom_bump)
	_shake_strength = minf(_shake_strength + impact_shake, max_shake)
