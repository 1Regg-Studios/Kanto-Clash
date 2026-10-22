extends Control

signal time_expired

@export var round_seconds := 60.0

@onready var _label: Label = $Label

var _time_left := 0.0
var _running := true


func _ready() -> void:
	start_round()


func start_round() -> void:
	_time_left = maxf(round_seconds, 0.0)
	_running = true
	_update_label()


func stop_round() -> void:
	_running = false


func _process(delta: float) -> void:
	if not _running:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	_update_label()
	if _time_left <= 0.0:
		_running = false
		time_expired.emit()


func _update_label() -> void:
	var total := int(ceil(_time_left))
	_label.text = "%02d : %02d" % [total / 60, total % 60]
