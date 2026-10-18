extends Control

const RANDOMIZER_SCENE := "res://src/UI/randomizer/minigame_randomizer.tscn"

const READY_ACTIONS := ["P1_Ready", "P2_Ready", "P3_Ready", "P4_Ready"]

const BOX_TEXTURE := preload("res://assets/Character Select/BOX.png")
const BOX_CHECK_TEXTURE := preload("res://assets/Character Select/BOX CHECK.png")

const READY_MODULATE := Color(1, 1, 1)
const NOT_READY_MODULATE := Color(0.6, 0.48, 0.5)
const TOGGLE_TIME := 0.15

const BLINK_MIN_ALPHA := 0.4
const BLINK_HALF_PERIOD := 0.5

@onready var _prompt: TextureRect = $Prompt
@onready var _portraits: Array[Control] = [
	$Player1/Portrait,
	$Player2/Portrait,
	$Player3/Portrait,
	$Player4/Portrait,
]
@onready var _boxes: Array[TextureRect] = [
	$Player1/Box,
	$Player2/Box,
	$Player3/Box,
	$Player4/Box,
]

var _ready_states: Array[bool] = [false, false, false, false]
var _transitioning := false


func _ready() -> void:
	AudioManager.start_menu_music()
	for portrait in _portraits:
		portrait.modulate = NOT_READY_MODULATE
	var blink := create_tween().set_loops()
	blink.tween_property(_prompt, "modulate:a", BLINK_MIN_ALPHA, BLINK_HALF_PERIOD)
	blink.tween_property(_prompt, "modulate:a", 1.0, BLINK_HALF_PERIOD)


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	for i in range(READY_ACTIONS.size()):
		if event.is_action_pressed(READY_ACTIONS[i]):
			AudioManager.play_ready()
			_set_ready(i, not _ready_states[i])
			get_viewport().set_input_as_handled()
			return


func _set_ready(index: int, ready: bool) -> void:
	_ready_states[index] = ready
	if ready:
		_boxes[index].texture = BOX_CHECK_TEXTURE
		_tween_portrait(index, READY_MODULATE)
	else:
		_boxes[index].texture = BOX_TEXTURE
		_tween_portrait(index, NOT_READY_MODULATE)

	if _all_players_ready():
		_start_game()


func _tween_portrait(index: int, color: Color) -> void:
	var tween := create_tween()
	tween.tween_property(_portraits[index], "modulate", color, TOGGLE_TIME)


func _all_players_ready() -> bool:
	for state in _ready_states:
		if not state:
			return false
	return true


func _start_game() -> void:
	_transitioning = true
	await SceneFader.change_scene(RANDOMIZER_SCENE)
